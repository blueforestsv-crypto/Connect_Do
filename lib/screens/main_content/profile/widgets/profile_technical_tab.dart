import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:connect_do/services/profile_service.dart';
import 'package:connect_do/services/user_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/utils/academic_options.dart';
import 'package:connect_do/utils/responsive_helper.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';

/// Pestaña "Perfil": muestra la información profesional del usuario.
/// La edición se hace en "Completa tu perfil" (un solo lugar para editar).
class ProfileTechnicalTab extends StatefulWidget {
  final int refreshKey;
  final VoidCallback onEditProfile;

  /// Se llama cuando esta pestaña cambia algo por sí misma (por ejemplo, el CV).
  final VoidCallback onProfileChanged;

  const ProfileTechnicalTab({
    super.key,
    required this.refreshKey,
    required this.onEditProfile,
    required this.onProfileChanged,
  });

  @override
  State<ProfileTechnicalTab> createState() => _ProfileTechnicalTabState();
}

class _ProfileTechnicalTabState extends State<ProfileTechnicalTab> {
  Map<String, dynamic> _user = {};
  bool _isUploadingCv = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProfileTechnicalTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) _load();
  }

  Future<void> _load() async {
    final user = await UserService.getUser();
    if (mounted) setState(() => _user = user);
  }

  String _str(String key) => _user[key]?.toString().trim() ?? '';

  List<String> get _skills {
    final skills = _user['skills'];
    return skills is List ? skills.map((s) => s.toString()).toList() : [];
  }

  String get _cvName {
    for (final key in ['cv_file_name', 'cv_url']) {
      if (_str(key).isNotEmpty) return _str(key).split(RegExp(r'[\\/]')).last;
    }
    return '';
  }

  /// "+50371234567" -> "+503 7123 4567".
  static String _formatPhone(String phone) {
    final match = RegExp(r'^\+503(\d{4})(\d{4})$').firstMatch(phone);
    return match == null ? phone : '+503 ${match[1]} ${match[2]}';
  }

  // ===============================
  // ACCIONES
  // ===============================
  Future<void> _openPortfolio() async {
    var link = _str('portfolio_link');
    if (link.isEmpty) return;
    if (!link.startsWith('http')) link = 'https://$link';

    final uri = Uri.tryParse(link);
    final opened =
        uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && mounted) {
      showAuthMessage(context, 'No se pudo abrir el enlace.');
    }
  }

  Future<void> _uploadCv() async {
    if (_isUploadingCv) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      setState(() => _isUploadingCv = true);

      final updated =
          Map<String, dynamic>.from(_user)
            ..['cv_file_name'] = file.name
            ..['cv_file_path'] = file.path ?? ''
            ..['cv_path'] = file.path ?? ''
            ..['cv_file_size'] = file.size
            ..['cv_url'] = file.name;

      await UserService.saveUser(updated);
      if (!mounted) return;
      setState(() => _user = updated);

      await ProfileService.updateMyProfile(cvUrl: file.name);
      if (!mounted) return;
      widget.onProfileChanged();
      showAuthMessage(
        context,
        'Currículum actualizado',
        type: AuthMessageType.success,
      );
    } catch (_) {
      if (mounted) {
        showAuthMessage(
          context,
          'Se guardó en tu teléfono, pero no se pudo sincronizar.',
          type: AuthMessageType.info,
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingCv = false);
    }
  }

  // ===============================
  // UI
  // ===============================
  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final level = _str('level');
    final university = AcademicOptions.normalizeUniversity(_str('university'));
    final description = _str('description');
    final skills = _skills;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        ResponsiveHelper.appBottomNavSpace(context),
      ),
      children: [
        _Section(
          icon: PhosphorIconsRegular.sparkle,
          title: 'Sobre mí',
          onEdit: widget.onEditProfile,
          child:
              description.isEmpty
                  ? _EmptyHint(
                    text: 'Cuéntales a las empresas quién eres.',
                    onTap: widget.onEditProfile,
                  )
                  : Text(
                    description,
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 14.5,
                      height: 1.5,
                      color: palette.label,
                    ),
                  ),
        ),
        _Section(
          icon: PhosphorIconsRegular.student,
          title: 'Estudios',
          onEdit: widget.onEditProfile,
          child: Column(
            children: [
              _InfoRow(
                icon: PhosphorIconsRegular.buildings,
                label: 'Universidad',
                value:
                    university == null
                        ? null
                        : AcademicOptions.universityLabel(university),
                onEmptyTap: widget.onEditProfile,
              ),
              _InfoRow(
                icon: PhosphorIconsRegular.briefcase,
                label: 'Carrera',
                value: _str('career'),
                onEmptyTap: widget.onEditProfile,
              ),
              _InfoRow(
                icon: PhosphorIconsRegular.certificate,
                label: 'Nivel',
                // "Pregrado (Licenciaturas, ...)" -> "Pregrado"
                value: level.split(' (').first,
                onEmptyTap: widget.onEditProfile,
              ),
              if (AcademicOptions.levelUsesCycle(level.isEmpty ? null : level))
                _InfoRow(
                  icon: PhosphorIconsRegular.calendarBlank,
                  label: 'Ciclo',
                  value: _str('cycle'),
                  onEmptyTap: widget.onEditProfile,
                  isLast: true,
                ),
            ],
          ),
        ),
        _Section(
          icon: PhosphorIconsRegular.lightning,
          title: 'Habilidades',
          onEdit: widget.onEditProfile,
          child:
              skills.isEmpty
                  ? _EmptyHint(
                    text: 'Agrega hasta 5 habilidades.',
                    onTap: widget.onEditProfile,
                  )
                  : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final skill in skills)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Brand.blue.withValues(
                              alpha: palette.isDark ? 0.18 : 0.08,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            skill,
                            style: const TextStyle(
                              fontFamily: Brand.displayFont,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Brand.blue,
                            ),
                          ),
                        ),
                    ],
                  ),
        ),
        _Section(
          icon: PhosphorIconsRegular.identificationCard,
          title: 'Contacto',
          onEdit: widget.onEditProfile,
          child: Column(
            children: [
              _InfoRow(
                icon: PhosphorIconsRegular.envelopeSimple,
                label: 'Correo',
                value: _str('email'),
              ),
              _InfoRow(
                icon: PhosphorIconsRegular.phone,
                label: 'Teléfono',
                value: _formatPhone(_str('phone')),
                onEmptyTap: widget.onEditProfile,
                isLast: true,
              ),
            ],
          ),
        ),
        _Section(
          icon: PhosphorIconsRegular.fileText,
          title: 'Documentos',
          child: Column(
            children: [
              _ActionTile(
                icon: PhosphorIconsRegular.link,
                title:
                    _str('portfolio_link').isEmpty
                        ? 'Agregar portafolio'
                        : _str('portfolio_link'),
                subtitle:
                    _str('portfolio_link').isEmpty
                        ? 'Behance, GitHub, sitio web…'
                        : 'Portafolio · toca para abrir',
                accent: Brand.blue,
                onTap:
                    _str('portfolio_link').isEmpty
                        ? widget.onEditProfile
                        : _openPortfolio,
                trailingIcon: PhosphorIconsRegular.arrowUpRight,
              ),
              const SizedBox(height: 10),
              _ActionTile(
                icon:
                    _cvName.isEmpty
                        ? PhosphorIconsRegular.uploadSimple
                        : PhosphorIconsRegular.fileText,
                title: _cvName.isEmpty ? 'Subir currículum' : _cvName,
                subtitle:
                    _cvName.isEmpty
                        ? 'PDF o Word'
                        : 'Currículum · toca para reemplazar',
                accent: _cvName.isEmpty ? Brand.blue : Brand.green,
                onTap: _uploadCv,
                isLoading: _isUploadingCv,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =====================================================
// PIEZAS
// =====================================================
class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final VoidCallback? onEdit;

  const _Section({
    required this.icon,
    required this.title,
    required this.child,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: Brand.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: Brand.displayFont,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: palette.title,
                  ),
                ),
              ),
              if (onEdit != null)
                TextButton(
                  onPressed: onEdit,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const Text(
                    'Editar',
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Brand.blue,
                    ),
                  ),
                )
              else
                const SizedBox(height: 40),
            ],
          ),
          const SizedBox(height: 6),
          Padding(padding: const EdgeInsets.only(right: 8), child: child),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onEmptyTap;
  final bool isLast;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onEmptyTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final hasValue = value != null && value!.trim().isNotEmpty;

    return InkWell(
      onTap: hasValue ? null : onEmptyTap,
      borderRadius: BorderRadius.circular(Brand.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border:
              isLast
                  ? null
                  : Border(bottom: BorderSide(color: palette.cardBorder)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: palette.muted),
            const SizedBox(width: 12),
            SizedBox(
              width: 92,
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: Brand.displayFont,
                  fontSize: 13.5,
                  color: palette.body,
                ),
              ),
            ),
            Expanded(
              child: Text(
                hasValue ? value! : 'Agregar',
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: Brand.displayFont,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color:
                      hasValue
                          ? palette.title
                          : (onEmptyTap == null ? palette.muted : Brand.blue),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;
  final IconData? trailingIcon;
  final bool isLoading;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
    this.trailingIcon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(Brand.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: authFieldDecoration(palette),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(Brand.radiusSm),
              ),
              child:
                  isLoading
                      ? Padding(
                        padding: const EdgeInsets.all(11),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: accent,
                        ),
                      )
                      : Icon(icon, size: 20, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: palette.title,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 12.5,
                      color: palette.muted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              trailingIcon ?? PhosphorIconsRegular.caretRight,
              size: 18,
              color: palette.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _EmptyHint({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: Brand.displayFont,
                fontSize: 14,
                color: palette.muted,
              ),
            ),
          ),
          const Icon(PhosphorIconsRegular.plus, size: 18, color: Brand.blue),
        ],
      ),
    );
  }
}
