import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/core/api/api_config.dart';
import 'package:connect_do/models/notification_model.dart';

/// Notificaciones del servidor (likes, comentarios, mensajes, contactos...).
class NotificationService {
  const NotificationService._();

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    if (token.isEmpty) {
      throw Exception('No se encontró token de sesión.');
    }

    return {'Accept': 'application/json', 'Authorization': 'Bearer $token'};
  }

  static Future<List<NotificationModel>> getNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/notifications?limit=$limit&offset=$offset',
      ),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      throw Exception('No se pudieron cargar las notificaciones.');
    }

    final data = jsonDecode(response.body);
    if (data is! List) return [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(NotificationModel.fromJson)
        .toList();
  }

  /// Total sin leer, para el punto rojo de la campana. Devuelve 0 si falla.
  static Future<int> getUnreadCount() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/notifications/unread-count'),
        headers: await _headers(),
      );

      if (response.statusCode != 200) return 0;

      final data = jsonDecode(response.body);
      return (data is Map ? data['unread_count'] as num? : null)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> markAsRead(String id) async {
    await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/notifications/$id/read'),
      headers: await _headers(),
    );
  }

  static Future<void> markAllAsRead() async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/notifications/read-all'),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      throw Exception('No se pudieron marcar como leídas.');
    }
  }
}
