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
    final cleanEmail = email.trim();

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': cleanEmail, 'password': password}),
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
    await _syncCurrentProfileFromBackend();
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

    await _mergeLocalUserData(userData, preserveOnlyIfSameUser: true);

    await _syncProfileWithBackend(userData);
    await _syncCurrentProfileFromBackend();
  }

  static Future<void> _saveSession({
    required String accessToken,
    String refreshToken = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('access_token', accessToken);

    if (refreshToken.isNotEmpty) {
      await prefs.setString('refresh_token', refreshToken);
    } else {
      await prefs.remove('refresh_token');
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

    await _mergeLocalUserData(backendUserData, preserveOnlyIfSameUser: true);
  }

  static Future<void> _mergeLocalUserData(
    Map<String, dynamic> newData, {
    bool preserveOnlyIfSameUser = false,
  }) async {
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

    final existingId = existingUserData['id']?.toString() ?? '';
    final existingEmail = existingUserData['email']?.toString() ?? '';

    final newId = newData['id']?.toString() ?? '';
    final newEmail = newData['email']?.toString() ?? '';

    final sameUser =
        (existingId.isNotEmpty && newId.isNotEmpty && existingId == newId) ||
        (existingEmail.isNotEmpty &&
            newEmail.isNotEmpty &&
            existingEmail.toLowerCase() == newEmail.toLowerCase());

    final Map<String, dynamic> mergedUserData;

    if (preserveOnlyIfSameUser && !sameUser) {
      mergedUserData = <String, dynamic>{
        ...newData,
        'profile_image_base64':
            newData['profile_image_base64']?.toString() ?? '',
        'profile_image_path': newData['profile_image_path']?.toString() ?? '',
        'profile_image_name': newData['profile_image_name']?.toString() ?? '',
        'google_photo_url': newData['google_photo_url']?.toString() ?? '',

        // CV local / demo
        'cv_url': newData['cv_url']?.toString() ?? '',
        'cv_file_base64': newData['cv_file_base64']?.toString() ?? '',
        'cv_file_name': newData['cv_file_name']?.toString() ?? '',
        'cv_file_path': newData['cv_file_path']?.toString() ?? '',
        'cv_path': newData['cv_path']?.toString() ?? '',
        'cv_file_size': newData['cv_file_size'] ?? 0,

        'career': newData['career']?.toString() ?? '',
        'cycle': newData['cycle']?.toString() ?? '',
        'phone': newData['phone']?.toString() ?? '',
        'description': newData['description']?.toString() ?? '',
        'portfolio_link': newData['portfolio_link']?.toString() ?? '',
        'skills': newData['skills'] ?? [],
      };
    } else {
      mergedUserData = <String, dynamic>{...existingUserData, ...newData};

      // Blindaje: si newData no trae CV, conservar el CV anterior.
      mergedUserData['cv_url'] =
          newData['cv_url']?.toString().isNotEmpty == true
              ? newData['cv_url']?.toString()
              : existingUserData['cv_url']?.toString() ?? '';

      mergedUserData['cv_file_base64'] =
          newData['cv_file_base64']?.toString().isNotEmpty == true
              ? newData['cv_file_base64']?.toString()
              : existingUserData['cv_file_base64']?.toString() ?? '';

      mergedUserData['cv_file_name'] =
          newData['cv_file_name']?.toString().isNotEmpty == true
              ? newData['cv_file_name']?.toString()
              : existingUserData['cv_file_name']?.toString() ?? '';

      mergedUserData['cv_file_path'] =
          newData['cv_file_path']?.toString().isNotEmpty == true
              ? newData['cv_file_path']?.toString()
              : existingUserData['cv_file_path']?.toString() ?? '';

      mergedUserData['cv_path'] =
          newData['cv_path']?.toString().isNotEmpty == true
              ? newData['cv_path']?.toString()
              : existingUserData['cv_path']?.toString() ?? '';

      mergedUserData['cv_file_size'] =
          newData['cv_file_size'] ?? existingUserData['cv_file_size'] ?? 0;
    }

    await prefs.setString('usuario_actual', jsonEncode(mergedUserData));
  }

  static Future<void> _syncCurrentProfileFromBackend() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token') ?? '';

      if (accessToken.isEmpty) return;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/profiles/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode != 200) return;

      final profileData = jsonDecode(response.body) as Map<String, dynamic>;

      final currentUserJson = prefs.getString('usuario_actual');

      Map<String, dynamic> currentUser = {};

      if (currentUserJson != null && currentUserJson.isNotEmpty) {
        try {
          currentUser = jsonDecode(currentUserJson) as Map<String, dynamic>;
        } catch (_) {
          currentUser = {};
        }
      }

      // Guardamos backup local antes de actualizar desde backend.
      final localCvUrl = currentUser['cv_url']?.toString() ?? '';
      final localCvFileBase64 = currentUser['cv_file_base64']?.toString() ?? '';
      final localCvFileName = currentUser['cv_file_name']?.toString() ?? '';
      final localCvFilePath = currentUser['cv_file_path']?.toString() ?? '';
      final localCvPath = currentUser['cv_path']?.toString() ?? '';
      final localCvFileSize = currentUser['cv_file_size'] ?? 0;

      currentUser['phone'] = profileData['phone']?.toString() ?? '';
      currentUser['university'] = profileData['university']?.toString() ?? '';
      currentUser['level'] = profileData['academic_level']?.toString() ?? '';
      currentUser['career'] = profileData['career']?.toString() ?? '';
      currentUser['cycle'] = profileData['academic_cycle']?.toString() ?? '';
      currentUser['description'] = profileData['bio']?.toString() ?? '';
      currentUser['portfolio_link'] =
          profileData['portfolio_url']?.toString() ?? '';

      currentUser['profile_image_base64'] =
          profileData['profile_image_base64']?.toString() ?? '';

      currentUser['google_photo_url'] =
          profileData['avatar_url']?.toString() ?? '';

      // CV: si backend no devuelve CV, conservar lo local.
      final backendCvUrl = profileData['cv_url']?.toString() ?? '';

      currentUser['cv_url'] =
          backendCvUrl.isNotEmpty ? backendCvUrl : localCvUrl;

      currentUser['cv_file_base64'] = localCvFileBase64;
      currentUser['cv_file_name'] = localCvFileName;
      currentUser['cv_file_path'] = localCvFilePath;
      currentUser['cv_path'] = localCvPath;
      currentUser['cv_file_size'] = localCvFileSize;

      await prefs.setString('usuario_actual', jsonEncode(currentUser));
    } catch (_) {
      // No rompemos login por un fallo de perfil.
    }
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

        // Por ahora el backend maneja cv_url como referencia/nombre demo.
        'cv_url':
            userData['cv_url']?.toString().isNotEmpty == true
                ? userData['cv_url']?.toString()
                : userData['cv_file_name']?.toString(),
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

    // Para evitar que aparezca usuario anterior en login rápido.
    await prefs.remove('usuario_actual');
  }
}
