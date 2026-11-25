import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/helpers/profile_completion.dart';
import 'package:connect_do/services/profile_service.dart';
import 'package:connect_do/services/user_service.dart';
import 'package:connect_do/screens/applications/my_applications_screen.dart';
import 'package:connect_do/screens/applications/received_applications_screen.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/utils/academic_options.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/feed/user_avatar.dart';

/// Tarjeta superior del perfil: foto, nombre, estudios y avance del perfil.
class ProfileHeader extends StatefulWidget {
  /// Cambia cada vez que el perfil se edita, para volver a leer los datos.
  final int refreshKey;
  final VoidCallback onEditProfile;
  final VoidCallback onOpenSettings;

  const ProfileHeader({
    super.key,
    required this.refreshKey,
    required this.onEditProfile,
    required this.onOpenSettings,
  });

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> {
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic> _user = {};
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProfileHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) _load();
  }

  Future<void> _load() async {
    final user = await UserService.getUser();
    if (mounted) setState(() => _user = user);
  }

  String _str(String key) => _user[key]?.toString().trim() ?? '';

  String get _name {
    final name =
        '${_str('firstName').isNotEmpty ? _str('firstName') : _str('first_name')} '
                '${_str('lastName').isNotEmpty ? _str('lastName') : _str('last_name')}'
            .trim();
    if (name.isNotEmpty) return name;
    final email = _str('email');
    return email.isEmpty ? 'Usuario' : email.split('@').first;
  }

  String get _photo {
    final base64Photo = _str('profile_image_base64');
    return base64Photo.isNotEmpty ? base64Photo : _str('google_photo_url');
  }

  /// "Ingenierías · UTEC" o lo que haya disponible.
  String? get _studies {
    final university = AcademicOptions.normalizeUniversity(_str('university'));
    final parts = [
      if (_str('career').isNotEmpty) _str('career'),
      if (university != null) university,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  // ===============================
  // CAMBIAR FOTO
  // ===============================
  Future<void> _changePhoto() async {
    if (_isUploadingPhoto) return;

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 900,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      // Se muestra y se guarda en el teléfono de inmediato.
      final updated = Map<String, dynamic>.from(_user)
        ..['profile_image_base64'] = base64Encode(bytes);
      await UserService.saveUser(updated);
      if (!mounted) return;
      setState(() {
        _user = updated;
        _isUploadingPhoto = true;
      });

      // En el servidor queda el enlace de Cloudinary (más liviano).
      final stored = await ProfileService.uploadProfilePhoto(
        bytes,
        picked.name,
      );
      final synced = Map<String, dynamic>.from(_user)
        ..['profile_image_base64'] = stored;
      await UserService.saveUser(synced);
      if (!mounted) return;
      setState(() => _user = synced);
      showAuthMessage(
        context,
        'Foto de perfil actualizada',
        type: AuthMessageType.success,
      );
    } catch (_) {
      if (!mounted) return;
      showAuthMessage(
        context,
        'La foto se guardó en tu teléfono, pero no se pudo subir. '
        'Inténtalo más tarde.',
        type: AuthMessageType.info,
      );
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  // ===============================
  // UI
  // ===============================
  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final percent = ProfileCompletion.percent(_user);
    final studies = _studies;
    final email = _str('email');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Perfil',
                style: TextStyle(
                  fontFamily: Brand.displayFont,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: palette.title,
                ),
              ),
              const Spacer(),
              _CircleIconButton(
                icon: PhosphorIconsRegular.gearSix,
                tooltip: 'Configuración',
                onTap: widget.onOpenSettings,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(Brand.radiusLg),
              border: Border.all(color: palette.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _buildAvatar(palette),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: Brand.displayFont,
                              fontSize: 20,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: palette.title,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                PhosphorIconsRegular.student,
                                size: 15,
                                color:
                                    studies == null
                                        ? palette.muted
                                        : Brand.blue,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  studies ?? 'Agrega tu carrera',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: Brand.displayFont,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        studies == null
                                            ? palette.muted
                                            : palette.label,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (email.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: Brand.displayFont,
                                fontSize: 12.5,
                                color: palette.muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (percent < 100) ...[
                  const SizedBox(height: 16),
                  _CompletionBar(percent: percent, onTap: widget.onEditProfile),
                ],
                const SizedBox(height: 16),
                OutlineActionButton(
                  text: 'Editar perfil',
                  icon: PhosphorIconsRegular.pencilSimple,
                  onPressed: widget.onEditProfile,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _QuickLink(
                        icon: PhosphorIconsRegular.paperPlaneTilt,
                        label: 'Mis postulaciones',
                        onTap: () => _push(const MyApplicationsScreen()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickLink(
                        icon: PhosphorIconsRegular.tray,
                        label: 'Recibidas',
                        onTap: () => _push(const ReceivedApplicationsScreen()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Widget _buildAvatar(AuthPalette palette) {
    return Semantics(
      button: true,
      label: 'Cambiar foto de perfil',
      child: GestureDetector(
        onTap: _changePhoto,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Brand.blue, Brand.green],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.card,
                ),
                child: UserAvatar(name: _name, photo: _photo, radius: 36),
              ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Brand.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.card, width: 2),
                ),
                child:
                    _isUploadingPhoto
                        ? const Padding(
                          padding: EdgeInsets.all(6),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(
                          PhosphorIconsRegular.camera,
                          size: 14,
                          color: Colors.white,
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletionBar extends StatelessWidget {
  final int percent;
  final VoidCallback onTap;

  const _CompletionBar({required this.percent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Brand.radiusMd),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Brand.blue.withValues(alpha: palette.isDark ? 0.14 : 0.06),
          borderRadius: BorderRadius.circular(Brand.radiusMd),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Tu perfil está al $percent%',
                  style: TextStyle(
                    fontFamily: Brand.displayFont,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: palette.label,
                  ),
                ),
                const Spacer(),
                const Text(
                  'Completar',
                  style: TextStyle(
                    fontFamily: Brand.displayFont,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Brand.blue,
                  ),
                ),
                const Icon(
                  PhosphorIconsRegular.caretRight,
                  size: 14,
                  color: Brand.blue,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  Container(height: 6, color: palette.fieldBorder),
                  FractionallySizedBox(
                    widthFactor: percent / 100,
                    child: Container(
                      height: 6,
                      decoration: const BoxDecoration(gradient: Brand.gradient),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: palette.card,
        shape: CircleBorder(side: BorderSide(color: palette.cardBorder)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, size: 21, color: palette.title),
          ),
        ),
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Material(
      color: Brand.blue.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(Brand.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(Brand.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: Brand.blue),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: Brand.displayFont,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: palette.title,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
