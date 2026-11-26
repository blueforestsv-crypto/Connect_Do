import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/services/safety_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/common/brand_bits.dart';
import 'package:connect_do/widgets/feed/user_avatar.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<BlockedUser>? _users;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final users = await SafetyService.blocked();
      if (mounted) {
        setState(() {
          _users = users;
          _hasError = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  Future<void> _unblock(BlockedUser user) async {
    try {
      await SafetyService.unblock(user.id);
      if (!mounted) return;
      setState(() => _users!.remove(user));
      showAuthMessage(
        context,
        '${user.name} fue desbloqueado',
        type: AuthMessageType.success,
      );
    } catch (error) {
      if (mounted) {
        showAuthMessage(
          context,
          error.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final users = _users;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: brandAppBar(context, 'Personas bloqueadas'),
      body:
          users == null && !_hasError
              ? const Center(
                child: CircularProgressIndicator(color: Brand.blue),
              )
              : RefreshIndicator(
                color: Brand.blue,
                onRefresh: _load,
                child:
                    users == null || users.isEmpty
                        ? EmptyState(
                          icon:
                              _hasError
                                  ? PhosphorIconsRegular.cloudSlash
                                  : PhosphorIconsRegular.prohibit,
                          title:
                              _hasError
                                  ? 'No se pudo cargar'
                                  : 'No has bloqueado a nadie',
                          subtitle:
                              _hasError
                                  ? 'Desliza hacia abajo para reintentar.'
                                  : 'Puedes bloquear a alguien desde su '
                                      'perfil, su chat o sus publicaciones.',
                        )
                        : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: users.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final user = users[i];
                            return BrandCard(
                              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                              child: Row(
                                children: [
                                  UserAvatar(
                                    name: user.name,
                                    photo: user.photo,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      user.name,
                                      style: TextStyle(
                                        fontFamily: Brand.displayFont,
                                        fontWeight: FontWeight.w700,
                                        color: palette.title,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => _unblock(user),
                                    child: const Text('Desbloquear'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
              ),
    );
  }
}
