import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileHeader extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onMenuTap;

  const ProfileHeader({
    super.key,
    required this.isDarkMode,
    required this.onMenuTap,
  });

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> {
  String _userName = "Cargando...";
  String _userCareer = "";
  String _googlePhoto = "";
  String _localPhotoPath = "";

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // ============================
  // CARGAR DATOS DEL USUARIO
  // ============================
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();

    final datosJson = prefs.getString('usuario_actual');

    if (datosJson == null) return;

    final userData = jsonDecode(datosJson);

    final String email = userData['email'] ?? "";

    final String firstName = userData['firstName'] ?? '';
    final String lastName = userData['lastName'] ?? '';

    String fullName = "$firstName $lastName".trim();

    if (fullName.isEmpty && email.isNotEmpty) {
      fullName = email.split('@')[0].replaceAll('.', ' ');
    }

    if (!mounted) return;

    setState(() {
      _userName = fullName.isEmpty ? "Usuario" : fullName;
      _userCareer = userData['career'] ?? "Sin carrera";
      _googlePhoto = userData['google_photo_url'] ?? "";
      _localPhotoPath = userData['profile_image_path'] ?? "";
    });
  }

  // ============================
  // CAMBIAR FOTO DE PERFIL
  // ============================
  Future<void> _changeProfilePhoto() async {
    try {
      final XFile? pickedImage = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedImage == null) return;

      final prefs = await SharedPreferences.getInstance();

      final datosJson = prefs.getString('usuario_actual');

      if (datosJson == null) return;

      final Map<String, dynamic> userData = jsonDecode(datosJson);

      userData['profile_image_path'] = pickedImage.path;

      await prefs.setString('usuario_actual', jsonEncode(userData));

      if (!mounted) return;

      setState(() {
        _localPhotoPath = pickedImage.path;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto de perfil actualizada'),
          backgroundColor: Color(0xFF22C55E),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cambiar foto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================
  // AVATAR
  // ============================
  ImageProvider? _getProfileImage() {
    if (_localPhotoPath.isNotEmpty) {
      final file = File(_localPhotoPath);

      if (file.existsSync()) {
        return FileImage(file);
      }
    }

    if (_googlePhoto.isNotEmpty) {
      return NetworkImage(_googlePhoto);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ImageProvider? imageProvider = _getProfileImage();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, bottom: 20, left: 20, right: 20),
      color: const Color(0xFF2563EB),
      child: Column(
        children: [
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF22C55E), size: 35),
              onPressed: widget.onMenuTap,
            ),
          ),

          Row(
            children: [
              GestureDetector(
                onTap: _changeProfilePhoto,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: Colors.white24,
                      backgroundImage: imageProvider,
                      child:
                          imageProvider == null
                              ? const Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.white,
                              )
                              : null,
                    ),

                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 20),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    Text(
                      _userCareer,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      'Toca la foto para cambiarla',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
