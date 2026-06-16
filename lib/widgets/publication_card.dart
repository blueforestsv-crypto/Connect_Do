import 'package:flutter/material.dart';

import 'package:connect_do/models/publication_model.dart';
import 'package:connect_do/widgets/feed/publication_actions.dart';
import 'package:connect_do/widgets/feed/publication_header.dart';
import 'package:connect_do/widgets/feed/publication_content.dart';

class PublicationCard extends StatelessWidget {
  final PublicationModel post;
  final VoidCallback? onDelete;
  final VoidCallback? onSavedChanged;

  const PublicationCard({
    super.key,
    required this.post,
    this.onDelete,
    this.onSavedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PublicationHeader(post: post, onDelete: onDelete),

            const SizedBox(height: 16),

            PublicationContent(post: post),

            const SizedBox(height: 18),

            PublicationActions(post: post, onSavedChanged: onSavedChanged),
          ],
        ),
      ),
    );
  }
}
