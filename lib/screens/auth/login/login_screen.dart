import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/screens/main_content/home/home_screen.dart';
import 'package:connect_do/screens/auth/register/benefits_screen.dart';
import 'package:connect_do/services/auth_service.dart';
import 'package:connect_do/services/profile_service.dart';
import 'package:connect_do/utils/responsive_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isCheckingMemory = true;
  bool _obscureText = true;

  String? _savedName;
  String? _savedEmail;
  String? _savedGooglePhotoUrl;
  String? _savedProfileImageBase64;

  bool _showQuickLogin = false;
  bool _hasSavedUser = false;

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
        String cleanBase64 = base64Photo;

        if (cleanBase64.contains(',')) {
          cleanBase64 = cleanBase64.split(',').last;
        }

        final Uint8List bytes = base64Decode(cleanBase64);

        return MemoryImage(bytes);
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
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vuelve a iniciar sesión para conectar con el servidor.',
          ),
          backgroundColor: Colors.orange,
        ),
      );

      return;
    }

    setState(() {
      _isLoading = true;
    });

    await prefs.setBool('sesion_activa', true);

    await _syncSavedUserWithBackendProfile();

    await Future.delayed(const Duration(milliseconds: 300));

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
    final typedEmail = _userController.text.trim();
    final typedPassword = _passwordController.text.trim();

    if (typedEmail.isEmpty || typedPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa correo y contraseña'),
          backgroundColor: Colors.orange,
        ),
      );

      return;
    }

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
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo iniciar sesión: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =====================================================
  // RECUPERAR CONTRASEÑA VISUAL
  // =====================================================
  void _showForgotPasswordDialog() {
    final emailController = TextEditingController(text: _userController.text);

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Text(
            'Recuperar contraseña',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            cursorColor: const Color(0xFF22C55E),
            decoration: InputDecoration(
              hintText: 'Ingresa tu correo',
              hintStyle: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey,
              ),
              helperText: 'Versión demo: recuperación próximamente.',
              helperStyle: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final email = emailController.text.trim();

                if (email.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ingresa tu correo'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Te enviaremos instrucciones cuando esta función esté disponible.',
                    ),
                    backgroundColor: Color(0xFF2563EB),
                  ),
                );
              },
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isCheckingMemory) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF2563EB)),
        ),
      );
    }

    final savedImage = _getSavedUserImage();

    final bottomPadding =
        ResponsiveHelper.keyboard(context) +
        ResponsiveHelper.bottomSafe(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(30, 30, 30, bottomPadding + 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_showQuickLogin && _hasSavedUser) ...[
                  Text(
                    'Bienvenido de nuevo',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white70 : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 30),

                  GestureDetector(
                    onTap: _isLoading ? null : _handleQuickLogin,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 55,
                            backgroundColor: const Color(0xFFE2E8F0),
                            backgroundImage: savedImage,
                            child:
                                savedImage == null
                                    ? const Icon(
                                      Icons.person,
                                      size: 55,
                                      color: Color(0xFF2563EB),
                                    )
                                    : null,
                          ),

                          const SizedBox(height: 20),

                          Text(
                            _savedName ?? 'Usuario',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 4),

                          Text(
                            _savedEmail ?? '',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.grey,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 30),

                          if (_isLoading)
                            const CircularProgressIndicator(
                              color: Color(0xFF2563EB),
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Center(
                                child: Text(
                                  'ENTRAR AHORA',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  TextButton(
                    onPressed:
                        _isLoading
                            ? null
                            : () {
                              setState(() {
                                _showQuickLogin = false;
                              });
                            },
                    child: const Text(
                      'Usar otra cuenta',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ] else ...[
                  const Icon(
                    Icons.lock_person_rounded,
                    size: 80,
                    color: Color(0xFF2563EB),
                  ),

                  const SizedBox(height: 40),

                  _buildTextField(
                    controller: _userController,
                    hint: 'Correo institucional',
                    icon: Icons.alternate_email,
                    isDark: isDark,
                    keyboardType: TextInputType.emailAddress,
                  ),

                  const SizedBox(height: 15),

                  _buildTextField(
                    controller: _passwordController,
                    hint: 'Contraseña',
                    icon: Icons.lock_outline,
                    isPassword: true,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 6),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _showForgotPasswordDialog,
                      child: const Text(
                        '¿Olvidaste tu contraseña?',
                        style: TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleManualLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        disabledBackgroundColor: Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child:
                          _isLoading
                              ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                              : const Text(
                                'Iniciar Sesión',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  if (_hasSavedUser)
                    TextButton(
                      onPressed:
                          _isLoading
                              ? null
                              : () {
                                setState(() {
                                  _showQuickLogin = true;
                                });
                              },
                      child: const Text(
                        'Volver al usuario guardado',
                        style: TextStyle(color: Color(0xFF22C55E)),
                      ),
                    ),

                  const SizedBox(height: 10),

                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '¿No tienes cuenta? ',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      TextButton(
                        onPressed:
                            _isLoading
                                ? null
                                : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const BenefitsScreen(),
                                    ),
                                  );
                                },
                        child: const Text(
                          'Regístrate',
                          style: TextStyle(
                            color: Color(0xFF22C55E),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _obscureText : false,
        keyboardType: keyboardType,
        textInputAction:
            isPassword ? TextInputAction.done : TextInputAction.next,
        onSubmitted: (_) {
          if (isPassword) {
            _handleManualLogin();
          }
        },
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        cursorColor: const Color(0xFF22C55E),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
          prefixIcon: Icon(icon, color: const Color(0xFF2563EB)),
          suffixIcon:
              isPassword
                  ? IconButton(
                    icon: Icon(
                      _obscureText
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: isDark ? Colors.white70 : Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  )
                  : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}
