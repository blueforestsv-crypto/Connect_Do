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
  String _currentPrivacy = "solo tus contactos";

  final TextEditingController _contentController = TextEditingController();

  bool isPublishing = false;
  bool hasContent = false;

  String? _selectedImagePath;
  String? _selectedFilePath;
  String? _selectedFileName;
  String? _selectedFileType;

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
        _selectedImagePath != null ||
        _selectedFilePath != null;
  }

  // =====================================================
  // SELECCIONAR ARCHIVO
  // =====================================================
  Future<void> _pickFile({
    required List<String> allowedExtensions,
    required String type,
  }) async {
    if (isPublishing) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;

      if (file.path == null) return;

      if (!mounted) return;

      setState(() {
        if (type == 'image') {
          _selectedImagePath = file.path;
          _selectedFilePath = null;
          _selectedFileName = null;
          _selectedFileType = null;
        } else {
          _selectedImagePath = null;
          _selectedFilePath = file.path;
          _selectedFileName = file.name;
          _selectedFileType = type;
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

  void _removeSelectedAttachment() {
    setState(() {
      _selectedImagePath = null;
      _selectedFilePath = null;
      _selectedFileName = null;
      _selectedFileType = null;
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
      final description = _contentController.text.trim();

      if (description.isEmpty) {
        throw Exception('Escribe el contenido de la publicación.');
      }

      final title = _buildTitleFromDescription(description);

      await PublicationService.createPublicationOnBackend(
        title: title,
        description: description,
        type: 'general',
        location: null,
        modality: null,
        imageUrl: null,
      );

      if (!mounted) return;

      _contentController.clear();

      setState(() {
        _selectedImagePath = null;
        _selectedFilePath = null;
        _selectedFileName = null;
        _selectedFileType = null;
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

  // =====================================================
  // BOTTOM SHEET DE ARCHIVOS
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
                  "Agregar a tu publicación",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _uploadItem(
                      icon: Icons.image,
                      label: "Imagen",
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pop(context);

                        _pickFile(
                          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
                          type: 'image',
                        );
                      },
                    ),
                    _uploadItem(
                      icon: Icons.videocam,
                      label: "Video",
                      color: Colors.orange,
                      onTap: () {
                        Navigator.pop(context);

                        _pickFile(
                          allowedExtensions: ['mp4', 'mov', 'avi', 'mkv'],
                          type: 'video',
                        );
                      },
                    ),
                    _uploadItem(
                      icon: Icons.insert_drive_file,
                      label: "Documento",
                      color: Colors.red,
                      onTap: () {
                        Navigator.pop(context);

                        _pickFile(
                          allowedExtensions: [
                            'pdf',
                            'doc',
                            'docx',
                            'ppt',
                            'pptx',
                            'xls',
                            'xlsx',
                            'txt',
                          ],
                          type: 'document',
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
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: color.withValues(alpha: 0.14),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ],
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
                    "¿Quién puede ver esto?",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                _privacyTile(
                  icon: Icons.people,
                  title: "solo tus contactos",
                  value: "solo tus contactos",
                ),
                _privacyTile(
                  icon: Icons.business_center,
                  title: "empresas y contactos",
                  value: "empresas y contactos",
                ),
                _privacyTile(
                  icon: Icons.public,
                  title: "todo el mundo",
                  value: "todo el mundo",
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
  // PREVIEW DE ARCHIVO
  // =====================================================
  Widget _buildAttachmentPreview(bool isDarkMode) {
    if (_selectedImagePath != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                _selectedImagePath!,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color:
                          isDarkMode
                              ? const Color(0xFF1E1E1E)
                              : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      'Imagen seleccionada: $_selectedImagePath',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.65),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _removeSelectedAttachment,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_selectedFilePath != null) {
      final Color cardColor =
          isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade100;

      final Color textColor = isDarkMode ? Colors.white : Colors.black87;

      IconData icon;

      if (_selectedFileType == 'video') {
        icon = Icons.videocam;
      } else {
        icon = Icons.insert_drive_file;
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(
                  0xFF2563EB,
                ).withValues(alpha: 0.15),
                child: Icon(icon, color: const Color(0xFF2563EB)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedFileName ?? 'Archivo seleccionado',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedFileType == 'video'
                          ? 'Video adjunto'
                          : 'Documento adjunto',
                      style: TextStyle(
                        color:
                            isDarkMode
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _removeSelectedAttachment,
                icon: const Icon(Icons.close, color: Colors.red),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
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
            icon: const Icon(Icons.add, color: Color(0xFF22C55E), size: 30),
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
                padding: const EdgeInsets.all(20),
                child: TextField(
                  controller: _contentController,
                  enabled: !isPublishing,
                  maxLines: null,
                  minLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(fontSize: 18, color: textColor),
                  cursorColor: const Color(0xFF22C55E),
                  decoration: InputDecoration(
                    hintText: "Comparte con tu red",
                    hintStyle: TextStyle(color: hintColor),
                    border: InputBorder.none,
                  ),
                ),
              ),
              _buildAttachmentPreview(isDarkMode),
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
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                            : Text(
                              "Publicar",
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
