import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:connect_do/models/post_model.dart';
import 'package:connect_do/models/publication_model.dart';
import 'package:connect_do/services/comment_service.dart';
import 'package:connect_do/services/saved_publication_service.dart';
import 'package:connect_do/widgets/comment_sheet.dart';

class PostCard extends StatefulWidget {
  final PostModel postData;

  const PostCard({super.key, required this.postData});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool isRewarded = false;
  bool isKept = false;

  int likesCount = 0;
  int commentsCount = 0;
  int _currentImage = 0;

  @override
  void initState() {
    super.initState();

    isRewarded = widget.postData.isLikedByMe;
    isKept = widget.postData.isBookmarkedByMe;

    likesCount = widget.postData.likes;
    commentsCount = widget.postData.comments;

    _loadSavedState();
    _loadCommentsCount();
  }

  // ===============================
  // CONVERTIR POSTMODEL A PUBLICATIONMODEL
  // ===============================
  PublicationModel _convertPostToPublication() {
    return PublicationModel(
      id: widget.postData.id,
      userName: widget.postData.userName,
      userPhoto: widget.postData.userAvatar,
      description: widget.postData.description,
      imagePath:
          widget.postData.imageUrls.isNotEmpty
              ? widget.postData.imageUrls.first
              : null,
      createdAt: DateTime.now(),
      likes: likesCount,
      comments: commentsCount,
    );
  }

  // ===============================
  // CARGAR ESTADO GUARDADO
  // ===============================
  Future<void> _loadSavedState() async {
    final publication = _convertPostToPublication();

    final saved = await SavedPublicationService.isSaved(publication.id);

    if (!mounted) return;

    setState(() {
      isKept = saved;
    });
  }

  // ===============================
  // CARGAR CANTIDAD DE COMENTARIOS
  // ===============================
  Future<void> _loadCommentsCount() async {
    final count = await CommentService.getCommentsCount(widget.postData.id);

    if (!mounted) return;

    setState(() {
      commentsCount = count;
    });
  }

  // ===============================
  // LIKE
  // ===============================
  void _toggleReward() {
    setState(() {
      isRewarded = !isRewarded;

      if (isRewarded) {
        likesCount++;
      } else {
        if (likesCount > 0) {
          likesCount--;
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isRewarded ? 'Te gustó esta publicación' : 'Quitaste tu me gusta',
        ),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  // ===============================
  // GUARDAR
  // ===============================
  Future<void> _toggleKeep() async {
    final publication = _convertPostToPublication();

    if (isKept) {
      await SavedPublicationService.removeSavedPublication(publication.id);
    } else {
      await SavedPublicationService.savePublication(publication);
    }

    if (!mounted) return;

    setState(() {
      isKept = !isKept;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isKept ? 'Publicación guardada' : 'Se eliminó de guardados',
        ),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  // ===============================
  // COMENTARIOS
  // ===============================
  Future<void> _showCommentSheet() async {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final publication = _convertPostToPublication();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return CommentSheet(post: publication, isDarkMode: isDarkMode);
      },
    );

    await _loadCommentsCount();
  }

  // ===============================
  // COMPARTIR
  // ===============================
  void _showShareMenu() {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final textColor = isDarkMode ? Colors.white : Colors.black87;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),

                ListTile(
                  leading: const Icon(
                    Icons.person_add_alt_1_outlined,
                    color: Color(0xFF2563EB),
                  ),
                  title: Text(
                    'Compartir con otro usuario',
                    style: TextStyle(color: textColor),
                  ),
                  onTap: () {
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Compartir con usuarios próximamente'),
                      ),
                    );
                  },
                ),

                ListTile(
                  leading: const Icon(
                    Icons.share_outlined,
                    color: Color(0xFF22C55E),
                  ),
                  title: Text(
                    'Compartir en otra app',
                    style: TextStyle(color: textColor),
                  ),
                  onTap: () {
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Compartir en otras apps próximamente'),
                      ),
                    );
                  },
                ),

