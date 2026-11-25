/// Opciones académicas compartidas entre el registro y "Completa tu perfil".
class AcademicOptions {
  AcademicOptions._();

  /// Universidades e instituciones de educación superior de El Salvador.
  /// Se guarda el acrónimo en el perfil (ej. "UTEC").
  /// Los dominios sirven para deducir la universidad del correo institucional.
  static const List<University> universityCatalog = [
    // Pública
    University('UES', 'Universidad de El Salvador', ['ues']),
    // Privadas
    University('UCA', 'Universidad Centroamericana José Simeón Cañas', ['uca']),
    University('UTEC', 'Universidad Tecnológica de El Salvador', ['utec']),
    University('UFG', 'Universidad Francisco Gavidia', ['ufg']),
    University('UDB', 'Universidad Don Bosco', ['udb']),
    University('UEES', 'Universidad Evangélica de El Salvador', ['uees']),
    University('UJMD', 'Universidad Dr. José Matías Delgado', ['ujmd']),
    University('UNAB', 'Universidad Dr. Andrés Bello', ['unab']),
    University('UMA', 'Universidad Modular Abierta', ['uma']),
    University('UPED', 'Universidad Pedagógica de El Salvador', [
      'pedagogica',
      'uped',
    ]),
    University('UPES', 'Universidad Politécnica de El Salvador', ['upes']),
    University('UNICAES', 'Universidad Católica de El Salvador', [
      'catolica',
      'unicaes',
    ]),
    University('USAM', 'Universidad Salvadoreña Alberto Masferrer', ['usam']),
    University('UNASA', 'Universidad Autónoma de Santa Ana', ['unasa']),
    University('UGB', 'Universidad Gerardo Barrios', ['ugb']),
    University('UNIVO', 'Universidad de Oriente', ['univo']),
    University('UMOAR', 'Universidad Monseñor Oscar Arnulfo Romero', ['umoar']),
    University('ULS', 'Universidad Luterana Salvadoreña', ['uls']),
    University('UPAN', 'Universidad Panamericana de El Salvador', ['upan']),
    University('UTLA', 'Universidad Técnica Latinoamericana', ['utla']),
    University('UCAD', 'Universidad Cristiana de las Asambleas de Dios', [
      'ucad',
    ]),
    University('USO', 'Universidad de Sonsonate', ['uso']),
    University('UAE', 'Universidad Albert Einstein', ['uae']),
    University('UNIN', 'Universidad Internacional Nehemías', []),
    // Instituciones especializadas con muchos estudiantes
    University('ESEN', 'Escuela Superior de Economía y Negocios', ['esen']),
    University(
      'ITCA-FEPADE',
      'Escuela Especializada en Ingeniería ITCA-FEPADE',
      ['itca'],
    ),
    University('EMH', 'Escuela de Comunicación Mónica Herrera', [
      'monicaherrera',
    ]),
    University('ENA', 'Escuela Nacional de Agricultura', ['ena']),
  ];

  /// Acrónimos, en el orden del catálogo, para los dropdowns.
  static final List<String> universities = [
    for (final u in universityCatalog) u.acronym,
  ];

  /// Valores guardados con el registro anterior -> acrónimo.
  static const Map<String, String> _legacyNames = {
    'Universidad Ándres Bello': 'UNAB',
    'Universidad Modular Abierta': 'UMA',
    'Universidad Pedagógica': 'UPED',
    'Universidad Técnologica': 'UTEC',
  };

  static University? universityByAcronym(String? acronym) {
    for (final u in universityCatalog) {
      if (u.acronym == acronym) return u;
    }
    return null;
  }

  /// "UTEC · Universidad Tecnológica de El Salvador"
  static String universityLabel(String acronym) {
    final u = universityByAcronym(acronym);
    return u == null ? acronym : '${u.acronym} · ${u.name}';
  }

  /// Convierte nombres viejos o completos al acrónimo actual.
  static String? normalizeUniversity(String? value) {
    final clean = value?.trim() ?? '';
    if (clean.isEmpty) return null;

    if (_legacyNames.containsKey(clean)) return _legacyNames[clean];

    for (final u in universityCatalog) {
      if (u.acronym.toLowerCase() == clean.toLowerCase() ||
          u.name.toLowerCase() == clean.toLowerCase()) {
        return u.acronym;
      }
    }

    return clean;
  }

  static const List<String> levels = [
    'Pregrado (Licenciaturas, Ingenierías, Arquitectura y Técnico)',
    'Postgrado',
    'Maestría',
  ];

  static const List<String> careers = [
    'Ingenierías',
    'Diseño',
    'Administración',
    'Psicología',
    'Derecho',
  ];

  static const List<String> cycles = [
    'Ciclo 01',
    'Ciclo 02',
    'Ciclo 03',
    'Ciclo 04',
    'Ciclo 05',
    'Ciclo 06',
    'Ciclo 07',
    'Ciclo 08',
    'Ciclo 09',
    'Ciclo 10',
  ];

  static const List<String> suggestedSkills = [
    'Liderazgo',
    'Trabajo en equipo',
    'Comunicación efectiva',
    'Resolución de problemas',
    'Gestión del tiempo',
    'Pensamiento crítico',
    'Oratoria',
    'Negociación',
    'Adaptabilidad',
    'Creatividad',
    'Gestión de proyectos',
    'Programación en Python',
    'Programación en Java',
    'C++',
    'Desarrollo Web',
    'HTML/CSS',
    'JavaScript',
    'Bases de Datos',
    'SQL',
    'Análisis de Datos',
    'Redes de computadoras',
    'Ciberseguridad',
    'Soporte Técnico',
    'Control de Calidad',
    'Desarrollo Móvil (Flutter)',
    'Git / GitHub',
    'Diseño Gráfico',
    'Adobe Photoshop',
    'Adobe Illustrator',
    'UX/UI',
    'Figma',
    'Edición de Video',
    'Adobe Premiere',
    'Fotografía',
    'Modelado 3D',
    'Animación',
    'Branding corporativo',
    'Marketing Digital',
    'Contabilidad',
    'Finanzas',
    'Microsoft Excel',
    'Microsoft Power BI',
    'Ventas',
    'Recursos Humanos',
    'Planeación Estratégica',
    'Atención al cliente',
    'Logística',
    'Entrevistas',
    'Pruebas psicométricas',
    'Psicología Clínica',
    'Psicología Organizacional',
    'Manejo de crisis',
    'Redacción legal',
    'Investigación jurídica',
    'Derecho Penal',
    'Derecho Laboral',
    'Derecho Mercantil',
    'Mediación de conflictos',
  ];

  /// Deduce la universidad (acrónimo) a partir del correo institucional.
  /// Ej.: ana@mail.utec.edu.sv -> UTEC.
  static String? universityFromEmail(String email) {
    final parts = email.trim().toLowerCase().split('@');

    if (parts.length != 2 || parts[1].isEmpty) return null;

    final labels = parts[1].split('.');
    for (final u in universityCatalog) {
      if (u.domainLabels.any(labels.contains)) return u.acronym;
    }

    return null;
  }

  /// Ciclo solo aplica a pregrado.
  static bool levelUsesCycle(String? level) =>
      level == null || level.startsWith('Pregrado');
}

class University {
  final String acronym;
  final String name;

  /// Etiquetas del dominio de correo (ej. "utec" en mail.utec.edu.sv).
  final List<String> domainLabels;

  const University(this.acronym, this.name, this.domainLabels);
}
