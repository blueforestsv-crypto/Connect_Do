import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/models/publication_model.dart';
import 'package:connect_do/services/publication_api_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/common/brand_bits.dart';

/// Editar el texto, el título o quién ve mi publicación. Devuelve la
/// publicación actualizada.
class EditPublicationScreen extends StatefulWidget {
  final PublicationModel post;

  const EditPublicationScreen({super.key, required this.post});

  @override
  State<EditPublicationScreen> createState() => _EditPublicationScreenState();
}

class _EditPublicationScreenState extends State<EditPublicationScreen> {
  static const _visibilities = {
    'public': 'Pública',
    'contacts': 'Mis contactos',
    'private': 'Solo yo',
  };

  late final _title = TextEditingController(text: widget.post.title);
  late final _description = TextEditingController(
    text: widget.post.description,
  );
  late String _visibility =
      _visibilities.containsKey(widget.post.visibility)
          ? widget.post.visibility
          : 'contacts';
  bool _saving = false;

  bool get _hasTitle => widget.post.type != 'general';

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final description = _description.text.trim();
    if (description.length < 10) {
      showAuthMessage(context, 'Escribe al menos 10 caracteres.');
      return;
    }
    if (_hasTitle && _title.text.trim().length < 3) {
      showAuthMessage(context, 'El título necesita al menos 3 caracteres.');
      return;
    }
    setState(() => _saving = true);
    try {
      final updated = await PublicationApiService().updatePublication(
        widget.post.id,
        title:
            _hasTitle
                ? _title.text.trim()
                : (description.length <= 60
                    ? description
                    : '${description.substring(0, 57)}…'),
        description: description,
        visibility: _visibility,
      );
      if (!mounted) return;
      showAuthMessage(
        context,
        'Publicación actualizada',
        type: AuthMessageType.success,
      );
      Navigator.pop(context, updated);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAuthMessage(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: brandAppBar(context, 'Editar publicación'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_hasTitle) ...[
            AuthTextField(
              controller: _title,
              label: 'Título',
              hint: 'Título',
              icon: PhosphorIconsRegular.textT,
              enabled: !_saving,
            ),
            const SizedBox(height: 14),
          ],
          AuthTextField(
            controller: _description,
            label: 'Texto',
            hint: '¿Qué quieres compartir?',
            icon: PhosphorIconsRegular.textAlignLeft,
            maxLines: 8,
            maxLength: 3000,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            enabled: !_saving,
          ),
          const SizedBox(height: 14),
          const AuthFieldLabel('Quién la ve'),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in _visibilities.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _visibility == entry.key,
                  onSelected:
                      _saving
                          ? null
                          : (_) => setState(() => _visibility = entry.key),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Las fotos y videos no se pueden cambiar; para eso, publica de nuevo.',
            style: TextStyle(
              fontFamily: Brand.displayFont,
              fontSize: 12.5,
              color: palette.muted,
            ),
          ),
          const SizedBox(height: 24),
          GradientButton(
            text: 'Guardar cambios',
            isLoading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
