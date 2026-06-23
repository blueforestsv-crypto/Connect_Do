import 'package:flutter/material.dart';

import 'package:connect_do/models/publication_model.dart';
import 'package:connect_do/widgets/media/app_media_player.dart';

class PublicationContent extends StatelessWidget {
  final PublicationModel post;

  const PublicationContent({super.key, required this.post});

  bool get _hasTitle {
    return post.title.trim().isNotEmpty;
  }

  bool get _hasDescription {
    return post.description.trim().isNotEmpty;
  }

  bool get _hasLocation {
    return post.location != null && post.location!.trim().isNotEmpty;
  }

  bool get _hasModality {
    return post.modalityLabel.trim().isNotEmpty;
  }

  bool get _hasImage {
    return post.imagePath != null && post.imagePath!.isNotEmpty;
  }

  bool get _hasFile {
    return post.filePath != null && post.filePath!.isNotEmpty;
  }

  bool get _isOpportunity {
    return post.type == 'internship' ||
        post.type == 'job' ||
        post.type == 'social_service' ||
        post.type == 'freelance' ||
        post.type == 'announcement';
  }

  String get _mediaType {
    if (_hasImage) return 'image';

    final type = post.fileType?.trim().toLowerCase();

    if (type == 'video') return 'video';
    if (type == 'audio') return 'audio';
    if (type == 'voice') return 'voice';
    if (type == 'document') return 'document';

    return 'document';
  }

  String? get _mediaPath {
    if (_hasImage) return post.imagePath;
    if (_hasFile) return post.filePath;

    return null;
  }

  String? get _mediaName {
    if (_hasImage) return 'Imagen publicada';

    return post.fileName;
  }

  // =====================================================
  // MODAL DEMO PARA APLICAR A OPORTUNIDAD
  // =====================================================
  void _showApplyModal(BuildContext context) {
    final messageController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;

        final bgColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
        final textColor = isDarkMode ? Colors.white : Colors.black87;
        final subtitleColor =
            isDarkMode ? Colors.white70 : Colors.grey.shade700;

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(26),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color:
                            isDarkMode ? Colors.white24 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFFEFF6FF),
                        child: Icon(
                          Icons.send_rounded,
                          color: Color(0xFF2563EB),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Aplicar a oportunidad',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 3),

                            Text(
                              post.typeLabel,
                              style: const TextStyle(
                                color: Color(0xFF22C55E),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:
                          isDarkMode
                              ? Colors.white.withValues(alpha: 0.06)
                              : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            isDarkMode
                                ? Colors.white10
                                : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.title.isNotEmpty
                              ? post.title
                              : 'Oportunidad disponible',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          post.userName,
                          style: TextStyle(color: subtitleColor, fontSize: 13),
                        ),

                        if (_hasLocation || _hasModality) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (_hasLocation)
                                _InfoChip(
                                  icon: Icons.location_on_outlined,
                                  label: post.location!,
                                  isDarkMode: isDarkMode,
                                ),
                              if (_hasModality)
                                _InfoChip(
                                  icon: Icons.work_outline_rounded,
                                  label: post.modalityLabel,
                                  isDarkMode: isDarkMode,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Mensaje breve',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextField(
                    controller: messageController,
                    maxLines: 4,
                    maxLength: 280,
                    style: TextStyle(color: textColor),
                    cursorColor: const Color(0xFF22C55E),
                    decoration: InputDecoration(
                      hintText:
                          'Escribe por qué te interesa esta oportunidad...',
                      hintStyle: TextStyle(
                        color: isDarkMode ? Colors.white38 : Colors.grey,
                      ),
                      counterStyle: TextStyle(
                        color: isDarkMode ? Colors.white38 : Colors.grey,
                      ),
                      filled: true,
                      fillColor:
                          isDarkMode
                              ? Colors.white.withValues(alpha: 0.06)
                              : const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color:
                              isDarkMode
                                  ? Colors.white10
                                  : const Color(0xFFE5E7EB),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color:
                              isDarkMode
                                  ? Colors.white10
                                  : const Color(0xFFE5E7EB),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Color(0xFF22C55E),
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Aplicación enviada correctamente'),
                            backgroundColor: Color(0xFF22C55E),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text(
                        'Enviar aplicación',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Center(
                    child: Text(
                      'Versión demo: la aplicación aún no se guarda en backend.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: subtitleColor, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor =
        isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700;

    final mediaPath = _mediaPath;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isOpportunity)
          _TypeBadge(label: post.typeLabel, isDarkMode: isDarkMode),

        if (_hasTitle) ...[
          if (_isOpportunity) const SizedBox(height: 10),
          Text(
            post.title,
            style: TextStyle(
              fontSize: _isOpportunity ? 17 : 16,
              height: 1.25,
              fontWeight: _isOpportunity ? FontWeight.w700 : FontWeight.w600,
              color: textColor,
            ),
          ),
        ],

        if (_hasDescription) ...[
          const SizedBox(height: 8),
          Text(
            post.description,
            style: TextStyle(fontSize: 15, height: 1.5, color: textColor),
          ),
        ],

        if (_isOpportunity && (_hasLocation || _hasModality)) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_hasLocation)
                _InfoChip(
                  icon: Icons.location_on_outlined,
                  label: post.location!,
                  isDarkMode: isDarkMode,
                ),
              if (_hasModality)
                _InfoChip(
                  icon: Icons.work_outline_rounded,
                  label: post.modalityLabel,
                  isDarkMode: isDarkMode,
                ),
            ],
          ),
        ],

        if (_isOpportunity) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showApplyModal(context),
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Aplicar aquí'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],

        if ((_hasTitle || _hasDescription || _hasLocation || _hasModality) &&
            mediaPath != null)
          const SizedBox(height: 16),

        if (mediaPath != null)
          AppMediaPlayer(
            filePath: mediaPath,
            fileName: _mediaName,
            mediaType: _mediaType,
            isDarkMode: isDarkMode,
          ),

        if (!_hasTitle &&
            !_hasDescription &&
            !_hasLocation &&
            !_hasModality &&
            mediaPath == null)
          Text(
            'Publicación sin contenido disponible.',
            style: TextStyle(fontSize: 14, color: subtitleColor),
          ),
      ],
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String label;
  final bool isDarkMode;

  const _TypeBadge({required this.label, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:
            isDarkMode
                ? const Color(0xFF1E3A8A).withAlpha(80)
                : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF2563EB),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDarkMode;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF2563EB)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color:
                  isDarkMode ? Colors.grey.shade200 : const Color(0xFF374151),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
