import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:connect_do/screens/main_content/home/home_screen.dart';
import 'package:connect_do/services/auth_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/form/google_web_button.dart';

/// Botón "Continuar con Google". Ejecuta todo el flujo OAuth y, si sale bien,
/// entra al Home. Sirve tanto para registrarse como para iniciar sesión.
///
/// En Android/iOS es un botón propio que abre el selector de cuentas.
/// En web Google exige su botón oficial, así que se dibuja ese y se escucha
/// el resultado por los eventos de autenticación.
class GoogleSignInButton extends StatefulWidget {
  final String text;

  /// Registro ("Registrarse con Google") en lugar de "Continuar con Google".
  final bool signUp;

  /// Avisa a la pantalla para bloquear sus otros botones mientras carga.
  final ValueChanged<bool>? onLoadingChanged;

  final bool enabled;

  const GoogleSignInButton({
    super.key,
    this.text = 'Continuar con Google',
    this.signUp = false,
    this.onLoadingChanged,
    this.enabled = true,
  });

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  // Logo oficial de Google ("G" de 4 colores).
  static const String _googleLogoSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
<path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
<path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
<path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
<path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
</svg>
''';

  bool _isLoading = false;

  // Solo web: preparación del plugin y escucha del botón oficial.
  Future<void>? _webReady;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _webEvents;

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      _webReady = AuthService.prepareGoogleSignIn();
      _webEvents = AuthService.googleAuthEvents.listen(
        _onWebEvent,
        onError: _onWebError,
      );
    }
  }

  @override
  void dispose() {
    _webEvents?.cancel();
    super.dispose();
  }

  void _setLoading(bool value) {
    if (!mounted) return;
    setState(() => _isLoading = value);
    widget.onLoadingChanged?.call(value);
  }

  /// Si Registro y Login están ambas en la pila, solo responde la visible.
  bool get _isVisibleRoute => ModalRoute.of(context)?.isCurrent ?? true;

  // ===============================
  // MÓVIL: selector de cuentas
  // ===============================
  Future<void> _signIn() async {
    _setLoading(true);

    try {
      final isNewUser = await AuthService.signInWithGoogle();

      // Canceló el selector de cuentas.
      if (isNewUser == null) {
        _setLoading(false);
        return;
      }

      _goHome(isNewUser);
    } catch (e) {
      _showError(e);
    }
  }

  // ===============================
  // WEB: botón oficial de Google
  // ===============================
  Future<void> _onWebEvent(GoogleSignInAuthenticationEvent event) async {
    if (!mounted || !_isVisibleRoute || _isLoading) return;
    if (event is! GoogleSignInAuthenticationEventSignIn) return;

    _setLoading(true);

    try {
      final isNewUser = await AuthService.completeGoogleSignIn(event.user);
      _goHome(isNewUser);
    } catch (e) {
      _showError(e);
    }
  }

  void _onWebError(Object error) {
    if (!mounted || !_isVisibleRoute) return;

    if (error is GoogleSignInException &&
        error.code == GoogleSignInExceptionCode.canceled) {
      return;
    }
    _showError(error);
  }

  // ===============================
  // RESULTADO
  // ===============================
  void _goHome(bool isNewUser) {
    if (!mounted) return;

    showAuthMessage(
      context,
      isNewUser
          ? '¡Cuenta creada con Google! Bienvenido a Connect Do.'
          : '¡Hola de nuevo!',
      type: AuthMessageType.success,
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  void _showError(Object error) {
    if (!mounted) return;
    _setLoading(false);

    final message =
        error is GoogleSignInException
            ? 'No se pudo iniciar sesión con Google (${error.code.name}).'
            : error.toString();
    showAuthMessage(context, message);
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return _buildWeb(context);

    final canTap = widget.enabled && !_isLoading;
    final palette = AuthPalette.of(context);

    return SizedBox(
      width: double.infinity,
      height: Brand.fieldHeight,
      child: OutlinedButton(
        onPressed: canTap ? _signIn : null,
        style: OutlinedButton.styleFrom(
          backgroundColor: palette.card,
          foregroundColor: palette.title,
          disabledForegroundColor: palette.muted,
          side: BorderSide(color: palette.fieldBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Brand.radiusMd),
          ),
        ),
        child:
            _isLoading
                ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF4285F4),
                  ),
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.string(_googleLogoSvg, width: 20, height: 20),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        widget.text,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: Brand.displayFont,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildWeb(BuildContext context) {
    final palette = AuthPalette.of(context);

    if (_isLoading) {
      return SizedBox(
        height: Brand.fieldHeight,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF4285F4),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Conectando con Google…',
                style: TextStyle(
                  fontFamily: Brand.displayFont,
                  fontSize: 14.5,
                  color: palette.body,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<void>(
      future: _webReady,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Google no está disponible ahora: ${snapshot.error}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: Brand.displayFont,
              fontSize: 13,
              color: palette.muted,
            ),
          );
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(height: Brand.fieldHeight);
        }

        // El botón de Google no se puede deshabilitar; se bloquea encima.
        return AbsorbPointer(
          absorbing: !widget.enabled,
          child: Opacity(
            opacity: widget.enabled ? 1 : 0.5,
            child: SizedBox(
              height: Brand.fieldHeight,
              child: Center(
                child: LayoutBuilder(
                  builder:
                      (context, constraints) => buildGoogleWebButton(
                        signUp: widget.signUp,
                        dark: palette.isDark,
                        width: constraints.maxWidth,
                      ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Separador "o" entre Google y el formulario con correo.
class AuthDivider extends StatelessWidget {
  final String text;

  const AuthDivider({super.key, this.text = 'o'});

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          Expanded(child: Divider(color: palette.fieldBorder, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              text,
              style: TextStyle(
                fontFamily: Brand.displayFont,
                color: palette.muted,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(child: Divider(color: palette.fieldBorder, height: 1)),
        ],
      ),
    );
  }
}
