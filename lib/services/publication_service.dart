import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/publication_model.dart';

class PublicationService {
  static const String _storageKey = 'publicaciones_feed';

  // ==========================
  // GUARDAR PUBLICACIÓN
  // ==========================
  static Future<void> addPublication(PublicationModel publication) async {
    final prefs = await SharedPreferences.getInstance();

    final publications = await getPublications();

    publications.insert(0, publication);

    final jsonList =
        publications.map((publication) => publication.toJson()).toList();

    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }

  // ==========================
  // OBTENER PUBLICACIONES
  // ==========================
  static Future<List<PublicationModel>> getPublications() async {
    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getString(_storageKey);

    if (data == null || data.isEmpty) {
      return [];
    }

    try {
      final List decoded = jsonDecode(data);

      return decoded.map((item) => PublicationModel.fromJson(item)).toList();
    } catch (e) {
      return [];
    }
  }

  // ==========================
  // ELIMINAR PUBLICACIÓN
  // ==========================
  static Future<void> deletePublication(String id) async {
    final prefs = await SharedPreferences.getInstance();

    final publications = await getPublications();

    publications.removeWhere((publication) => publication.id == id);

    final jsonList =
        publications.map((publication) => publication.toJson()).toList();

    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }

  // ==========================
  // LIMPIAR TODAS
  // ==========================
  static Future<void> clearPublications() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_storageKey);
  }
}
