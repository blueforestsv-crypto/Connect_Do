import 'package:flutter/material.dart';

import 'package:project_ena/models/publication_model.dart';
import 'package:project_ena/services/publication_service.dart';
import 'package:project_ena/widgets/feed/publication_card.dart';
import 'package:project_ena/utils/responsive_helper.dart';

class PublicationDetailScreen extends StatefulWidget {
  final String publicationId;

  const PublicationDetailScreen({super.key, required this.publicationId});

  @override
  State<PublicationDetailScreen> createState() =>
      _PublicationDetailScreenState();
}

class _PublicationDetailScreenState extends State<PublicationDetailScreen> {
  bool isLoading = true;
  PublicationModel? publication;

  @override
  void initState() {
    super.initState();
    _loadPublication();
  }

  Future<void> _loadPublication() async {
    final publications = await PublicationService.getPublications();

    PublicationModel? found;

    try {
      found = publications.firstWhere(
        (post) => post.id == widget.publicationId,
      );
    } catch (_) {
      found = null;
    }

    if (!mounted) return;

    setState(() {
      publication = found;
      isLoading = false;
    });
  }

  Future<void> _deletePublication() async {
    if (publication == null) return;

    await PublicationService.deletePublication(publication!.id);

    if (!mounted) return;

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Publicación eliminada'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildNotFoundState({
    required Color textColor,
    required Color subtitleColor,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        30,
        0,
        30,
        ResponsiveHelper.bottomSafe(context) + 40,
      ),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),

        Icon(Icons.article_outlined, size: 65, color: subtitleColor),

        const SizedBox(height: 14),

        Text(
          'Esta publicación ya no está disponible',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textColor,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Puede que haya sido eliminada o que todavía no esté sincronizada.',
          textAlign: TextAlign.center,
          style: TextStyle(color: subtitleColor, fontSize: 14, height: 1.4),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDarkMode ? const Color(0xFF121212) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor =
        isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          'Publicación',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
      body:
          isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF22C55E)),
              )
              : publication == null
              ? _buildNotFoundState(
                textColor: textColor,
                subtitleColor: subtitleColor,
              )
              : RefreshIndicator(
                color: const Color(0xFF22C55E),
                backgroundColor:
                    isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                onRefresh: _loadPublication,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(
                    top: 12,
                    bottom: ResponsiveHelper.bottomSafe(context) + 40,
                  ),
                  children: [
                    PublicationCard(
                      post: publication!,
                      onDelete: _deletePublication,
                    ),
                  ],
                ),
              ),
    );
  }
}
