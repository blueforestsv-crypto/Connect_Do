import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/core/api/api_config.dart';

class ChatService {
  const ChatService._();

  static Future<String> _getAccessToken() async {
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

  static Future<Map<String, String>> _headers() async {
    final token = await _getAccessToken();

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ===============================
  // CONVERSACIONES
  // ===============================
  static Future<List<Map<String, dynamic>>> getConversations() async {
    final headers = await _headers();

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/chats/conversations'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Error al cargar conversaciones: ${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! List) {
      return [];
    }

    return decoded.map((item) => item as Map<String, dynamic>).toList();
  }

  // ===============================
  // TOTAL DE MENSAJES NO LEÍDOS
  // ===============================
  static Future<int> getTotalUnreadMessages() async {
    // Ruta ligera: solo el número (antes se descargaban todas las
    // conversaciones con sus fotos para sumarlo).
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/chats/unread-count'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map && data['total'] is num) {
        // Más los de grupos (si el servidor aún no los tiene, cuenta 0).
        return (data['total'] as num).toInt() + await _groupsUnread();
      }
    }

    // Servidor anterior: se calcula como antes.
    final conversations = await getConversations();

    int total = 0;

    for (final conversation in conversations) {
      final unread = conversation['unread_count'];

      if (unread is int) {
        total += unread;
      } else {
        total += int.tryParse(unread?.toString() ?? '0') ?? 0;
      }
    }

    return total;
  }

  static Future<int> _groupsUnread() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/groups/unread-count'),
        headers: await _headers(),
      );
      if (response.statusCode != 200) return 0;
      return ((jsonDecode(response.body)['total'] as num?) ?? 0).toInt();
    } catch (_) {
      return 0;
    }
  }

  // ===============================
  // MENSAJES CON CONTACTO
  // ===============================
  static Future<List<Map<String, dynamic>>> getMessages({
    required String contactId,
    int limit = 50,
    int offset = 0,

    /// Solo los mensajes posteriores a esta fecha (actualizaciones ligeras).
    DateTime? after,
  }) async {
    final headers = await _headers();

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/chats/$contactId/messages').replace(
        queryParameters: {
          'limit': '$limit',
          'offset': '$offset',
          // La foto de perfil ya la tiene la pantalla: no se vuelve a bajar.
          'include_images': 'false',
          if (after != null) 'after': after.toUtc().toIso8601String(),
        },
      ),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Error al cargar mensajes: ${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! List) {
      return [];
    }

    return decoded.map((item) => item as Map<String, dynamic>).toList();
  }

  // ===============================
  // ENVIAR MENSAJE
  // ===============================
  static Future<Map<String, dynamic>> sendMessage({
    required String contactId,
    required String content,

    /// Foto, video o nota de voz ya subida a Cloudinary.
    Map<String, dynamic>? attachment,

    /// Mensaje que se responde citándolo.
    String? replyToId,
  }) async {
    final headers = await _headers();

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/chats/$contactId/messages'),
      headers: headers,
      body: jsonEncode({
        'content': content,
        if (attachment != null) 'attachment': attachment,
        if (replyToId != null) 'reply_to_id': replyToId,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Error al enviar mensaje: ${response.statusCode} ${response.body}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ===============================
  // REACCIONAR / ELIMINAR / EN LÍNEA
  // ===============================

  /// [emoji] null quita mi reacción. Devuelve todas las reacciones.
  static Future<Map<String, String>> react(
    String messageId,
    String? emoji,
  ) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/chats/messages/$messageId/react'),
      headers: await _headers(),
      body: jsonEncode({'emoji': emoji}),
    );
    if (response.statusCode != 200) {
      throw Exception('No se pudo reaccionar.');
    }
    return reactionsFrom(jsonDecode(response.body)['reactions']);
  }

  /// Eliminar para todos (solo mis mensajes).
  static Future<void> deleteForEveryone(String messageId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/chats/messages/$messageId'),
      headers: await _headers(),
    );
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('No se pudo eliminar.');
    }
  }

  /// {online, last_seen_at} del contacto.
  static Future<(bool, DateTime?)> presence(String contactId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/chats/$contactId/presence'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) return (false, null);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      data['online'] == true,
      DateTime.tryParse(data['last_seen_at']?.toString() ?? '')?.toLocal(),
    );
  }

  static Map<String, String> reactionsFrom(dynamic raw) => {
    if (raw is Map)
      for (final entry in raw.entries)
        entry.key.toString(): entry.value.toString(),
  };

  // ===============================
  // MARCAR COMO LEÍDOS
  // ===============================
  static Future<void> markAsRead({required String contactId}) async {
    final headers = await _headers();

    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/chats/$contactId/read'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Error al marcar mensajes como leídos: ${response.statusCode} ${response.body}',
      );
    }
  }
}
