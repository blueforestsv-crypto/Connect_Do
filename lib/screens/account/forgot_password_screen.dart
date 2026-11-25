import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/services/auth_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/auth/auth_layout.dart';
import 'package:connect_do/widgets/auth/code_input.dart';
import 'package:connect_do/widgets/auth/password_strength.dart';

/// Recuperar contraseña: 1) correo → 2) código + contraseña nueva.
/// Al terminar devuelve el correo para rellenar el login.
class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const int _minPassword = 8;
  static const int _resendSeconds = 60;

  late final _emailController = TextEditingController(
    text: widget.initialEmail,
  );
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _codeSent = false;
  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;
  bool _codeError = false;
  String? _debugCode;

  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _countdown--);
      if (_countdown <= 0) timer.cancel();
    });
  }

  Future<void> _sendCode() async {
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim();

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _emailError = 'Escribe un correo válido.');
      return;
    }

    setState(() {
      _emailError = null;
      _isLoading = true;
    });

    try {
      final debugCode = await AuthService.requestPasswordReset(email);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _debugCode = debugCode;
        _codeController.clear();
      });
      _startCountdown();
    } catch (error) {
      if (mounted) showAuthMessage(context, error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirm() async {
    FocusScope.of(context).unfocus();
    final code = _codeController.text;
    final password = _passwordController.text;

    setState(() {
      _codeError = code.length < 6;
      _passwordError =
          password.length < _minPassword
              ? 'Usa al menos $_minPassword caracteres.'
              : null;
    });
    if (_codeError || _passwordError != null) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      await AuthService.confirmPasswordReset(
        email: email,
        code: code,
        newPassword: password,
      );
      if (!mounted) return;
      showAuthMessage(
        context,
        'Contraseña actualizada. Ya puedes entrar.',
        type: AuthMessageType.success,
      );
      Navigator.pop(context, email);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _codeError = true;
      });
      _codeController.clear();
      showAuthMessage(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return AuthLayout(
      headerIcon: PhosphorIconsRegular.key,
      title: _codeSent ? 'Crea una contraseña nueva' : 'Recupera tu cuenta',
      subtitle: Text(
        _codeSent
            ? 'Escribe el código que enviamos a ${_emailController.text.trim()}'
            : 'Te enviaremos un código a tu correo para que elijas una '
                'contraseña nueva.',
      ),
      onBack:
          _codeSent && !_isLoading
              ? () => setState(() {
                _codeSent = false;
                _timer?.cancel();
              })
              : null,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _codeSent ? _buildCodeStep(palette) : _buildEmailStep(),
      ),
    );
  }

  Widget _buildEmailStep() {
    return Column(
      key: const ValueKey('email'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthTextField(
          controller: _emailController,
          label: 'Correo electrónico',
          hint: 'tu.correo@gmail.com',
          icon: PhosphorIconsRegular.envelopeSimple,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          errorText: _emailError,
          enabled: !_isLoading,
          onSubmitted: (_) => _sendCode(),
        ),
        const SizedBox(height: 24),
        GradientButton(
          text: 'Enviar código',
          isLoading: _isLoading,
          trailingIcon: PhosphorIconsRegular.paperPlaneTilt,
          onPressed: _sendCode,
        ),
      ],
    );
  }

  Widget _buildCodeStep(AuthPalette palette) {
    return Column(
      key: const ValueKey('code'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AuthFieldLabel('Código'),
        CodeInput(
          controller: _codeController,
          hasError: _codeError,
          enabled: !_isLoading,
          autofocus: true,
          onCompleted: (_) => setState(() => _codeError = false),
        ),
        if (_debugCode != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Modo prueba · tu código es $_debugCode',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: Brand.displayFont,
                fontSize: 12.5,
                color: palette.muted,
              ),
            ),
          ),
        const SizedBox(height: 18),
        AuthTextField(
          controller: _passwordController,
          label: 'Contraseña nueva',
          hint: 'Mínimo $_minPassword caracteres',
          icon: PhosphorIconsRegular.lockSimple,
          isPassword: true,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          errorText: _passwordError,
          enabled: !_isLoading,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _confirm(),
        ),
        PasswordStrength(password: _passwordController.text),
        const SizedBox(height: 24),
        GradientButton(
          text: 'Cambiar contraseña',
          isLoading: _isLoading,
          trailingIcon: PhosphorIconsRegular.checkCircle,
          onPressed: _confirm,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _countdown > 0 || _isLoading ? null : _sendCode,
          child: Text(
            _countdown > 0
                ? '¿No llegó? Revisa spam · reenviar en ${_countdown}s'
                : '¿No llegó? Reenviar código',
            style: TextStyle(
              fontFamily: Brand.displayFont,
              fontWeight: FontWeight.w600,
              color: _countdown > 0 ? palette.muted : Brand.blue,
            ),
          ),
        ),
      ],
    );
  }
}
