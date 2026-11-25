import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/services/publication_api_service.dart';
import 'package:connect_do/services/user_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/utils/responsive_helper.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/auth/auth_layout.dart';
import 'package:connect_do/widgets/feed/opportunity_card.dart';
import 'package:connect_do/widgets/feed/user_avatar.dart';

/// Crear una publicación: general u oportunidad (empleo, pasantía...).
class NewPublicationScreen extends StatefulWidget {
  final VoidCallback onBackToFeed;

  const NewPublicationScreen({super.key, required this.onBackToFeed});

  @override
  State<NewPublicationScreen> createState() => _NewPublicationScreenState();
}

const _types = [
  (value: 'general', label: 'Publicación'),
  (value: 'job', label: 'Empleo'),
  (value: 'internship', label: 'Pasantía'),
  (value: 'social_service', label: 'Servicio social'),
  (value: 'freelance', label: 'Freelance'),
  (value: 'announcement', label: 'Convocatoria'),
];

const _visibilities = [
  (
    value: 'contacts',
    label: 'Mis contactos',
    hint: 'Solo las personas con las que conectaste',
    icon: PhosphorIconsRegular.usersThree,
  ),
  (
    value: 'public',
    label: 'Público',
    hint: 'Cualquier persona en Connect Do',
    icon: PhosphorIconsRegular.globeHemisphereWest,
  ),
  (
    value: 'private',
    label: 'Solo yo',
    hint: 'Nadie más la verá',
    icon: PhosphorIconsRegular.lockSimple,
  ),
];

const _modalities = [
  (value: 'onsite', label: 'Presencial'),
  (value: 'remote', label: 'Remoto'),
  (value: 'hybrid', label: 'Híbrido'),
];

class _NewPublicationScreenState extends State<NewPublicationScreen> {
  static const int _maxImages = 4;
  static const int _minDescription = 10;

  final PublicationApiService _api = PublicationApiService();
  final ImagePicker _picker = ImagePicker();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  String _type = 'general';
  String _visibility = 'contacts';
  String? _modality;
  final List<({Uint8List bytes, String name})> _images = [];

  bool _isPublishing = false;
  bool _submitted = false;

  String _myName = '';
  String _myPhoto = '';

  bool get _isOpportunity => const {
    'job',
    'internship',
    'social_service',
    'freelance',
  }.contains(_type);

  bool get _needsTitle => _type != 'general';

