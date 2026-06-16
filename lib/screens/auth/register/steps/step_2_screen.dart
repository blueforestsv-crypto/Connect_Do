import 'package:flutter/material.dart';

import 'package:connect_do/utils/responsive_helper.dart';

import 'step_3_screen.dart';

class Step2Screen extends StatefulWidget {
  // Recibe los datos del Paso 1 (nombre, correo, FOTO, etc.)
  final Map<String, dynamic> userData;

  const Step2Screen({super.key, required this.userData});

  @override
  State<Step2Screen> createState() => _Step2ScreenState();
}

class _Step2ScreenState extends State<Step2Screen> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();

  // Controlador auxiliar para limpiar el campo de autocompletado
  TextEditingController? _autoCompleteController;

  // LISTA MAESTRA DE SUGERENCIAS
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

  final List<String> _selectedSkills = [];

  @override
  void dispose() {
    _descriptionController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  // ===============================
  // AÑADIR HABILIDAD
  // ===============================
  void _addSkill(String skill) {
    const int maxSkills = 5;

    final cleanSkill = skill.trim();

    if (_selectedSkills.length >= maxSkills) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Solo puedes agregar un máximo de 5 habilidades."),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (cleanSkill.isNotEmpty && !_selectedSkills.contains(cleanSkill)) {
      setState(() {
        _selectedSkills.add(cleanSkill);
      });
    }
  }

  // ===============================
  // REMOVER HABILIDAD
  // ===============================
  void _removeSkill(String skill) {
    setState(() {
      _selectedSkills.remove(skill);
    });
  }

  // ===============================
  // VALIDAR Y AVANZAR
  // ===============================
  void _goToNextStep() {
    if (_descriptionController.text.trim().isEmpty || _selectedSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Por favor, ingresa una descripción y al menos una habilidad.",
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final Map<String, dynamic> allData = Map<String, dynamic>.from(
      widget.userData,
    );

    allData['description'] = _descriptionController.text.trim();
    allData['skills'] = _selectedSkills;
    allData['portfolio_link'] = _linkController.text.trim();

    debugPrint("Datos listos para enviar al backend (o al Paso 3): $allData");

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Step3Screen(userData: allData)),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("¡Datos guardados! Navegando al paso 3..."),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding =
        ResponsiveHelper.keyboard(context) +
        ResponsiveHelper.bottomSafe(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF22C55E),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 30),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Las empresas quieren conocerte, háblales un poco de ti',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 30),

            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 30,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(bottom: bottomPadding + 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Haz tu descripción en 300 caracteres'),

                      _buildTextArea(
                        controller: _descriptionController,
                        hint: 'Descríbete',
                      ),

                      _buildLabel('Ingresa tus habilidades y conocimientos'),

                      _buildSkillsAutocomplete(),

                      _buildLabel(
                        'Si eres estudiante de diseño, mercadeo, desarrollo de software o carreras a fines y tienes un portafolio digital, deja tu link aquí',
                      ),

                      _buildTextField(
                        controller: _linkController,
                        hint: 'Pon aquí tu link',
                      ),

                      const SizedBox(height: 40),

                      Center(
                        child: SizedBox(
                          width: 220,
                          height: 60,
                          child: ElevatedButton(
                            onPressed: _goToNextStep,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF22C55E),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Siguiente',
                              style: TextStyle(
                                fontFamily: 'Space Grotesk',
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: ResponsiveHelper.bottomSafe(context) + 20),
          ],
        ),
      ),
    );
  }

  // ===============================
  // LABEL
  // ===============================
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 20),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Space Grotesk',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white,
          height: 1.3,
        ),
      ),
    );
  }

  // ===============================
  // TEXT FIELD NORMAL
  // ===============================
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.url,
        style: const TextStyle(
          fontFamily: 'Space Grotesk',
          fontSize: 14,
          color: Colors.black87,
        ),
        cursorColor: const Color(0xFF22C55E),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Colors.grey,
            fontFamily: 'Space Grotesk',
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 15,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  // ===============================
  // TEXT AREA
  // ===============================
  Widget _buildTextArea({
    required TextEditingController controller,
    required String hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
      ),
      child: TextField(
        controller: controller,
        maxLines: 4,
        maxLength: 300,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(
          fontFamily: 'Space Grotesk',
          fontSize: 14,
          color: Colors.black87,
        ),
        cursorColor: const Color(0xFF22C55E),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Colors.grey,
            fontFamily: 'Space Grotesk',
          ),
          contentPadding: const EdgeInsets.all(20),
          border: InputBorder.none,
          counterStyle: const TextStyle(
            color: Colors.grey,
            fontFamily: 'Space Grotesk',
          ),
        ),
      ),
    );
  }

  // ===============================
  // AUTOCOMPLETADO DE HABILIDADES
  // ===============================
  Widget _buildSkillsAutocomplete() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 55),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return const Iterable<String>.empty();
          }

          return _habilidadesSugeridas.where((String option) {
            return option.toLowerCase().contains(
              textEditingValue.text.toLowerCase(),
            );
          });
        },
        onSelected: (String selection) {
          _addSkill(selection);

          Future.delayed(Duration.zero, () {
            _autoCompleteController?.clear();
          });
        },
        fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
          _autoCompleteController = controller;

          return Wrap(
            spacing: 6.0,
            runSpacing: 6.0,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ..._selectedSkills.map((skill) {
                return InputChip(
                  label: Text(
                    skill,
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: const Color(0xFF22C55E),
                  deleteIconColor: Colors.white,
                  onDeleted: () => _removeSkill(skill),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  side: BorderSide.none,
                );
              }),

              IntrinsicWidth(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 150),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    cursorColor: const Color(0xFF22C55E),
                    decoration: InputDecoration(
                      hintText:
                          _selectedSkills.isEmpty ? 'Busca habilidades...' : '',
                      hintStyle: const TextStyle(
                        color: Colors.grey,
                        fontFamily: 'Space Grotesk',
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        _addSkill(value);
                        controller.clear();
                        focusNode.requestFocus();
                      }
                    },
                  ),
                ),
              ),
            ],
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              color: Colors.white,
              elevation: 4.0,
              borderRadius: BorderRadius.circular(15),
              child: SizedBox(
                width: MediaQuery.of(context).size.width - 90,
                height: 200,
                child: ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: options.length,
                  itemBuilder: (BuildContext context, int index) {
                    final String option = options.elementAt(index);

                    return ListTile(
                      title: Text(
                        option,
                        style: const TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      onTap: () {
                        onSelected(option);
                      },
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
