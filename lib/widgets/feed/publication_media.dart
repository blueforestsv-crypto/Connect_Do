import 'package:flutter/material.dart';

import 'package:connect_do/models/publication_model.dart';
import 'package:connect_do/widgets/media/app_media_player.dart';
import 'package:connect_do/widgets/media/media_gallery.dart';

class PublicationMedia extends StatelessWidget {
  final PublicationModel post;

  const PublicationMedia({super.key, required this.post});

  String? get _legacyMediaPath {
    final imagePath = post.imagePath;

    if (imagePath != null && imagePath.trim().isNotEmpty) {
      return imagePath;
    }

    final filePath = post.filePath;

    if (filePath != null && filePath.trim().isNotEmpty) {
      return filePath;
    }

    return null;
  }

  String get _legacyMediaType {
    final imagePath = post.imagePath;

    if (imagePath != null && imagePath.trim().isNotEmpty) {
      return 'image';
    }

    final type = post.fileType?.trim().toLowerCase();

    if (type == 'video') return 'video';
    if (type == 'audio') return 'audio';
    if (type == 'voice') return 'voice';
    if (type == 'document') return 'document';

    return 'document';
  }

  String? get _legacyMediaName {
    final imagePath = post.imagePath;

    if (imagePath != null && imagePath.trim().isNotEmpty) {
      return 'Imagen publicada';
    }

    return post.fileName;
  }

  @override
  Widget build(BuildContext context) {
    final items = post.mediaItems.where((m) => m.isImage || m.isVideo).toList();
    if (items.isNotEmpty) return MediaGallery(items: items);

    final String? legacyPath = _legacyMediaPath;

    if (legacyPath != null) {
      return AppMediaPlayer(
        filePath: legacyPath,
        fileName: _legacyMediaName,
        mediaType: _legacyMediaType,
        isDarkMode: Theme.of(context).brightness == Brightness.dark,
      );
    }

    return const SizedBox.shrink();
  }
}
