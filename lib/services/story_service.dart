import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/core/api/api_config.dart';
import 'package:connect_do/services/media_upload_service.dart';

class StoryUser {
  final String id;
  final String name;
  final String photo;

  const StoryUser({required this.id, required this.name, required this.photo});

  factory StoryUser.fromJson(Map<String, dynamic> json) => StoryUser(
    id: json['id'].toString(),
    name:
        '${json['first_name'] ?? ''} ${json['last_name'] ?? ''}'.trim().isEmpty
            ? 'Usuario'
            : '${json['first_name'] ?? ''} ${json['last_name'] ?? ''}'.trim(),
    photo: json['profile_image_base64']?.toString() ?? '',
  );
}

class StoryItem {
  final String id;
  final String type;
  final String url;
  final int? width;
  final int? height;
  final double? duration;
  final String? caption;
  final DateTime createdAt;
  bool viewed;
  final int? viewsCount;

  StoryItem({
    required this.id,
    required this.type,
    required this.url,
    required this.createdAt,
    this.width,
    this.height,
    this.duration,
    this.caption,
    this.viewed = false,
    this.viewsCount,
  });

  bool get isVideo => type == 'video';

  factory StoryItem.fromJson(Map<String, dynamic> json) => StoryItem(
    id: json['id'].toString(),
    type: json['type']?.toString() ?? 'image',
    url: json['url']?.toString() ?? '',
    width: (json['width'] as num?)?.toInt(),
    height: (json['height'] as num?)?.toInt(),
    duration: (json['duration'] as num?)?.toDouble(),
    caption: json['caption']?.toString(),
    createdAt:
        DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
        DateTime.now(),
    viewed: json['viewed'] == true,
    viewsCount: (json['views_count'] as num?)?.toInt(),
  );
}

class StoryGroup {
  final StoryUser user;
  final bool isMe;
  final List<StoryItem> stories;

  /// Historias destacadas del perfil: sin vistas, sin borrar ni responder.
  final bool isHighlight;

  StoryGroup({
    required this.user,
    required this.isMe,
    required this.stories,
    this.isHighlight = false,
  });

  bool get hasUnseen => stories.any((s) => !s.viewed);

  /// La primera sin ver, para empezar por ahí.
  int get firstUnseenIndex {
    final index = stories.indexWhere((s) => !s.viewed);
    return index == -1 ? 0 : index;
  }

  factory StoryGroup.fromJson(Map<String, dynamic> json) => StoryGroup(
    user: StoryUser.fromJson(Map<String, dynamic>.from(json['user'] as Map)),
    isMe: json['is_me'] == true,
    stories: [
      for (final item in (json['stories'] as List? ?? const []))
        StoryItem.fromJson(Map<String, dynamic>.from(item as Map)),
    ],
  );
}

class StoryViewerEntry {
  final StoryUser user;
  final DateTime viewedAt;

  const StoryViewerEntry({required this.user, required this.viewedAt});
}

/// Historias de 24 horas (solo entre contactos).
class StoryService {
  const StoryService._();

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    if (token.isEmpty) throw Exception('Tu sesión expiró.');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static dynamic _decode(http.Response response, String fallback) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body.isEmpty ? null : jsonDecode(response.body);
    }
    var message = fallback;
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['detail'] is String) message = data['detail'];
    } catch (_) {}
    throw Exception(message);
  }

  static Future<List<StoryGroup>> getStories() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/stories'),
      headers: await _headers(),
    );
    final data = _decode(response, 'No se pudieron cargar las historias.');
    return [
      for (final group in (data as List? ?? const []))
        StoryGroup.fromJson(Map<String, dynamic>.from(group as Map)),
    ];
  }

  static Future<void> create(UploadedMedia media, {String? caption}) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/stories'),
      headers: await _headers(),
      body: jsonEncode({
        ...media.toJson()..remove('size_bytes'),
        if (caption != null && caption.trim().isNotEmpty)
          'caption': caption.trim(),
      }),
    );
    _decode(response, 'No se pudo publicar la historia.');
  }

  static Future<void> markViewed(String storyId) async {
    try {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/stories/$storyId/view'),
        headers: await _headers(),
      );
    } catch (_) {}
  }

  static Future<List<StoryViewerEntry>> viewers(String storyId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/stories/$storyId/viewers'),
      headers: await _headers(),
    );
    final data = _decode(response, 'No se pudo cargar quién la vio.');
    return [
      for (final item in (data as List? ?? const []))
        StoryViewerEntry(
          user: StoryUser.fromJson(
            Map<String, dynamic>.from((item as Map)['user'] as Map),
          ),
          viewedAt:
              DateTime.tryParse(item['viewed_at'].toString())?.toLocal() ??
              DateTime.now(),
        ),
    ];
  }

  static Future<void> delete(String storyId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/stories/$storyId'),
      headers: await _headers(),
    );
    _decode(response, 'No se pudo borrar la historia.');
  }
}
