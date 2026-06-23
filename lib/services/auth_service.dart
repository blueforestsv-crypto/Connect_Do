import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/core/api/api_config.dart';

class AuthService {
  const AuthService._();

  static Future<void> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Error al iniciar sesión: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final accessToken = data['access_token']?.toString();
    final refreshToken = data['refresh_token']?.toString();

    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('El backend no devolvió access_token.');
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('access_token', accessToken);

    if (refreshToken != null && refreshToken.isNotEmpty) {
      await prefs.setString('refresh_token', refreshToken);
    }

    await prefs.setBool('sesion_activa', true);

    await _saveCurrentUser(accessToken);
  }

  static Future<void> _saveCurrentUser(String accessToken) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/auth/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200) {
      return;
    }

    final userData = jsonDecode(response.body) as Map<String, dynamic>;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'usuario_actual',
      jsonEncode({
        'id': userData['id']?.toString() ?? '',
        'email': userData['email']?.toString() ?? '',
        'firstName': userData['first_name']?.toString() ?? '',
        'lastName': userData['last_name']?.toString() ?? '',
        'profile_image_path': '',
        'google_photo_url': '',
      }),
    );
  }
}
