import 'package:flutter/material.dart';

import 'package:project_ena/models/publication_model.dart';
import 'package:project_ena/widgets/media/app_media_player.dart';

class PublicationContent extends StatelessWidget {
  final PublicationModel post;

  const PublicationContent({super.key, required this.post});

  bool get _hasDescription {
    return post.description.trim().isNotEmpty;
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

    final mediaPath = _mediaPath;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_hasDescription)
          Text(
            post.description,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),

        if (_hasDescription && mediaPath != null) const SizedBox(height: 16),

        if (mediaPath != null)
          AppMediaPlayer(
            filePath: mediaPath,
            fileName: _mediaName,
            mediaType: _mediaType,
            isDarkMode: isDarkMode,
          ),
      ],
    );
  }
}
