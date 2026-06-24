import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:connect_do/services/publication_service.dart';
import 'package:connect_do/utils/responsive_helper.dart';

class NewPublicationScreen extends StatefulWidget {
  final VoidCallback onBackToFeed;

  const NewPublicationScreen({super.key, required this.onBackToFeed});

  @override
  State<NewPublicationScreen> createState() => _NewPublicationScreenState();
}

class _NewPublicationScreenState extends State<NewPublicationScreen> {
  String _currentPrivacy = 'solo tus contactos';

  final TextEditingController _contentController = TextEditingController();

  bool isPublishing = false;
  bool hasContent = false;

  String? _selectedMediaName;
  String? _selectedMediaType;
  Uint8List? _selectedMediaBytes;
  Uint8List? _selectedImageBytes;

  @override
  void initState() {
    super.initState();
    _contentController.addListener(_checkContent);
  }

  @override
  void dispose() {
    _contentController.removeListener(_checkContent);
    _contentController.dispose();
    super.dispose();
  }

  void _checkContent() {
    setState(() {
      hasContent = _canPublish;
    });
  }

  bool get _canPublish {
    return _contentController.text.trim().isNotEmpty ||
        _selectedMediaName != null ||
        _selectedImageBytes != null;
  }

  // =====================================================
  // SELECCIONAR MULTIMEDIA
  // =====================================================
  Future<void> _pickMedia({
    required List<String> allowedExtensions,
    required String type,
  }) async {
    if (isPublishing) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;

      if (file.bytes == null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo leer el archivo seleccionado.'),
            backgroundColor: Colors.red,
          ),
        );

