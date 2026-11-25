import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/services/auth_service.dart';
import 'package:connect_do/services/user_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/auth/auth_layout.dart';
import 'package:connect_do/widgets/auth/code_input.dart';

/// Cambiar el correo: 1) correo nuevo + contraseña → 2) código enviado al
/// correo nuevo. Devuelve true si se cambió.
class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();

  String _currentEmail = '';
  bool _codeSent = false;
  bool _isLoading = false;
  bool _codeError = false;
  String? _emailError;
  String? _debugCode;

  @override
  void initState() {
    super.initState();
    UserService.getUser().then((user) {
      if (mounted) {
        setState(() => _currentEmail = user['email']?.toString() ?? '');
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
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
      final debugCode = await AuthService.requestEmailChange(
        newEmail: email,
        password: _passwordController.text,
      );
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _debugCode = debugCode;
      });
    } catch (error) {
      if (mounted) showAuthMessage(context, error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirm([String? completed]) async {
    final code = completed ?? _codeController.text;
    if (code.length < 6) {
      setState(() => _codeError = true);
      return;
    }

    setState(() {
      _codeError = false;
      _isLoading = true;
    });

    try {
      await AuthService.confirmEmailChange(code);
      if (!mounted) return;
      showAuthMessage(
        context,
        'Tu correo ahora es ${_emailController.text.trim()}',
        type: AuthMessageType.success,
      );
      Navigator.pop(context, true);
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
      headerIcon: PhosphorIconsRegular.envelopeSimple,
      title: _codeSent ? 'Revisa tu correo nuevo' : 'Cambiar correo',
      subtitle: Text(
        _codeSent
            ? 'Escribe el código que enviamos a ${_emailController.text.trim()}'
            : _currentEmail.isEmpty
            ? 'Te enviaremos un código al correo nuevo.'
            : 'Tu correo actual es $_currentEmail',
      ),
      onBack:
          _codeSent && !_isLoading
              ? () => setState(() => _codeSent = false)
              : null,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child:
            _codeSent
                ? Column(
                  key: const ValueKey('code'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CodeInput(
                      controller: _codeController,
                      hasError: _codeError,
                      enabled: !_isLoading,
                      autofocus: true,
                      onCompleted: _confirm,
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
                    const SizedBox(height: 24),
                    GradientButton(
                      text: 'Confirmar correo',
                      isLoading: _isLoading,
                      trailingIcon: PhosphorIconsRegular.checkCircle,
                      onPressed: _confirm,
                    ),
                  ],
                )
                : Column(
                  key: const ValueKey('form'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthTextField(
                      controller: _emailController,
                      label: 'Correo nuevo',
                      hint: 'tu.correo@gmail.com',
                      icon: PhosphorIconsRegular.envelopeSimple,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      errorText: _emailError,
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      controller: _passwordController,
                      label: 'Tu contraseña',
                      hint: 'Para confirmar que eres tú',
                      icon: PhosphorIconsRegular.lockSimple,
                      isPassword: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      enabled: !_isLoading,
                      onSubmitted: (_) => _sendCode(),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 2),
                      child: Text(
                        'Si entraste con Google y no tienes contraseña, '
                        'déjala vacía.',
                        style: TextStyle(
                          fontFamily: Brand.displayFont,
                          fontSize: 12.5,
                          color: palette.muted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    GradientButton(
                      text: 'Enviar código',
                      isLoading: _isLoading,
                      trailingIcon: PhosphorIconsRegular.paperPlaneTilt,
                      onPressed: _sendCode,
                    ),
                  ],
                ),
      ),
    );
  }
}