                ListTile(
                  leading: const Icon(
                    Icons.dynamic_feed_outlined,
                    color: Colors.orange,
                  ),
                  title: Text(
                    'Compartir en el feed',
                    style: TextStyle(color: textColor),
                  ),
                  onTap: () {
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Compartir en feed próximamente'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===============================
  // MENÚ DE OPCIONES
  // ===============================
  void _showPostOptions() {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final textColor = isDarkMode ? Colors.white : Colors.black87;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),

                ListTile(
                  leading: const Icon(Icons.share_outlined),
                  title: Text(
                    'Compartir publicación',
                    style: TextStyle(color: textColor),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showShareMenu();
                  },
                ),

                ListTile(
                  leading: const Icon(
                    Icons.visibility_off_outlined,
                    color: Colors.orange,
                  ),
                  title: Text(
                    'Ocultar publicación',
                    style: TextStyle(color: textColor),
                  ),
                  onTap: () {
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Publicación ocultada temporalmente'),
                      ),
                    );
                  },
                ),

                ListTile(
                  leading: const Icon(
                    Icons.flag_outlined,
                    color: Colors.deepOrange,
                  ),
                  title: Text(
                    'Reportar publicación',
                    style: TextStyle(color: textColor),
                  ),
                  onTap: () {
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reporte enviado para revisión'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===============================
  // BUILD
  // ===============================
  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final Color cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    final Color textColor = isDarkMode ? Colors.white : Colors.black87;

    final Color subtitleColor =
        isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;

    final Color borderColor =
        isDarkMode ? Colors.white10 : Colors.grey.shade200;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      elevation: 1,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===============================
          // HEADER
          // ===============================
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                  backgroundImage:
                      widget.postData.userAvatar.isNotEmpty
                          ? NetworkImage(widget.postData.userAvatar)
                          : null,
                  child:
                      widget.postData.userAvatar.isEmpty
                          ? Icon(
                            PhosphorIconsRegular.user,
                            color: subtitleColor,
                          )
                          : null,
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.postData.userName,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      Text(
                        widget.postData.timeAgo,
                        style: TextStyle(color: subtitleColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                IconButton(
                  onPressed: _showPostOptions,
                  icon: Icon(Icons.more_horiz, color: subtitleColor),
                ),
              ],
            ),
          ),

          // ===============================
          // IMÁGENES
          // ===============================
          if (widget.postData.imageUrls.isNotEmpty)
            Column(
              children: [
                SizedBox(
                  height: 260,
                  width: double.infinity,
                  child: PageView.builder(
                    itemCount: widget.postData.imageUrls.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentImage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return Image.network(
                        widget.postData.imageUrls[index],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return Container(
                            color:
                                isDarkMode
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade200,
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: subtitleColor,
                              size: 50,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                if (widget.postData.imageUrls.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        widget.postData.imageUrls.length,
                        (index) => Container(
                          width: _currentImage == index ? 9 : 7,
                          height: _currentImage == index ? 9 : 7,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                _currentImage == index
                                    ? const Color(0xFF2563EB)
                                    : Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

          // ===============================
          // CONTENIDO
          // ===============================
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              widget.postData.description,
              style: TextStyle(color: textColor, fontSize: 15, height: 1.45),
            ),
          ),

          // ===============================
          // CONTADORES
          // ===============================
          if (likesCount > 0 || commentsCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                '${likesCount > 0 ? '$likesCount me gusta' : ''}'
                '${likesCount > 0 && commentsCount > 0 ? ' · ' : ''}'
                '${commentsCount > 0 ? '$commentsCount comentarios' : ''}',
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          const SizedBox(height: 4),

          Divider(color: borderColor, height: 1),

          // ===============================
          // ACCIONES
          // ===============================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _actionButton(
                  icon: isRewarded ? Icons.favorite : Icons.favorite_border,
                  text: 'Me gusta',
                  color: isRewarded ? Colors.red : subtitleColor,
                  onTap: _toggleReward,
                ),

                _actionButton(
                  icon: Icons.comment_outlined,
                  text: 'Comentar',
                  color: subtitleColor,
                  onTap: _showCommentSheet,
                ),

                _actionButton(
                  icon: isKept ? Icons.bookmark : Icons.bookmark_border,
                  text: 'Guardar',
                  color: isKept ? const Color(0xFF10B970) : subtitleColor,
                  onTap: _toggleKeep,
                ),

                _actionButton(
                  icon: Icons.share_outlined,
                  text: 'Compartir',
                  color: subtitleColor,
                  onTap: _showShareMenu,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String text,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),

            const SizedBox(width: 5),

            Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
