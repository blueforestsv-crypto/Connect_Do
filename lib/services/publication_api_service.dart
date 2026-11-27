import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/models/comment_model.dart';
import 'package:connect_do/models/publication_model.dart';
import 'package:connect_do/services/api_config.dart';

class PublicationApiService {
  Future<String> _getAccessToken() async {
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

  Future<List<PublicationModel>> getPublications({
    String? type,
    int limit = 20,
    int offset = 0,

    /// Solo las publicaciones del usuario actual (perfil).
    bool mine = false,

    /// Solo las que guardé.
    bool saved = false,

    /// Solo de las personas que sigo.
    bool following = false,

    /// Solo las de esta persona.
    String? authorId,

    /// Texto a buscar (título, descripción, lugar o autor).
    String? query,

    /// Buscador de empleos.
    bool opportunities = false,
    String? modality,
    String? location,
    bool verifiedOnly = false,
  }) async {
    final token = await _getAccessToken();

    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (mine) 'mine': 'true',
      if (saved) 'saved': 'true',
      if (following) 'following': 'true',
      if (authorId != null && authorId.isNotEmpty) 'author': authorId,
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (opportunities) 'opportunities': 'true',
      if (modality != null) 'modality': modality,
      if (location != null && location.trim().isNotEmpty)
        'location': location.trim(),
      if (verifiedOnly) 'verified': 'true',
    };

    if (type != null && type.trim().isNotEmpty) {
      queryParams['type'] = type.trim();
    }

    final response = await http.get(
      ApiConfig.uri('/publications', queryParams),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Error al cargar publicaciones: ${response.statusCode} ${response.body}',
      );
    }

    final decodedBody = jsonDecode(response.body);

    if (decodedBody is! List) {
      throw Exception('La respuesta del servidor no es una lista válida.');
    }

