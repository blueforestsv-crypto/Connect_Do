import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/utils/responsive_helper.dart';

class ProfileTechnicalTab extends StatefulWidget {
  final bool isDarkMode;
  final bool isPrivateProfile;

  const ProfileTechnicalTab({
    super.key,
    required this.isDarkMode,
    required this.isPrivateProfile,
  });

  @override
  State<ProfileTechnicalTab> createState() => _ProfileTechnicalTabState();
}

class _ProfileTechnicalTabState extends State<ProfileTechnicalTab> {
  Map<String, dynamic> _userData = {};

  String _userEmail = "";
  String _userPhone = "No registrado";
  String _userCareer = "";
  String _userCycle = "";
  String _userDescription = "";
  String _portfolioLink = "";
  String _cvName = "Sin CV";
  String _cvPath = "";

  List<String> _skills = [];

  final List<String> _habilidadesSugeridas = [
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
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // ===============================
  // CARGAR DATOS DEL USUARIO
  // ===============================
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();

    final datosJson = prefs.getString('usuario_actual');

    if (datosJson == null || datosJson.isEmpty) return;

    final Map<String, dynamic> userData = jsonDecode(datosJson);

    final String cvPath =
        (userData['cv_file_path'] ?? userData['cv_path'] ?? '').toString();

    final String cvName =
        (userData['cv_file_name'] ?? '').toString().isNotEmpty
            ? userData['cv_file_name'].toString()
            : cvPath.isNotEmpty
            ? cvPath.split('/').last
            : 'Sin CV';

    if (!mounted) return;

    setState(() {
      _userData = userData;

      _userEmail = userData['email'] ?? "";
      _userPhone = userData['phone'] ?? "No registrado";
      _userCareer = userData['career'] ?? "Sin carrera";
      _userCycle = userData['cycle'] ?? "Sin ciclo";
      _userDescription = userData['description'] ?? "";
      _portfolioLink = userData['portfolio_link'] ?? "";

      _skills = List<String>.from(userData['skills'] ?? []);

      _cvPath = cvPath;
      _cvName = cvName;
    });
  }

  // ===============================
  // GUARDAR CAMBIOS
  // ===============================
  Future<void> _saveChanges() async {
    final prefs = await SharedPreferences.getInstance();

    _userData['skills'] = _skills;
    _userData['cycle'] = _userCycle;
    _userData['description'] = _userDescription;
    _userData['portfolio_link'] = _portfolioLink;

    // Guardamos en formato nuevo
    _userData['cv_file_path'] = _cvPath;
    _userData['cv_file_name'] = _cvName == 'Sin CV' ? '' : _cvName;

    // Compatibilidad con código viejo
    _userData['cv_path'] = _cvPath;

    await prefs.setString('usuario_actual', jsonEncode(_userData));
  }

  // ===============================
  // SELECCIONAR CV DESDE ARCHIVOS
  // ===============================
  Future<void> _pickCvFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;

