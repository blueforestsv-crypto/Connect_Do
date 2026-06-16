import 'package:flutter/material.dart';

import 'package:project_ena/models/publication_model.dart';
import 'package:project_ena/services/saved_publication_service.dart';
import 'package:project_ena/widgets/feed/publication_card.dart';

class SavedPublicationsScreen extends StatefulWidget {
  const SavedPublicationsScreen({super.key});

  @override
  State<SavedPublicationsScreen> createState() =>
      _SavedPublicationsScreenState();
}

class _SavedPublicationsScreenState extends State<SavedPublicationsScreen> {
  bool isLoading = true;
  List<PublicationModel> savedPosts = [];

  @override
  void initState() {
    super.initState();
    _loadSavedPosts();
  }

  Future<void> _loadSavedPosts() async {
    final data = await SavedPublicationService.getSavedPublications();

    if (!mounted) return;

    setState(() {
      savedPosts = data;
      isLoading = false;
    });
  }

  Future<void> _removeSavedPost(PublicationModel post) async {
    await SavedPublicationService.removeSavedPublication(post.id);

    await _loadSavedPosts();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Se eliminó de guardados'),
        backgroundColor: Colors.orange,
        duration: Duration(milliseconds: 900),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDarkMode ? const Color(0xFF121212) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor =
        isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;

    if (isLoading) {
      return Container(
        color: bgColor,
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF22C55E)),
        ),
      );
    }

    if (savedPosts.isEmpty) {
      return Container(
        color: bgColor,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 35),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bookmark_border,
                  size: 70,
                  color:
                      isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'No tienes publicaciones guardadas',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cuando guardes una publicación aparecerá aquí.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: bgColor,
      child: RefreshIndicator(
        color: const Color(0xFF22C55E),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        onRefresh: _loadSavedPosts,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 110),
          itemCount: savedPosts.length,
          itemBuilder: (context, index) {
            final post = savedPosts[index];

            return PublicationCard(
              post: post,
              onDelete: () => _removeSavedPost(post),
              onSavedChanged: _loadSavedPosts,
            );
          },
        ),
      ),
    );
  }
}
