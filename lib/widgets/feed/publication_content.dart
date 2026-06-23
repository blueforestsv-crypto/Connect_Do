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
        _TypeBadge(label: post.typeLabel, isDarkMode: isDarkMode),

        if (_hasTitle) ...[
          const SizedBox(height: 10),
          Text(
            post.title,
            style: TextStyle(
              fontSize: 17,
              height: 1.25,
              fontWeight: FontWeight.w700,
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

        if (_hasLocation || _hasModality) ...[
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
