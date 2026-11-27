import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/screens/main_content/chats/individual_chat_screen.dart';
import 'package:connect_do/core/api/api_config.dart';
import 'package:connect_do/core/firebase/firebase_config.dart';
import 'package:connect_do/screens/applications/my_applications_screen.dart';
import 'package:connect_do/screens/applications/received_applications_screen.dart';
import 'package:connect_do/screens/main_content/chats/chatlist_screen.dart';
import 'package:connect_do/screens/main_content/contacts/contacts_screen.dart';
import 'package:connect_do/screens/main_content/home/publication_detail_screen.dart';
import 'package:connect_do/screens/main_content/notification/notifications_screen.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';

/// Notificaciones push (solo Android). Si Firebase no está configurado en
/// [FirebaseConfig], todo esto se salta sin errores.
class PushService {
  const PushService._();

  /// Para abrir pantallas desde un push sin tener un BuildContext.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const String _tokenKey = 'push_device_token';

  /// Cambia cada vez que llega un push con la app abierta, para que las
  /// pantallas se actualicen al instante sin consultar a cada rato.
  static final ValueNotifier<int> received = ValueNotifier<int>(0);

  static bool _ready = false;
  static StreamSubscription<String>? _refreshSub;

  static bool get _supported =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      FirebaseConfig.isConfigured;

  /// Se llama una vez al arrancar la app.
  static Future<void> init() async {
    if (!_supported || _ready) return;
    try {
      await Firebase.initializeApp(options: FirebaseConfig.android);
      _ready = true;

      // App abierta: aviso dentro de la app (el sistema no lo muestra).
      FirebaseMessaging.onMessage.listen(_showInApp);

      // Tocó el push con la app en segundo plano.
      FirebaseMessaging.onMessageOpenedApp.listen(_open);

      // Tocó el push con la app cerrada.
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        // Espera a que la primera pantalla exista.
        WidgetsBinding.instance.addPostFrameCallback((_) => _open(initial));
      }
    } catch (error) {
      debugPrint('Push deshabilitado: $error');
    }
  }

  /// Pide permiso y registra este teléfono para la cuenta actual. Se llama
  /// al entrar a la app con sesión iniciada.
  static Future<void> registerDevice() async {
    if (!_ready) return;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      // Se usa el token de registro clásico a propósito: es el destino
      // que acepta "token" en la API HTTP v1 del servidor. La API nueva
      // (register/onRegistered) entrega un FID con otro tipo de envío.
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _sendToken(token);

      // ignore: deprecated_member_use
      _refreshSub ??= FirebaseMessaging.instance.onTokenRefresh.listen(
        _sendToken,
      );
    } catch (error) {
      debugPrint('No se pudo registrar el push: $error');
    }
  }

  /// Al cerrar sesión: este teléfono deja de recibir los push de la cuenta.
  /// Debe llamarse ANTES de borrar el token de sesión.
  static Future<void> unregisterDevice() async {
    if (!_ready) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey) ?? '';
    final access = prefs.getString('access_token') ?? '';
    if (token.isEmpty || access.isEmpty) return;

    try {
      await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/devices/unregister'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $access',
            },
            body: jsonEncode({'token': token}),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
    await prefs.remove(_tokenKey);
  }

  static Future<void> _sendToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final access = prefs.getString('access_token') ?? '';
    if (access.isEmpty) return;

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/devices'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $access',
      },
      body: jsonEncode({'token': token, 'platform': 'android'}),
    );
    if (response.statusCode == 200) {
      await prefs.setString(_tokenKey, token);
    }
  }

  // =====================================================
  // AL RECIBIR / TOCAR
  // =====================================================
  static void _showInApp(RemoteMessage message) {
    received.value++;
    // Si ya estás en esa conversación, el mensaje aparece solo en el chat.
    if (message.data['type'] == 'message' &&
        message.data['related_user_id'] == IndividualChatScreen.openChatId) {
      return;
    }
    final context = navigatorKey.currentContext;
    final notification = message.notification;
    if (context == null || notification == null) return;

    final title = notification.title ?? '';
    final body = notification.body ?? '';
    showAuthMessage(
      context,
      [title, body].where((t) => t.isNotEmpty).join(' · '),
      type: AuthMessageType.info,
    );
  }

  static void _open(RemoteMessage message) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    navigator.push(
      MaterialPageRoute(builder: (_) => destinationFor(message.data)),
    );
  }

  /// Pantalla que corresponde a cada tipo de notificación.
  @visibleForTesting
  static Widget destinationFor(Map<String, dynamic> data) {
    final publicationId = data['related_publication_id']?.toString() ?? '';

    return switch (data['type']?.toString()) {
      'like' ||
      'comment' ||
      'publication' ||
      'opportunity' ||
      'share' ||
      'job_alert' when publicationId.isNotEmpty => PublicationDetailScreen(
        publicationId: publicationId,
      ),
      // Abre directo la conversación con quien escribió.
      'message' when (data['related_user_id']?.toString() ?? '').isNotEmpty =>
        IndividualChatScreen(
          chatId: data['related_user_id'].toString(),
          chatName: data['sender_name']?.toString() ?? 'Chat',
          chatAvatar: data['sender_photo']?.toString() ?? '',
        ),
      'message' || 'application_contact' => const ChatListScreen(),
      'contact_request' => const ContactsScreen(initialTabIndex: 2),
      'contact_accepted' => const ContactsScreen(initialTabIndex: 1),
      'application_new' => const ReceivedApplicationsScreen(),
      'application_status' => const MyApplicationsScreen(),
      _ => const NotificationsScreen(),
    };
  }
}
