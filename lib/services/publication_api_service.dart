import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/models/publication_model.dart';
import 'package:connect_do/services/api_config.dart';

class PublicationApiService {
  Future<String> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();

    final token =
        prefs.getString('access_token') ??
        prefs.getString('accessToken') ??
        prefs.getString('token');

    if (token == null || token.isEmpty) {
      throw Exception('No se encontró token de sesión.');
    }

    return token;
  }

  Future<List<PublicationModel>> getPublications({
    String? type,
    int limit = 20,
    int offset = 0,
  }) async {
    final token = await _getAccessToken();

    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    if (type != null && type.trim().isNotEmpty) {
      queryParams['type'] = type.trim();
    }

    final response = await http.get(
      ApiConfig.uri('/publications', queryParams),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Error al cargar publicaciones: ${response.statusCode} ${response.body}',
      );
    }

    final decodedBody = jsonDecode(response.body);

    if (decodedBody is! List) {
      throw Exception('La respuesta del servidor no es una lista válida.');
    }

    return decodedBody
        .whereType<Map<String, dynamic>>()
        .map(PublicationModel.fromJson)
        .toList();
  }

  Future<void> deletePublication(String publicationId) async {
    final token = await _getAccessToken();

    final response = await http.delete(
      ApiConfig.uri('/publications/$publicationId'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200 &&
        response.statusCode != 202 &&
        response.statusCode != 204) {
      throw Exception(
        'Error al eliminar publicación: ${response.statusCode} ${response.body}',
      );
    }
  }
}
