/// Calcula qué tan completo está el perfil a partir de `usuario_actual`.
class ProfileCompletion {
  ProfileCompletion._();

  static bool _has(Map<String, dynamic> user, String key) =>
      (user[key]?.toString().trim() ?? '').isNotEmpty;

  static Map<String, bool> _checks(Map<String, dynamic> user) {
    final skills = user['skills'];

    return {
      'university': _has(user, 'university'),
      'career': _has(user, 'career'),
      'level': _has(user, 'level'),
      'description': _has(user, 'description'),
      'skills': skills is List && skills.isNotEmpty,
      'phone': _has(user, 'phone'),
      'photo':
          _has(user, 'profile_image_base64') || _has(user, 'google_photo_url'),
      'cv':
          _has(user, 'cv_file_name') ||
          _has(user, 'cv_url') ||
          _has(user, 'cv_path'),
    };
  }

  /// Porcentaje de 0 a 100.
  static int percent(Map<String, dynamic> user) {
    final checks = _checks(user);
    final done = checks.values.where((v) => v).length;
    return ((done / checks.length) * 100).round();
  }

  static bool isComplete(Map<String, dynamic> user) => percent(user) == 100;
}
