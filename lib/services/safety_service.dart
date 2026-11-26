import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/core/api/api_config.dart';

class BlockedUser {
  final String id;
  final String name;
  final String photo;

  const BlockedUser({
    required this.id,
    required this.name,
    required this.photo,
  });
}

class AdminReport {
  final String id;
  final String targetType;
  final String targetId;
  final String? targetUserId;
  final String targetUserName;
  final String reason;
  final String? details;
  final String reporterName;
  final String? preview;
  final int reportsAgainstUser;
  final DateTime createdAt;

  const AdminReport({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.targetUserId,
    required this.targetUserName,
    required this.reason,
    required this.details,
    required this.reporterName,
    required this.preview,
    required this.reportsAgainstUser,
    required this.createdAt,
  });

  factory AdminReport.fromJson(Map<String, dynamic> json) => AdminReport(
    id: json['id'].toString(),
    targetType: json['target_type'].toString(),
    targetId: json['target_id'].toString(),
    targetUserId: json['target_user_id']?.toString(),
    targetUserName: json['target_user_name']?.toString() ?? '',
    reason: json['reason'].toString(),
    details: json['details']?.toString(),
    reporterName: json['reporter_name']?.toString() ?? '',
    preview: json['preview']?.toString(),
    reportsAgainstUser: (json['reports_against_user'] as num?)?.toInt() ?? 0,
    createdAt:
        DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
        DateTime.now(),
  );
}

/// Motivos de reporte, en el idioma de la app.
const reportReasons = <String, String>{
  'spam': 'Spam o publicidad engañosa',
  'scam': 'Estafa o fraude',
  'fake_job': 'Oferta de empleo falsa',
  'harassment': 'Acoso o bullying',
  'hate': 'Discurso de odio',
  'nudity': 'Desnudos o contenido sexual',
  'violence': 'Violencia o amenazas',
  'impersonation': 'Se hace pasar por otra persona',
  'other': 'Otro motivo',
};

/// Bloquear, reportar, moderar y eliminar la cuenta.
class SafetyService {
  const SafetyService._();

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    if (token.isEmpty) throw Exception('Tu sesión expiró.');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static void _check(http.Response response, String fallback) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    var message = fallback;
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['detail'] is String) message = data['detail'];
    } catch (_) {}
    throw Exception(message);
  }

  static Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: query);

  // ---------------- bloquear ----------------
  static Future<void> block(String userId) async {
    final response = await http.post(
      _uri('/users/$userId/block'),
      headers: await _headers(),
    );
    _check(response, 'No se pudo bloquear.');
  }

  static Future<void> unblock(String userId) async {
    final response = await http.delete(
      _uri('/users/$userId/block'),
      headers: await _headers(),
    );
    _check(response, 'No se pudo desbloquear.');
  }

  static Future<List<BlockedUser>> blocked() async {
    final response = await http.get(
      _uri('/users/blocked'),
      headers: await _headers(),
    );
    _check(response, 'No se pudo cargar la lista.');
    return [
      for (final item in jsonDecode(response.body) as List)
        BlockedUser(
          id: item['id'].toString(),
          name: '${item['first_name']} ${item['last_name']}'.trim(),
          photo: item['profile_image_base64']?.toString() ?? '',
        ),
    ];
  }

  // ---------------- reportar ----------------
  static Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
  }) async {
    final response = await http.post(
      _uri('/reports'),
      headers: await _headers(),
      body: jsonEncode({
        'target_type': targetType,
        'target_id': targetId,
        'reason': reason,
        if (details != null && details.trim().isNotEmpty)
          'details': details.trim(),
      }),
    );
    _check(response, 'No se pudo enviar el reporte.');
  }

  // ---------------- moderación ----------------
  static Future<List<AdminReport>> adminReports({
    String status = 'pending',
  }) async {
    final response = await http.get(
      _uri('/admin/reports', {'status': status}),
      headers: await _headers(),
    );
    _check(response, 'No se pudieron cargar los reportes.');
    return [
      for (final item in jsonDecode(response.body) as List)
        AdminReport.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  }

  /// [action]: dismiss | remove_content | suspend_user
  static Future<void> resolve(String reportId, String action) async {
    final response = await http.post(
      _uri('/admin/reports/$reportId/resolve'),
      headers: await _headers(),
      body: jsonEncode({'action': action}),
    );
    _check(response, 'No se pudo resolver el reporte.');
  }

  // ---------------- eliminar cuenta ----------------
  static Future<void> deleteAccount({String? password, String? confirm}) async {
    final response = await http.delete(
      _uri('/auth/account'),
      headers: await _headers(),
      body: jsonEncode({
        if (password != null && password.isNotEmpty) 'password': password,
        if (confirm != null) 'confirm': confirm,
      }),
    );
    _check(response, 'No se pudo eliminar la cuenta.');
  }
}
