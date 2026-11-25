import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/models/application_model.dart';
import 'package:connect_do/services/api_config.dart';

class ApplicationService {
  /// Publicaciones a las que ya me postulé (para mostrar "Postulado" en el
  /// feed aunque se reinicie la app). Se llena con [getMyApplications].
  static final Set<String> appliedPublicationIds = {};

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();

    final token =
        prefs.getString('access_token') ??
        prefs.getString('accessToken') ??
        prefs.getString('token');

    if (token == null || token.isEmpty) {
      throw Exception('Tu sesión expiró. Inicia sesión nuevamente.');
    }

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static dynamic _decodeOrThrow(http.Response response, String fallback) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body.isEmpty ? null : jsonDecode(response.body);
    }
    if (response.statusCode == 401) {
      throw Exception('Tu sesión expiró. Inicia sesión nuevamente.');
    }
    var message = fallback;
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['detail'] is String) message = data['detail'];
    } catch (_) {}
    throw Exception(message);
  }

  static List<ApplicationModel> _list(dynamic data) =>
      data is List
          ? data
              .whereType<Map>()
              .map((e) => ApplicationModel.fromJson(Map.from(e)))
              .toList()
          : [];

  Future<void> applyToPublication({
    required String publicationId,
    String? coverMessage,
  }) async {
    final response = await http.post(
      ApiConfig.uri('/applications'),
      headers: await _headers(),
      body: jsonEncode({
        'publication_id': publicationId,
        'cover_message':
            coverMessage ?? 'Hola, me interesa aplicar a esta oportunidad.',
      }),
    );

    if (response.statusCode == 409) {
      appliedPublicationIds.add(publicationId);
      throw Exception('Ya aplicaste a esta oportunidad.');
    }

    _decodeOrThrow(response, 'No se pudo enviar tu postulación.');
    appliedPublicationIds.add(publicationId);
  }

  static Future<List<ApplicationModel>> getMyApplications() async {
    final response = await http.get(
      ApiConfig.uri('/applications/me'),
      headers: await _headers(),
    );
    final items = _list(
      _decodeOrThrow(response, 'No se pudieron cargar tus postulaciones.'),
    );
    appliedPublicationIds
      ..clear()
      ..addAll(items.map((a) => a.publicationId));
    return items;
  }

  static Future<List<ApplicationModel>> getReceivedApplications() async {
    final response = await http.get(
      ApiConfig.uri('/applications/received'),
      headers: await _headers(),
    );
    return _list(
      _decodeOrThrow(response, 'No se pudieron cargar las postulaciones.'),
    );
  }

  static Future<ApplicationModel> updateStatus(
    String applicationId,
    String status,
  ) async {
    final response = await http.patch(
      ApiConfig.uri('/applications/$applicationId'),
      headers: await _headers(),
      body: jsonEncode({'status': status}),
    );
    final data = _decodeOrThrow(response, 'No se pudo cambiar el estado.');
    return ApplicationModel.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Envía un mensaje al estudiante (aparece en su chat) y marca la
  /// postulación como "Contactado".
  static Future<void> contactStudent(
    String applicationId,
    String message,
  ) async {
    final response = await http.post(
      ApiConfig.uri('/applications/$applicationId/contact'),
      headers: await _headers(),
      body: jsonEncode({'content': message}),
    );
    _decodeOrThrow(response, 'No se pudo enviar el mensaje.');
  }

  static Future<void> withdraw(ApplicationModel application) async {
    final response = await http.delete(
      ApiConfig.uri('/applications/${application.id}'),
      headers: await _headers(),
    );
    _decodeOrThrow(response, 'No se pudo retirar la postulación.');
    appliedPublicationIds.remove(application.publicationId);
  }
}
