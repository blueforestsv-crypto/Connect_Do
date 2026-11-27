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

  /// Versión editada por el autor (se muestra sin recargar el feed).
  PublicationModel? _edited;

  void _onEdited(PublicationModel updated) {
    setState(() => _edited = updated);
    widget.onChanged?.call(updated);
  }

  @override
  void didUpdateWidget(covariant PublicationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) _edited = null;
  }

  @override
  Widget build(BuildContext context) {
    final animation = _animation;
    final post = _edited ?? widget.post;

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(animation),
        child:
            post.isOpportunity
                ? OpportunityCard(
                  post: post,
                  onDelete: widget.onDelete,
                  onHide: widget.onHide,
                  onSavedChanged: widget.onSavedChanged,
                  onChanged: widget.onChanged,
                  onEdited: _onEdited,
                )
                : FeedCardShell(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PublicationHeader(
                        post: post,
                        onDelete: widget.onDelete,
                        onHide: widget.onHide,
                        onEdited: _onEdited,
                      ),
                      const SizedBox(height: 12),
                      PublicationContent(post: post),
                      if (post.hasAnyMedia) ...[
                        const SizedBox(height: 12),
                        PublicationMedia(post: post),
                      ],
                      const SizedBox(height: 12),
                      PublicationActions(
                        post: post,
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
