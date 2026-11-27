import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/core/api/api_config.dart';

/// Nombre del dispositivo para "Sesiones activas".
String deviceLabel() {
  if (kIsWeb) return 'Navegador web';
  if (Platform.isAndroid) return 'Teléfono Android';
  if (Platform.isIOS) return 'iPhone';
  return Platform.operatingSystem;
}

/// [deviceLabel] listo para un encabezado HTTP: los encabezados solo
/// admiten ASCII ("Teléfono" lleva tilde), así que va codificado y el
/// servidor lo decodifica.
String deviceHeader() => Uri.encodeComponent(deviceLabel());

class PrivacySettings {
  /// "contacts" | "everyone"
  final String messagePrivacy;

  /// "contacts" | "followers"
  final String storyPrivacy;
  final bool showPresence;

  const PrivacySettings({
    this.messagePrivacy = 'contacts',
    this.storyPrivacy = 'contacts',
    this.showPresence = true,
  });

  factory PrivacySettings.fromJson(Map<String, dynamic> json) =>
      PrivacySettings(
        messagePrivacy: json['message_privacy']?.toString() ?? 'contacts',
        storyPrivacy: json['story_privacy']?.toString() ?? 'contacts',
        showPresence: json['show_presence'] != false,
      );
}

class ActiveSession {
  final String id;
  final String jti;
  final String deviceName;
  final DateTime? createdAt;
  final DateTime? lastUsedAt;
  final bool isCurrent;

  const ActiveSession({
    required this.id,
    required this.jti,
    required this.deviceName,
    this.createdAt,
    this.lastUsedAt,
    this.isCurrent = false,
  });
}

class PrivacyService {
  const PrivacyService._();

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${prefs.getString('access_token') ?? ''}',
    };
  }

  static Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  static Future<PrivacySettings> get() async {
    final response = await http.get(
      _uri('/auth/privacy'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('No se pudo cargar tu privacidad.');
    }
    return PrivacySettings.fromJson(jsonDecode(response.body));
  }

  static Future<PrivacySettings> update({
    String? messagePrivacy,
    String? storyPrivacy,
    bool? showPresence,
  }) async {
    final response = await http.patch(
      _uri('/auth/privacy'),
      headers: await _headers(),
      body: jsonEncode({
        if (messagePrivacy != null) 'message_privacy': messagePrivacy,
        if (storyPrivacy != null) 'story_privacy': storyPrivacy,
        if (showPresence != null) 'show_presence': showPresence,
      }),
    );
    if (response.statusCode != 200) throw Exception('No se pudo guardar.');
    return PrivacySettings.fromJson(jsonDecode(response.body));
  }

  // ===============================
  // SESIONES
  // ===============================

  /// Identificador de la sesión de este teléfono (va dentro del token).
  static Future<String?> currentJti() async {
    final prefs = await SharedPreferences.getInstance();
    return jtiOf(prefs.getString('refresh_token') ?? '');
  }

  @visibleForTesting
  static String? jtiOf(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      return (jsonDecode(payload) as Map)['jti']?.toString();
    } catch (_) {
      return null;
    }
  }

  static Future<List<ActiveSession>> sessions() async {
    final response = await http.get(
      _uri('/auth/sessions'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('No se pudieron cargar las sesiones.');
    }
    final mine = await currentJti();
    return [
      for (final raw in jsonDecode(response.body) as List)
        ActiveSession(
          id: raw['id'].toString(),
          jti: raw['jti'].toString(),
          deviceName: raw['device_name']?.toString() ?? 'Dispositivo',
          createdAt:
              DateTime.tryParse(raw['created_at']?.toString() ?? '')?.toLocal(),
          lastUsedAt:
              DateTime.tryParse(
                raw['last_used_at']?.toString() ?? '',
              )?.toLocal(),
          isCurrent: raw['jti'].toString() == mine,
        ),
    ]..sort((a, b) => a.isCurrent == b.isCurrent ? 0 : (a.isCurrent ? -1 : 1));
  }

  static Future<void> revoke(String sessionId) async {
    final response = await http.delete(
      _uri('/auth/sessions/$sessionId'),
      headers: await _headers(),
    );
    if (response.statusCode != 204) throw Exception('No se pudo cerrar.');
  }

  /// Cierra todas menos la de este teléfono. Devuelve cuántas cerró.
  static Future<int> revokeOthers() async {
    final keep = await currentJti();
    if (keep == null) throw Exception('No se encontró la sesión actual.');
    final response = await http.post(
      _uri('/auth/sessions/revoke-others'),
      headers: await _headers(),
      body: jsonEncode({'keep_jti': keep}),
    );
    if (response.statusCode != 200) throw Exception('No se pudo cerrar.');
    return ((jsonDecode(response.body)['revoked'] as num?) ?? 0).toInt();
  }

  // ===============================
  // DESCARGAR MIS DATOS
  // ===============================

  /// Baja la copia (JSON) y abre el menú para guardarla o enviarla.
  static Future<void> exportAndShare() async {
    final response = await http.get(
      _uri('/auth/account/export'),
      headers: await _headers(),
    );
    if (response.statusCode == 429) {
      throw Exception('Ya pediste tus datos hace poco. Intenta en una hora.');
    }
    if (response.statusCode != 200) {
      throw Exception('No se pudo preparar la copia.');
    }
    if (kIsWeb) {
      throw Exception('Descárgala desde la app del teléfono.');
    }
    // Se guarda con formato legible.
    final pretty = const JsonEncoder.withIndent(
      '  ',
    ).convert(jsonDecode(utf8.decode(response.bodyBytes)));
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/connect_do_mis_datos.json');
    await file.writeAsString(pretty);
    await Share.shareXFiles([
      XFile(file.path, mimeType: 'application/json'),
    ], subject: 'Mis datos de Connect Do');
  }
}
