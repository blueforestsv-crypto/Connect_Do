import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:connect_do/models/publication_model.dart';
import 'package:connect_do/widgets/feed/publication_actions.dart';
import 'package:connect_do/widgets/feed/publication_content.dart';
import 'package:connect_do/widgets/feed/publication_header.dart';

class PublicationCard extends StatelessWidget {
  final PublicationModel post;
  final VoidCallback? onDelete;
  final VoidCallback? onSavedChanged;

  const PublicationCard({
    super.key,
    required this.post,
    this.onDelete,
    this.onSavedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PublicationHeader(post: post, onDelete: onDelete),

            const SizedBox(height: 16),

            PublicationContent(post: post),

            if (post.hasMedia) ...[
              const SizedBox(height: 14),
              _PublicationMediaPreview(post: post),
            ],

            const SizedBox(height: 18),

            PublicationActions(post: post, onSavedChanged: onSavedChanged),
          ],
        ),
      ),
    );
  }
}

class _PublicationMediaPreview extends StatelessWidget {
  final PublicationModel post;

  const _PublicationMediaPreview({required this.post});

  @override
  Widget build(BuildContext context) {
    final PublicationMediaItem? media = post.firstMedia;

    if (media == null) {
      return const SizedBox.shrink();
    }

    if (media.isImage) {
      final Uint8List? imageBytes = _decodeBase64(media.base64);

      if (imageBytes == null) {
        return _buildBrokenMedia(context, 'No se pudo cargar la imagen.');
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.memory(
          imageBytes,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildBrokenMedia(context, 'No se pudo mostrar la imagen.');
          },
        ),
      );
    }

    if (media.isVideo) {
      return _buildVideoPlaceholder(context, media);
    }

    return _buildBrokenMedia(context, 'Archivo multimedia no compatible.');
  }

  Widget _buildVideoPlaceholder(
    BuildContext context,
    PublicationMediaItem media,
  ) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFF2563EB),
            child: Icon(Icons.play_arrow_rounded, color: Colors.white),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              media.fileName ?? 'Video adjunto',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrokenMedia(BuildContext context, String message) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.broken_image_outlined, color: Colors.red),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Uint8List? _decodeBase64(String value) {
    try {
      String cleanBase64 = value.trim();

      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }

      if (cleanBase64.isEmpty) {
        return null;
      }

      return base64Decode(cleanBase64);
    } catch (_) {
      return null;
    }
  }
}
