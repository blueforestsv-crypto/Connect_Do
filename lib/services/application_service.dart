import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/services/api_config.dart';

class ApplicationService {
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

  Future<void> applyToPublication({
    required String publicationId,
    String? coverMessage,
  }) async {
    final token = await _getAccessToken();

    final response = await http.post(
      ApiConfig.uri('/applications'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'publication_id': publicationId,
        'cover_message':
            coverMessage ?? 'Hola, me interesa aplicar a esta oportunidad.',
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return;
    }

    if (response.statusCode == 409) {
      throw Exception('Ya aplicaste a esta oportunidad.');
    }

    if (response.statusCode == 400) {
      throw Exception('No puedes aplicar a tu propia publicación.');
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception('Tu sesión expiró. Inicia sesión nuevamente.');
    }

    throw Exception(
      'Error al aplicar: ${response.statusCode} ${response.body}',
    );
  }
}