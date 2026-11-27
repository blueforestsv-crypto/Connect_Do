import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/models/publication_model.dart';
import 'package:connect_do/services/publication_api_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/common/brand_bits.dart';
import 'package:connect_do/widgets/publication_card.dart';

/// Publicaciones con un #hashtag.
class HashtagScreen extends StatefulWidget {
  final String tag;

  const HashtagScreen({super.key, required this.tag});

  @override
  State<HashtagScreen> createState() => _HashtagScreenState();
}

class _HashtagScreenState extends State<HashtagScreen> {
  List<PublicationModel>? _posts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final posts = await PublicationApiService().getPublications(
        query: widget.tag,
        limit: 50,
      );
      if (mounted) setState(() => _posts = posts);
    } catch (_) {
      if (mounted) setState(() => _posts = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final posts = _posts;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: brandAppBar(context, widget.tag),
      body:
          posts == null
              ? const Center(
                child: CircularProgressIndicator(color: Brand.blue),
              )
              : RefreshIndicator(
                color: Brand.blue,
                onRefresh: _load,
                child:
                    posts.isEmpty
                        ? EmptyState(
                          icon: PhosphorIconsRegular.hash,
                          title: 'Nada todavía',
                          subtitle:
                              'Sé la primera persona en publicar con '
                              '${widget.tag}.',
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 32),
                          itemCount: posts.length,
                          itemBuilder:
                              (_, i) => PublicationCard(
                                key: ValueKey(posts[i].id),
                                post: posts[i],
                                index: i,
                              ),
                        ),
              ),
    );
  }
}
