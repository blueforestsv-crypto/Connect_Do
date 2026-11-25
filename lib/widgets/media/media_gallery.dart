import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/models/publication_model.dart';
import 'package:connect_do/screens/media/media_viewer_screen.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/utils/cloudinary_url.dart';

/// Fotos y videos de una publicación: uno solo a todo el ancho, o varios
/// que se deslizan. Al tocar se abren a pantalla completa.
class MediaGallery extends StatefulWidget {
  final List<PublicationMediaItem> items;
  final double radius;

  const MediaGallery({super.key, required this.items, this.radius = 16});

  @override
  State<MediaGallery> createState() => _MediaGalleryState();
}

class _MediaGalleryState extends State<MediaGallery> {
  int _page = 0;

  double get _aspect {
    // Se usa la proporción de la primera foto, limitada para que una foto
    // muy alta no ocupe toda la pantalla.
    final ratio = widget.items.first.aspectRatio ?? (4 / 3);
    return ratio.clamp(0.8, 1.9);
  }

  void _open(int index) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder:
            (_, __, ___) =>
                MediaViewerScreen(items: widget.items, initialIndex: index),
        transitionsBuilder:
            (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: AspectRatio(
        aspectRatio: _aspect,
        child: Stack(
          children: [
            PageView.builder(
              itemCount: items.length,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder:
                  (_, index) => GestureDetector(
                    onTap: () => _open(index),
                    child: MediaThumbnail(item: items[index]),
                  ),
            ),
            if (items.length > 1) ...[
              Positioned(
                top: 10,
                right: 10,
                child: _Badge(text: '${_page + 1}/${items.length}'),
              ),
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < items.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _page ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: i == _page ? 1 : 0.6,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Una foto, o la portada de un video con su botón de reproducir.
class MediaThumbnail extends StatelessWidget {
  final PublicationMediaItem item;
  final BoxFit fit;
  final int width;

  const MediaThumbnail({
    super.key,
    required this.item,
    this.fit = BoxFit.cover,
    this.width = 900,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    final Widget image;
    if (item.hasUrl) {
      image = Image(
        image: CachedNetworkImageProvider(
          item.isVideo
              ? CloudinaryUrl.videoPoster(item.url, width: width)
              : CloudinaryUrl.image(item.url, width: width),
        ),
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder:
            (_, child, progress) =>
                progress == null ? child : Container(color: palette.fieldFill),
        errorBuilder: (_, __, ___) => _broken(palette),
      );
    } else {
      final bytes = _decode(item.base64);
      image =
          bytes == null
              ? _broken(palette)
              : Image.memory(
                bytes,
                fit: fit,
                width: double.infinity,
                height: double.infinity,
                gaplessPlayback: true,
              );
    }

    if (!item.isVideo) return image;

    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        Center(
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white70, width: 1.5),
            ),
            child: const Icon(
              PhosphorIconsFill.play,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
        if (item.duration != null)
          Positioned(
            bottom: 10,
            right: 10,
            child: _Badge(text: formatDuration(item.duration!)),
          ),
      ],
    );
  }

  Widget _broken(AuthPalette palette) => Container(
    color: palette.fieldFill,
    alignment: Alignment.center,
    child: Icon(PhosphorIconsRegular.imageBroken, color: palette.muted),
  );

  static final Map<int, Uint8List?> _cache = {};

  static Uint8List? _decode(String value) {
    return _cache.putIfAbsent(value.hashCode, () {
      try {
        final clean = value.contains(',') ? value.split(',').last : value;
        return clean.trim().isEmpty ? null : base64Decode(clean.trim());
      } catch (_) {
        return null;
      }
    });
  }
}

String formatDuration(double seconds) {
  final total = seconds.round();
  final minutes = total ~/ 60;
  final rest = (total % 60).toString().padLeft(2, '0');
  return '$minutes:$rest';
}

class _Badge extends StatelessWidget {
  final String text;

  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: Brand.displayFont,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
