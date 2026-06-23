import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/core/api/api_config.dart';
import 'package:connect_do/models/publication_model.dart';

class PublicationService {
  static const String _storageKey = 'publicaciones_feed';

  // ==========================
  // GUARDAR PUBLICACIÓN LOCAL
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
  // OBTENER PUBLICACIONES LOCALES
  // ==========================
  static Future<List<PublicationModel>> getPublications() async {
    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getString(_storageKey);

    if (data == null || data.isEmpty) {
      return [];
    }

    try {
      final List decoded = jsonDecode(data);

      return decoded
          .map(
            (item) => PublicationModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ==========================
  // OBTENER PUBLICACIONES DEL BACKEND
  // ==========================
  static Future<List<PublicationModel>> getPublicationsFromBackend({
    int limit = 20,
    int offset = 0,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.publications}?limit=$limit&offset=$offset',
    );

    final response = await http.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Error al cargar publicaciones: ${response.statusCode} ${response.body}',
      );
    }

    final decodedBody = jsonDecode(response.body);

    if (decodedBody is List) {
      return decodedBody
          .map(
            (item) => PublicationModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }

    if (decodedBody is Map<String, dynamic> && decodedBody['items'] is List) {
      final items = decodedBody['items'] as List;

      return items
          .map(
            (item) => PublicationModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }

    throw Exception('Formato de publicaciones no reconocido.');
  }

  // ==========================
  // CREAR PUBLICACIÓN EN BACKEND
  // ==========================
  static Future<PublicationModel> createPublicationOnBackend({
    required String title,
    required String description,
    required String type,
    String? location,
    String? modality,
    String? imageUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final token =
        prefs.getString('access_token') ??
        prefs.getString('accessToken') ??
        prefs.getString('token');

    if (token == null || token.isEmpty) {
      throw Exception('No se encontró el token de sesión.');
    }

    final body = <String, dynamic>{
      'title': title,
      'description': description,
      'type': type,
      'location': location,
      'modality': modality,
      'image_url': imageUrl,
    };

    body.removeWhere((key, value) {
      if (value == null) return true;
      if (value is String && value.trim().isEmpty) return true;
      return false;
    });

    final response = await http.post(
      Uri.parse(ApiConfig.publications),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Error al crear publicación: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    return PublicationModel.fromJson(data);
  }

  // ==========================
  // ELIMINAR PUBLICACIÓN LOCAL
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
  // LIMPIAR TODAS LAS PUBLICACIONES LOCALES
  // ==========================
  static Future<void> clearPublications() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_storageKey);
  }
}
