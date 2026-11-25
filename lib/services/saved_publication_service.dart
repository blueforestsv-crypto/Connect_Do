import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/models/publication_model.dart';
import 'package:connect_do/services/publication_api_service.dart';

/// Antes las guardadas vivían solo en el teléfono; ahora están en el
/// servidor. Esto queda solo para migrar lo que había guardado localmente.
class SavedPublicationService {
  /// Sube al servidor lo guardado localmente y lo borra del teléfono.
  /// Las que ya no existen se descartan.
  static Future<void> migrateToServer() async {
    final local = await getSavedPublications();
    if (local.isEmpty) return;

    final api = PublicationApiService();
    final pending = <PublicationModel>[];
    for (final post in local) {
      try {
        await api.setSaved(post.id, saved: true);
      } catch (error) {
        // Sin red: se reintenta la próxima vez. Si ya no existe, se descarta.
        if (!(error is PublicationApiException && error.statusCode == 404)) {
          pending.add(post);
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    if (pending.isEmpty) {
      await prefs.remove(_storageKey);
    } else {
      await prefs.setString(
        _storageKey,
        jsonEncode(pending.map((post) => post.toJson()).toList()),
      );
    }
  }

  static const String _storageKey = 'saved_publications';

  // ===============================
  // OBTENER PUBLICACIONES GUARDADAS
  // ===============================
  static Future<List<PublicationModel>> getSavedPublications() async {
    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getString(_storageKey);

    if (data == null || data.isEmpty) {
      return [];
    }

    final List decoded = jsonDecode(data);

    return decoded.map((item) => PublicationModel.fromJson(item)).toList();
  }

  // ===============================
  // SABER SI YA ESTÁ GUARDADA
  // ===============================
  static Future<bool> isSaved(String publicationId) async {
    final savedPublications = await getSavedPublications();

    return savedPublications.any((post) => post.id == publicationId);
  }

  // ===============================
  // GUARDAR PUBLICACIÓN
  // ===============================
  static Future<void> savePublication(PublicationModel publication) async {
    final prefs = await SharedPreferences.getInstance();

    final savedPublications = await getSavedPublications();

    final alreadySaved = savedPublications.any(
      (post) => post.id == publication.id,
    );

    if (!alreadySaved) {
      savedPublications.insert(0, publication);
    }

    final jsonList = savedPublications.map((post) => post.toJson()).toList();

    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }

  // ===============================
  // QUITAR DE GUARDADOS
  // ===============================
  static Future<void> removeSavedPublication(String publicationId) async {
    final prefs = await SharedPreferences.getInstance();

    final savedPublications = await getSavedPublications();

    savedPublications.removeWhere((post) => post.id == publicationId);

    final jsonList = savedPublications.map((post) => post.toJson()).toList();

    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }

  // ===============================
  // ALTERNAR GUARDADO
  // ===============================
  static Future<bool> toggleSaved(PublicationModel publication) async {
    final currentlySaved = await isSaved(publication.id);

    if (currentlySaved) {
      await removeSavedPublication(publication.id);
      return false;
    } else {
      await savePublication(publication);
      return true;
    }
  }

  // ===============================
  // LIMPIAR GUARDADOS
  // ===============================
  static Future<void> clearSavedPublications() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_storageKey);
  }
}
