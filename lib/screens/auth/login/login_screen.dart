import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/screens/account/forgot_password_screen.dart';
import 'package:connect_do/screens/main_content/home/home_screen.dart';
import 'package:connect_do/screens/auth/register/register_screen.dart';
import 'package:connect_do/services/auth_service.dart';
import 'package:connect_do/services/profile_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/auth/auth_layout.dart';
import 'package:connect_do/widgets/form/google_sign_in_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isCheckingMemory = true;

  String? _savedName;
  String? _savedEmail;
  String? _savedGooglePhotoUrl;
  String? _savedProfileImageBase64;

  bool _showQuickLogin = false;
  bool _hasSavedUser = false;

  Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    _checkSavedUser();
  }

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // =====================================================
  // REVISAR SI HAY USUARIO GUARDADO
  // =====================================================
  Future<void> _checkSavedUser() async {
    final prefs = await SharedPreferences.getInstance();

    final datosJson = prefs.getString('usuario_actual');

    if (datosJson != null && datosJson.isNotEmpty) {
      try {
        final Map<String, dynamic> userData = jsonDecode(datosJson);

        final firstName =
            userData['firstName']?.toString() ??
            userData['first_name']?.toString() ??
            '';

        final lastName =
            userData['lastName']?.toString() ??
            userData['last_name']?.toString() ??
            '';

        final fullName = '$firstName $lastName'.trim();

        final email = userData['email']?.toString() ?? '';

        String displayName = fullName;

        if (displayName.isEmpty && email.isNotEmpty) {
          displayName = email.split('@')[0].replaceAll('.', ' ');
        }

        final googlePhoto =
            userData['google_photo_url']?.toString() ??
            userData['photoUrl']?.toString() ??
            userData['photo_url']?.toString() ??
            '';

        final profileImageBase64 =
            userData['profile_image_base64']?.toString() ?? '';

        if (!mounted) return;

        setState(() {
          _savedEmail = email;
          _savedName = displayName.isNotEmpty ? displayName : 'Usuario';
          _savedGooglePhotoUrl = googlePhoto;
          _savedProfileImageBase64 = profileImageBase64;
          _hasSavedUser = email.isNotEmpty;
          _showQuickLogin = email.isNotEmpty;
        });
      } catch (_) {
        if (!mounted) return;

        setState(() {
          _savedEmail = null;
          _savedName = null;
          _savedGooglePhotoUrl = null;
          _savedProfileImageBase64 = null;
          _hasSavedUser = false;
          _showQuickLogin = false;
        });
      }
    }

    if (!mounted) return;

    setState(() {
      _isCheckingMemory = false;
    });
  }

  // =====================================================
  // SINCRONIZAR FOTO DESDE BACKEND
  // =====================================================
  Future<void> _syncSavedUserWithBackendProfile() async {
    try {
      final backendProfile = await ProfileService.getMyProfile();

      if (backendProfile == null) return;

      final backendPhoto =
          backendProfile['profile_image_base64']?.toString() ?? '';

      if (backendPhoto.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final datosJson = prefs.getString('usuario_actual');

      Map<String, dynamic> userData = {};

      if (datosJson != null && datosJson.isNotEmpty) {
        try {
          userData = jsonDecode(datosJson) as Map<String, dynamic>;
        } catch (_) {
          userData = {};
        }
      }

      userData['profile_image_base64'] = backendPhoto;

      await prefs.setString('usuario_actual', jsonEncode(userData));

      if (!mounted) return;

      setState(() {
        _savedProfileImageBase64 = backendPhoto;
      });
    } catch (_) {
      // Si falla, usamos lo local y no rompemos el login.
    }
  }

  // =====================================================
  // OBTENER FOTO GUARDADA
  // =====================================================
  ImageProvider? _getSavedUserImage() {
    final base64Photo = _savedProfileImageBase64?.trim() ?? '';

    if (base64Photo.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(base64Photo.split(',').last));
      } catch (_) {
        return null;
      }
    }

    final googlePhoto = _savedGooglePhotoUrl?.trim() ?? '';

    if (googlePhoto.isNotEmpty) {
      return NetworkImage(googlePhoto);
    }

    return null;
  }

  // =====================================================
  // ENTRAR COMO USUARIO GUARDADO
  // =====================================================
  Future<void> _handleQuickLogin() async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString('access_token');

    if (token == null || token.isEmpty) {
      if (!mounted) return;

      setState(() {
        _showQuickLogin = false;
        _userController.text = _savedEmail ?? '';
      });

      showAuthMessage(
        context,
        'Tu sesión expiró. Escribe tu contraseña para continuar.',
        type: AuthMessageType.info,
      );

      return;
    }

    setState(() {
      _isLoading = true;
    });

    await prefs.setBool('sesion_activa', true);

    await _syncSavedUserWithBackendProfile();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  // =====================================================
  // LOGIN MANUAL CON BACKEND
  // =====================================================
  Future<void> _handleManualLogin() async {
    FocusScope.of(context).unfocus();

    final typedEmail = _userController.text.trim();
    final typedPassword = _passwordController.text.trim();

    final errors = <String, String>{
      if (typedEmail.isEmpty) 'email': 'Escribe tu correo.',
      if (typedPassword.isEmpty) 'password': 'Escribe tu contraseña.',
    };

    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService.login(email: typedEmail, password: typedPassword);

      await _syncSavedUserWithBackendProfile();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showAuthMessage(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showAuthMessage(
        context,
        'No pudimos conectar con el servidor. Revisa tu internet.',
      );
    }
  }

  // =====================================================
  // RECUPERAR CONTRASEÑA
  // =====================================================
  Future<void> _openForgotPassword() async {
    final email = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder:
            (_) => ForgotPasswordScreen(initialEmail: _userController.text),
      ),
    );

    // Al volver con la contraseña cambiada, deja el correo listo.
    if (email != null && mounted) {
      setState(() {
        _showQuickLogin = false;
        _userController.text = email;
        _passwordController.clear();
      });
    }
  }

  void _goToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  // =====================================================
  // UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    if (_isCheckingMemory) {
      return Scaffold(
        backgroundColor: AuthPalette.of(context).background,
        body: const Center(child: CircularProgressIndicator(color: Brand.blue)),
      );
    }

    final quick = _showQuickLogin && _hasSavedUser;
    final firstName = (_savedName ?? '').split(' ').first;

    return AuthLayout(
      title: quick ? 'Hola de nuevo, $firstName' : 'Bienvenido de nuevo',
      subtitle: Text(
        quick
            ? 'Continúa donde lo dejaste.'
            : 'Inicia sesión para ver nuevas oportunidades.',
      ),
      footer: AuthFooterLink(
        question: '¿No tienes cuenta?',
        action: 'Regístrate',
        onTap: _isLoading || _isGoogleLoading ? null : _goToRegister,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder:
            (child, animation) => FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                alignment: Alignment.topCenter,
                child: child,
              ),
            ),
        child: quick ? _buildQuickLogin() : _buildManualLogin(),
      ),
    );
  }

  Widget _buildQuickLogin() {
    final palette = AuthPalette.of(context);
    final savedImage = _getSavedUserImage();
    final firstName = (_savedName ?? 'Usuario').split(' ').first;

    return Column(
      key: const ValueKey('quick'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Brand.blue, Brand.green],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.card,
              ),
              child: CircleAvatar(
                radius: 44,
                backgroundColor: palette.fieldFill,
                backgroundImage: savedImage,
                child:
                    savedImage == null
                        ? Icon(
                          PhosphorIconsRegular.user,
                          size: 40,
                          color: palette.muted,
                        )
                        : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _savedName ?? 'Usuario',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: Brand.displayFont,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.title,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _savedEmail ?? '',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: Brand.displayFont,
            fontSize: 14,
            color: palette.body,
          ),
        ),
        const SizedBox(height: 24),
        GradientButton(
          text: 'Continuar como $firstName',
          isLoading: _isLoading,
          onPressed: _handleQuickLogin,
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed:
              _isLoading
                  ? null
                  : () => setState(() {
                    _showQuickLogin = false;
                    _errors = {};
                  }),
          icon: Icon(
            PhosphorIconsRegular.userPlus,
            size: 18,
            color: palette.body,
          ),
          label: Text(
            'Usar otra cuenta',
            style: TextStyle(
              fontFamily: Brand.displayFont,
              color: palette.body,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualLogin() {
    final palette = AuthPalette.of(context);
    final busy = _isLoading || _isGoogleLoading;

    return AutofillGroup(
      key: const ValueKey('manual'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GoogleSignInButton(
            enabled: !_isLoading,
            onLoadingChanged: (v) => setState(() => _isGoogleLoading = v),
          ),
          const AuthDivider(text: 'o con tu correo'),
          AuthTextField(
            controller: _userController,
            label: 'Correo electrónico',
            hint: 'tu.correo@gmail.com',
            icon: PhosphorIconsRegular.envelopeSimple,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email, AutofillHints.username],
            errorText: _errors['email'],
            enabled: !busy,
            onChanged: (_) {
              if (_errors.containsKey('email')) {
                setState(() => _errors = {..._errors}..remove('email'));
              }
            },
          ),
          const SizedBox(height: 16),
          AuthTextField(
            controller: _passwordController,
            label: 'Contraseña',
            hint: 'Tu contraseña',
            icon: PhosphorIconsRegular.lockSimple,
            isPassword: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            errorText: _errors['password'],
            enabled: !busy,
            onChanged: (_) {
              if (_errors.containsKey('password')) {
                setState(() => _errors = {..._errors}..remove('password'));
              }
            },
            onSubmitted: (_) => _handleManualLogin(),
            trailingLabel: GestureDetector(
              onTap: busy ? null : _openForgotPassword,
              child: const Text(
                '¿La olvidaste?',
                style: TextStyle(
                  fontFamily: Brand.displayFont,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Brand.blue,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          GradientButton(
            text: 'Iniciar sesión',
            isLoading: _isLoading,
            onPressed: _isGoogleLoading ? null : _handleManualLogin,
          ),
          if (_hasSavedUser) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed:
                  busy ? null : () => setState(() => _showQuickLogin = true),
              child: Text(
                'Volver a ${(_savedName ?? 'mi cuenta').split(' ').first}',
                style: TextStyle(
                  fontFamily: Brand.displayFont,
                  color: palette.body,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
