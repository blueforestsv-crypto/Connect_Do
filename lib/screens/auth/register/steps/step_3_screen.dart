import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/utils/responsive_helper.dart';

class Step3Screen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const Step3Screen({super.key, required this.userData});

  @override
  State<Step3Screen> createState() => _Step3ScreenState();
}

class _Step3ScreenState extends State<Step3Screen> {
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  File? _profileImage;
  String? _googlePhotoUrl;

  String? _cvName;
  String? _cvPath;

  bool _isObscured = true;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    _googlePhotoUrl =
        widget.userData['google_photo_url'] ??
        widget.userData['photoUrl'] ??
        widget.userData['photo_url'] ??
        '';
  }

  @override
  void dispose() {
    _passController.dispose();
    _confirmPassController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ===============================
  // SELECCIONAR FOTO DE PERFIL
  // ===============================
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (pickedFile == null) return;

      setState(() {
        _profileImage = File(pickedFile.path);
      });
    } catch (e) {
      _showErrorSnackBar('Error al seleccionar imagen: $e');
    }
  }

  void _showImageSourceSelection() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: ResponsiveHelper.bottomSafe(context),
              ),
              child: Wrap(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.photo_camera,
                      color: Color(0xFF2563EB),
                    ),
                    title: const Text(
                      'Tomar una foto',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        color: Colors.black87,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.photo_library,
                      color: Color(0xFF22C55E),
                    ),
                    title: const Text(
                      'Elegir de la galería',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        color: Colors.black87,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // ===============================
  // SELECCIONAR CV
  // ===============================
  Future<void> _pickDocument() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      if (result == null) return;

      final file = result.files.single;

      setState(() {
        _cvName = file.name;
        _cvPath = file.path;
      });
    } catch (e) {
      _showErrorSnackBar('Error al seleccionar CV: $e');
    }
  }

  // ===============================
  // FINALIZAR REGISTRO
  // ===============================
  Future<void> _finishRegistration() async {
    final pass = _passController.text.trim();
    final confirmPass = _confirmPassController.text.trim();
    final phone = _phoneController.text.trim();

    if (pass.isEmpty || confirmPass.isEmpty || phone.isEmpty) {
      _showErrorSnackBar('Por favor, completa todos los campos.');
      return;
    }

    if (pass != confirmPass) {
      _showErrorSnackBar('Las contraseñas no coinciden.');
      return;
    }

    final phoneExp = RegExp(r'^[267]\d{7}$');

    if (!phoneExp.hasMatch(phone)) {
      _showErrorSnackBar(
        'El teléfono debe tener 8 números y empezar con 2, 6 o 7 (Ej: 71234567).',
      );
      return;
    }

    final Map<String, dynamic> finalData = Map<String, dynamic>.from(
      widget.userData,
    );

    finalData['password'] = pass;
    finalData['phone'] = '+503$phone';

    // ===============================
    // FOTO DE PERFIL
    // ===============================
    finalData['profile_image_path'] = _profileImage?.path ?? '';

    finalData['google_photo_url'] = _googlePhotoUrl ?? '';

    finalData['use_google_photo'] =
        _profileImage == null &&
        _googlePhotoUrl != null &&
        _googlePhotoUrl!.isNotEmpty;

    // ===============================
    // CV
    // ===============================
    finalData['cv_file_path'] = _cvPath ?? '';
    finalData['cv_file_name'] = _cvName ?? '';

    // Compatibilidad con código viejo, por si alguna pantalla aún lee cv_path
    finalData['cv_path'] = _cvPath ?? '';

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('usuario_actual', jsonEncode(finalData));
    await prefs.setBool('sesion_activa', true);

    if (!mounted) return;

    Navigator.pushNamed(context, '/verification');
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Space Grotesk'),
        ),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  ImageProvider? _getProfilePreviewImage() {
    if (_profileImage != null) {
      return FileImage(_profileImage!);
    }

    if (_googlePhotoUrl != null && _googlePhotoUrl!.isNotEmpty) {
      return NetworkImage(_googlePhotoUrl!);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final profilePreviewImage = _getProfilePreviewImage();

    final bottomPadding =
        ResponsiveHelper.keyboard(context) +
        ResponsiveHelper.bottomSafe(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF22C55E),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Ya casi estamos, sube una foto de perfil donde te veas listo para tu primera oportunidad laboral',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(45),
                    topRight: Radius.circular(45),
                  ),
                ),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(35, 25, 35, bottomPadding + 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ===============================
                      // FOTO
                      // ===============================
                      Center(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _showImageSourceSelection,
                              child: CircleAvatar(
                                radius: 60,
                                backgroundColor: const Color(0xFFD1D5DB),
                                backgroundImage: profilePreviewImage,
                                child:
                                    profilePreviewImage == null
                                        ? const Icon(
                                          Icons.person,
                                          size: 75,
                                          color: Colors.grey,
                                        )
                                        : null,
                              ),
                            ),

                            const SizedBox(height: 10),

                            _buildCompactButton(
                              text:
                                  _profileImage == null
                                      ? 'Sube una foto'
                                      : 'Cambiar foto',
                              icon: Icons.upload_rounded,
                              onPressed: _showImageSourceSelection,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 15),

                      _buildLabel('Ingresa tu contraseña'),
                      _buildTextField(_passController, isPassword: true),

                      _buildLabel('Confirma contraseña'),
                      _buildTextField(_confirmPassController, isPassword: true),

                      _buildLabel('Ingresa tu número de teléfono'),
                      _buildTextField(
                        _phoneController,
                        hint: '0000 0000',
                        type: TextInputType.number,
                        isPhone: true,
                      ),

                      const SizedBox(height: 15),

                      // ===============================
                      // CV
                      // ===============================
                      Center(
                        child: Column(
                          children: [
                            _buildCompactButton(
                              text:
                                  _cvName == null
                                      ? 'Sube tu curriculum'
                                      : 'Cambiar curriculum',
                              icon: Icons.upload_file,
                              onPressed: _pickDocument,
                            ),

                            if (_cvName != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.description_outlined,
                                        color: Colors.white,
                                        size: 16,
                                      ),

                                      const SizedBox(width: 6),

                                      Flexible(
                                        child: Text(
                                          _cvName!,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontFamily: 'Space Grotesk',
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      Center(
                        child: SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _finishRegistration,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF22C55E),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Finalizar Registro',
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

                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, bottom: 8, top: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Space Grotesk',
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, {
    String hint = "",
    bool isPassword = false,
    bool isPhone = false,
    TextInputType type = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _isObscured : false,
        keyboardType: type,
        inputFormatters:
            isPhone
                ? [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ]
                : null,
        style: const TextStyle(
          fontFamily: 'Space Grotesk',
          color: Colors.black87,
        ),
        cursorColor: const Color(0xFF22C55E),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 15,
          ),
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(
            fontFamily: 'Space Grotesk',
            color: Colors.grey,
          ),
          prefixIcon:
              isPhone
                  ? Padding(
                    padding: const EdgeInsets.only(left: 20, right: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '+503 ',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Container(width: 1, height: 20, color: Colors.grey),
                      ],
                    ),
                  )
                  : null,
          suffixIcon:
              isPassword
                  ? IconButton(
                    icon: Icon(
                      _isObscured ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _isObscured = !_isObscured;
                      });
                    },
                  )
                  : null,
        ),
      ),
    );
  }

  Widget _buildCompactButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 32,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE5E7EB),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 0),
        ),
        icon: Icon(icon, size: 16),
        label: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Space Grotesk',
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}
