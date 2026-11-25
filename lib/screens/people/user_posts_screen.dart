import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/models/publication_model.dart';
import 'package:connect_do/services/publication_api_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/utils/responsive_helper.dart';
import 'package:connect_do/widgets/common/brand_bits.dart';
import 'package:connect_do/widgets/publication_card.dart';

/// Las publicaciones de una persona que yo puedo ver.
class UserPostsScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const UserPostsScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<UserPostsScreen> createState() => _UserPostsScreenState();
}

class _UserPostsScreenState extends State<UserPostsScreen> {
  List<PublicationModel> _posts = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final posts = await PublicationApiService().getPublications(
        authorId: widget.userId,
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _hasError = false;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  void _replace(PublicationModel updated) {
    final index = _posts.indexWhere((p) => p.id == updated.id);
    if (index != -1) _posts[index] = updated;
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final firstName = widget.userName.split(' ').first;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: brandAppBar(context, 'Publicaciones de $firstName'),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(
                  color: Brand.blue,
                  strokeWidth: 2.5,
                ),
              )
              : RefreshIndicator(
                color: Brand.blue,
                onRefresh: _load,
                child:
                    _posts.isEmpty
                        ? EmptyState(
                          icon:
                              _hasError
                                  ? PhosphorIconsRegular.cloudSlash
                                  : PhosphorIconsRegular.newspaper,
                          title:
                              _hasError
                                  ? 'No se pudieron cargar'
                                  : 'Sin publicaciones',
                          subtitle:
                              _hasError
                                  ? 'Desliza hacia abajo para reintentar.'
                                  : '$firstName no tiene publicaciones que '
                                      'puedas ver.',
                        )
                        : ListView.builder(
                          padding: EdgeInsets.only(
                            top: 8,
                            bottom: ResponsiveHelper.bottomSafe(context) + 24,
                          ),
                          itemCount: _posts.length,
                          itemBuilder:
                              (_, index) => PublicationCard(
                                key: ValueKey(_posts[index].id),
                                post: _posts[index],
                                index: index,
                                onChanged: _replace,
                              ),
                        ),
              ),
    );
  }
}