    return decodedBody
        .whereType<Map<String, dynamic>>()
        .map(PublicationModel.fromJson)
        .toList();
  }

  Future<void> deletePublication(String publicationId) async {
    final token = await _getAccessToken();

    final response = await http.delete(
      ApiConfig.uri('/publications/$publicationId'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200 &&
        response.statusCode != 202 &&
        response.statusCode != 204) {
      throw Exception(
        'Error al eliminar publicación: ${response.statusCode} ${response.body}',
      );
    }
  }

  // =====================================================
  // CREAR PUBLICACIÓN
  // =====================================================
  Future<PublicationModel> createPublication({
    required String type,
    required String title,
    required String description,
    String visibility = 'contacts',
    String? location,
    String? modality,
    List<Map<String, dynamic>> mediaItems = const [],
    List<String> mentions = const [],
  }) async {
    final body = <String, dynamic>{
      if (mentions.isNotEmpty) 'mentions': mentions,
      'type': type,
      'title': title,
      'description': description,
      'visibility': visibility,
      if (location != null && location.trim().isNotEmpty)
        'location': location.trim(),
      if (modality != null) 'modality': modality,
      'media_items': mediaItems,
    };

    final response = await http.post(
      ApiConfig.uri('/publications'),
      headers: await _headers(json: true),
      body: jsonEncode(body),
    );

    _ensureOk(response, 'No se pudo publicar. Inténtalo de nuevo.');

    return PublicationModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // =====================================================
  // PUBLICACIÓN INDIVIDUAL
  // =====================================================
  Future<PublicationModel> getPublication(String publicationId) async {
    final response = await http.get(
      ApiConfig.uri('/publications/$publicationId'),
      headers: await _headers(),
    );

    _ensureOk(response, 'No se pudo cargar la publicación.');

    return PublicationModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // =====================================================
  // ME GUSTA
  // =====================================================
  /// Devuelve el estado final y el total de "me gusta".
  Future<({bool liked, int likesCount})> setLiked(
    String publicationId, {
    required bool liked,
  }) async {
    final uri = ApiConfig.uri('/publications/$publicationId/like');
    final headers = await _headers();

    final response =
        liked
            ? await http.post(uri, headers: headers)
            : await http.delete(uri, headers: headers);

    _ensureOk(response, 'No se pudo actualizar el me gusta.');

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    return (
      liked: data['liked'] == true,
      likesCount: (data['likes_count'] as num?)?.toInt() ?? 0,
    );
  }

  Future<bool> setSaved(String publicationId, {required bool saved}) async {
    final uri = ApiConfig.uri('/publications/$publicationId/save');
    final headers = await _headers();

    final response =
        saved
            ? await http.put(uri, headers: headers)
            : await http.delete(uri, headers: headers);

    _ensureOk(response, 'No se pudo actualizar tus guardados.');
    return (jsonDecode(response.body) as Map)['saved'] == true;
  }

  // =====================================================
  // COMENTARIOS
  // =====================================================
  Future<List<CommentModel>> getComments(
    String publicationId, {
    int limit = 100,
    int offset = 0,
  }) async {
    final response = await http.get(
      ApiConfig.uri('/publications/$publicationId/comments', {
        'limit': '$limit',
        'offset': '$offset',
      }),
      headers: await _headers(),
    );

    _ensureOk(response, 'No se pudieron cargar los comentarios.');

    final data = jsonDecode(response.body);

    return (data as List)
        .whereType<Map<String, dynamic>>()
        .map(CommentModel.fromJson)
        .toList();
  }

  Future<CommentModel> addComment(
    String publicationId,
    String text, {
    String? parentId,
    List<String> mentions = const [],
  }) async {
    final response = await http.post(
      ApiConfig.uri('/publications/$publicationId/comments'),
      headers: await _headers(json: true),
      body: jsonEncode({
        'text': text,
        if (parentId != null) 'parent_id': parentId,
        if (mentions.isNotEmpty) 'mentions': mentions,
      }),
    );

    _ensureOk(response, 'No se pudo publicar el comentario.');

    return CommentModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<CommentModel> updateComment(
    String publicationId,
    String commentId,
    String text,
  ) async {
    final response = await http.patch(
      ApiConfig.uri('/publications/$publicationId/comments/$commentId'),
      headers: await _headers(json: true),
      body: jsonEncode({'text': text}),
    );

    _ensureOk(response, 'No se pudo editar el comentario.');

    return CommentModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> deleteComment(String publicationId, String commentId) async {
    final response = await http.delete(
      ApiConfig.uri('/publications/$publicationId/comments/$commentId'),
      headers: await _headers(),
    );

    _ensureOk(response, 'No se pudo eliminar el comentario.');
  }

  // =====================================================
  // AUXILIARES
  // =====================================================
  Future<Map<String, String>> _headers({bool json = false}) async {
    final token = await _getAccessToken();

    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (json) 'Content-Type': 'application/json',
    };
  }

  /// Lanza una excepción con el mensaje del backend (campo "detail").
  void _ensureOk(http.Response response, String fallback) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    String message = fallback;
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['detail'] is String) {
        message = data['detail'] as String;
      }
    } catch (_) {}

    throw PublicationApiException(message, statusCode: response.statusCode);
  }

  /// Me gusta en un comentario.
  Future<({bool liked, int likesCount})> setCommentLiked(
    String publicationId,
    String commentId, {
    required bool liked,
  }) async {
    final uri = ApiConfig.uri(
      '/publications/$publicationId/comments/$commentId/like',
    );
    final headers = await _headers();
    final response =
        liked
            ? await http.post(uri, headers: headers)
            : await http.delete(uri, headers: headers);
    _ensureOk(response, 'No se pudo actualizar el me gusta.');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      liked: data['liked'] == true,
      likesCount: (data['likes_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// Editar título, texto o visibilidad de mi publicación.
  Future<PublicationModel> updatePublication(
    String publicationId, {
    String? title,
    String? description,
    String? visibility,
  }) async {
    final response = await http.patch(
      ApiConfig.uri('/publications/$publicationId'),
      headers: await _headers(json: true),
      body: jsonEncode({
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (visibility != null) 'visibility': visibility,
      }),
    );
    _ensureOk(response, 'No se pudo guardar la publicación.');
    return PublicationModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}

class PublicationApiException implements Exception {
  final String message;
  final int statusCode;

  const PublicationApiException(this.message, {required this.statusCode});

  @override
  String toString() => message;
}
