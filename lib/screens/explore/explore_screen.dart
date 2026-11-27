import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/models/publication_model.dart';
import 'package:connect_do/screens/main_content/home/publication_detail_screen.dart';
import 'package:connect_do/services/social_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/utils/cloudinary_url.dart';
import 'package:connect_do/widgets/common/brand_bits.dart';
import 'package:connect_do/widgets/social/person_tile.dart';

/// Descubrir: personas sugeridas y publicaciones populares.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  static const _pageSize = 24;

  final _scroll = ScrollController();
  List<PublicationModel> _posts = [];
  List<PersonCard> _people = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 500) {
        _loadMore();
      }
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await SocialService.explore(limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _posts = data.posts;
        _people = data.people;
        _hasMore = data.posts.length == _pageSize;
        _error = false;
      });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final data = await SocialService.explore(
        offset: _posts.length,
        limit: _pageSize,
      );
      if (!mounted) return;
      final known = _posts.map((p) => p.id).toSet();
      setState(() {
        _posts.addAll(data.posts.where((p) => !known.contains(p.id)));
        _hasMore = data.posts.length == _pageSize;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _open(PublicationModel post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicationDetailScreen(publicationId: post.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: brandAppBar(context, 'Explorar'),
      body:
          _loading
              ? const Center(
                child: CircularProgressIndicator(color: Brand.blue),
              )
              : RefreshIndicator(
                color: Brand.blue,
                onRefresh: _load,
                child: CustomScrollView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    if (_people.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Text(
                            'PERSONAS QUE QUIZÁ CONOZCAS',
                            style: TextStyle(
                              fontFamily: Brand.displayFont,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: palette.muted,
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList.separated(
                          itemCount: _people.length.clamp(0, 5),
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => PersonTile(person: _people[i]),
                        ),
                      ),
                    ],
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: Text(
                          'POPULAR EN CONNECT DO',
                          style: TextStyle(
                            fontFamily: Brand.displayFont,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: palette.muted,
                          ),
                        ),
                      ),
                    ),
                    if (_posts.isEmpty)
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 300,
                          child: EmptyState(
                            icon:
                                _error
                                    ? PhosphorIconsRegular.cloudSlash
                                    : PhosphorIconsRegular.compass,
                            title:
                                _error
                                    ? 'No se pudo cargar'
                                    : 'Aún no hay nada popular',
                            subtitle:
                                _error
                                    ? 'Desliza hacia abajo para reintentar.'
                                    : 'Las publicaciones públicas con más '
                                        'interacción aparecerán aquí.',
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(2, 0, 2, 32),
                        sliver: SliverGrid.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 2,
                                crossAxisSpacing: 2,
                              ),
                          itemCount: _posts.length,
                          itemBuilder:
                              (_, i) => _Tile(
                                post: _posts[i],
                                onTap: () => _open(_posts[i]),
                              ),
                        ),
                      ),
                    if (_loadingMore)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(color: Brand.blue),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
    );
  }
}

/// Cuadrito de la cuadrícula: la foto o la portada del video; si no hay,
/// el texto sobre un fondo de color.
class _Tile extends StatelessWidget {
  final PublicationModel post;
  final VoidCallback onTap;

  const _Tile({required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final media = post.mediaItems.where((m) => m.hasUrl).toList();
    final first = media.isEmpty ? null : media.first;

    final Widget content;
    if (first != null) {
      content = Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image: CachedNetworkImageProvider(
              first.isVideo
                  ? CloudinaryUrl.videoPoster(first.url, width: 400)
                  : CloudinaryUrl.transform(
                    first.url,
                    'c_fill,w_400,h_400,q_auto,f_auto',
                  ),
            ),
            fit: BoxFit.cover,
            errorBuilder:
                (_, __, ___) =>
                    Container(color: AuthPalette.of(context).fieldFill),
          ),
          if (first.isVideo || media.length > 1)
            Positioned(
              top: 6,
              right: 6,
              child: Icon(
                first.isVideo
                    ? PhosphorIconsFill.playCircle
                    : PhosphorIconsFill.copy,
                color: Colors.white,
                size: 18,
                shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
              ),
            ),
        ],
      );
    } else {
      content = Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(gradient: Brand.gradient),
        alignment: Alignment.center,
        child: Text(
          post.description,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: Brand.displayFont,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      );
    }

    return GestureDetector(onTap: onTap, child: content);
  }
}
