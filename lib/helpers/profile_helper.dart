class ProfileHelper {
  // ==========================
  // OBTENER NOMBRE DEL USUARIO
  // ==========================
  static String getUserName(Map<String, dynamic> userData) {
    String email = userData['email'] ?? '';

    String firstName = userData['firstName'] ?? '';

    String lastName = userData['lastName'] ?? '';

    String fullName = "$firstName $lastName".trim();

    // fallback temporal usando correo
    if (fullName.isEmpty && email.isNotEmpty) {
      fullName = email.split('@')[0].replaceAll('.', ' ');
    }

    return fullName.isEmpty ? "Usuario" : fullName;
  }

  // ==========================
  // OBTENER NOMBRE DEL CV
  // ==========================
  static String getCvName(String? cvPath) {
    if (cvPath == null || cvPath.isEmpty) {
      return "Sin CV";
    }

    return cvPath.split('/').last;
  }

  // ==========================
  // FOTO LOCAL
  // ==========================
  static String getLocalPhoto(Map<String, dynamic> userData) {
    return userData['profile_image_path'] ?? '';
  }

  // ==========================
  // FOTO GOOGLE
  // ==========================
  static String getGooglePhoto(Map<String, dynamic> userData) {
    return userData['google_photo_url'] ?? '';
  }

  // ==========================
  // DESCRIPCIÓN
  // ==========================
  static String getDescription(Map<String, dynamic> userData) {
    return userData['description'] ?? '';
  }

  // ==========================
  // PORTAFOLIO
  // ==========================
  static String getPortfolioLink(Map<String, dynamic> userData) {
    return userData['portfolio_link'] ?? '';
  }

  // ==========================
  // TELÉFONO
  // ==========================
  static String getPhone(Map<String, dynamic> userData) {
    return userData['phone'] ?? 'No registrado';
  }

  // ==========================
  // CARRERA
  // ==========================
  static String getCareer(Map<String, dynamic> userData) {
    return userData['career'] ?? 'Sin carrera';
  }

  // ==========================
  // CICLO
  // ==========================
  static String getCycle(Map<String, dynamic> userData) {
    return userData['cycle'] ?? 'Sin ciclo';
  }

  // ==========================
  // UNIVERSIDAD
  // ==========================
  static String getUniversity(Map<String, dynamic> userData) {
    return userData['university'] ?? 'No registrada';
  }

  // ==========================
  // NIVEL ACADÉMICO
  // ==========================
  static String getLevel(Map<String, dynamic> userData) {
    return userData['level'] ?? 'No definido';
  }

  // ==========================
  // HABILIDADES
  // ==========================
  static List<String> getSkills(Map<String, dynamic> userData) {
    if (userData['skills'] == null) {
      return [];
    }

    return List<String>.from(userData['skills']);
  }
}
