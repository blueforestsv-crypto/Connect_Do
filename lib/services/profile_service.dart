import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/core/api/api_config.dart';

class ProfileService {
  const ProfileService._();

  static Future<Map<String, dynamic>?> getMyProfile() async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString('access_token');

    if (token == null || token.isEmpty) {
      return null;
    }

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/profiles/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      return null;
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>?> updateMyProfile({
    String? phone,
    String? university,
    String? academicLevel,
    String? career,
    String? academicCycle,
    String? bio,
    String? portfolioUrl,
    String? avatarUrl,
    String? profileImageBase64,
    String? cvUrl,
    bool? isPrivate,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString('access_token');

    if (token == null || token.isEmpty) {
      throw Exception('No se encontró token de sesión.');
    }

    final body = <String, dynamic>{
      'phone': phone,
      'university': university,
      'academic_level': academicLevel,
      'career': career,
      'academic_cycle': academicCycle,
      'bio': bio,
      'portfolio_url': portfolioUrl,
      'avatar_url': avatarUrl,
      'profile_image_base64': profileImageBase64,
      'cv_url': cvUrl,
      'is_private': isPrivate,
    };

    body.removeWhere((key, value) => value == null);

    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/profiles/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Error al actualizar perfil: ${response.statusCode} ${response.body}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