  @override
  void initState() {
    super.initState();
    for (final controller in [_titleController, _descriptionController]) {
      controller.addListener(() => setState(() {}));
    }
    _loadMe();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadMe() async {
    final user = await UserService.getUser();
    final name =
        '${user['firstName'] ?? user['first_name'] ?? ''} '
                '${user['lastName'] ?? user['last_name'] ?? ''}'
            .trim();
    final photo = user['profile_image_base64']?.toString() ?? '';

    if (!mounted) return;
    setState(() {
      _myName = name.isEmpty ? 'Tú' : name;
      _myPhoto =
          photo.isNotEmpty ? photo : user['google_photo_url']?.toString() ?? '';
    });
  }

  // ===============================
  // VALIDACIÓN
  // ===============================
  String? get _titleError {
    if (!_needsTitle) return null;
    final title = _titleController.text.trim();
    if (title.length < 3) return 'Escribe un título (mínimo 3 caracteres).';
    return null;
  }

  String? get _descriptionError {
    final length = _descriptionController.text.trim().length;
    if (length < _minDescription) {
      return 'Escribe al menos $_minDescription caracteres '
          '(${_minDescription - length} más).';
    }
    return null;
  }

  bool get _isValid => _titleError == null && _descriptionError == null;

  // ===============================
  // FOTOS
  // ===============================
  Future<void> _pickImages() async {
    final remaining = _maxImages - _images.length;
    if (remaining <= 0 || _isPublishing) return;

    try {
      final picked = await _picker.pickMultiImage(
        maxWidth: 1600,
        imageQuality: 80,
        limit: remaining > 1 ? remaining : null,
      );
      if (picked.isEmpty) return;

      final selected = <({Uint8List bytes, String name})>[];
      for (final file in picked.take(remaining)) {
        selected.add((bytes: await file.readAsBytes(), name: file.name));
      }

      if (!mounted) return;
      setState(() => _images.addAll(selected));

      if (picked.length > remaining) {
        showAuthMessage(
          context,
          'Puedes subir hasta $_maxImages fotos.',
          type: AuthMessageType.info,
        );
      }
    } catch (_) {
      if (mounted) showAuthMessage(context, 'No se pudieron cargar las fotos.');
    }
  }

  static String _mimeFor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  // ===============================
  // PUBLICAR
  // ===============================
  Future<void> _publish() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
    if (!_isValid || _isPublishing) return;

    setState(() => _isPublishing = true);

    final description = _descriptionController.text.trim();
    // Las publicaciones generales no piden título: se usa el inicio del texto.
    final title =
        _needsTitle
            ? _titleController.text.trim()
            : (description.length <= 60
                ? description
                : '${description.substring(0, 57)}…');

    try {
      await _api.createPublication(
        type: _type,
        title: title,
        description: description,
        visibility: _visibility,
        location: _needsTitle ? _locationController.text : null,
        modality: _isOpportunity ? _modality : null,
        mediaItems: [
          for (final image in _images)
            {
              'type': 'image',
              'base64': base64Encode(image.bytes),
              'file_name': image.name,
              'mime_type': _mimeFor(image.name),
              'size_bytes': image.bytes.length,
            },
        ],
      );

      if (!mounted) return;
      _reset();
      showAuthMessage(context, '¡Publicado!', type: AuthMessageType.success);
      widget.onBackToFeed();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isPublishing = false);
      showAuthMessage(context, error.toString());
    }
  }

  void _reset() {
    _titleController.clear();
    _descriptionController.clear();
    _locationController.clear();
    setState(() {
      _type = 'general';
      _modality = null;
      _images.clear();
      _isPublishing = false;
      _submitted = false;
    });
  }

  void _chooseVisibility() {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final palette = AuthPalette.of(sheetContext);

        return Container(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(Brand.radiusLg),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.fieldBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Text(
                  '¿Quién puede verla?',
                  style: TextStyle(
                    fontFamily: Brand.displayFont,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: palette.title,
                  ),
                ),
              ),
              for (final option in _visibilities)
                ListTile(
                  leading: Icon(
                    option.icon,
                    color:
                        option.value == _visibility ? Brand.blue : palette.body,
                  ),
                  title: Text(
                    option.label,
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontWeight: FontWeight.w600,
                      color: palette.title,
                    ),
                  ),
                  subtitle: Text(
                    option.hint,
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 12.5,
                      color: palette.muted,
                    ),
                  ),
                  trailing:
                      option.value == _visibility
                          ? const Icon(
                            PhosphorIconsFill.checkCircle,
                            color: Brand.blue,
                          )
                          : null,
                  onTap: () {
                    setState(() => _visibility = option.value);
                    Navigator.pop(sheetContext);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // ===============================
  // UI
  // ===============================
  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final visibility = _visibilities.firstWhere((v) => v.value == _visibility);

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
              child: Row(
                children: [
                  AuthBackButton(
                    onTap: _isPublishing ? () {} : widget.onBackToFeed,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Nueva publicación',
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: palette.title,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  ResponsiveHelper.appBottomNavSpace(context),
                ),
                children: [
                  // Autor y privacidad
                  Row(
                    children: [
                      UserAvatar(name: _myName, photo: _myPhoto),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _myName,
                              style: TextStyle(
                                fontFamily: Brand.displayFont,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: palette.title,
                              ),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: _isPublishing ? null : _chooseVisibility,
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
                                decoration: BoxDecoration(
                                  color: palette.card,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: palette.cardBorder),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      visibility.icon,
                                      size: 14,
                                      color: Brand.blue,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      visibility.label,
                                      style: TextStyle(
                                        fontFamily: Brand.displayFont,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: palette.label,
                                      ),
                                    ),
                                    Icon(
                                      PhosphorIconsRegular.caretDown,
                                      size: 13,
                                      color: palette.muted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const AuthFieldLabel('Tipo'),
                  _buildTypeSelector(palette),
                  const SizedBox(height: 16),
                  if (_needsTitle) ...[
                    AuthTextField(
                      controller: _titleController,
                      label: 'Título',
                      hint:
                          _isOpportunity
                              ? 'Ej. Pasantía en Desarrollo Móvil'
                              : 'Ej. Convocatoria Hackatón 2026',
                      icon: PhosphorIconsRegular.textT,
                      errorText: _submitted ? _titleError : null,
                      enabled: !_isPublishing,
                    ),
                    const SizedBox(height: 16),
                  ],
                  AuthTextField(
                    controller: _descriptionController,
                    label: _isOpportunity ? 'Detalles y requisitos' : 'Texto',
                    hint:
                        _isOpportunity
                            ? 'Qué harán, requisitos, horario, cómo aplicar…'
                            : '¿Qué quieres compartir con tu red?',
                    icon: PhosphorIconsRegular.textAlignLeft,
                    maxLines: 6,
                    maxLength: 3000,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    errorText: _submitted ? _descriptionError : null,
                    enabled: !_isPublishing,
                  ),
                  if (_needsTitle) ...[
                    const SizedBox(height: 16),
                    AuthTextField(
                      controller: _locationController,
                      label: 'Ubicación (opcional)',
                      hint: 'Ej. San Salvador',
                      icon: PhosphorIconsRegular.mapPin,
                      enabled: !_isPublishing,
                    ),
                  ],
                  if (_isOpportunity) ...[
                    const SizedBox(height: 16),
                    const AuthFieldLabel('Modalidad (opcional)'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in _modalities)
                          _ChoiceChip(
                            label: option.label,
                            selected: _modality == option.value,
                            onTap:
                                () => setState(
                                  () =>
                                      _modality =
                                          _modality == option.value
                                              ? null
                                              : option.value,
                                ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  AuthFieldLabel(
                    'Fotos',
                    trailing: Text(
                      '${_images.length}/$_maxImages',
                      style: TextStyle(
                        fontFamily: Brand.displayFont,
                        fontSize: 12,
                        color: palette.muted,
                      ),
                    ),
                  ),
                  _buildImages(palette),
                  const SizedBox(height: 28),
                  GradientButton(
                    text: 'Publicar',
                    isLoading: _isPublishing,
                    trailingIcon: PhosphorIconsRegular.paperPlaneRight,
                    onPressed: _publish,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector(AuthPalette palette) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final type in _types)
          Builder(
            builder: (context) {
              final (icon, color) =
                  type.value == 'general'
                      ? (PhosphorIconsRegular.newspaper, Brand.blue)
                      : type.value == 'announcement'
                      ? (PhosphorIconsRegular.megaphone, Brand.blue)
                      : opportunityStyle(type.value);
              final selected = _type == type.value;

              return GestureDetector(
                onTap:
                    _isPublishing
                        ? null
                        : () => setState(() => _type = type.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                  decoration: BoxDecoration(
                    color:
                        selected
                            ? color.withValues(
                              alpha: palette.isDark ? 0.22 : 0.10,
                            )
                            : palette.card,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected ? color : palette.cardBorder,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 16,
                        color: selected ? color : palette.body,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        type.label,
                        style: TextStyle(
                          fontFamily: Brand.displayFont,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: selected ? color : palette.label,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildImages(AuthPalette palette) {
    return GridView.count(
      crossAxisCount: 4,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < _images.length; i++)
          Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Brand.radiusSm),
                child: Image.memory(_images[i].bytes, fit: BoxFit.cover),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap:
                      _isPublishing
                          ? null
                          : () => setState(() => _images.removeAt(i)),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      PhosphorIconsRegular.x,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        if (_images.length < _maxImages)
          InkWell(
            onTap: _pickImages,
            borderRadius: BorderRadius.circular(Brand.radiusSm),
            child: Container(
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(Brand.radiusSm),
                border: Border.all(color: palette.fieldBorder),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    PhosphorIconsRegular.imageSquare,
                    color: Brand.blue,
                    size: 22,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Agregar',
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: palette.body,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Brand.blue : palette.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? Brand.blue : palette.cardBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: Brand.displayFont,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : palette.label,
          ),
        ),
      ),
    );
  }
}
