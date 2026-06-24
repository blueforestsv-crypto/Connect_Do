import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connect_do/services/profile_service.dart';

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
  String _userName = 'Cargando...';
  String _userCareer = '';
  String _userEmail = '';
  String _googlePhoto = '';
  String _localPhotoBase64 = '';

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

    if (datosJson == null || datosJson.isEmpty) {
      if (!mounted) return;

      setState(() {
        _userName = 'Usuario';
        _userCareer = 'Sin carrera';
        _userEmail = '';
        _googlePhoto = '';
        _localPhotoBase64 = '';
      });

      return;
    }

    try {
      final Map<String, dynamic> userData = jsonDecode(datosJson);

      final String email = userData['email']?.toString() ?? '';

      final String firstName = userData['firstName']?.toString() ?? '';
      final String lastName = userData['lastName']?.toString() ?? '';

      String fullName = '$firstName $lastName'.trim();

      if (fullName.isEmpty && email.isNotEmpty) {
        fullName = email.split('@')[0].replaceAll('.', ' ');
      }

      final String career = userData['career']?.toString() ?? '';

      final String googlePhoto = userData['google_photo_url']?.toString() ?? '';

      final String profilePhotoBase64 =
          userData['profile_image_base64']?.toString() ?? '';

      if (!mounted) return;

      setState(() {
        _userName = fullName.isEmpty ? 'Usuario' : fullName;
        _userCareer = career.isEmpty ? 'Sin carrera registrada' : career;
        _userEmail = email;
        _googlePhoto = googlePhoto;
        _localPhotoBase64 = profilePhotoBase64;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _userName = 'Usuario';
        _userCareer = 'Sin carrera registrada';
        _userEmail = '';
        _googlePhoto = '';
        _localPhotoBase64 = '';
      });
    }
  }

  // ============================
  // CAMBIAR FOTO DE PERFIL
  // ============================
  Future<void> _changeProfilePhoto() async {
    try {
      final XFile? pickedImage = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 900,
      );

      if (pickedImage == null) return;

      final Uint8List imageBytes = await pickedImage.readAsBytes();

      final String imageBase64 = base64Encode(imageBytes);

      final prefs = await SharedPreferences.getInstance();

      final datosJson = prefs.getString('usuario_actual');

      Map<String, dynamic> userData = {};

      if (datosJson != null && datosJson.isNotEmpty) {
        userData = jsonDecode(datosJson) as Map<String, dynamic>;
      }

      userData['profile_image_base64'] = imageBase64;

      // Dejamos este campo viejo por compatibilidad, pero ya no dependemos de él.
      userData['profile_image_path'] = pickedImage.name;

      try {
        await ProfileService.updateMyProfile(profileImageBase64: imageBase64);
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'La foto se guardó localmente, pero no se pudo subir al backend: $e',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }

      await prefs.setString('usuario_actual', jsonEncode(userData));

      if (!mounted) return;

      setState(() {
        _localPhotoBase64 = imageBase64;
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
    if (_localPhotoBase64.isNotEmpty) {
      try {
        final Uint8List bytes = base64Decode(_localPhotoBase64);
        return MemoryImage(bytes);
      } catch (_) {
        return null;
      }
    }

    if (_googlePhoto.isNotEmpty) {
      return NetworkImage(_googlePhoto);
    }

    return null;
  }

  String _getInitials() {
    final cleanName = _userName.trim();

    if (cleanName.isEmpty || cleanName == 'Cargando...') {
      return 'U';
    }

    final parts =
        cleanName.split(' ').where((part) => part.trim().isNotEmpty).toList();

    if (parts.isEmpty) return 'U';

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
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
                              ? Text(
                                _getInitials(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
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

                    if (_userEmail.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _userEmail,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

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
