import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/screens/main_content/home/home_screen.dart';
import 'package:connect_do/screens/auth/register/welcome_screen.dart';
import 'package:connect_do/services/auth_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/auth/auth_layout.dart';

/// Verificación del correo con el código de 6 dígitos que emite el backend.
/// La cuenta ya existe y la sesión ya está iniciada cuando se llega aquí.
class VerificationScreen extends StatefulWidget {
  final String email;

  /// Código que devuelve el backend en modo development (sin correo real).
  final String? debugCode;

  /// Error al enviar el primer código, para mostrarlo al abrir la pantalla.
  final String? initialError;

  const VerificationScreen({
    super.key,
    required this.email,
    this.debugCode,
    this.initialError,
  });

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  static const int _codeLength = 6;
  static const int _resendSeconds = 60;

  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocus = FocusNode();

  bool _isLoading = false;
  bool _isResending = false;
  bool _hasError = false;
  String? _debugCode;
  int _resendCountdown = _resendSeconds;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _debugCode = widget.debugCode;
    _codeFocus.addListener(() => setState(() {}));
    _startResendCountdown();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _codeFocus.requestFocus();

      if (widget.initialError != null) {
        showAuthMessage(context, widget.initialError!);
      }
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = _resendSeconds);

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      if (_resendCountdown <= 1) {
        timer.cancel();
        setState(() => _resendCountdown = 0);
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text;

    if (code.length < _codeLength) {
      setState(() => _hasError = true);
      showAuthMessage(context, 'Ingresa los $_codeLength dígitos del código.');
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      await AuthService.confirmVerificationCode(code);

      if (!mounted) return;

      HapticFeedback.mediumImpact();
      showAuthMessage(
        context,
        '¡Correo verificado! Bienvenido a Connect Do.',
        type: AuthMessageType.success,
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      HapticFeedback.heavyImpact();
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      _codeController.clear();
      _codeFocus.requestFocus();
      showAuthMessage(context, e.toString());
    }
  }

  Future<void> _resendCode() async {
    setState(() => _isResending = true);

    try {
      final debugCode = await AuthService.requestVerificationCode(widget.email);

      if (!mounted) return;

      setState(() {
        _debugCode = debugCode;
        _hasError = false;
      });
      _codeController.clear();
      _startResendCountdown();
      showAuthMessage(
        context,
        'Te enviamos un código nuevo.',
        type: AuthMessageType.info,
      );
    } catch (e) {
      if (!mounted) return;
      showAuthMessage(context, e.toString());
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  /// Correo equivocado: se cierra la sesión y se vuelve al inicio.
  Future<void> _useAnotherEmail() async {
    await AuthService.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return AuthLayout(
      headerIcon: PhosphorIconsRegular.envelopeOpen,
      title: 'Revisa tu correo',
      showBack: false,
      subtitle: Text.rich(
        TextSpan(
          text: 'Enviamos un código de $_codeLength dígitos a\n',
          children: [
            TextSpan(
              text: widget.email,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: palette.title,
              ),
            ),
          ],
        ),
      ),
      footer: AuthFooterLink(
        question: '¿Correo equivocado?',
        action: 'Usar otro',
        onTap: _isLoading ? null : _useAnotherEmail,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCodeInput(palette),
          if (_debugCode != null) _buildDebugCode(palette),
          const SizedBox(height: 24),
          GradientButton(
            text: 'Verificar y entrar',
            isLoading: _isLoading,
            onPressed: _verifyCode,
          ),
          const SizedBox(height: 8),
          _buildResendButton(palette),
        ],
      ),
    );
  }

  /// Un solo TextField invisible sobre 6 casillas: permite pegar el código
  /// completo y el autocompletado de códigos del sistema.
  Widget _buildCodeInput(AuthPalette palette) {
    return GestureDetector(
      onTap: () => _codeFocus.requestFocus(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _codeController,
            builder: (context, value, _) {
              final text = value.text;

              return Row(
                children: [
                  for (var index = 0; index < _codeLength; index++) ...[
                    if (index > 0) SizedBox(width: index == 3 ? 14 : 8),
                    Expanded(child: _buildDigitBox(palette, text, index)),
                  ],
                ],
              );
            },
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: _codeController,
                focusNode: _codeFocus,
                enabled: !_isLoading,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: _codeLength,
                showCursor: false,
                enableInteractiveSelection: false,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  if (_hasError) setState(() => _hasError = false);
                  if (value.length == _codeLength && !_isLoading) {
                    _verifyCode();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDigitBox(AuthPalette palette, String text, int index) {
    final digit = index < text.length ? text[index] : '';
    final filled = digit.isNotEmpty;
    final isActive =
        _codeFocus.hasFocus &&
        (index == text.length ||
            (index == _codeLength - 1 && text.length == _codeLength));

    final borderColor =
        _hasError
            ? Brand.danger
            : isActive
            ? Brand.blue
            : filled
            ? Brand.green.withValues(alpha: 0.6)
            : palette.fieldBorder;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isActive ? palette.card : palette.fieldFill,
        borderRadius: BorderRadius.circular(Brand.radiusMd),
        border: Border.all(
          color: borderColor,
          width: isActive || _hasError ? 1.8 : 1,
        ),
        boxShadow:
            isActive && !_hasError
                ? [
                  BoxShadow(
                    color: Brand.blue.withValues(alpha: 0.12),
                    spreadRadius: 4,
                  ),
                ]
                : null,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        transitionBuilder:
            (child, animation) =>
                ScaleTransition(scale: animation, child: child),
        child: Text(
          digit,
          key: ValueKey('$index-$digit'),
          style: TextStyle(
            fontFamily: Brand.displayFont,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: palette.title,
          ),
        ),
      ),
    );
  }

  Widget _buildDebugCode(AuthPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Brand.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Brand.radiusSm),
          border: Border.all(color: Brand.warning.withValues(alpha: 0.4)),
        ),
        child: Text.rich(
          TextSpan(
            text: 'Modo prueba · tu código es ',
            children: [
              TextSpan(
                text: _debugCode,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: Brand.displayFont,
            color: palette.label,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildResendButton(AuthPalette palette) {
    final canResend = _resendCountdown == 0 && !_isResending && !_isLoading;

    return TextButton(
      onPressed: canResend ? _resendCode : null,
      child: Text(
        _isResending
            ? 'Enviando…'
            : _resendCountdown > 0
            ? '¿No llegó? Revisa spam · reenviar en ${_resendCountdown}s'
            : '¿No llegó? Reenviar código',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: Brand.displayFont,
          color: canResend ? Brand.blue : palette.muted,
          fontWeight: canResend ? FontWeight.w700 : FontWeight.w500,
          fontSize: 13.5,
        ),
      ),
    );
  }
}
