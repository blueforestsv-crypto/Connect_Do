import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/core/api/api_config.dart';
import 'package:connect_do/models/publication_model.dart';
import 'package:connect_do/services/story_service.dart';

class PersonCard {
  final String id;
  final String name;
  final String? headline;
  final String? career;
  final String? university;
  final String photo;
  final bool isCompany;
  final bool verified;
  bool isFollowing;
  final String? reason;

  PersonCard({
    required this.id,
    required this.name,
    required this.photo,
    this.headline,
    this.career,
    this.university,
    this.isCompany = false,
    this.verified = false,
    this.isFollowing = false,
    this.reason,
  });

  /// "Estudiante de Sistemas · UES" o el titular.
  String get subtitle =>
      (headline ?? '').isNotEmpty
          ? headline!
          : [
            if ((career ?? '').isNotEmpty) career!,
            if ((university ?? '').isNotEmpty) university!,
          ].join(' · ');

  factory PersonCard.fromJson(Map<String, dynamic> json) => PersonCard(
    id: json['id'].toString(),
    name: json['name']?.toString() ?? 'Usuario',
    photo: json['profile_image_base64']?.toString() ?? '',
    headline: json['headline']?.toString(),
    career: json['career']?.toString(),
    university: json['university']?.toString(),
    isCompany: json['account_type'] == 'company',
    verified: json['company_verified'] == true,
    isFollowing: json['is_following'] == true,
    reason: json['reason']?.toString(),
  );
}

class Highlight {
  final String id;
  final String title;
  final String? coverUrl;
  final List<StoryItem> items;

  const Highlight({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.items,
  });

  factory Highlight.fromJson(Map<String, dynamic> json) => Highlight(
    id: json['id'].toString(),
    title: json['title']?.toString() ?? '',
    coverUrl: json['cover_url']?.toString(),
    items: [
      for (final item in json['items'] as List? ?? const [])
        StoryItem.fromJson({
          ...Map<String, dynamic>.from(item as Map),
          'viewed': true,
        }),
    ],
  );
}

/// Seguir, Explorar, sugerencias e historias destacadas.
class SocialService {
  const SocialService._();

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    if (token.isEmpty) throw Exception('Tu sesión expiró.');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: query);

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

  static List<PersonCard> _people(dynamic data) => [
    for (final item in data as List? ?? const [])
      PersonCard.fromJson(Map<String, dynamic>.from(item as Map)),
  ];

  // ---------------- seguir ----------------
  static Future<void> setFollowing(
    String userId, {
    required bool follow,
  }) async {
    final uri = _uri('/users/$userId/follow');
    final headers = await _headers();
    final response =
        follow
            ? await http.post(uri, headers: headers)
            : await http.delete(uri, headers: headers);
    _decode(
      response,
      follow ? 'No se pudo seguir.' : 'No se pudo dejar de seguir.',
    );
  }

  static Future<List<PersonCard>> followList(
    String userId, {
    required bool followers,
  }) async {
    final response = await http.get(
      _uri('/users/$userId/${followers ? 'followers' : 'following'}'),
      headers: await _headers(),
    );
    return _people(_decode(response, 'No se pudo cargar la lista.'));
  }

  // ---------------- explorar ----------------
  static Future<({List<PublicationModel> posts, List<PersonCard> people})>
  explore({int offset = 0, int limit = 24}) async {
    final response = await http.get(
      _uri('/explore', {'offset': '$offset', 'limit': '$limit'}),
      headers: await _headers(),
    );
    final data = Map<String, dynamic>.from(
      _decode(response, 'No se pudo cargar Explorar.') as Map,
    );
    return (
      posts: [
        for (final item in data['publications'] as List? ?? const [])
          PublicationModel.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
      people: _people(data['people']),
    );
  }

  static Future<List<PersonCard>> suggestions() async {
    final response = await http.get(
      _uri('/people/suggestions'),
      headers: await _headers(),
    );
    return _people(_decode(response, 'No se pudieron cargar sugerencias.'));
  }

  // ---------------- destacadas ----------------
  static Future<List<Highlight>> highlights(String userId) async {
    final response = await http.get(
      _uri('/users/$userId/highlights'),
      headers: await _headers(),
    );
    final data = _decode(response, 'No se pudieron cargar las destacadas.');
    return [
      for (final item in data as List? ?? const [])
        Highlight.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  }

  static Future<Highlight> createHighlight(
    String title,
    List<String> storyIds,
  ) async {
    final response = await http.post(
      _uri('/highlights'),
      headers: await _headers(),
      body: jsonEncode({'title': title, 'story_ids': storyIds}),
    );
    final data = _decode(response, 'No se pudo crear la destacada.');
    return Highlight.fromJson(Map<String, dynamic>.from(data as Map));
  }

  static Future<void> addToHighlight(
    String highlightId,
    List<String> storyIds,
  ) async {
    final response = await http.post(
      _uri('/highlights/$highlightId/items'),
      headers: await _headers(),
      body: jsonEncode({'story_ids': storyIds}),
    );
    _decode(response, 'No se pudo agregar.');
  }

  static Future<void> deleteHighlight(String highlightId) async {
    final response = await http.delete(
      _uri('/highlights/$highlightId'),
      headers: await _headers(),
    );
    _decode(response, 'No se pudo borrar.');
  }
}
