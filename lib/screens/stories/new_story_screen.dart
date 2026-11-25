import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/services/media_upload_service.dart';
import 'package:connect_do/services/story_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';

/// Crear una historia: elegir foto o video, escribir un texto y compartir.
/// Devuelve true si se publicó.
class NewStoryScreen extends StatefulWidget {
  const NewStoryScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    // Se abre directo la galería.
    WidgetsBinding.instance.addPostFrameCallback((_) => _choose());
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
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
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child:
                  _bytes == null
                      ? const SizedBox.shrink()
                      : _isVideo
                      ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              PhosphorIconsFill.videoCamera,
                              color: Colors.white70,
                              size: 64,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Video listo para compartir',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      )
                      : Image.memory(_bytes!, fit: BoxFit.contain),
            ),
            Row(
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
                const Spacer(),
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
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
              ],
            ),
            if (_bytes != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: TextField(
                          controller: _caption,
                          enabled: !_sharing,
                          maxLength: 200,
                          maxLines: 3,
                          minLines: 1,
                          style: const TextStyle(color: Colors.white),
                          cursorColor: Colors.white,
                          decoration: const InputDecoration(
                            hintText: 'Agrega un texto…',
                            hintStyle: TextStyle(color: Colors.white60),
                            border: InputBorder.none,
                            counterText: '',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: Brand.gradient,
                      ),
                      child:
                          _sharing
                              ? Padding(
                                padding: const EdgeInsets.all(14),
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
              ),
          ],
        ),
      ),
    );
  }
}
