import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/screens/auth/register/welcome_screen.dart';
import 'package:connect_do/services/auth_service.dart';
import 'package:connect_do/services/safety_service.dart';
import 'package:connect_do/services/user_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/auth/auth_layout.dart';

/// Eliminar la cuenta y todos los datos (lo exige Google Play).
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _controller = TextEditingController();
  bool _deleting = false;

  /// Las cuentas creadas solo con Google no tienen contraseña: confirman
  /// escribiendo ELIMINAR.
  bool _googleOnly = false;

  @override
  void initState() {
    super.initState();
    UserService.getUser().then((user) {
      if (!mounted) return;
      setState(() {
        _googleOnly = user['has_password'] == false;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      showAuthMessage(
        context,
        _googleOnly
            ? 'Escribe ELIMINAR para confirmar.'
            : 'Escribe tu contraseña para confirmar.',
      );
      return;
    }

    setState(() => _deleting = true);
    try {
      await SafetyService.deleteAccount(
        password: _googleOnly ? null : value,
        confirm: _googleOnly ? value : 'ELIMINAR',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _deleting = false);
      final message = error.toString().replaceFirst('Exception: ', '');
      // Cuenta de Google sin contraseña: se pide ELIMINAR.
      if (message.contains('ELIMINAR') && !_googleOnly) {
        setState(() {
          _googleOnly = true;
          _controller.clear();
        });
      }
      showAuthMessage(context, message);
      return;
    }

    // Borrar todo lo guardado en el teléfono y volver al inicio.
    await AuthService.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
    showAuthMessage(
      context,
      'Tu cuenta y tus datos fueron eliminados.',
      type: AuthMessageType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return AuthLayout(
      headerIcon: PhosphorIconsRegular.trash,
      title: 'Eliminar mi cuenta',
      subtitle: const Text(
        'Se borrarán para siempre tu perfil, CV, publicaciones, mensajes, '
        'historias, stickers, contactos y postulaciones. No se puede deshacer.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthTextField(
            controller: _controller,
            label: _googleOnly ? 'Escribe ELIMINAR' : 'Tu contraseña',
            hint: _googleOnly ? 'ELIMINAR' : 'Para confirmar que eres tú',
            icon:
                _googleOnly
                    ? PhosphorIconsRegular.warning
                    : PhosphorIconsRegular.lockSimple,
            isPassword: !_googleOnly,
            enabled: !_deleting,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _delete(),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 2),
            child: Text(
              _googleOnly
                  ? 'Tu cuenta usa Google, así que no tiene contraseña.'
                  : '¿Entraste con Google y no tienes contraseña? Escribe '
                      'ELIMINAR.',
              style: TextStyle(
                fontFamily: Brand.displayFont,
                fontSize: 12.5,
                color: palette.muted,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Brand.danger,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Brand.radiusMd),
                ),
              ),
              onPressed: _deleting ? null : _delete,
              icon:
                  _deleting
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(PhosphorIconsRegular.trash),
              label: const Text(
                'Eliminar mi cuenta para siempre',
                style: TextStyle(
                  fontFamily: Brand.displayFont,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
