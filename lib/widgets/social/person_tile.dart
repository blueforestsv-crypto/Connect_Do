import 'package:flutter/material.dart';

import 'package:connect_do/screens/people/user_profile_screen.dart';
import 'package:connect_do/services/social_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/common/brand_bits.dart';
import 'package:connect_do/widgets/common/verified_badge.dart';
import 'package:connect_do/widgets/feed/user_avatar.dart';

/// Persona con botón Seguir / Siguiendo.
class PersonTile extends StatefulWidget {
  final PersonCard person;
  final String? myId;

  const PersonTile({super.key, required this.person, this.myId});

  @override
  State<PersonTile> createState() => _PersonTileState();
}

class _PersonTileState extends State<PersonTile> {
  bool _busy = false;

  Future<void> _toggle() async {
    final person = widget.person;
    final follow = !person.isFollowing;
    setState(() {
      _busy = true;
      person.isFollowing = follow;
    });
    try {
      await SocialService.setFollowing(person.id, follow: follow);
    } catch (_) {
      if (mounted) setState(() => person.isFollowing = !follow);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final person = widget.person;
    final subtitle = person.reason ?? person.subtitle;

    return BrandCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfileScreen(userId: person.id),
            ),
          ),
      child: Row(
        children: [
          UserAvatar(name: person.name, photo: person.photo),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        person.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: Brand.displayFont,
                          fontWeight: FontWeight.w700,
                          color: palette.title,
                        ),
                      ),
                    ),
                    if (person.isCompany) ...[
                      const SizedBox(width: 4),
                      VerifiedBadge(verified: person.verified, size: 14),
                    ],
                  ],
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 12.5,
                      color: palette.muted,
                    ),
                  ),
              ],
            ),
          ),
          if (person.id != widget.myId)
            SizedBox(
              height: 34,
              child:
                  person.isFollowing
                      ? OutlinedButton(
                        onPressed: _busy ? null : _toggle,
                        child: const Text('Siguiendo'),
                      )
                      : FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Brand.blue,
                        ),
                        onPressed: _busy ? null : _toggle,
                        child: const Text('Seguir'),
                      ),
            ),
        ],
      ),
    );
  }
}
