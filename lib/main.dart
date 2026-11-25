import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 1. TODOS LOS IMPORTS
import 'screens/auth/register/welcome_screen.dart';
import 'screens/auth/register/benefits_screen.dart';
import 'screens/auth/login/login_screen.dart';
import 'screens/auth/register/register_screen.dart';
import 'screens/auth/register/verification_screen.dart';

import 'screens/main_content/home/home_screen.dart';
import 'screens/main_content/chats/chatlist_screen.dart';
import 'screens/main_content/notification/notifications_screen.dart';
import 'screens/main_content/profile/profile_screen.dart';

import 'services/auth_service.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ThemeService.loadTheme();

  final Widget initialScreen = await _getInitialScreen();

  runApp(MyApp(initialScreen: initialScreen));
}

// ===============================
// DECIDIR PANTALLA INICIAL
// ===============================
Future<Widget> _getInitialScreen() async {
  final prefs = await SharedPreferences.getInstance();

  final bool sessionActive = prefs.getBool('sesion_activa') ?? false;
  final String? userJson = prefs.getString('usuario_actual');

  final bool hasUser = userJson != null && userJson.isNotEmpty;

  if (sessionActive && hasUser) {
    // Cuenta creada pero el correo aún no se verificó.
    if (prefs.getBool(AuthService.pendingVerificationKey) ?? false) {
      final email = _emailFromUserJson(userJson);
      if (email.isNotEmpty) return VerificationScreen(email: email);
    }

    return const HomeScreen();
  }

  // La presentación solo se muestra en la primera apertura.
  final bool onboardingSeen = prefs.getBool(BenefitsScreen.seenKey) ?? false;

  if (!onboardingSeen && !hasUser) {
    return const BenefitsScreen();
  }

  return const WelcomeScreen();
}

String _emailFromUserJson(String userJson) {
  try {
    final data = jsonDecode(userJson) as Map<String, dynamic>;
    return data['email']?.toString() ?? '';
  } catch (_) {
    return '';
  }
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;

  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Connect Do',

          // ☀️ TEMA CLARO
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            primaryColor: const Color(0xFF2563EB),
            scaffoldBackgroundColor: Colors.white,
            fontFamily: 'Space Grotesk',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2563EB),
              brightness: Brightness.light,
            ),
          ),

          // 🌙 TEMA OSCURO
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            primaryColor: const Color(0xFF2563EB),
            scaffoldBackgroundColor: const Color(0xFF121212),
            fontFamily: 'Space Grotesk',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2563EB),
              brightness: Brightness.dark,
            ),
          ),

          themeMode: currentMode,

          home: initialScreen,

          routes: {
            '/welcome': (context) => const WelcomeScreen(),
            '/benefits': (context) => const BenefitsScreen(),
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),

            '/home': (context) => const HomeScreen(),
            '/chat': (context) => const ChatListScreen(),
            '/notifications': (context) => const NotificationsScreen(),
            '/profile': (context) => const ProfileScreen(),
          },
        );
      },
    );
  }
}
