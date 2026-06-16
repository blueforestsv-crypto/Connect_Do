import 'package:flutter/material.dart';

import 'package:connect_do/utils/responsive_helper.dart';

import 'step_2_screen.dart';

class Step1Screen extends StatefulWidget {
  const Step1Screen({super.key});

  @override
  State<Step1Screen> createState() => _Step1ScreenState();
}

class _Step1ScreenState extends State<Step1Screen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  String? _selectedUni;
  String? _selectedLevel;
  String? _selectedCareer;
  String? _selectedCycle;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // ===============================
  // VALIDAR Y AVANZAR
  // ===============================
  void _goToNextStep() {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        _selectedUni == null ||
        email.isEmpty ||
        _selectedLevel == null ||
        _selectedCareer == null ||
        _selectedCycle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Por favor, completa todos los campos para continuar"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final Map<String, dynamic> collectedData = {
      'firstName': firstName,
      'lastName': lastName,
      'university': _selectedUni,
      'email': email,
      'level': _selectedLevel,
      'career': _selectedCareer,
      'cycle': _selectedCycle,
    };

    debugPrint("Datos del Paso 1 listos: $collectedData");

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Step2Screen(userData: collectedData),
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
      backgroundColor: const Color(0xFF2563EB),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: bottomPadding + 20),
          child: Column(
            children: [
              // ===============================
              // HEADER VERDE CON SCROLL
              // ===============================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(35, 34, 35, 32),
                decoration: const BoxDecoration(
                  color: Color(0xFF22C55E),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(60),
                  ),
                ),
                child: const Column(
                  children: [
                    Text(
                      'Comencemos:',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),

                    SizedBox(height: 8),

                    Text(
                      'Ingresa tu nombre y un poco de tu información institucional para crear tu perfil.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 13,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              // ===============================
              // FORMULARIO AZUL
              // ===============================
              Container(
                width: double.infinity,
                color: const Color(0xFF2563EB),
                padding: const EdgeInsets.fromLTRB(35, 24, 35, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Nombre'),

                    _buildTextField(
                      hint: 'Ingresa tu nombre',
                      controller: _firstNameController,
                      keyboardType: TextInputType.name,
                    ),

                    _buildLabel('Apellido'),

                    _buildTextField(
                      hint: 'Ingresa tu apellido',
                      controller: _lastNameController,
                      keyboardType: TextInputType.name,
                    ),

                    _buildLabel('Elige tu universidad'),

                    _buildDropdown(
                      hint: 'Selecciona tu universidad',
                      value: _selectedUni,
                      items: const [
                        'Universidad Ándres Bello',
                        'Universidad Modular Abierta',
                        'Universidad Pedagógica',
                        'Universidad Técnologica',
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedUni = val;
                        });
                      },
                    ),

                    _buildLabel('Ingresa tu correo institucional'),

                    _buildTextField(
                      hint: 'ejemplo@mail.utec.edu.sv',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),

                    _buildLabel('Tu nivel académico universitario'),

                    _buildDropdown(
                      hint: 'Selecciona un nivel',
                      value: _selectedLevel,
                      items: const [
                        'Pregrado (Licenciaturas, Ingenierías, Arquitectura y Técnico)',
                        'Postgrado',
                        'Maestría',
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedLevel = val;
                        });
                      },
                    ),

                    _buildLabel('Carrera'),

                    _buildDropdown(
                      hint: 'Selecciona una carrera',
                      value: _selectedCareer,
                      items: const [
                        'Ingenierías',
                        'Diseño',
                        'Administración',
                        'Psicología',
                        'Derecho',
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedCareer = val;
                        });
                      },
                    ),

                    _buildLabel('Ciclo actual'),

                    _buildDropdown(
                      hint: 'Selecciona el ciclo',
                      value: _selectedCycle,
                      items: const [
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
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedCycle = val;
                        });
                      },
                    ),

                    const SizedBox(height: 40),

                    Center(
                      child: SizedBox(
                        width: 220,
                        height: 55,
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
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===============================
  // LABEL
  // ===============================
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, bottom: 8, top: 18),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Space Grotesk',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  // ===============================
  // TEXT FIELD
  // ===============================
  Widget _buildTextField({
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization:
            keyboardType == TextInputType.name
                ? TextCapitalization.words
                : TextCapitalization.none,
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
            fontSize: 14,
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
  // DROPDOWN
  // ===============================
  Widget _buildDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: Colors.white,
          hint: Text(
            hint,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
              fontFamily: 'Space Grotesk',
            ),
          ),
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
          style: const TextStyle(
            fontFamily: 'Space Grotesk',
            color: Colors.black87,
            fontSize: 14,
          ),
          items:
              items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                );
              }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
