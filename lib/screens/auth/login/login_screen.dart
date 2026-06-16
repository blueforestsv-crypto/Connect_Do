import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/screens/main_content/home/home_screen.dart';
import 'package:connect_do/screens/auth/register/benefits_screen.dart';
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
  String? _savedLocalPhotoPath;

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

    if (!mounted) return;

    final datosJson = prefs.getString('usuario_actual');

    if (datosJson != null && datosJson.isNotEmpty) {
      final Map<String, dynamic> userData = jsonDecode(datosJson);

      final firstName = userData['firstName'] ?? '';
      final lastName = userData['lastName'] ?? '';
      final fullName = '$firstName $lastName'.trim();

      final email = (userData['email'] ?? '').toString();

      String displayName = fullName;

      if (displayName.isEmpty && email.isNotEmpty) {
        displayName = email.split('@')[0].replaceAll('.', ' ');
      }

      if (!mounted) return;

      setState(() {
        _savedEmail = email;
        _savedName = displayName.isNotEmpty ? displayName : 'Usuario';
        _savedGooglePhotoUrl = userData['google_photo_url'] ?? '';
        _savedLocalPhotoPath = userData['profile_image_path'] ?? '';
        _hasSavedUser = email.isNotEmpty;
        _showQuickLogin = email.isNotEmpty;
      });
    }

    if (!mounted) return;

    setState(() {
      _isCheckingMemory = false;
    });
  }

  // =====================================================
  // OBTENER FOTO GUARDADA
  // =====================================================
  ImageProvider? _getSavedUserImage() {
    if (_savedLocalPhotoPath != null && _savedLocalPhotoPath!.isNotEmpty) {
      final file = File(_savedLocalPhotoPath!);

      if (file.existsSync()) {
        return FileImage(file);
      }
    }

    if (_savedGooglePhotoUrl != null && _savedGooglePhotoUrl!.isNotEmpty) {
      return NetworkImage(_savedGooglePhotoUrl!);
    }

    return null;
  }

  // =====================================================
  // ENTRAR COMO USUARIO GUARDADO
  // =====================================================
  Future<void> _handleQuickLogin() async {
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    await prefs.setBool('sesion_activa', true);

    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  // =====================================================
  // LOGIN MANUAL LOCAL
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

    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    final datosJson = prefs.getString('usuario_actual');

    if (datosJson == null || datosJson.isEmpty) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay una cuenta registrada en este dispositivo'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final Map<String, dynamic> userData = jsonDecode(datosJson);

    final savedEmail = (userData['email'] ?? '').toString().trim();
    final savedPassword = (userData['password'] ?? '').toString().trim();

    await Future.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;

    final emailMatches = typedEmail.toLowerCase() == savedEmail.toLowerCase();

    final passwordMatches = typedPassword == savedPassword;

    if (emailMatches && passwordMatches) {
      await prefs.setBool('sesion_activa', true);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } else {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Correo o contraseña incorrectos'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                    "Bienvenido de nuevo",
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
                            _savedName ?? "Usuario",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 4),

                          Text(
                            _savedEmail ?? "",
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
                                  "ENTRAR AHORA",
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
                      "Usar otra cuenta",
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
                    hint: "Correo institucional",
                    icon: Icons.alternate_email,
                    isDark: isDark,
                    keyboardType: TextInputType.emailAddress,
                  ),

                  const SizedBox(height: 15),

                  _buildTextField(
                    controller: _passwordController,
                    hint: "Contraseña",
                    icon: Icons.lock_outline,
                    isPassword: true,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 30),

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
                                "Iniciar Sesión",
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
                        "Volver al usuario guardado",
                        style: TextStyle(color: Color(0xFF22C55E)),
                      ),
                    ),

                  const SizedBox(height: 10),

                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        "¿No tienes cuenta? ",
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
                          "Regístrate",
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
