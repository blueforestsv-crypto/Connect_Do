import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  static const String _userKey = 'usuario_actual';

  // Obtener usuario actual
  static Future<Map<String, dynamic>> getUser() async {
    final prefs = await SharedPreferences.getInstance();

    String? userJson = prefs.getString(_userKey);

    if (userJson == null) {
      return {};
    }

    return jsonDecode(userJson);
  }

  // Guardar usuario completo
  static Future<void> saveUser(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_userKey, jsonEncode(userData));
  }

  // Actualizar un campo específico
  static Future<void> updateField(String key, dynamic value) async {
    final user = await getUser();

    user[key] = value;

    await saveUser(user);
  }

  // Actualizar múltiples campos
  static Future<void> updateProfile({
    String? description,
    String? phone,
    String? cycle,
    String? portfolioLink,
    bool? privateProfile,
  }) async {
    final user = await getUser();

    if (description != null) {
      user['description'] = description;
    }

    if (phone != null) {
      user['phone'] = phone;
    }

    if (cycle != null) {
      user['cycle'] = cycle;
    }

    if (portfolioLink != null) {
      user['portfolio_link'] = portfolioLink;
    }

    if (privateProfile != null) {
      user['private_profile'] = privateProfile;
    }

    await saveUser(user);
  }

  // Actualizar habilidades
  static Future<void> updateSkills(List<String> skills) async {
    final user = await getUser();

    user['skills'] = skills;

    await saveUser(user);
  }

  // Obtener skills
  static Future<List<String>> getSkills() async {
    final user = await getUser();

    if (user['skills'] == null) {
      return [];
    }

    return List<String>.from(user['skills']);
  }

  // Obtener modo oscuro
  static Future<bool> isDarkMode() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool('dark_mode') ?? false;
  }

  // Guardar modo oscuro
  static Future<void> saveDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('dark_mode', value);
  }

  // Logout
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_userKey);
  }
}
