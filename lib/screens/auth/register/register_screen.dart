import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/screens/auth/register/verification_screen.dart';
import 'package:connect_do/services/auth_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/utils/academic_options.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/auth/auth_layout.dart';
import 'package:connect_do/widgets/auth/password_strength.dart';
import 'package:connect_do/widgets/form/google_sign_in_button.dart';

/// Registro en una sola pantalla: solo lo necesario para crear la cuenta.
/// El resto del perfil se completa después desde la app.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const int _minPasswordLength = 8;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _detectedUniversity;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  /// Errores en línea por campo; se muestran después del primer intento.
  Map<String, String> _errors = {};
  bool _submitted = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onEmailChanged(String value) {
    final university = AcademicOptions.universityFromEmail(value);

    if (university != _detectedUniversity) {
      setState(() => _detectedUniversity = university);
    }
    _revalidate();
  }

  void _revalidate([String? _]) {
    if (_submitted) setState(() => _errors = _validate());
  }

  Map<String, String> _validate() {
    final errors = <String, String>{};
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (firstName.length < 2) errors['firstName'] = 'Escribe tu nombre.';
    if (lastName.length < 2) errors['lastName'] = 'Escribe tu apellido.';

    if (email.isEmpty) {
      errors['email'] = 'Escribe tu correo.';
    } else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      errors['email'] = 'Ese correo no parece válido.';
    }

    if (password.length < _minPasswordLength) {
      errors['password'] = 'Usa al menos $_minPasswordLength caracteres.';
    }

    return errors;
  }

  Future<void> _createAccount() async {
    FocusScope.of(context).unfocus();

    final errors = _validate();
    setState(() {
      _submitted = true;
      _errors = errors;
    });
    if (errors.isNotEmpty) return;

    final email = _emailController.text.trim();

    setState(() => _isLoading = true);

    try {
      await AuthService.createAccount(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        email: email,
        password: _passwordController.text,
        university: _detectedUniversity,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showAuthMessage(context, e.toString());
      return;
    }

    // La cuenta ya existe: si falla el envío, se reintenta desde la
    // pantalla de verificación con "Reenviar código".
    String? debugCode;
    String? sendError;
    try {
      debugCode = await AuthService.requestVerificationCode(email);
    } catch (e) {
      sendError = e.toString();
    }

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder:
            (_) => VerificationScreen(
              email: email,
              debugCode: debugCode,
              initialError: sendError,
            ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _isLoading || _isGoogleLoading;

    return AuthLayout(
      title: 'Crea tu cuenta',
      subtitle: const Text(
        'Conecta con empresas que buscan talento universitario.',
      ),
      footer: AuthFooterLink(
        question: '¿Ya tienes cuenta?',
        action: 'Inicia sesión',
        onTap:
            busy
                ? null
                : () => Navigator.pushReplacementNamed(context, '/login'),
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GoogleSignInButton(
              text: 'Regístrate con Google',
              signUp: true,
              enabled: !_isLoading,
              onLoadingChanged: (v) => setState(() => _isGoogleLoading = v),
            ),
            const AuthDivider(text: 'o con tu correo'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AuthTextField(
                    controller: _firstNameController,
                    label: 'Nombre',
                    hint: 'Ana',
                    icon: PhosphorIconsRegular.user,
                    keyboardType: TextInputType.name,
                    autofillHints: const [AutofillHints.givenName],
                    errorText: _errors['firstName'],
                    onChanged: _revalidate,
                    enabled: !busy,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AuthTextField(
                    controller: _lastNameController,
                    label: 'Apellido',
                    hint: 'López',
                    icon: PhosphorIconsRegular.user,
                    keyboardType: TextInputType.name,
                    autofillHints: const [AutofillHints.familyName],
                    errorText: _errors['lastName'],
                    onChanged: _revalidate,
                    enabled: !busy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _emailController,
              label: 'Correo electrónico',
              hint: 'tu.correo@gmail.com',
              icon: PhosphorIconsRegular.envelopeSimple,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              errorText: _errors['email'],
              onChanged: _onEmailChanged,
              enabled: !busy,
            ),
            _UniversityChip(acronym: _detectedUniversity),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _passwordController,
              label: 'Contraseña',
              hint: 'Mínimo $_minPasswordLength caracteres',
              icon: PhosphorIconsRegular.lockSimple,
              isPassword: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              errorText: _errors['password'],
              onChanged: (_) {
                setState(() {});
                _revalidate();
              },
              onSubmitted: (_) => _createAccount(),
              enabled: !busy,
            ),
            PasswordStrength(password: _passwordController.text),
            const SizedBox(height: 24),
            GradientButton(
              text: 'Crear cuenta',
              isLoading: _isLoading,
              onPressed: _isGoogleLoading ? null : _createAccount,
            ),
            const SizedBox(height: 14),
            Text(
              'Te enviaremos un código para confirmar tu correo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: Brand.displayFont,
                fontSize: 12.5,
                color: AuthPalette.of(context).muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Universidad deducida del dominio del correo.
class _UniversityChip extends StatelessWidget {
  final String? acronym;

  const _UniversityChip({required this.acronym});

  @override
  Widget build(BuildContext context) {
    final university =
        acronym == null ? null : AcademicOptions.universityByAcronym(acronym);

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topLeft,
      child:
          acronym == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
                    decoration: BoxDecoration(
                      color: Brand.green.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Brand.green.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          PhosphorIconsRegular.graduationCap,
                          size: 16,
                          color: Brand.success,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            university == null
                                ? acronym!
                                : AcademicOptions.universityLabel(acronym!),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: Brand.displayFont,
                              fontSize: 12.5,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                              color: Brand.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }
}
