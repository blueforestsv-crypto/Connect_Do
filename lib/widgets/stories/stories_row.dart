import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/screens/stories/new_story_screen.dart';
import 'package:connect_do/screens/stories/story_viewer_screen.dart';
import 'package:connect_do/services/story_service.dart';
import 'package:connect_do/services/user_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/feed/user_avatar.dart';

/// Fila de historias arriba de la lista de chats.
class StoriesRow extends StatefulWidget {
  const StoriesRow({super.key});

  @override
  State<StoriesRow> createState() => StoriesRowState();
}

class StoriesRowState extends State<StoriesRow> {
  List<StoryGroup> _groups = [];
  String _myName = 'Tú';
  String _myPhoto = '';

  @override
  void initState() {
    super.initState();
    _loadMe();
    reload();
  }

  Future<void> _loadMe() async {
    final user = await UserService.getUser();
    if (!mounted) return;
    final name =
        '${user['firstName'] ?? user['first_name'] ?? ''} '
                '${user['lastName'] ?? user['last_name'] ?? ''}'
            .trim();
    setState(() {
      _myName = name.isEmpty ? 'Tú' : name;
      _myPhoto =
          user['profile_image_base64']?.toString() ??
          user['google_photo_url']?.toString() ??
          '';
    });
  }

  Future<void> reload() async {
    try {
      final groups = await StoryService.getStories();
      if (mounted) setState(() => _groups = groups);
    } catch (_) {
      // Sin red: se queda lo que había.
    }
  }

  StoryGroup? get _mine {
    for (final group in _groups) {
      if (group.isMe) return group;
    }
    return null;
  }

  List<StoryGroup> get _others => _groups.where((g) => !g.isMe).toList();

  Future<void> _create() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NewStoryScreen()),
    );
    if (created == true) reload();
  }

  Future<void> _open(List<StoryGroup> groups, int index) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder:
            (_, __, ___) =>
                StoryViewerScreen(groups: groups, initialGroup: index),
        transitionsBuilder:
            (_, animation, __, child) => ScaleTransition(
              scale: Tween(begin: 0.92, end: 1.0).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
      ),
    );
    // Se recarga para actualizar los anillos (vistas) y borradas.
    if (mounted) {
      setState(() {});
      reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = _mine;
    final others = _others;

    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _StoryBubble(
            name: 'Tu historia',
            photo: _myPhoto,
            avatarName: _myName,
            ring: mine == null ? _Ring.none : _Ring.seen,
            showAdd: true,
            onTap: mine == null ? _create : () => _open([mine], 0),
            onAdd: _create,
          ),
          for (var i = 0; i < others.length; i++)
            _StoryBubble(
              name: others[i].user.name.split(' ').first,
              photo: others[i].user.photo,
              avatarName: others[i].user.name,
              ring: others[i].hasUnseen ? _Ring.unseen : _Ring.seen,
              onTap: () => _open(others, i),
            ),
        ],
      ),
    );
  }
}

enum _Ring { none, seen, unseen }

class _StoryBubble extends StatelessWidget {
  final String name;
  final String photo;
  final String avatarName;
  final _Ring ring;
  final bool showAdd;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  const _StoryBubble({
    required this.name,
    required this.photo,
    required this.avatarName,
    required this.ring,
    required this.onTap,
    this.showAdd = false,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    final Decoration ringDecoration = switch (ring) {
      _Ring.unseen => const BoxDecoration(
        shape: BoxShape.circle,
        gradient: Brand.gradient,
      ),
      _Ring.seen => BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: palette.fieldBorder, width: 2),
      ),
      _Ring.none => const BoxDecoration(shape: BoxShape.circle),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 68,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 66,
                    height: 66,
                    padding: const EdgeInsets.all(3),
                    decoration: ringDecoration,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: palette.background,
                        shape: BoxShape.circle,
                      ),
                      child: UserAvatar(
                        name: avatarName,
                        photo: photo,
                        radius: 27,
                      ),
                    ),
                  ),
                  if (showAdd)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: GestureDetector(
                        onTap: onAdd,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Brand.blue,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: palette.background,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            PhosphorIconsBold.plus,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: Brand.displayFont,
                  fontSize: 12,
                  fontWeight:
                      ring == _Ring.unseen ? FontWeight.w700 : FontWeight.w500,
                  color: palette.label,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