      if (file.path == null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo obtener la ruta del archivo'),
            backgroundColor: Colors.red,
          ),
        );

        return;
      }

      setState(() {
        _cvPath = file.path!;
        _cvName = file.name;
      });

      await _saveChanges();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CV actualizado correctamente'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar CV: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ===============================
  // EDITAR CICLO
  // ===============================
  void _showUpdateCycleDialog() {
    final controller = TextEditingController(text: _userCycle);

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor:
              widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text(
            'Editar ciclo',
            style: TextStyle(
              color: widget.isDarkMode ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: controller,
            style: TextStyle(
              color: widget.isDarkMode ? Colors.white : Colors.black87,
            ),
            cursorColor: const Color(0xFF22C55E),
            decoration: InputDecoration(
              hintText: 'Ej. Ciclo 06',
              hintStyle: TextStyle(
                color: widget.isDarkMode ? Colors.white54 : Colors.grey,
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
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                setState(() {
                  _userCycle = controller.text.trim();
                });

                await _saveChanges();

                if (!mounted) return;

                Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  // ===============================
  // EDITAR SOBRE MÍ
  // ===============================
  void _showEditDescriptionDialog() {
    final controller = TextEditingController(text: _userDescription);

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor:
              widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text(
            'Editar sobre mí',
            style: TextStyle(
              color: widget.isDarkMode ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: controller,
            maxLines: 5,
            maxLength: 300,
            style: TextStyle(
              color: widget.isDarkMode ? Colors.white : Colors.black87,
            ),
            cursorColor: const Color(0xFF22C55E),
            decoration: InputDecoration(
              hintText: 'Escribe algo sobre ti',
              hintStyle: TextStyle(
                color: widget.isDarkMode ? Colors.white54 : Colors.grey,
              ),
              counterStyle: TextStyle(
                color: widget.isDarkMode ? Colors.white54 : Colors.grey,
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
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                setState(() {
                  _userDescription = controller.text.trim();
                });

                await _saveChanges();

                if (!mounted) return;

                Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  // ===============================
  // EDITAR PORTAFOLIO
  // ===============================
  void _showEditPortfolioDialog() {
    final controller = TextEditingController(text: _portfolioLink);

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor:
              widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text(
            'Editar portafolio',
            style: TextStyle(
              color: widget.isDarkMode ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            style: TextStyle(
              color: widget.isDarkMode ? Colors.white : Colors.black87,
            ),
            cursorColor: const Color(0xFF22C55E),
            decoration: InputDecoration(
              hintText: 'https://tu-portafolio.com',
              hintStyle: TextStyle(
                color: widget.isDarkMode ? Colors.white54 : Colors.grey,
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
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                setState(() {
                  _portfolioLink = controller.text.trim();
                });

                await _saveChanges();

                if (!mounted) return;

                Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  // ===============================
  // AÑADIR HABILIDAD
  // ===============================
  void _showAddSkillDialog() {
    String selectedSkill = "";

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor:
              widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text(
            'Añadir habilidad',
            style: TextStyle(
              color: widget.isDarkMode ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: DropdownButtonFormField<String>(
            dropdownColor:
                widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            decoration: InputDecoration(
              labelText: 'Selecciona una habilidad',
              labelStyle: TextStyle(
                color: widget.isDarkMode ? Colors.white70 : Colors.black54,
              ),
              border: const OutlineInputBorder(),
            ),
            style: TextStyle(
              color: widget.isDarkMode ? Colors.white : Colors.black87,
            ),
            items:
                _habilidadesSugeridas.map((skill) {
                  return DropdownMenuItem(value: skill, child: Text(skill));
                }).toList(),
            onChanged: (value) {
              selectedSkill = value ?? "";
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (selectedSkill.isNotEmpty &&
                    !_skills.contains(selectedSkill)) {
                  setState(() {
                    _skills.add(selectedSkill);
                  });

                  await _saveChanges();
                }

                if (!mounted) return;

                Navigator.pop(context);
              },
              child: const Text('Añadir'),
            ),
          ],
        );
      },
    );
  }

  // ===============================
  // BUILD
  // ===============================
  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        ResponsiveHelper.appBottomNavSpace(context),
      ),
      children: [
        _sectionTitle("Información General"),

        const SizedBox(height: 15),

        if (!widget.isPrivateProfile) _infoCard(textColor),

        if (widget.isPrivateProfile) _privateProfileNotice(),

        const SizedBox(height: 30),

        _sectionTitle("Sobre mí"),

        const SizedBox(height: 12),

        _descriptionCard(textColor),

        const SizedBox(height: 30),

        _portfolioCard(textColor),

        _sectionTitle("Curriculum Vitae"),

        const SizedBox(height: 12),

        _cvCard(textColor),

        const SizedBox(height: 30),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionTitle("Habilidades"),
            TextButton.icon(
              onPressed: _showAddSkillDialog,
              icon: const Icon(Icons.add, color: Color(0xFF22C55E)),
              label: const Text(
                "Añadir",
                style: TextStyle(color: Color(0xFF22C55E)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        _skillsCard(),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 17,
        color:
            widget.isDarkMode ? Colors.blue.shade300 : const Color(0xFF1E3A8A),
      ),
    );
  }

  Widget _privateProfileNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? Colors.white10 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        'Tu información general está oculta porque tienes activado el perfil privado.',
        style: TextStyle(
          color: widget.isDarkMode ? Colors.white70 : Colors.black54,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _infoCard(Color textColor) {
    return Card(
      elevation: 0,
      color: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.email, color: Color(0xFF2563EB)),
            title: Text(
              "Correo",
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              _userEmail,
              style: TextStyle(
                color: widget.isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.phone, color: Color(0xFF22C55E)),
            title: Text(
              "Teléfono",
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              _userPhone,
              style: TextStyle(
                color: widget.isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.school, color: Colors.orange),
            title: Text(
              "Carrera",
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              _userCareer,
              style: TextStyle(
                color: widget.isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.timeline, color: Colors.purple),
            title: Text(
              "Ciclo",
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              _userCycle,
              style: TextStyle(
                color: widget.isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit, color: Colors.orange),
              onPressed: _showUpdateCycleDialog,
            ),
          ),
        ],
      ),
    );
  }

  Widget _descriptionCard(Color textColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? Colors.white10 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              _userDescription.isNotEmpty
                  ? _userDescription
                  : 'Todavía no tienes descripción',
              style: TextStyle(color: textColor, height: 1.5),
            ),
          ),

          const SizedBox(width: 8),

          InkWell(
            onTap: _showEditDescriptionDialog,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.edit_outlined, color: Colors.orange, size: 21),
            ),
          ),
        ],
      ),
    );
  }

  Widget _portfolioCard(Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Portafolio"),

        const SizedBox(height: 12),

        Card(
          elevation: 0,
          color: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          child: ListTile(
            leading: const Icon(Icons.link, color: Colors.green),
            title: Text(
              _portfolioLink.isNotEmpty ? _portfolioLink : 'Sin portafolio',
              style: TextStyle(color: textColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle:
                _portfolioLink.isEmpty
                    ? Text(
                      'Toca el lápiz para agregar tu portafolio',
                      style: TextStyle(
                        color: widget.isDarkMode ? Colors.white60 : Colors.grey,
                      ),
                    )
                    : null,
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.orange),
              onPressed: _showEditPortfolioDialog,
            ),
          ),
        ),

        const SizedBox(height: 30),
      ],
    );
  }

  Widget _cvCard(Color textColor) {
    final hasCv = _cvPath.isNotEmpty;

    return Card(
      elevation: 0,
      color: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      child: ListTile(
        onTap: _pickCvFile,
        leading: Icon(
          hasCv ? Icons.picture_as_pdf : Icons.upload_file,
          color: hasCv ? Colors.red : const Color(0xFF22C55E),
        ),
        title: Text(
          hasCv ? _cvName : 'Sin CV',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          hasCv
              ? 'CV cargado. Toca para actualizarlo'
              : 'Toca para subir tu CV',
          style: TextStyle(
            color: widget.isDarkMode ? Colors.white60 : Colors.grey,
          ),
        ),
        trailing: const Icon(Icons.upload_file, color: Color(0xFF22C55E)),
      ),
    );
  }

  Widget _skillsCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? Colors.white10 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
      ),
      child:
          _skills.isEmpty
              ? Text(
                'Aún no has agregado habilidades',
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white60 : Colors.grey,
                ),
              )
              : Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    _skills.map((skill) {
                      return InputChip(
                        label: Text(
                          skill,
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: const Color(0xFF22C55E),
                        deleteIconColor: Colors.white,
                        onDeleted: () async {
                          setState(() {
                            _skills.remove(skill);
                          });

                          await _saveChanges();
                        },
                      );
                    }).toList(),
              ),
    );
  }
}
