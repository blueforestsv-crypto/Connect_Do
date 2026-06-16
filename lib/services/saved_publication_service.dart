import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/models/publication_model.dart';

class SavedPublicationService {
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
