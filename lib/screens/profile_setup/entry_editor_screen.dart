import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/services/professional_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/common/brand_bits.dart';

/// Agregar o editar una línea del perfil (experiencia, formación…).
/// Devuelve true si se guardó o borró algo.
class EntryEditorScreen extends StatefulWidget {
  final String kind;
  final ProfileEntry? entry;

  const EntryEditorScreen({super.key, required this.kind, this.entry});

  @override
  State<EntryEditorScreen> createState() => _EntryEditorScreenState();
}

class _EntryEditorScreenState extends State<EntryEditorScreen> {
  late final _title = TextEditingController(text: widget.entry?.title);
  late final _org = TextEditingController(text: widget.entry?.organization);
  late final _location = TextEditingController(text: widget.entry?.location);
  late final _description = TextEditingController(
    text: widget.entry?.description,
  );
  late final _url = TextEditingController(text: widget.entry?.url);
  late DateTime? _start = widget.entry?.startDate;
  late DateTime? _end = widget.entry?.endDate;
  late bool _current = widget.entry?.isCurrent ?? false;
  bool _saving = false;

  // Qué pide cada tipo.
  ({String title, String titleHint, String org, String orgHint, bool dates})
  get _labels => switch (widget.kind) {
    'experience' => (
      title: 'Cargo',
      titleHint: 'Desarrollador Flutter',
      org: 'Empresa',
      orgHint: 'Tech SV',
      dates: true,
    ),
    'education' => (
      title: 'Carrera o título',
      titleHint: 'Ingeniería en Sistemas',
      org: 'Institución',
      orgHint: 'UES',
      dates: true,
    ),
    'certification' => (
      title: 'Certificación',
      titleHint: 'Google Data Analytics',
      org: 'Emitida por',
      orgHint: 'Coursera',
      dates: true,
    ),
    'project' => (
      title: 'Proyecto',
      titleHint: 'App de turnos para clínicas',
      org: 'Rol o equipo (opcional)',
      orgHint: 'Líder del equipo',
      dates: true,
    ),
    'language' => (
      title: 'Idioma',
      titleHint: 'Inglés',
      org: 'Nivel',
      orgHint: 'Intermedio (B1)',
      dates: false,
    ),
    _ => (
      title: 'Actividad',
      titleHint: 'Tutor de matemáticas',
      org: 'Organización',
      orgHint: 'Fundación…',
      dates: true,
    ),
  };

  @override
  void dispose() {
    for (final c in [_title, _org, _location, _description, _url]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (start ? _start : _end) ?? now,
      firstDate: DateTime(1970),
      lastDate: DateTime(now.year + 6),
      initialDatePickerMode: DatePickerMode.year,
      helpText: start ? 'Fecha de inicio' : 'Fecha de fin',
    );
    if (picked == null) return;
    setState(() {
      final month = DateTime(picked.year, picked.month);
      start ? _start = month : _end = month;
    });
  }

  String _monthLabel(DateTime? date) {
    if (date == null) return 'Elegir';
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  Future<void> _save() async {
    if (_title.text.trim().length < 2) {
      showAuthMessage(context, 'Escribe ${_labels.title.toLowerCase()}.');
      return;
    }
    setState(() => _saving = true);
    String? text(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    try {
      await ProfessionalService.saveEntry(
        ProfileEntry(
          id: widget.entry?.id ?? '',
          kind: widget.kind,
          title: _title.text.trim(),
          organization: text(_org),
          location: text(_location),
          startDate: _labels.dates ? _start : null,
          endDate: _labels.dates ? _end : null,
          isCurrent: _labels.dates && _current,
          description: text(_description),
          url: text(_url),
        ),
        id: widget.entry?.id,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAuthMessage(
        context,
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _delete() async {
    final id = widget.entry?.id;
    if (id == null) return;
    setState(() => _saving = true);
    try {
      await ProfessionalService.deleteEntry(id);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAuthMessage(
        context,
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final labels = _labels;
    final kindName = entryKinds[widget.kind] ?? '';

    return Scaffold(
      backgroundColor: palette.background,
      appBar: brandAppBar(
        context,
        widget.entry == null ? 'Agregar · $kindName' : 'Editar · $kindName',
        actions: [
          if (widget.entry != null)
            IconButton(
              tooltip: 'Borrar',
              onPressed: _saving ? null : _delete,
              icon: const Icon(PhosphorIconsRegular.trash, color: Brand.danger),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AuthTextField(
            controller: _title,
            label: labels.title,
            hint: labels.titleHint,
            icon: PhosphorIconsRegular.textT,
            enabled: !_saving,
          ),
          const SizedBox(height: 14),
          AuthTextField(
            controller: _org,
            label: labels.org,
            hint: labels.orgHint,
            icon: PhosphorIconsRegular.buildings,
            enabled: !_saving,
          ),
          if (labels.dates) ...[
            const SizedBox(height: 14),
            AuthTextField(
              controller: _location,
              label: 'Lugar (opcional)',
              hint: 'San Salvador',
              icon: PhosphorIconsRegular.mapPin,
              enabled: !_saving,
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _current,
              activeTrackColor: Brand.blue,
              title: Text(
                widget.kind == 'education'
                    ? 'Estudio aquí actualmente'
                    : 'Actualmente',
                style: TextStyle(
                  fontFamily: Brand.displayFont,
                  fontWeight: FontWeight.w600,
                  color: palette.title,
                ),
              ),
              onChanged: (v) => setState(() => _current = v),
            ),
            Row(
              children: [
                Expanded(
                  child: _DateButton(
                    label: 'Inicio',
                    value: _monthLabel(_start),
                    onTap: () => _pickDate(start: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateButton(
                    label: 'Fin',
                    value: _current ? 'Actualidad' : _monthLabel(_end),
                    onTap: _current ? null : () => _pickDate(start: false),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          const AuthFieldLabel('Descripción (opcional)'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: authFieldDecoration(palette),
            child: TextField(
              controller: _description,
              enabled: !_saving,
              minLines: 3,
              maxLines: 8,
              maxLength: 2000,
              style: TextStyle(
                fontFamily: Brand.displayFont,
                color: palette.title,
              ),
              decoration: const InputDecoration(
                hintText: 'Logros, tecnologías, responsabilidades…',
                border: InputBorder.none,
                counterText: '',
              ),
            ),
          ),
          if (widget.kind == 'project' || widget.kind == 'certification') ...[
            const SizedBox(height: 14),
            AuthTextField(
              controller: _url,
              label: 'Enlace (opcional)',
              hint: 'https://…',
              icon: PhosphorIconsRegular.link,
              keyboardType: TextInputType.url,
              enabled: !_saving,
            ),
          ],
          const SizedBox(height: 24),
          GradientButton(text: 'Guardar', isLoading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _DateButton({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Brand.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: authFieldDecoration(palette),
        child: Row(
          children: [
            Icon(PhosphorIconsRegular.calendar, size: 18, color: palette.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 11.5,
                      color: palette.muted,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontWeight: FontWeight.w600,
                      color: onTap == null ? palette.muted : palette.title,
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
