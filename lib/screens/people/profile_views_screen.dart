import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/screens/people/user_profile_screen.dart';
import 'package:connect_do/services/professional_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/common/brand_bits.dart';
import 'package:connect_do/widgets/feed/user_avatar.dart';

/// Quién vio tu perfil en los últimos 30 días.
class ProfileViewsScreen extends StatefulWidget {
  const ProfileViewsScreen({super.key});

  @override
  State<ProfileViewsScreen> createState() => _ProfileViewsScreenState();
}

class _ProfileViewsScreenState extends State<ProfileViewsScreen> {
  int? _total;
  List<ProfileVisitor> _visitors = [];
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ProfessionalService.myViews();
      if (!mounted) return;
      setState(() {
        _total = data.total;
        _visitors = data.visitors;
        _error = false;
      });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: brandAppBar(context, 'Quién vio tu perfil'),
      body:
          _total == null && !_error
              ? const Center(
                child: CircularProgressIndicator(color: Brand.blue),
              )
              : RefreshIndicator(
                color: Brand.blue,
                onRefresh: _load,
                child:
                    _visitors.isEmpty
                        ? EmptyState(
                          icon:
                              _error
                                  ? PhosphorIconsRegular.cloudSlash
                                  : PhosphorIconsRegular.eye,
                          title:
                              _error ? 'No se pudo cargar' : 'Aún sin visitas',
                          subtitle:
                              _error
                                  ? 'Desliza hacia abajo para reintentar.'
                                  : 'Completa tu perfil y comparte '
                                      'publicaciones para que te encuentren.',
                        )
                        : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            BrandCard(
                              child: Row(
                                children: [
                                  const Icon(
                                    PhosphorIconsFill.eye,
                                    color: Brand.blue,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '$_total visitas en 30 días',
                                    style: TextStyle(
                                      fontFamily: Brand.displayFont,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: palette.title,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            for (final visitor in _visitors)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: BrandCard(
                                  padding: const EdgeInsets.all(12),
                                  onTap:
                                      () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (_) => UserProfileScreen(
                                                userId: visitor.userId,
                                              ),
                                        ),
                                      ),
                                  child: Row(
                                    children: [
                                      UserAvatar(
                                        name: visitor.name,
                                        photo: visitor.photo,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              visitor.name,
                                              style: TextStyle(
                                                fontFamily: Brand.displayFont,
                                                fontWeight: FontWeight.w700,
                                                color: palette.title,
                                              ),
                                            ),
                                            if ((visitor.headline ?? '')
                                                .isNotEmpty)
                                              Text(
                                                visitor.headline!,
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
                                      Text(
                                        timeAgo(visitor.viewedAt),
                                        style: TextStyle(
                                          fontFamily: Brand.displayFont,
                                          fontSize: 12,
                                          color: palette.muted,
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