        return;
      }

      if (!mounted) return;

      setState(() {
        // En Flutter Web no existe file.path.
        // Por eso usamos file.name y file.bytes.
        _selectedMediaName = file.name;
        _selectedMediaType = type;
        _selectedMediaBytes = file.bytes;

        if (type == 'image') {
          _selectedImageBytes = file.bytes;
        } else {
          _selectedImageBytes = null;
        }

        hasContent = _canPublish;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo seleccionar el archivo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeSelectedMedia() {
    setState(() {
      _selectedMediaName = null;
      _selectedMediaType = null;
      _selectedMediaBytes = null;
      _selectedImageBytes = null;
      hasContent = _canPublish;
    });
  }

  // =====================================================
  // PUBLICAR EN BACKEND
  // =====================================================
  Future<void> _publishPost() async {
    if (!_canPublish || isPublishing) return;

    setState(() {
      isPublishing = true;
    });

    try {
      final rawDescription = _contentController.text.trim();

      final description =
          rawDescription.isNotEmpty ? rawDescription : 'Publicación multimedia';

      final title = _buildTitleFromDescription(description);

      final List<Map<String, dynamic>> mediaItems = [];

      if (_selectedMediaType == 'image' && _selectedImageBytes != null) {
        mediaItems.add({
          'type': 'image',
          'base64': base64Encode(_selectedImageBytes!),
          'file_name': _selectedMediaName ?? 'imagen.png',
          'mime_type': _guessMimeType(_selectedMediaName),
          'size_bytes': _selectedImageBytes!.length,
        });
      }

      if (_selectedMediaType == 'video') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Por ahora solo subiremos imágenes. Video queda preparado para después.',
            ),
            duration: Duration(milliseconds: 1600),
          ),
        );

        setState(() {
          isPublishing = false;
        });

        return;
      }

      final visibility = _mapPrivacyToVisibility(_currentPrivacy);

      await PublicationService.createPublicationOnBackend(
        title: title,
        description: description,
        type: 'general',
        location: null,
        modality: null,
        visibility: visibility,
        imageUrl: null,
        mediaItems: mediaItems,
      );

      if (!mounted) return;

      _contentController.clear();

      setState(() {
        _selectedMediaName = null;
        _selectedMediaType = null;
        _selectedMediaBytes = null;
        _selectedImageBytes = null;
        hasContent = false;
        isPublishing = false;
      });

      widget.onBackToFeed();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Publicación creada exitosamente!'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isPublishing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al publicar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _buildTitleFromDescription(String description) {
    final cleanDescription = description.trim();

    if (cleanDescription.length <= 60) {
      return cleanDescription;
    }

    return '${cleanDescription.substring(0, 60)}...';
  }

  String _mapPrivacyToVisibility(String privacy) {
    switch (privacy) {
      case 'todo el mundo':
        return 'public';
      case 'solo tus contactos':
        return 'contacts';
      case 'empresas y contactos':
        return 'contacts';
      default:
        return 'contacts';
    }
  }

  String _guessMimeType(String? fileName) {
    final name = fileName?.toLowerCase() ?? '';

    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) {
      return 'image/jpeg';
    }

    if (name.endsWith('.webp')) {
      return 'image/webp';
    }

    return 'image/png';
  }

  // =====================================================
  // BOTTOM SHEET DE ADJUNTOS
  // =====================================================
  void _showUploadOptions(BuildContext context) {
    if (isPublishing) return;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: ResponsiveHelper.sheetPadding(context),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(25),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  'Adjuntar a tu publicación',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),

                const SizedBox(height: 20),

                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 24,
                  runSpacing: 18,
                  children: [
                    _uploadItem(
                      icon: Icons.image_outlined,
                      label: 'Imagen',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pop(context);

                        _pickMedia(
                          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
                          type: 'image',
                        );
                      },
                    ),

                    _uploadItem(
                      icon: Icons.videocam_outlined,
                      label: 'Video',
                      color: Colors.orange,
                      onTap: () {
                        Navigator.pop(context);

                        _pickMedia(
                          allowedExtensions: ['mp4', 'mov', 'avi', 'mkv'],
                          type: 'video',
                        );
                      },
                    ),

                    _uploadItem(
                      icon: Icons.picture_as_pdf_outlined,
                      label: 'PDF',
                      color: Colors.red,
                      onTap: () {
                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Subida de PDF próximamente'),
                            duration: Duration(milliseconds: 1200),
                          ),
                        );
                      },
                    ),

                    _uploadItem(
                      icon: Icons.link_rounded,
                      label: 'Link',
                      color: Colors.purple,
                      onTap: () {
                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Agregar links próximamente'),
                            duration: Duration(milliseconds: 1200),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _uploadItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color.withValues(alpha: 0.14),
              child: Icon(icon, color: color, size: 30),
            ),

            const SizedBox(height: 8),

            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // PRIVACIDAD
  // =====================================================
  void _showPrivacyOptions(BuildContext context) {
    if (isPublishing) return;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: ResponsiveHelper.sheetPadding(context),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: Text(
                    '¿Quién puede ver esto?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ),

                _privacyTile(
                  icon: Icons.people,
                  title: 'solo tus contactos',
                  value: 'solo tus contactos',
                ),

                _privacyTile(
                  icon: Icons.business_center,
                  title: 'empresas y contactos',
                  value: 'empresas y contactos',
                ),

                _privacyTile(
                  icon: Icons.public,
                  title: 'todo el mundo',
                  value: 'todo el mundo',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _privacyTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Icon(
        icon,
        color:
            value == _currentPrivacy
                ? const Color(0xFF22C55E)
                : isDarkMode
                ? Colors.white70
                : Colors.black54,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black87,
          fontWeight:
              value == _currentPrivacy ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing:
          value == _currentPrivacy
              ? const Icon(Icons.check, color: Color(0xFF22C55E))
              : null,
      onTap: () => _updatePrivacy(value),
    );
  }

  void _updatePrivacy(String value) {
    setState(() {
      _currentPrivacy = value;
    });

    Navigator.pop(context);
  }

  // =====================================================
  // PREVIEW DE ADJUNTO
  // =====================================================
  Widget _buildMediaPreview(bool isDarkMode) {
    if (_selectedMediaType == null) {
      return const SizedBox.shrink();
    }

    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor =
        isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;

    if (_selectedMediaType == 'image' && _selectedImageBytes != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.memory(
                _selectedImageBytes!,
                width: double.infinity,
                height: 260,
                fit: BoxFit.cover,
              ),
            ),

            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.65),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _removeSelectedMedia,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final icon =
        _selectedMediaType == 'video'
            ? Icons.play_circle_outline_rounded
            : Icons.attach_file_rounded;

    final label =
        _selectedMediaType == 'video'
            ? 'Video seleccionado'
            : 'Archivo seleccionado';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
              child: Icon(icon, color: const Color(0xFF2563EB)),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    _selectedMediaName ?? 'Archivo multimedia',
                    style: TextStyle(color: subtitleColor, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            IconButton(
              onPressed: _removeSelectedMedia,
              icon: const Icon(Icons.close, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // BUILD
  // =====================================================
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = isDarkMode ? const Color(0xFF121212) : Colors.white;

    final textColor = isDarkMode ? Colors.white : Colors.black87;

    final hintColor = isDarkMode ? Colors.grey[500] : Colors.grey[400];

    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: true,

      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        elevation: 0,
        automaticallyImplyLeading: false,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: isPublishing ? null : widget.onBackToFeed,
        ),

        title: Row(
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white24,
              child: Icon(Icons.person, color: Colors.white, size: 18),
            ),

            const SizedBox(width: 10),

            Flexible(
              child: GestureDetector(
                onTap: () => _showPrivacyOptions(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _currentPrivacy,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            tooltip: 'Adjuntar archivo',
            icon: const Icon(
              Icons.attach_file_rounded,
              color: Color(0xFF22C55E),
              size: 28,
            ),
            onPressed: isPublishing ? null : () => _showUploadOptions(context),
          ),

          const SizedBox(width: 5),
        ],
      ),

      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(
            bottom: ResponsiveHelper.appBottomNavSpace(context),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: TextField(
                  controller: _contentController,
                  enabled: !isPublishing,
                  maxLines: null,
                  minLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(fontSize: 18, color: textColor),
                  cursorColor: const Color(0xFF22C55E),
                  decoration: InputDecoration(
                    hintText: '¿Qué quieres compartir?',
                    hintStyle: TextStyle(color: hintColor),
                    border: InputBorder.none,
                  ),
                ),
              ),

              _buildMediaPreview(isDarkMode),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed:
                        (_canPublish && !isPublishing) ? _publishPost : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _canPublish
                              ? const Color(0xFF22C55E)
                              : Colors.grey[600],
                      disabledBackgroundColor:
                          isDarkMode ? Colors.grey[800] : Colors.grey[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 0,
                    ),
                    child:
                        isPublishing
                            ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                            : Text(
                              'Publicar',
                              style: TextStyle(
                                color:
                                    _canPublish
                                        ? Colors.white
                                        : Colors.grey.shade500,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
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
