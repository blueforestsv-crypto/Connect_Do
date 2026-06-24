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
  // MENSAJES CON CONTACTO
  // ===============================
  static Future<List<Map<String, dynamic>>> getMessages({
    required String contactId,
    int limit = 50,
    int offset = 0,
  }) async {
    final headers = await _headers();

    final response = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/chats/$contactId/messages?limit=$limit&offset=$offset',
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
  }) async {
    final headers = await _headers();

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/chats/$contactId/messages'),
      headers: headers,
      body: jsonEncode({'content': content}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Error al enviar mensaje: ${response.statusCode} ${response.body}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

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
