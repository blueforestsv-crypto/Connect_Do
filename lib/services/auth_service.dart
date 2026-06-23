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

    final existingUserJson = prefs.getString('usuario_actual');

    Map<String, dynamic> existingUserData = {};

    if (existingUserJson != null && existingUserJson.isNotEmpty) {
      try {
        existingUserData = jsonDecode(existingUserJson) as Map<String, dynamic>;
      } catch (_) {
        existingUserData = {};
      }
    }

    final backendUserData = <String, dynamic>{
      'id': userData['id']?.toString() ?? '',
      'email': userData['email']?.toString() ?? '',
      'firstName': userData['first_name']?.toString() ?? '',
      'lastName': userData['last_name']?.toString() ?? '',
    };

    final mergedUserData = <String, dynamic>{
      ...existingUserData,
      ...backendUserData,
    };

    mergedUserData['profile_image_base64'] =
        existingUserData['profile_image_base64']?.toString() ?? '';

    mergedUserData['profile_image_path'] =
        existingUserData['profile_image_path']?.toString() ?? '';

    mergedUserData['google_photo_url'] =
        existingUserData['google_photo_url']?.toString() ?? '';

    mergedUserData['cv_file_base64'] =
        existingUserData['cv_file_base64']?.toString() ?? '';

    mergedUserData['cv_file_name'] =
        existingUserData['cv_file_name']?.toString() ?? '';

    mergedUserData['cv_file_path'] =
        existingUserData['cv_file_path']?.toString() ?? '';

    mergedUserData['cv_path'] = existingUserData['cv_path']?.toString() ?? '';

    mergedUserData['cv_file_size'] = existingUserData['cv_file_size'] ?? 0;

    mergedUserData['career'] = existingUserData['career']?.toString() ?? '';

    mergedUserData['cycle'] = existingUserData['cycle']?.toString() ?? '';

    mergedUserData['phone'] = existingUserData['phone']?.toString() ?? '';

    mergedUserData['description'] =
        existingUserData['description']?.toString() ?? '';

    mergedUserData['portfolio_link'] =
        existingUserData['portfolio_link']?.toString() ?? '';

    mergedUserData['skills'] = existingUserData['skills'] ?? [];

    await prefs.setString('usuario_actual', jsonEncode(mergedUserData));
  }
}
