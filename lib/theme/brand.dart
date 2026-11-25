import 'package:flutter/material.dart';

/// Tokens de marca Connect Do. La firma visual es el degradado azul → verde
/// del logo; el resto de la interfaz es neutra para que ese degradado luzca.
class Brand {
  Brand._();

  // Colores de marca
  static const Color blue = Color(0xFF2563EB);
  static const Color blueDeep = Color(0xFF1D4ED8);
  static const Color green = Color(0xFF22C55E);

  // Estados
  static const Color danger = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF16A34A);

  static const LinearGradient gradient = LinearGradient(
    colors: [blue, green],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Radios y espaciado (múltiplos de 4/8)
  static const double radiusSm = 12;
  static const double radiusMd = 14;
  static const double radiusLg = 24;
  static const double fieldHeight = 52;

  static const String displayFont = 'Space Grotesk';
}

/// Colores neutros que cambian con el modo claro/oscuro.
class AuthPalette {
  final bool isDark;

  const AuthPalette._(this.isDark);

  factory AuthPalette.of(BuildContext context) =>
      AuthPalette._(Theme.of(context).brightness == Brightness.dark);

  Color get background =>
      isDark ? const Color(0xFF0B1220) : const Color(0xFFF6F8FB);
  Color get card => isDark ? const Color(0xFF131C2E) : Colors.white;
  Color get cardBorder =>
      isDark ? const Color(0xFF1F2A40) : const Color(0xFFE8EDF3);
  Color get title => isDark ? Colors.white : const Color(0xFF0F172A);
  Color get body => isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
  Color get muted => isDark ? const Color(0xFF7C8AA3) : const Color(0xFF94A3B8);
  Color get label => isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155);
  Color get fieldFill =>
      isDark ? const Color(0xFF0F1729) : const Color(0xFFF8FAFC);
  Color get fieldBorder =>
      isDark ? const Color(0xFF26324A) : const Color(0xFFE2E8F0);
  Color get shadow =>
      isDark ? Colors.black.withValues(alpha: 0.35) : const Color(0x140F172A);
}
