import 'dart:convert';

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:connect_do/core/api/api_config.dart';
import 'package:connect_do/services/media_upload_service.dart';

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
    List<String>? skills,
    bool? isPrivate,
    String? headline,
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
      'skills': skills,
      'is_private': isPrivate,
      'headline': headline,
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

  // =====================================================
  // CV (archivo real en el servidor)
  // =====================================================
  static const int maxCvBytes = 5 * 1024 * 1024;

  static Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    if (token.isEmpty) {
      throw Exception('Tu sesión expiró. Inicia sesión nuevamente.');
    }
    return token;
  }

  static String _detail(http.Response response, String fallback) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['detail'] is String) return data['detail'];
    } catch (_) {}
    return fallback;
  }

  /// Abre el selector y sube el archivo. Devuelve el nombre, o null si la
  /// persona canceló.
  static Future<PlatformFile?> pickAndUploadCv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    await uploadCv(file);
    return file;
  }

  static Future<void> uploadCv(PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw Exception('No se pudo leer el archivo.');
    }
    if (bytes.length > maxCvBytes) {
      throw Exception('El CV no puede pesar más de 5 MB.');
    }

    final request =
        http.MultipartRequest(
            'PUT',
            Uri.parse('${ApiConfig.baseUrl}/profiles/me/cv'),
          )
          ..headers['Authorization'] = 'Bearer ${await _token()}'
          ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: file.name),
          );

    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode != 200) {
      throw Exception(_detail(response, 'No se pudo subir tu CV.'));
    }
  }

  static Future<void> deleteCv() async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/profiles/me/cv'),
      headers: {'Authorization': 'Bearer ${await _token()}'},
    );
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception(_detail(response, 'No se pudo quitar tu CV.'));
    }
  }

  /// Pide un enlace temporal (10 min) y abre el CV en el visor del teléfono.
  static Future<void> openCv(String userId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/profiles/$userId/cv-link'),
      headers: {'Authorization': 'Bearer ${await _token()}'},
    );
    if (response.statusCode != 200) {
      throw Exception(_detail(response, 'No se pudo abrir el CV.'));
    }

    final path = (jsonDecode(response.body) as Map)['path'].toString();
    final opened = await launchUrl(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) throw Exception('No hay una app para abrir el CV.');
  }

  // =====================================================
  // PERFIL DE OTRA PERSONA
  // =====================================================
  static Future<Map<String, dynamic>> getPublicProfile(String userId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/profiles/$userId'),
      headers: {'Authorization': 'Bearer ${await _token()}'},
    );
    if (response.statusCode != 200) {
      throw Exception(_detail(response, 'No se pudo cargar el perfil.'));
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  // =====================================================
  // FOTO DE PERFIL
  // =====================================================
  /// Sube la foto a Cloudinary y la guarda en el perfil. Si Cloudinary aún
  /// no está configurado en el servidor, la guarda como antes (base64).
  /// Devuelve el valor guardado (enlace o base64) para usarlo en el teléfono.
  static Future<String> uploadProfilePhoto(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      final uploaded = await MediaUploadService.upload(
        bytes: bytes,
        fileName: fileName,
        kind: MediaKind.image,
        purpose: MediaPurpose.avatar,
      );
      await updateMyProfile(avatarUrl: uploaded.url);
      return uploaded.url;
    } on MediaUploadException catch (error) {
      if (!error.message.contains('aún no está disponible')) rethrow;
      final value = base64Encode(bytes);
      await updateMyProfile(profileImageBase64: value);
      return value;
    }
  }
}
