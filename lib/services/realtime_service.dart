import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:connect_do/core/api/api_config.dart';
import 'package:connect_do/services/auth_service.dart';

/// Conexión en tiempo real con el servidor (WebSocket).
///
/// Mientras la app está abierta llegan al instante: mensajes nuevos,
/// "visto", "escribiendo…", reacciones, mensajes eliminados y quién está
/// en línea. En segundo plano se cierra (para eso están las notificaciones
/// push) y al volver se reconecta. Si la conexión se cae, las pantallas
/// siguen funcionando con su consulta periódica de respaldo.
class RealtimeService with WidgetsBindingObserver {
  RealtimeService._();

  static final RealtimeService instance = RealtimeService._();

  final _events = StreamController<Map<String, dynamic>>.broadcast();

  /// Todos los eventos del servidor ({"type": "message", ...}).
  Stream<Map<String, dynamic>> get events => _events.stream;

  /// true mientras la conexión está abierta.
  final ValueNotifier<bool> connected = ValueNotifier(false);

  /// Contactos en línea ahora mismo (según los avisos recibidos).
  final Map<String, bool> online = {};

  /// Última conexión conocida de cada contacto.
  final Map<String, DateTime> lastSeen = {};

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _ping;
  Timer? _retry;
  int _attempt = 0;
  bool _observing = false;
  bool _wanted = false;
  bool _connecting = false;

  /// Abre la conexión si hay sesión (se puede llamar muchas veces).
  Future<void> ensureConnected() async {
    if (!_observing) {
      _observing = true;
      WidgetsBinding.instance.addObserver(this);
    }
    _wanted = true;
    if (_channel != null || _connecting) return;
    await _connect();
  }

  /// Al cerrar sesión.
  void disconnect() {
    _wanted = false;
    _close();
    online.clear();
    lastSeen.clear();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_wanted) {
        _attempt = 0;
        _connect();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // En segundo plano no se mantiene abierta (ahorra datos y batería).
      _close();
    }
  }

  Future<void> _connect() async {
    if (_channel != null || _connecting) return;
    _connecting = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('sesion_activa') ?? false)) return;
      await AuthService.ensureFreshSession();
      final token =
          prefs.getString('access_token') ?? prefs.getString('accessToken');
      if (token == null || token.isEmpty) return;

      final base = Uri.parse(ApiConfig.baseUrl);
      final uri = base.replace(
        scheme: base.scheme == 'https' ? 'wss' : 'ws',
        path: '/ws',
        queryParameters: {'token': token},
      );
      final channel = WebSocketChannel.connect(uri);
      await channel.ready.timeout(const Duration(seconds: 20));
      _channel = channel;
      _attempt = 0;
      connected.value = true;
      _subscription = channel.stream.listen(
        _onData,
        onError: (_) => _onClosed(),
        onDone: _onClosed,
        cancelOnError: true,
      );
      // Render corta las conexiones inactivas: un "ping" cada 25 s.
      _ping?.cancel();
      _ping = Timer.periodic(
        const Duration(seconds: 25),
        (_) => send({'type': 'ping'}),
      );
    } catch (_) {
      _onClosed();
    } finally {
      _connecting = false;
    }
  }

  void _onData(dynamic raw) {
    try {
      final data = jsonDecode(raw as String);
      if (data is! Map) return;
      final event = Map<String, dynamic>.from(data);
      if (event['type'] == 'presence') {
        final id = event['user_id']?.toString() ?? '';
        online[id] = event['online'] == true;
        final seen = DateTime.tryParse(event['last_seen_at']?.toString() ?? '');
        if (seen != null) lastSeen[id] = seen.toLocal();
      }
      if (event['type'] != 'pong') _events.add(event);
    } catch (_) {}
  }

  void _onClosed() {
    _close();
    if (!_wanted) return;
    // Reintento con espera creciente: 2, 4, 8… hasta 60 s.
    _attempt++;
    final seconds = (1 << _attempt.clamp(1, 6)).clamp(2, 60);
    _retry?.cancel();
    _retry = Timer(Duration(seconds: seconds), _connect);
  }

  void _close() {
    _ping?.cancel();
    _retry?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    connected.value = false;
  }

  void send(Map<String, dynamic> data) {
    try {
      _channel?.sink.add(jsonEncode(data));
    } catch (_) {}
  }

  /// "Escribiendo…" a un contacto o a un grupo.
  void sendTyping({String? to, String? groupId, required bool isTyping}) {
    send({
      'type': 'typing',
      if (to != null) 'to': to,
      if (groupId != null) 'group_id': groupId,
      'is_typing': isTyping,
    });
  }

  /// Para pruebas: inyecta un evento como si viniera del servidor.
  @visibleForTesting
  void debugEmit(Map<String, dynamic> event) => _onData(jsonEncode(event));
}
