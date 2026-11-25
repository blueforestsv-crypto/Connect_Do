import 'package:flutter/material.dart';

import 'package:connect_do/models/publication_model.dart';
import 'package:connect_do/widgets/feed/feed_card_shell.dart';
import 'package:connect_do/widgets/feed/opportunity_card.dart';
import 'package:connect_do/widgets/feed/publication_actions.dart';
import 'package:connect_do/widgets/feed/publication_content.dart';
import 'package:connect_do/widgets/feed/publication_header.dart';
import 'package:connect_do/widgets/feed/publication_media.dart';

class PublicationCard extends StatefulWidget {
  final PublicationModel post;
  final VoidCallback? onDelete;
  final VoidCallback? onHide;
  final VoidCallback? onSavedChanged;
  final ValueChanged<PublicationModel>? onChanged;
  final int index;

  const PublicationCard({
    super.key,
    required this.post,
    this.onDelete,
    this.onHide,
    this.onSavedChanged,
    this.onChanged,
    this.index = 0,
  });

  @override
  State<PublicationCard> createState() => _PublicationCardState();
}

class _PublicationCardState extends State<PublicationCard>
    with SingleTickerProviderStateMixin {
  /// Publicaciones que ya hicieron su animación de entrada: al volver a
  /// desplazarse hacia ellas aparecen directamente.
  static final Set<String> _alreadyShown = {};

  // El escalonado se hace con un Interval dentro de la misma animación,
  // sin temporizadores.
  late final int _staggerMs = (widget.index * 50).clamp(0, 250);

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 380 + _staggerMs),
  );

  late final Animation<double> _animation = CurvedAnimation(
    parent: _entrance,
    curve: Interval(
      _staggerMs / (380 + _staggerMs),
      1,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void initState() {
    super.initState();

    if (_alreadyShown.add(widget.post.id)) {
      _entrance.forward();
    } else {
      _entrance.value = 1;
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = _animation;

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(animation),
        child:
            widget.post.isOpportunity
                ? OpportunityCard(
                  post: widget.post,
                  onDelete: widget.onDelete,
                  onHide: widget.onHide,
                  onSavedChanged: widget.onSavedChanged,
                  onChanged: widget.onChanged,
                )
                : FeedCardShell(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PublicationHeader(
                        post: widget.post,
                        onDelete: widget.onDelete,
                        onHide: widget.onHide,
                      ),
                      const SizedBox(height: 12),
                      PublicationContent(post: widget.post),
                      if (widget.post.hasAnyMedia) ...[
                        const SizedBox(height: 12),
                        PublicationMedia(post: widget.post),
                      ],
                      const SizedBox(height: 12),
                      PublicationActions(
                        post: widget.post,
                        onSavedChanged: widget.onSavedChanged,
                        onChanged: widget.onChanged,
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}
