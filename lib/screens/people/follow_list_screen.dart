import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/services/social_service.dart';
import 'package:connect_do/services/user_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/common/brand_bits.dart';
import 'package:connect_do/widgets/social/person_tile.dart';

/// Seguidores o seguidos de una persona.
class FollowListScreen extends StatefulWidget {
  final String userId;
  final bool followers;

  const FollowListScreen({
    super.key,
    required this.userId,
    required this.followers,
  });

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  List<PersonCard>? _people;
  String? _error;
  String _myId = '';

  @override
  void initState() {
    super.initState();
    UserService.getUser().then((u) {
      if (mounted) setState(() => _myId = u['id']?.toString() ?? '');
    });
    _load();
  }

  Future<void> _load() async {
    try {
      final people = await SocialService.followList(
        widget.userId,
        followers: widget.followers,
      );
      if (mounted) setState(() => _people = people);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final people = _people;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: brandAppBar(
        context,
        widget.followers ? 'Seguidores' : 'Siguiendo',
      ),
      body:
          people == null && _error == null
              ? const Center(
                child: CircularProgressIndicator(color: Brand.blue),
              )
              : RefreshIndicator(
                color: Brand.blue,
                onRefresh: _load,
                child:
                    people == null || people.isEmpty
                        ? EmptyState(
                          icon: PhosphorIconsRegular.usersThree,
                          title: _error != null ? 'No disponible' : 'Nadie aún',
                          subtitle:
                              _error ??
                              (widget.followers
                                  ? 'Todavía no tiene seguidores.'
                                  : 'Todavía no sigue a nadie.'),
                        )
                        : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: people.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 10),
                          itemBuilder:
                              (_, i) =>
                                  PersonTile(person: people[i], myId: _myId),
                        ),
              ),
    );
  }
}
