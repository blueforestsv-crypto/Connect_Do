import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/widgets/common/app_sheet.dart';
import 'package:connect_do/utils/cloudinary_url.dart';
import 'package:connect_do/helpers/profile_completion.dart';
import 'package:connect_do/services/profile_service.dart';
import 'package:connect_do/services/user_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/utils/academic_options.dart';
import 'package:connect_do/utils/responsive_helper.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/auth/auth_layout.dart';

/// Datos de perfil que antes se pedían en el registro. Todo es opcional:
/// el usuario guarda lo que tenga y puede volver después.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  static const int _maxSkills = 5;

  final _descriptionController = TextEditingController();
  final _portfolioController = TextEditingController();
  final _phoneController = TextEditingController();
  TextEditingController? _skillsInputController;

  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic> _user = {};
  bool _isLoadingData = true;
  bool _isSaving = false;
  String? _phoneError;

  String? _university;
  String? _level;
  String? _career;
  String? _cycle;
  final List<String> _skills = [];

  Uint8List? _newPhotoBytes;
  String _currentPhotoBase64 = '';
  String _googlePhotoUrl = '';

  String? _cvName;
  String? _cvPath;
  int _cvSize = 0;

  /// Archivo elegido en esta pantalla; se sube al guardar.
  PlatformFile? _pendingCv;

  @override
  void initState() {
    super.initState();
    _loadUser();
    // El progreso se recalcula mientras escribe.
    _descriptionController.addListener(_refresh);
    _phoneController.addListener(_refresh);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _portfolioController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  String _str(String key) => _user[key]?.toString().trim() ?? '';

  String? _nonEmpty(String key) => _str(key).isEmpty ? null : _str(key);

  Future<void> _loadUser() async {
    final user = await UserService.getUser();

    if (!mounted) return;

    setState(() {
      _user = user;

      _university =
          AcademicOptions.normalizeUniversity(_nonEmpty('university')) ??
          AcademicOptions.universityFromEmail(_str('email'));
      _level = _nonEmpty('level');
      _career = _nonEmpty('career');
      _cycle = _nonEmpty('cycle');

      _descriptionController.text = _str('description');
      _portfolioController.text = _str('portfolio_link');

      // Se guarda como +503XXXXXXXX; en el campo solo van los 8 dígitos.
      _phoneController.text = _str('phone').replaceFirst('+503', '');

      final skills = user['skills'];
      if (skills is List) {
        _skills.addAll(skills.map((s) => s.toString()));
      }

      _currentPhotoBase64 = _str('profile_image_base64');
      _googlePhotoUrl = _str('google_photo_url');

      _cvName = _nonEmpty('cv_file_name');
      _cvPath = _nonEmpty('cv_file_path') ?? _nonEmpty('cv_path');
      _cvSize = int.tryParse(_str('cv_file_size')) ?? 0;

      _isLoadingData = false;
    });
  }

  /// Estado actual del formulario, para el porcentaje en vivo.
  Map<String, dynamic> get _draft => {
    'university': _university ?? '',
    'career': _career ?? '',
    'level': _level ?? '',
    'description': _descriptionController.text,
    'skills': _skills,
    'phone': _phoneController.text,
    'profile_image_base64':
        _newPhotoBytes != null ? 'nueva' : _currentPhotoBase64,
    'google_photo_url': _googlePhotoUrl,
    'cv_file_name': _cvName ?? '',
  };

  // ===============================
  // HABILIDADES
  // ===============================
  void _addSkill(String skill) {
    final clean = skill.trim();
    if (clean.isEmpty || _skills.contains(clean)) return;

    if (_skills.length >= _maxSkills) {
      showAuthMessage(
        context,
        'Puedes agregar hasta $_maxSkills habilidades.',
        type: AuthMessageType.info,
      );
      return;
    }

    setState(() => _skills.add(clean));
  }

  // ===============================
  // FOTO Y CV
  // ===============================
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 900,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() => _newPhotoBytes = bytes);
    } catch (e) {
      if (!mounted) return;
      showAuthMessage(context, 'No se pudo seleccionar la imagen.');
    }
  }

  void _showImageSourceSelection() {
    showAppSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final palette = AuthPalette.of(sheetContext);

        Widget option(IconData icon, String text, ImageSource source) {
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Brand.blue.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(Brand.radiusSm),
              ),
              child: Icon(icon, color: Brand.blue, size: 21),
            ),
            title: Text(
              text,
              style: TextStyle(
                fontFamily: Brand.displayFont,
                fontWeight: FontWeight.w600,
                color: palette.title,
              ),
            ),
            onTap: () {
              Navigator.pop(sheetContext);
              _pickImage(source);
            },
          );
        }

        return Material(
          color: palette.card,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Brand.radiusLg),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 20),
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
                const SizedBox(height: 12),
                option(
                  PhosphorIconsRegular.camera,
                  'Tomar una foto',
                  ImageSource.camera,
                ),
                option(
                  PhosphorIconsRegular.image,
                  'Elegir de la galería',
                  ImageSource.gallery,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickCv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        withData: true,
      );
      if (result == null) return;

      final file = result.files.single;
      if (!mounted) return;

      if (file.size > ProfileService.maxCvBytes) {
        showAuthMessage(context, 'El CV no puede pesar más de 5 MB.');
        return;
      }

      setState(() {
        _pendingCv = file;
        _cvName = file.name;
        _cvPath = file.path;
        _cvSize = file.size;
      });
    } catch (e) {
      if (!mounted) return;
      showAuthMessage(context, 'No se pudo seleccionar el archivo.');
    }
  }

  ImageProvider? _photoPreview() {
    if (_newPhotoBytes != null) return MemoryImage(_newPhotoBytes!);

    final current = photoProvider(_currentPhotoBase64, size: 300);
    if (current != null) return current;

    if (_googlePhotoUrl.isNotEmpty) {
      return CachedNetworkImageProvider(_googlePhotoUrl);
    }

    return null;
  }

  // ===============================
  // GUARDAR
  // ===============================
  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    final phoneDigits = _phoneController.text.trim();
    if (phoneDigits.isNotEmpty &&
        !RegExp(r'^[267]\d{7}$').hasMatch(phoneDigits)) {
      setState(
        () => _phoneError = 'Deben ser 8 dígitos y empezar con 2, 6 o 7.',
      );
      return;
    }
    setState(() {
      _phoneError = null;
      _isSaving = true;
    });

    final usesCycle = AcademicOptions.levelUsesCycle(_level);
    final cycle = usesCycle ? (_cycle ?? '') : '';
    final phone = phoneDigits.isEmpty ? '' : '+503$phoneDigits';
    final description = _descriptionController.text.trim();
    final portfolio = _portfolioController.text.trim();
    final photoBase64 =
        _newPhotoBytes != null ? base64Encode(_newPhotoBytes!) : null;

    final updated =
        Map<String, dynamic>.from(_user)
          ..['university'] = _university ?? ''
          ..['level'] = _level ?? ''
          ..['career'] = _career ?? ''
          ..['cycle'] = cycle
          ..['description'] = description
          ..['portfolio_link'] = portfolio
          ..['phone'] = phone
          ..['skills'] = List<String>.from(_skills)
          ..['cv_file_name'] = _cvName ?? ''
          ..['cv_file_path'] = _cvPath ?? ''
          ..['cv_path'] = _cvPath ?? ''
          ..['cv_file_size'] = _cvSize
          ..['cv_url'] = _cvName ?? '';

    if (photoBase64 != null) {
      updated['profile_image_base64'] = photoBase64;
    }

    // Local primero, para no perder lo escrito si falla la red.
    await UserService.saveUser(updated);

    String? syncError;
    try {
      await ProfileService.updateMyProfile(
        university: _university,
        academicLevel: _level,
        career: _career,
        academicCycle: usesCycle ? _cycle : '',
        bio: description,
        portfolioUrl: portfolio,
        phone: phone,
        skills: List<String>.from(_skills),
      );
      if (_newPhotoBytes != null) {
        final stored = await ProfileService.uploadProfilePhoto(
          _newPhotoBytes!,
          'perfil.jpg',
        );
        updated['profile_image_base64'] = stored;
        await UserService.saveUser(updated);
      }
      if (_pendingCv != null) {
        await ProfileService.uploadCv(_pendingCv!);
        _pendingCv = null;
      }
    } catch (e) {
      syncError = e.toString();
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (syncError != null) {
      showAuthMessage(
        context,
        'Se guardó en tu teléfono, pero no se pudo sincronizar. '
        'Inténtalo más tarde.',
        type: AuthMessageType.info,
      );
      return;
    }

    final percent = ProfileCompletion.percent(updated);
    showAuthMessage(
      context,
      percent == 100 ? '¡Perfil completo!' : 'Perfil guardado · $percent%',
      type: AuthMessageType.success,
    );

    Navigator.pop(context, true);
  }

  // ===============================
  // UI
  // ===============================
  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child:
            _isLoadingData
                ? const Center(
                  child: CircularProgressIndicator(color: Brand.blue),
                )
                : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        20,
                        8,
                        20,
                        ResponsiveHelper.bottomSafe(context) + 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 48,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: AuthBackButton(
                                onTap: () => Navigator.maybePop(context),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Completa tu perfil',
                            style: TextStyle(
                              fontFamily: Brand.displayFont,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.6,
                              color: palette.title,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Las empresas ven esto cuando te postulas. '
                            'Llena lo que tengas; puedes volver cuando quieras.',
                            style: TextStyle(
                              fontFamily: Brand.displayFont,
                              fontSize: 15,
                              height: 1.45,
                              color: palette.body,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _ProgressCard(
                            percent: ProfileCompletion.percent(_draft),
                          ),
                          const SizedBox(height: 16),
                          _buildPhotoCard(palette),
                          const SizedBox(height: 16),
                          _buildAcademicCard(),
                          const SizedBox(height: 16),
                          _buildAboutCard(palette),
                          const SizedBox(height: 16),
                          _buildContactCard(palette),
                          const SizedBox(height: 28),
                          GradientButton(
                            text: 'Guardar perfil',
                            isLoading: _isSaving,
                            trailingIcon: PhosphorIconsRegular.checkCircle,
                            onPressed: _save,
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed:
                                _isSaving ? null : () => Navigator.pop(context),
                            child: Text(
                              'Hacerlo más tarde',
                              style: TextStyle(
                                fontFamily: Brand.displayFont,
                                fontWeight: FontWeight.w600,
                                color: palette.body,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
      ),
    );
  }

  Widget _buildPhotoCard(AuthPalette palette) {
    final preview = _photoPreview();

    return AuthCard(
      child: Row(
        children: [
          GestureDetector(
            onTap: _showImageSourceSelection,
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
                    child: CircleAvatar(
                      radius: 34,
                      backgroundColor: palette.fieldFill,
                      backgroundImage: preview,
                      child:
                          preview == null
                              ? Icon(
                                PhosphorIconsRegular.user,
                                size: 30,
                                color: palette.muted,
                              )
                              : null,
                    ),
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
                    child: const Icon(
                      PhosphorIconsRegular.camera,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Foto de perfil',
                  style: TextStyle(
                    fontFamily: Brand.displayFont,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: palette.title,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Una foto donde te veas listo para tu primera oportunidad.',
                  style: TextStyle(
                    fontFamily: Brand.displayFont,
                    fontSize: 13,
                    height: 1.4,
                    color: palette.body,
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _showImageSourceSelection,
                  child: Text(
                    preview == null ? 'Subir foto' : 'Cambiar foto',
                    style: const TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Brand.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicCard() {
    return _Section(
      icon: PhosphorIconsRegular.student,
      title: 'Datos académicos',
      children: [
        AuthDropdown(
          label: 'Universidad',
          hint: 'Selecciona tu universidad',
          icon: PhosphorIconsRegular.buildings,
          value: _university,
          items: AcademicOptions.universities,
          itemLabel: AcademicOptions.universityLabel,
          onChanged: (v) => setState(() => _university = v),
        ),
        const SizedBox(height: 16),
        AuthDropdown(
          label: 'Nivel académico',
          hint: 'Selecciona un nivel',
          icon: PhosphorIconsRegular.certificate,
          value: _level,
          items: AcademicOptions.levels,
          onChanged: (v) => setState(() => _level = v),
        ),
        const SizedBox(height: 16),
        AuthDropdown(
          label: 'Carrera',
          hint: 'Selecciona una carrera',
          icon: PhosphorIconsRegular.briefcase,
          value: _career,
          items: AcademicOptions.careers,
          onChanged: (v) => setState(() => _career = v),
        ),
        if (AcademicOptions.levelUsesCycle(_level)) ...[
          const SizedBox(height: 16),
          AuthDropdown(
            label: 'Ciclo actual',
            hint: 'Selecciona el ciclo',
            icon: PhosphorIconsRegular.calendarBlank,
            value: _cycle,
            items: AcademicOptions.cycles,
            onChanged: (v) => setState(() => _cycle = v),
          ),
        ],
      ],
    );
  }

  Widget _buildAboutCard(AuthPalette palette) {
    return _Section(
      icon: PhosphorIconsRegular.sparkle,
      title: 'Sobre ti',
      children: [
        AuthTextField(
          controller: _descriptionController,
          label: 'Descripción',
          hint: 'Cuéntales a las empresas quién eres y qué te apasiona.',
          icon: PhosphorIconsRegular.textAlignLeft,
          maxLines: 5,
          maxLength: 300,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
        ),
        const SizedBox(height: 16),
        AuthFieldLabel(
          'Habilidades',
          trailing: Text(
            '${_skills.length}/$_maxSkills',
            style: TextStyle(
              fontFamily: Brand.displayFont,
              fontSize: 12,
              color: palette.muted,
            ),
          ),
        ),
        _buildSkillsInput(palette),
        const SizedBox(height: 16),
        AuthTextField(
          controller: _portfolioController,
          label: 'Portafolio (opcional)',
          hint: 'https://behance.net/tu-usuario',
          icon: PhosphorIconsRegular.link,
          keyboardType: TextInputType.url,
        ),
      ],
    );
  }

  Widget _buildContactCard(AuthPalette palette) {
    return _Section(
      icon: PhosphorIconsRegular.identificationCard,
      title: 'Contacto y documentos',
      children: [
        AuthTextField(
          controller: _phoneController,
          label: 'Teléfono',
          hint: '7123 4567',
          icon: PhosphorIconsRegular.phone,
          prefixText: '+503',
          keyboardType: TextInputType.phone,
          errorText: _phoneError,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(8),
          ],
          onChanged: (_) {
            if (_phoneError != null) setState(() => _phoneError = null);
          },
        ),
        const SizedBox(height: 16),
        const AuthFieldLabel('Currículum'),
        InkWell(
          onTap: _pickCv,
          borderRadius: BorderRadius.circular(Brand.radiusMd),
          child: Container(
            height: Brand.fieldHeight + 12,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: authFieldDecoration(palette),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: (_cvName == null ? Brand.blue : Brand.green)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _cvName == null
                        ? PhosphorIconsRegular.uploadSimple
                        : PhosphorIconsRegular.fileText,
                    size: 20,
                    color: _cvName == null ? Brand.blue : Brand.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _cvName ?? 'Sube tu currículum',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: Brand.displayFont,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: palette.title,
                        ),
                      ),
                      Text(
                        _cvName == null ? 'PDF o Word' : _formatSize(_cvSize),
                        style: TextStyle(
                          fontFamily: Brand.displayFont,
                          fontSize: 12.5,
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _cvName == null ? 'Elegir' : 'Cambiar',
                  style: const TextStyle(
                    fontFamily: Brand.displayFont,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Brand.blue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return 'Archivo listo';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  Widget _buildSkillsInput(AuthPalette palette) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: Brand.fieldHeight),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: authFieldDecoration(palette),
      child: Autocomplete<String>(
        optionsBuilder: (value) {
          if (value.text.isEmpty) return const Iterable<String>.empty();

          final query = value.text.toLowerCase();
          return AcademicOptions.suggestedSkills.where(
            (option) =>
                option.toLowerCase().contains(query) &&
                !_skills.contains(option),
          );
        },
        onSelected: (selection) {
          _addSkill(selection);
          Future.delayed(Duration.zero, () => _skillsInputController?.clear());
        },
        fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
          _skillsInputController = controller;

          return Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final skill in _skills)
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                  decoration: BoxDecoration(
                    color: Brand.blue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        skill,
                        style: const TextStyle(
                          fontFamily: Brand.displayFont,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Brand.blue,
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setState(() => _skills.remove(skill)),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(
                            PhosphorIconsRegular.x,
                            size: 14,
                            color: Brand.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_skills.length < _maxSkills)
                IntrinsicWidth(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 160),
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      style: TextStyle(
                        fontFamily: Brand.displayFont,
                        fontSize: 15,
                        color: palette.title,
                      ),
                      cursorColor: Brand.blue,
                      decoration: InputDecoration(
                        hintText:
                            _skills.isEmpty
                                ? 'Ej. Figma, SQL, Liderazgo…'
                                : 'Agregar otra…',
                        hintStyle: TextStyle(
                          fontFamily: Brand.displayFont,
                          fontSize: 15,
                          color: palette.muted,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                      ),
                      onSubmitted: (value) {
                        _addSkill(value);
                        controller.clear();
                        focusNode.requestFocus();
                      },
                    ),
                  ),
                ),
            ],
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              color: palette.card,
              elevation: 6,
              shadowColor: palette.shadow,
              borderRadius: BorderRadius.circular(Brand.radiusMd),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width - 90,
                  maxHeight: 220,
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options.elementAt(index);
                    return ListTile(
                      dense: true,
                      leading: const Icon(
                        PhosphorIconsRegular.plus,
                        size: 18,
                        color: Brand.blue,
                      ),
                      title: Text(
                        option,
                        style: TextStyle(
                          fontFamily: Brand.displayFont,
                          fontSize: 14.5,
                          color: palette.title,
                        ),
                      ),
                      onTap: () => onSelected(option),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Tarjeta de sección con ícono y título.
class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _Section({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return AuthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Brand.blue),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontFamily: Brand.displayFont,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: palette.title,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}

/// Barra de progreso del perfil con el degradado de marca.
class _ProgressCard extends StatelessWidget {
  final int percent;

  const _ProgressCard({required this.percent});

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(Brand.radiusMd),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                percent == 100 ? '¡Perfil completo!' : 'Tu perfil',
                style: TextStyle(
                  fontFamily: Brand.displayFont,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: palette.label,
                ),
              ),
              const Spacer(),
              Text(
                '$percent%',
                style: TextStyle(
                  fontFamily: Brand.displayFont,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: palette.title,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Container(height: 8, color: palette.fieldBorder),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  widthFactor: percent / 100,
                  child: Container(
                    height: 8,
                    decoration: const BoxDecoration(gradient: Brand.gradient),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
