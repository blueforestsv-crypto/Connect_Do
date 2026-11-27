import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/core/api/api_config.dart';

/// Miembro de un grupo (o autor de un mensaje del grupo).
class GroupPerson {
  final String id;
  final String name;
  final String photo;
  final String role;

  const GroupPerson({
    required this.id,
    required this.name,
    this.photo = '',
    this.role = 'member',
  });

  bool get isAdmin => role == 'admin';

  factory GroupPerson.fromJson(Map<String, dynamic> json) => GroupPerson(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? 'Usuario',
    photo: json['profile_image_base64']?.toString() ?? '',
    role: json['role']?.toString() ?? 'member',
  );
}

class ChatGroup {
  final String id;
  final String name;
  final String photoUrl;
  final List<GroupPerson> members;
  final String myRole;
  final Map<String, dynamic>? lastMessage;
  final int unreadCount;

  const ChatGroup({
    required this.id,
    required this.name,
    this.photoUrl = '',
    this.members = const [],
    this.myRole = 'member',
    this.lastMessage,
    this.unreadCount = 0,
  });

  bool get iAmAdmin => myRole == 'admin';

  DateTime? get lastActivity =>
      DateTime.tryParse(
        lastMessage?['created_at']?.toString() ?? '',
      )?.toLocal();

  factory ChatGroup.fromJson(Map<String, dynamic> json) => ChatGroup(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? 'Grupo',
    photoUrl: json['photo_url']?.toString() ?? '',
    members: [
      for (final m in (json['members'] as List? ?? const []))
        GroupPerson.fromJson(Map<String, dynamic>.from(m as Map)),
    ],
    myRole: json['my_role']?.toString() ?? 'member',
    lastMessage:
        json['last_message'] is Map
            ? Map<String, dynamic>.from(json['last_message'] as Map)
            : null,
    unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
  );
}

/// Chats grupales.
class GroupService {
  const GroupService._();

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: query);

  static String _error(http.Response response, String fallback) {
    try {
      final detail = jsonDecode(response.body)['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
    } catch (_) {}
    return fallback;
  }

  static Future<List<ChatGroup>> list() async {
    final response = await http.get(_uri('/groups'), headers: await _headers());
    // Servidor sin grupos todavía: simplemente no hay.
    if (response.statusCode == 404) return [];
    if (response.statusCode != 200) {
      throw Exception('No se pudieron cargar los grupos.');
    }
    return [
      for (final g in jsonDecode(response.body) as List)
        ChatGroup.fromJson(Map<String, dynamic>.from(g as Map)),
    ];
  }

  static Future<ChatGroup> get(String id) async {
    final response = await http.get(
      _uri('/groups/$id'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception(_error(response, 'No se pudo abrir el grupo.'));
    }
    return ChatGroup.fromJson(jsonDecode(response.body));
  }

  static Future<ChatGroup> create(String name, List<String> memberIds) async {
    final response = await http.post(
      _uri('/groups'),
      headers: await _headers(),
      body: jsonEncode({'name': name, 'member_ids': memberIds}),
    );
    if (response.statusCode != 201) {
      throw Exception(_error(response, 'No se pudo crear el grupo.'));
    }
    return ChatGroup.fromJson(jsonDecode(response.body));
  }

  static Future<ChatGroup> rename(String id, String name) async {
    final response = await http.patch(
      _uri('/groups/$id'),
      headers: await _headers(),
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode != 200) {
      throw Exception(_error(response, 'No se pudo cambiar el nombre.'));
    }
    return ChatGroup.fromJson(jsonDecode(response.body));
  }

  static Future<ChatGroup> addMembers(String id, List<String> userIds) async {
    final response = await http.post(
      _uri('/groups/$id/members'),
      headers: await _headers(),
      body: jsonEncode({'user_ids': userIds}),
    );
    if (response.statusCode != 200) {
      throw Exception(_error(response, 'No se pudo agregar.'));
    }
    return ChatGroup.fromJson(jsonDecode(response.body));
  }

  /// Sacar a alguien (admin) o salir (mi propio id).
  static Future<void> removeMember(String id, String userId) async {
    final response = await http.delete(
      _uri('/groups/$id/members/$userId'),
      headers: await _headers(),
    );
    if (response.statusCode != 204) {
      throw Exception(_error(response, 'No se pudo completar.'));
    }
  }

  static Future<List<Map<String, dynamic>>> messages(
    String id, {
    DateTime? after,
  }) async {
    final response = await http.get(
      _uri('/groups/$id/messages', {
        'limit': '50',
        if (after != null) 'after': after.toUtc().toIso8601String(),
      }),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('No se pudieron cargar los mensajes.');
    }
    return [
      for (final m in jsonDecode(response.body) as List)
        Map<String, dynamic>.from(m as Map),
    ];
  }

  static Future<Map<String, dynamic>> send(
    String id, {
    required String content,
    Map<String, dynamic>? attachment,
    String? replyToId,
  }) async {
    final response = await http.post(
      _uri('/groups/$id/messages'),
      headers: await _headers(),
      body: jsonEncode({
        'content': content,
        if (attachment != null) 'attachment': attachment,
        if (replyToId != null) 'reply_to_id': replyToId,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception(_error(response, 'No se pudo enviar.'));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<void> markRead(String id) async {
    await http.post(_uri('/groups/$id/read'), headers: await _headers());
  }

  static Future<Map<String, String>> react(
    String messageId,
    String? emoji,
  ) async {
    final response = await http.post(
      _uri('/groups/messages/$messageId/react'),
      headers: await _headers(),
      body: jsonEncode({'emoji': emoji}),
    );
    if (response.statusCode != 200) throw Exception('No se pudo reaccionar.');
    final raw = jsonDecode(response.body)['reactions'];
    return {
      if (raw is Map)
        for (final e in raw.entries) e.key.toString(): e.value.toString(),
    };
  }

  static Future<void> deleteForEveryone(String messageId) async {
    final response = await http.delete(
      _uri('/groups/messages/$messageId'),
      headers: await _headers(),
    );
    if (response.statusCode != 204) throw Exception('No se pudo eliminar.');
  }
}
