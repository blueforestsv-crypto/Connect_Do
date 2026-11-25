import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:video_player/video_player.dart';

import 'package:connect_do/models/publication_model.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/utils/cloudinary_url.dart';
import 'package:connect_do/widgets/media/media_gallery.dart';

/// Fotos y videos a pantalla completa: deslizar entre ellos, pellizcar para
/// hacer zoom en fotos y reproducir videos.
class MediaViewerScreen extends StatefulWidget {
  final List<PublicationMediaItem> items;
  final int initialIndex;

  const MediaViewerScreen({
    super.key,
    required this.items,
    this.initialIndex = 0,
  });

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _page = widget.initialIndex;
  bool _zoomed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              // Con zoom, el dedo mueve la foto en vez de cambiar de página.
              physics:
                  _zoomed
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
              itemCount: widget.items.length,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (_, index) {
                final item = widget.items[index];
                return item.isVideo && item.hasUrl
                    ? _VideoPage(url: item.url, active: index == _page)
                    : _ZoomableImage(
                      item: item,
                      onZoomChanged: (zoomed) {
                        if (zoomed != _zoomed) {
                          setState(() => _zoomed = zoomed);
                        }
                      },
                    );
              },
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        PhosphorIconsRegular.x,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const Spacer(),
                    if (widget.items.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(
                          '${_page + 1} de ${widget.items.length}',
                          style: const TextStyle(
                            fontFamily: Brand.displayFont,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomableImage extends StatefulWidget {
  final PublicationMediaItem item;
  final ValueChanged<bool> onZoomChanged;

  const _ZoomableImage({required this.item, required this.onZoomChanged});

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final TransformationController _transform = TransformationController();

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _toggleZoom(TapDownDetails details) {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed) {
      _transform.value = Matrix4.identity();
    } else {
      final p = details.localPosition;
      _transform.value =
          Matrix4.identity()
            ..translateByDouble(-p.dx * 1.5, -p.dy * 1.5, 0, 1)
            ..scaleByDouble(2.5, 2.5, 1, 1);
    }
    widget.onZoomChanged(!zoomed);
  }

  @override
  Widget build(BuildContext context) {
    TapDownDetails? lastTap;

    return GestureDetector(
      onDoubleTapDown: (details) => lastTap = details,
      onDoubleTap: () {
        if (lastTap != null) _toggleZoom(lastTap!);
      },
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: 1,
        maxScale: 5,
        onInteractionEnd:
            (_) => widget.onZoomChanged(
              _transform.value.getMaxScaleOnAxis() > 1.01,
            ),
        child: Center(
          child: MediaThumbnail(
            item: widget.item,
            fit: BoxFit.contain,
            width: 2000,
          ),
        ),
      ),
    );
  }
}

class _VideoPage extends StatefulWidget {
  final String url;
  final bool active;

  const _VideoPage({required this.url, required this.active});

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  late final VideoPlayerController _video = VideoPlayerController.networkUrl(
    Uri.parse(CloudinaryUrl.video(widget.url)),
  );
  bool _failed = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _video
        .initialize()
        .then((_) {
          if (!mounted) return;
          _video.setLooping(true);
          if (widget.active) _video.play();
          setState(() {});
        })
        .catchError((_) {
          if (mounted) setState(() => _failed = true);
        });
    _video.addListener(_onTick);
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant _VideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Al deslizar a otra foto, este video se pausa.
    if (!widget.active && _video.value.isPlaying) _video.pause();
  }

  @override
  void dispose() {
    _video.removeListener(_onTick);
    _video.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      _showControls = true;
      _video.value.isPlaying ? _video.pause() : _video.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(
        child: Text(
          'No se pudo reproducir el video.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final value = _video.value;
    if (!value.isInitialized) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            CloudinaryUrl.videoPoster(widget.url, width: 1200),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.5,
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _showControls = !_showControls),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: value.aspectRatio,
              child: VideoPlayer(_video),
            ),
          ),
          AnimatedOpacity(
            opacity: _showControls || !value.isPlaying ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: Stack(
              children: [
                Center(
                  child: IconButton(
                    iconSize: 64,
                    onPressed: _togglePlay,
                    icon: Icon(
                      value.isPlaying
                          ? PhosphorIconsFill.pauseCircle
                          : PhosphorIconsFill.playCircle,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 24 + MediaQuery.of(context).padding.bottom,
                  child: Row(
                    children: [
                      Text(
                        formatDuration(value.position.inMilliseconds / 1000),
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: VideoProgressIndicator(
                          _video,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(
                            playedColor: Brand.blue,
                            bufferedColor: Colors.white38,
                            backgroundColor: Colors.white12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        formatDuration(value.duration.inMilliseconds / 1000),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
