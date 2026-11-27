import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/core/api/api_config.dart';

/// Envía al servidor los errores de la app (en lugar de Crashlytics, que
/// pide configurar Firebase con google-services y puede cerrar la app si
/// falta algo). Los administradores los ven en Moderación → Errores.
class ErrorReporter {
  const ErrorReporter._();

  /// Versión de la app (mantener igual que "version" en pubspec.yaml).
  static const String appVersion = '0.1.0';

  static final Set<String> _sent = {};
  static int _count = 0;

  /// Engancha los errores de Flutter y los de Dart no capturados.
  static void install() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      previous?.call(details);
      report(details.exception, details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      report(error, stack);
      return true;
    };
  }

  static Future<void> report(Object error, StackTrace? stack) async {
    // En modo debug se ven en la consola; no se llena el servidor.
    if (kDebugMode) return;
    final message = error.toString();
    // Un mismo error una sola vez, y como mucho 10 por sesión.
    if (_count >= 10 || !_sent.add(message)) return;
    _count++;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/client-errors'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null && token.isNotEmpty)
                'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'message':
                  message.length > 1900 ? message.substring(0, 1900) : message,
              'stack': stack?.toString(),
              'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
              'app_version': appVersion,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Sin red: se pierde, no pasa nada.
    }
  }
}
