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
      body: jsonEncode({'email': email.trim(), 'password': password}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Error al iniciar sesión: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final accessToken = data['access_token']?.toString() ?? '';
    final refreshToken = data['refresh_token']?.toString() ?? '';

    if (accessToken.isEmpty) {
      throw Exception('El backend no devolvió access_token.');
    }

    await _saveSession(accessToken: accessToken, refreshToken: refreshToken);

    await _saveCurrentUser(accessToken);
  }

  static Future<void> register({required Map<String, dynamic> userData}) async {
    final email = userData['email']?.toString().trim() ?? '';
    final password = userData['password']?.toString() ?? '';

    final firstName =
        userData['firstName']?.toString().trim() ??
        userData['first_name']?.toString().trim() ??
        '';

    final lastName =
        userData['lastName']?.toString().trim() ??
        userData['last_name']?.toString().trim() ??
        '';

    if (email.isEmpty ||
        password.isEmpty ||
        firstName.isEmpty ||
        lastName.isEmpty) {
      throw Exception('Faltan datos obligatorios para registrar la cuenta.');
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Error al registrar usuario: ${response.statusCode} ${response.body}',
      );
    }
  }

  static Future<void> registerAndLogin({
    required Map<String, dynamic> userData,
  }) async {
    final email = userData['email']?.toString().trim() ?? '';
    final password = userData['password']?.toString() ?? '';

    await register(userData: userData);

    await login(email: email, password: password);

    await _mergeLocalUserData(userData);

    await _syncProfileWithBackend(userData);
  }

  static Future<void> _saveSession({
    required String accessToken,
    String refreshToken = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('access_token', accessToken);

    if (refreshToken.isNotEmpty) {
      await prefs.setString('refresh_token', refreshToken);
    }

    await prefs.setBool('sesion_activa', true);
  }

  static Future<void> _saveCurrentUser(String accessToken) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/auth/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200) return;

    final userData = jsonDecode(response.body) as Map<String, dynamic>;

    final backendUserData = <String, dynamic>{
      'id': userData['id']?.toString() ?? '',
      'email': userData['email']?.toString() ?? '',
      'firstName': userData['first_name']?.toString() ?? '',
      'lastName': userData['last_name']?.toString() ?? '',
      'first_name': userData['first_name']?.toString() ?? '',
      'last_name': userData['last_name']?.toString() ?? '',
    };

    await _mergeLocalUserData(backendUserData);
  }

  static Future<void> _mergeLocalUserData(Map<String, dynamic> newData) async {
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

    final mergedUserData = <String, dynamic>{...existingUserData, ...newData};

    await prefs.setString('usuario_actual', jsonEncode(mergedUserData));
  }

  static Future<void> _syncProfileWithBackend(
    Map<String, dynamic> userData,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token') ?? '';

      if (accessToken.isEmpty) return;

      final body = <String, dynamic>{
        'phone': userData['phone']?.toString(),
        'university': userData['university']?.toString(),
        'academic_level': userData['level']?.toString(),
        'career': userData['career']?.toString(),
        'academic_cycle': userData['cycle']?.toString(),
        'bio': userData['description']?.toString(),
        'portfolio_url': userData['portfolio_link']?.toString(),
        'profile_image_base64': userData['profile_image_base64']?.toString(),
        'cv_url': userData['cv_file_name']?.toString(),
      };

      body.removeWhere((key, value) {
        if (value == null) return true;
        if (value is String && value.trim().isEmpty) return true;
        return false;
      });

      if (body.isEmpty) return;

      await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/profiles/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(body),
      );
    } catch (_) {
      // No rompemos el registro si el perfil no se pudo sincronizar.
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.setBool('sesion_activa', false);
  }
}
