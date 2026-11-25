import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/services/auth_service.dart';

/// Mantiene viva la sesión mientras la app está abierta: renueva el token
/// de acceso cada pocos minutos y al volver a la app desde segundo plano.
///
/// Si el servidor rechaza la sesión (venció a los 30 días o se cerró desde
/// otro lado), llama a [onExpired] para volver al login.
class SessionKeeper with WidgetsBindingObserver {
  SessionKeeper._();

  static final SessionKeeper instance = SessionKeeper._();

  static const Duration _interval = Duration(minutes: 10);

  bool _started = false;
  VoidCallback? onExpired;

  void start({VoidCallback? onExpired}) {
    this.onExpired = onExpired;
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    Timer.periodic(_interval, (_) => check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) check();
  }

  Future<void> check() async {
    final prefs = await SharedPreferences.getInstance();
    // Solo con la sesión abierta (en el login no hay nada que renovar).
    if (!(prefs.getBool('sesion_activa') ?? false)) return;

    final ok = await AuthService.ensureFreshSession();
    if (ok == false) {
      await prefs.setBool('sesion_activa', false);
      onExpired?.call();
    }
  }
}
