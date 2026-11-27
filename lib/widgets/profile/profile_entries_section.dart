import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:connect_do/services/profile_service.dart';
import 'package:connect_do/screens/profile_setup/entry_editor_screen.dart';
import 'package:connect_do/services/professional_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/common/brand_bits.dart';

/// Experiencia, formación, certificaciones… agrupadas por tipo.
/// Con [editable] (mi perfil) se puede agregar y editar.
class ProfileEntriesSection extends StatefulWidget {
  final List<ProfileEntry>? entries;
  final bool editable;

  const ProfileEntriesSection({super.key, this.entries, this.editable = false});

  @override
  State<ProfileEntriesSection> createState() => _ProfileEntriesSectionState();
}

class _ProfileEntriesSectionState extends State<ProfileEntriesSection> {
  late List<ProfileEntry> _entries = widget.entries ?? [];
  bool _loading = false;
  String _headline = '';

  @override
  void initState() {
    super.initState();
    if (widget.editable) _load();
  }

  @override
  void didUpdateWidget(covariant ProfileEntriesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.editable && widget.entries != oldWidget.entries) {
      _entries = widget.entries ?? [];
    }
  }

  Future<void> _editHeadline() async {
    final controller = TextEditingController(text: _headline);
    final value = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Tu titular'),
            content: TextField(
              controller: controller,
              maxLength: 160,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Estudiante de Sistemas · Flutter y Firebase',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed:
                    () => Navigator.pop(dialogContext, controller.text.trim()),
                child: const Text('Guardar'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (value == null) return;
    try {
      await ProfileService.updateMyProfile(headline: value);
      if (mounted) setState(() => _headline = value);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    ProfileService.getMyProfile().then((profile) {
      if (mounted) {
        setState(() => _headline = profile?['headline']?.toString() ?? '');
      }
    });
    try {
      final entries = await ProfessionalService.myEntries();
      if (mounted) setState(() => _entries = entries);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(String kind, [ProfileEntry? entry]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EntryEditorScreen(kind: kind, entry: entry),
      ),
    );
    if (changed == true) _load();
  }

  void _chooseKind() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final palette = AuthPalette.of(sheetContext);
        return Material(
          color: palette.card,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Brand.radiusLg),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                for (final kind in entryKinds.entries)
                  ListTile(
                    leading: Icon(_icon(kind.key), color: Brand.blue),
                    title: Text(
                      kind.value,
                      style: TextStyle(
                        fontFamily: Brand.displayFont,
                        fontWeight: FontWeight.w600,
                        color: palette.title,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _edit(kind.key);
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  static IconData _icon(String kind) => switch (kind) {
    'experience' => PhosphorIconsRegular.briefcase,
    'education' => PhosphorIconsRegular.graduationCap,
    'certification' => PhosphorIconsRegular.certificate,
    'project' => PhosphorIconsRegular.rocketLaunch,
    'language' => PhosphorIconsRegular.translate,
    _ => PhosphorIconsRegular.handHeart,
  };

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    if (!widget.editable && _entries.isEmpty) return const SizedBox.shrink();

    final groups = <String, List<ProfileEntry>>{};
    for (final entry in _entries) {
      groups.putIfAbsent(entry.kind, () => []).add(entry);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.editable)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Text(
                  'TRAYECTORIA',
                  style: TextStyle(
                    fontFamily: Brand.displayFont,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: palette.muted,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _chooseKind,
                  icon: const Icon(PhosphorIconsBold.plus, size: 16),
                  label: const Text('Agregar'),
                ),
              ],
            ),
          ),
        if (widget.editable)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: BrandCard(
              onTap: _editHeadline,
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  const Icon(
                    PhosphorIconsRegular.identificationBadge,
                    color: Brand.blue,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Titular',
                          style: TextStyle(
                            fontFamily: Brand.displayFont,
                            fontSize: 12,
                            color: palette.muted,
                          ),
                        ),
                        Text(
                          _headline.isEmpty
                              ? 'Ej.: Estudiante de Sistemas · Flutter'
                              : _headline,
                          style: TextStyle(
                            fontFamily: Brand.displayFont,
                            fontWeight: FontWeight.w600,
                            color:
                                _headline.isEmpty
                                    ? palette.muted
                                    : palette.title,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    PhosphorIconsRegular.pencilSimple,
                    size: 16,
                    color: palette.muted,
                  ),
                ],
              ),
            ),
          ),
        if (widget.editable && _entries.isEmpty && !_loading)
          BrandCard(
            onTap: _chooseKind,
            child: Row(
              children: [
                const Icon(PhosphorIconsRegular.briefcase, color: Brand.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Agrega tu experiencia, formación, certificaciones, '
                    'proyectos e idiomas. Las empresas lo revisan primero.',
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 13.5,
                      color: palette.body,
                    ),
                  ),
                ),
              ],
            ),
          ),
        for (final kind in entryKinds.keys)
          if (groups[kind] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: BrandCard(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_icon(kind), size: 18, color: Brand.blue),
                        const SizedBox(width: 8),
                        Text(
                          entryKinds[kind]!,
                          style: TextStyle(
                            fontFamily: Brand.displayFont,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: palette.title,
                          ),
                        ),
                        const Spacer(),
                        if (widget.editable)
                          IconButton(
                            tooltip: 'Agregar',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _edit(kind),
                            icon: Icon(
                              PhosphorIconsRegular.plus,
                              size: 18,
                              color: palette.muted,
                            ),
                          ),
                      ],
                    ),
                    for (final entry in groups[kind]!)
                      _EntryTile(
                        entry: entry,
                        onTap:
                            widget.editable ? () => _edit(kind, entry) : null,
                      ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  final ProfileEntry entry;
  final VoidCallback? onTap;

  const _EntryTile({required this.entry, this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final subtitle = [
      if ((entry.organization ?? '').isNotEmpty) entry.organization!,
      if ((entry.location ?? '').isNotEmpty) entry.location!,
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.title,
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: palette.title,
                    ),
                  ),
                ),
                if (onTap != null)
                  Icon(
                    PhosphorIconsRegular.pencilSimple,
                    size: 15,
                    color: palette.muted,
                  ),
              ],
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: Brand.displayFont,
                  fontSize: 13,
                  color: palette.label,
                ),
              ),
            if (entry.period.isNotEmpty)
              Text(
                entry.period,
                style: TextStyle(
                  fontFamily: Brand.displayFont,
                  fontSize: 12.5,
                  color: palette.muted,
                ),
              ),
            if ((entry.description ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  entry.description!,
                  style: TextStyle(
                    fontFamily: Brand.displayFont,
                    fontSize: 13.5,
                    height: 1.4,
                    color: palette.body,
                  ),
                ),
              ),
            if ((entry.url ?? '').isNotEmpty)
              GestureDetector(
                onTap:
                    () => launchUrl(
                      Uri.parse(entry.url!),
                      mode: LaunchMode.externalApplication,
                    ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    entry.url!,
                    style: const TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Brand.blue,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
