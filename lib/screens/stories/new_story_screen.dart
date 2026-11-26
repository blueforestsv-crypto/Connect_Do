import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:video_player/video_player.dart';

import 'package:connect_do/services/media_upload_service.dart';
import 'package:connect_do/services/story_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';

/// Crear una historia: elegir foto o video, escribir un texto y compartir.
/// Devuelve true si se publicó.
class NewStoryScreen extends StatefulWidget {
  /// Solo para pruebas: abre la pantalla con esta foto ya elegida.
  @visibleForTesting
  final Uint8List? initialImage;

  const NewStoryScreen({super.key, this.initialImage});

  @override
  State<NewStoryScreen> createState() => _NewStoryScreenState();
}

class _NewStoryScreenState extends State<NewStoryScreen> {
  static const int _maxVideoSeconds = 30;

  final ImagePicker _picker = ImagePicker();
  final TextEditingController _caption = TextEditingController();

  Uint8List? _bytes;
  String _name = '';
  bool _isVideo = false;
  double? _progress;
  bool _sharing = false;

  /// Vista previa del video elegido (en el teléfono, no en la web).
  VideoPlayerController? _preview;

  @override
  void initState() {
    super.initState();
    if (widget.initialImage != null) {
      _bytes = widget.initialImage;
      _name = 'foto.png';
      return;
    }
    // Se abre directo la galería.
    WidgetsBinding.instance.addPostFrameCallback((_) => _choose());
  }

  @override
  void dispose() {
    _caption.dispose();
    _preview?.dispose();
    super.dispose();
  }

  Future<void> _setPreview(XFile file, bool isVideo) async {
    final old = _preview;
    _preview = null;
    await old?.dispose();
    if (!isVideo || kIsWeb) return;

    final controller = VideoPlayerController.file(File(file.path));
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _preview = controller);
    } catch (_) {
      await controller.dispose();
    }
  }

  Future<void> _choose() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final palette = AuthPalette.of(sheetContext);
        Widget tile(IconData icon, String label, String value) => ListTile(
          leading: Icon(icon, color: Brand.blue),
          title: Text(
            label,
            style: TextStyle(
              fontFamily: Brand.displayFont,
              fontWeight: FontWeight.w600,
              color: palette.title,
            ),
          ),
          onTap: () => Navigator.pop(sheetContext, value),
        );
        return Material(
          color: palette.card,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Brand.radiusLg),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                tile(PhosphorIconsRegular.image, 'Foto de la galería', 'photo'),
                if (!kIsWeb)
                  tile(PhosphorIconsRegular.camera, 'Tomar foto', 'camera'),
                tile(
                  PhosphorIconsRegular.videoCamera,
                  'Video (hasta $_maxVideoSeconds s)',
                  'video',
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) {
      if (_bytes == null && mounted) Navigator.pop(context);
      return;
    }

    try {
      final XFile? file =
          source == 'video'
              ? await _picker.pickVideo(
                source: ImageSource.gallery,
                maxDuration: const Duration(seconds: _maxVideoSeconds),
              )
              : await _picker.pickImage(
                source:
                    source == 'camera'
                        ? ImageSource.camera
                        : ImageSource.gallery,
                maxWidth: 1440,
                imageQuality: 82,
              );
      if (file == null) {
        if (_bytes == null && mounted) Navigator.pop(context);
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _name = file.name;
        _isVideo = source == 'video';
      });
      _setPreview(file, _isVideo);
    } catch (_) {
      if (mounted) showAuthMessage(context, 'No se pudo abrir el archivo.');
    }
  }

  Future<void> _share() async {
    if (_bytes == null || _sharing) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _sharing = true;
      _progress = 0;
    });

    try {
      final uploaded = await MediaUploadService.upload(
        bytes: _bytes!,
        fileName: _name,
        kind: _isVideo ? MediaKind.video : MediaKind.image,
        purpose: MediaPurpose.story,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
      await StoryService.create(uploaded, caption: _caption.text);
      if (!mounted) return;
      showAuthMessage(
        context,
        'Historia compartida · dura 24 horas',
        type: AuthMessageType.success,
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _sharing = false);
      showAuthMessage(
        context,
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Orden fijo: barra arriba, la foto o el video en el centro (se achica
    // al abrir el teclado) y la descripción siempre abajo, sobre el teclado.
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Brand.radiusLg),
                    child: _buildPreview(),
                  ),
                ),
              ),
            ),
            if (_bytes != null) _buildCaptionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Cerrar',
            onPressed: _sharing ? null : () => Navigator.pop(context),
            icon: const Icon(
              PhosphorIconsRegular.x,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'Nueva historia',
              style: TextStyle(
                fontFamily: Brand.displayFont,
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (_bytes != null)
            TextButton.icon(
              onPressed: _sharing ? null : _choose,
              icon: const Icon(
                PhosphorIconsRegular.arrowsClockwise,
                color: Colors.white,
                size: 18,
              ),
              label: const Text(
                'Cambiar',
                style: TextStyle(
                  fontFamily: Brand.displayFont,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_bytes == null) {
      return Center(
        child: TextButton.icon(
          onPressed: _choose,
          icon: const Icon(PhosphorIconsRegular.image, color: Colors.white),
          label: const Text(
            'Elegir foto o video',
            style: TextStyle(
              fontFamily: Brand.displayFont,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    if (!_isVideo) {
      return Container(
        color: const Color(0xFF111111),
        alignment: Alignment.center,
        child: Image.memory(_bytes!, fit: BoxFit.contain),
      );
    }

    final preview = _preview;
    return Container(
      color: const Color(0xFF111111),
      alignment: Alignment.center,
      child:
          preview != null && preview.value.isInitialized
              ? AspectRatio(
                aspectRatio: preview.value.aspectRatio,
                child: VideoPlayer(preview),
              )
              : const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    PhosphorIconsFill.videoCamera,
                    color: Colors.white70,
                    size: 56,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Video listo para compartir',
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildCaptionBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white24),
              ),
              child: TextField(
                controller: _caption,
                enabled: !_sharing,
                maxLength: 200,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                  fontFamily: Brand.displayFont,
                  color: Colors.white,
                  fontSize: 15,
                ),
                cursorColor: Colors.white,
                decoration: const InputDecoration(
                  hintText: 'Agrega una descripción…',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                  counterText: '',
                  contentPadding: EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: Brand.gradient,
            ),
            child:
                _sharing
                    ? Padding(
                      padding: const EdgeInsets.all(13),
                      child: CircularProgressIndicator(
                        value: _progress,
                        strokeWidth: 3,
                        color: Colors.white,
                        backgroundColor: Colors.white24,
                      ),
                    )
                    : IconButton(
                      tooltip: 'Compartir',
                      onPressed: _share,
                      icon: const Icon(
                        PhosphorIconsFill.paperPlaneRight,
                        color: Colors.white,
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
