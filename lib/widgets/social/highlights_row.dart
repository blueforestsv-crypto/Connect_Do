import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/screens/stories/story_viewer_screen.dart';
import 'package:connect_do/services/social_service.dart';
import 'package:connect_do/services/story_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/utils/cloudinary_url.dart';

/// Historias destacadas en el perfil (círculos con título).
class HighlightsRow extends StatefulWidget {
  final String userId;
  final String userName;
  final String userPhoto;
  final bool isMe;

  const HighlightsRow({
    super.key,
    required this.userId,
    required this.userName,
    required this.userPhoto,
    this.isMe = false,
  });

  @override
  State<HighlightsRow> createState() => HighlightsRowState();
}

class HighlightsRowState extends State<HighlightsRow> {
  List<Highlight> _highlights = [];

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final list = await SocialService.highlights(widget.userId);
      if (mounted) setState(() => _highlights = list);
    } catch (_) {}
  }

  void _open(Highlight highlight) {
    final group = StoryGroup(
      user: StoryUser(
        id: widget.userId,
        name: highlight.title,
        photo: widget.userPhoto,
      ),
      // Las destacadas no cuentan vistas ni se responden.
      isMe: true,
      isHighlight: true,
      stories: highlight.items,
    );
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => StoryViewerScreen(groups: [group]),
      ),
    );
  }

  Future<void> _delete(Highlight highlight) async {
    if (!widget.isMe) return;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text('¿Quitar «${highlight.title}»?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text(
                  'Quitar',
                  style: TextStyle(color: Brand.danger),
                ),
              ),
            ],
          ),
    );
    if (ok != true) return;
    try {
      await SocialService.deleteHighlight(highlight.id);
      if (mounted) setState(() => _highlights.remove(highlight));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_highlights.isEmpty) return const SizedBox.shrink();
    final palette = AuthPalette.of(context);

    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        children: [
          for (final highlight in _highlights)
            GestureDetector(
              onTap: () => _open(highlight),
              onLongPress: () => _delete(highlight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: SizedBox(
                  width: 68,
                  child: Column(
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: palette.fieldBorder,
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child:
                              highlight.coverUrl == null
                                  ? Container(
                                    color: palette.fieldFill,
                                    child: const Icon(
                                      PhosphorIconsRegular.star,
                                      color: Brand.blue,
                                    ),
                                  )
                                  : Image(
                                    image: CachedNetworkImageProvider(
                                      highlight.coverUrl!.contains('/video/')
                                          ? CloudinaryUrl.videoPoster(
                                            highlight.coverUrl!,
                                            width: 200,
                                          )
                                          : CloudinaryUrl.square(
                                            highlight.coverUrl!,
                                            size: 200,
                                          ),
                                    ),
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (_, __, ___) =>
                                            Container(color: palette.fieldFill),
                                  ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        highlight.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: Brand.displayFont,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: palette.label,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
