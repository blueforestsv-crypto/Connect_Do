import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/services/auth_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/auth/auth_layout.dart';
import 'package:connect_do/widgets/auth/password_strength.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  static const int _minPassword = 8;

  final _currentController = TextEditingController();
  final _newController = TextEditingController();

  bool _isLoading = false;
  String? _newError;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final newPassword = _newController.text;

    if (newPassword.length < _minPassword) {
      setState(() => _newError = 'Usa al menos $_minPassword caracteres.');
      return;
    }
    if (newPassword == _currentController.text) {
      setState(() => _newError = 'Debe ser distinta de la actual.');
      return;
    }

    setState(() {
      _newError = null;
      _isLoading = true;
    });

    try {
      final message = await AuthService.changePassword(
        currentPassword: _currentController.text,
        newPassword: newPassword,
      );
      if (!mounted) return;
      showAuthMessage(context, message, type: AuthMessageType.success);
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showAuthMessage(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return AuthLayout(
      headerIcon: PhosphorIconsRegular.lockSimple,
      title: 'Cambiar contraseña',
      subtitle: const Text('Usa una contraseña que no uses en otras apps.'),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthTextField(
              controller: _currentController,
              label: 'Contraseña actual',
              hint: 'Tu contraseña de ahora',
              icon: PhosphorIconsRegular.lockSimple,
              isPassword: true,
              autofillHints: const [AutofillHints.password],
              enabled: !_isLoading,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 2),
              child: Text(
                'Si entraste con Google y nunca creaste una, déjala vacía.',
                style: TextStyle(
                  fontFamily: Brand.displayFont,
                  fontSize: 12.5,
                  color: palette.muted,
                ),
              ),
            ),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _newController,
              label: 'Contraseña nueva',
              hint: 'Mínimo $_minPassword caracteres',
              icon: PhosphorIconsRegular.key,
              isPassword: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              errorText: _newError,
              enabled: !_isLoading,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
            ),
            PasswordStrength(password: _newController.text),
            const SizedBox(height: 24),
            GradientButton(
              text: 'Guardar contraseña',
              isLoading: _isLoading,
              trailingIcon: PhosphorIconsRegular.checkCircle,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
