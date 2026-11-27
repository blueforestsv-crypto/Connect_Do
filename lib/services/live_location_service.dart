import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/core/api/api_config.dart';

class LocationException implements Exception {
  final String message;
  const LocationException(this.message);

  @override
  String toString() => message;
}

/// Ubicación del teléfono y "compartir en tiempo real".
///
/// En tiempo real, la posición se envía mientras la app está abierta (no se
/// pide ubicación en segundo plano: Android exige un permiso especial que
/// Play Store revisa con lupa). Al cerrar la app deja de actualizarse.
class LiveLocationService {
  LiveLocationService._();

  static final LiveLocationService instance = LiveLocationService._();

  /// Mensajes cuya ubicación estoy compartiendo ahora (id -> hasta cuándo).
  final ValueNotifier<Map<String, DateTime>> sharing = ValueNotifier({});

  final Map<String, bool> _isGroup = {};
  StreamSubscription<Position>? _stream;
  Timer? _expiry;
  DateTime? _lastSent;
  Position? _pending;

  /// Pide permiso si hace falta y devuelve la posición actual.
  static Future<Position> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException('Activa la ubicación del teléfono.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException('Permite la ubicación para compartirla.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'La ubicación está bloqueada para Connect Do. Actívala en Ajustes.',
      );
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  bool isSharing(String messageId) =>
      (sharing.value[messageId]?.isAfter(DateTime.now())) ?? false;

  /// Empieza a enviar mi posición para [messageId] hasta [until].
  void start(String messageId, DateTime until, {required bool isGroup}) {
    _isGroup[messageId] = isGroup;
    sharing.value = {...sharing.value, messageId: until};
    _stream ??= Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(_onPosition, onError: (_) {});
    _scheduleExpiry();
  }

  /// Deja de compartir (y avisa al servidor).
  Future<void> stop(String messageId) async {
    _remove(messageId);
    try {
      await http.post(_uri(messageId, stop: true), headers: await _headers());
    } catch (_) {}
  }

  void _remove(String messageId) {
    final next = {...sharing.value}..remove(messageId);
    sharing.value = next;
    _isGroup.remove(messageId);
    if (next.isEmpty) {
      _stream?.cancel();
      _stream = null;
      _expiry?.cancel();
    }
  }

  void _scheduleExpiry() {
    _expiry?.cancel();
    if (sharing.value.isEmpty) return;
    final soonest = sharing.value.values.reduce(
      (a, b) => a.isBefore(b) ? a : b,
    );
    final wait = soonest.difference(DateTime.now());
    _expiry = Timer(wait.isNegative ? Duration.zero : wait, () {
      final now = DateTime.now();
      for (final entry in {...sharing.value}.entries) {
        if (!entry.value.isAfter(now)) _remove(entry.key);
      }
      _scheduleExpiry();
    });
  }

  /// Como mucho un envío cada 10 s (el último punto nunca se pierde).
  void _onPosition(Position position) {
    _pending = position;
    final now = DateTime.now();
    if (_lastSent != null && now.difference(_lastSent!).inSeconds < 10) return;
    _lastSent = now;
    _flush();
  }

  Future<void> _flush() async {
    final position = _pending;
    if (position == null) return;
    _pending = null;
    final headers = await _headers();
    for (final id in sharing.value.keys.toList()) {
      if (!isSharing(id)) {
        _remove(id);
        continue;
      }
      try {
        final response = await http.patch(
          _uri(id),
          headers: headers,
          body: jsonEncode({
            'lat': position.latitude,
            'lng': position.longitude,
          }),
        );
        // El servidor dice que ya terminó (venció o se detuvo).
        if (response.statusCode == 400 || response.statusCode == 404) {
          _remove(id);
        }
      } catch (_) {}
    }
  }

  Uri _uri(String messageId, {bool stop = false}) {
    final base = _isGroup[messageId] == true ? '/groups' : '/chats';
    return Uri.parse(
      '${ApiConfig.baseUrl}$base/messages/$messageId/location'
      '${stop ? '/stop' : ''}',
    );
  }

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${prefs.getString('access_token') ?? ''}',
    };
  }
}
