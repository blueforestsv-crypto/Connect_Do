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

  bool _isSyncingPhoto = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();

    final datosJson = prefs.getString('usuario_actual');

    Map<String, dynamic> userData = {};

    if (datosJson != null && datosJson.isNotEmpty) {
      try {
        userData = jsonDecode(datosJson) as Map<String, dynamic>;
      } catch (_) {
        userData = {};
      }
    }

    _setHeaderFromLocalUser(userData);

    await _loadProfileFromBackendAndSyncLocalPhoto(userData);
  }

  void _setHeaderFromLocalUser(Map<String, dynamic> userData) {
    final String email = userData['email']?.toString() ?? '';

    final String firstName =
        userData['firstName']?.toString() ??
        userData['first_name']?.toString() ??
        '';

    final String lastName =
        userData['lastName']?.toString() ??
        userData['last_name']?.toString() ??
        '';

    String fullName = '$firstName $lastName'.trim();

    if (fullName.isEmpty && email.isNotEmpty) {
      fullName = email.split('@')[0].replaceAll('.', ' ');
    }

    final String career = userData['career']?.toString() ?? '';

    final String googlePhoto =
        userData['google_photo_url']?.toString() ??
        userData['photoUrl']?.toString() ??
        userData['photo_url']?.toString() ??
        '';

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
  }

  Future<void> _loadProfileFromBackendAndSyncLocalPhoto(
    Map<String, dynamic> localUserData,
  ) async {
    try {
      final backendProfile = await ProfileService.getMyProfile();

      if (backendProfile == null) {
        return;
      }

      final String backendProfileImage =
          backendProfile['profile_image_base64']?.toString() ?? '';

      final String localProfileImage =
          localUserData['profile_image_base64']?.toString() ?? '';

      final prefs = await SharedPreferences.getInstance();

      final Map<String, dynamic> updatedUserData = Map<String, dynamic>.from(
        localUserData,
      );

      if (backendProfileImage.isNotEmpty) {
        updatedUserData['profile_image_base64'] = backendProfileImage;

        await prefs.setString('usuario_actual', jsonEncode(updatedUserData));

        if (!mounted) return;

        setState(() {
          _localPhotoBase64 = backendProfileImage;
        });

        return;
      }

      if (backendProfileImage.isEmpty && localProfileImage.isNotEmpty) {
        await _syncLocalPhotoToBackend(localProfileImage);

        updatedUserData['profile_image_base64'] = localProfileImage;

        await prefs.setString('usuario_actual', jsonEncode(updatedUserData));

        if (!mounted) return;

        setState(() {
          _localPhotoBase64 = localProfileImage;
        });
      }
    } catch (_) {
      // Si falla backend, dejamos la foto local para no romper la demo.
    }
  }

  Future<void> _syncLocalPhotoToBackend(String imageBase64) async {
    if (imageBase64.trim().isEmpty) return;

    try {
      setState(() {
        _isSyncingPhoto = true;
      });

      await ProfileService.updateMyProfile(profileImageBase64: imageBase64);
    } finally {
      if (!mounted) return;

      setState(() {
        _isSyncingPhoto = false;
      });
    }
  }

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
        try {
          userData = jsonDecode(datosJson) as Map<String, dynamic>;
        } catch (_) {
          userData = {};
        }
      }

      userData['profile_image_base64'] = imageBase64;
      userData['profile_image_path'] = pickedImage.name;

      await prefs.setString('usuario_actual', jsonEncode(userData));

      if (!mounted) return;

      setState(() {
        _localPhotoBase64 = imageBase64;
      });

      try {
        await _syncLocalPhotoToBackend(imageBase64);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto de perfil actualizada en backend'),
            backgroundColor: Color(0xFF22C55E),
            duration: Duration(seconds: 2),
          ),
        );
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
                      child:
                          _isSyncingPhoto
                              ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Icon(
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

                    Text(
                      _isSyncingPhoto
                          ? 'Sincronizando foto...'
                          : 'Toca la foto para cambiarla',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
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
