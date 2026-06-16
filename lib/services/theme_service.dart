import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(
    ThemeMode.light,
  );

  static Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkMode = prefs.getBool('isDarkMode') ?? false;

    themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('isDarkMode', value);

    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
  }

  static bool get isDarkMode {
    return themeNotifier.value == ThemeMode.dark;
  }
}
