import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:project_ena/models/contact_request_model.dart';
import 'package:project_ena/models/publication_model.dart';
import 'package:project_ena/services/comment_service.dart';
import 'package:project_ena/services/contact_service.dart';
import 'package:project_ena/services/saved_publication_service.dart';
import 'package:project_ena/widgets/comment_sheet.dart';

class PublicationActions extends StatefulWidget {
  final PublicationModel post;
  final VoidCallback? onSavedChanged;

  const PublicationActions({
    super.key,
    required this.post,
    this.onSavedChanged,
  });

  @override
  State<PublicationActions> createState() => _PublicationActionsState();
}

class _PublicationActionsState extends State<PublicationActions> {
  bool isLiked = false;
  bool isSaved = false;

  int likes = 0;
  int commentsCount = 0;

  @override
  void initState() {
    super.initState();

    _loadSavedState();
    _loadCommentsCount();
  }

  Future<void> _loadSavedState() async {
    final saved = await SavedPublicationService.isSaved(widget.post.id);

    if (!mounted) return;

    setState(() {
      isSaved = saved;
    });
  }

  Future<void> _loadCommentsCount() async {
    final comments = await CommentService.getComments(widget.post.id);

    if (!mounted) return;

    setState(() {
      commentsCount = comments.length;
    });
  }

  void _toggleLike() {
    setState(() {
      isLiked = !isLiked;

      if (isLiked) {
        likes++;
      } else {
        if (likes > 0) {
          likes--;
        }
      }
    });
  }

  Future<void> _toggleSave() async {
    if (isSaved) {
      await SavedPublicationService.removeSavedPublication(widget.post.id);
    } else {
      await SavedPublicationService.savePublication(widget.post);
    }

    if (!mounted) return;

    setState(() {
      isSaved = !isSaved;
    });

    widget.onSavedChanged?.call();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isSaved ? 'Publicación guardada' : 'Se eliminó de guardados',
        ),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  Future<void> _showCommentsSheet() async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return CommentSheet(post: widget.post, isDarkMode: isDarkMode);
      },
    );

    await _loadCommentsCount();
  }

  String _buildShareText() {
    final description = widget.post.description.trim();

    final buffer = StringBuffer();

    buffer.writeln('Mira esta publicación de ${widget.post.userName}:');

    if (description.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(description);
    }

    if ((widget.post.fileName ?? '').isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Archivo adjunto: ${widget.post.fileName}');
    }

    buffer.writeln();
    buffer.writeln('Compartido desde Project ENA');

    return buffer.toString();
  }

  Future<void> _shareToExternalApp() async {
    try {
      final text = _buildShareText();

      final filePath = widget.post.filePath ?? widget.post.imagePath;

      final hasLocalFile =
          filePath != null && filePath.isNotEmpty && filePath.startsWith('/');

      if (hasLocalFile && File(filePath).existsSync()) {
        await Share.shareXFiles([XFile(filePath)], text: text);

        return;
      }

      await Share.share(text);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo compartir: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('usuario_actual');

    if (userJson == null || userJson.isEmpty) {
      return null;
    }

    final userData = jsonDecode(userJson);

    return userData['email'] ?? 'local_user';
  }

  Future<void> _showShareMenu() async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
                    color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),

                Text(
                  'Compartir publicación',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                ListTile(
                  leading: const Icon(
                    Icons.person_add_alt_1_outlined,
                    color: Color(0xFF2563EB),
                  ),
                  title: Text(
                    'Enviar a contacto',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Compartir dentro de la app',
                    style: TextStyle(
                      color:
                          isDarkMode ? Colors.grey.shade400 : Colors.grey[600],
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showContactsToShare();
                  },
                ),

                ListTile(
                  leading: const Icon(
                    Icons.share_outlined,
                    color: Color(0xFF22C55E),
                  ),
                  title: Text(
                    'Compartir en otra app',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'WhatsApp, Messenger, correo, etc.',
                    style: TextStyle(
                      color:
                          isDarkMode ? Colors.grey.shade400 : Colors.grey[600],
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _shareToExternalApp();
                  },
                ),

                ListTile(
                  leading: const Icon(
                    Icons.dynamic_feed_outlined,
                    color: Colors.orange,
                  ),
                  title: Text(
                    'Compartir en el feed',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Republicar en tu perfil',
                    style: TextStyle(
                      color:
                          isDarkMode ? Colors.grey.shade400 : Colors.grey[600],
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Compartir en el feed próximamente'),
                        duration: Duration(milliseconds: 1200),
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

  Future<void> _showContactsToShare() async {
    final currentUserId = await _getCurrentUserId();

    if (!mounted) return;

    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontró el usuario actual'),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    final contacts = await ContactService.getContacts(currentUserId);

    if (!mounted) return;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final textColor = isDarkMode ? Colors.white : Colors.black87;
        final subtitleColor =
            isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;

        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.65,
            child: Column(
              children: [
                const SizedBox(height: 12),

                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  'Enviar a contacto',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                Expanded(
                  child:
                      contacts.isEmpty
                          ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 30,
                              ),
                              child: Text(
                                'Aún no tienes contactos para compartir esta publicación.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                          : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                            itemCount: contacts.length,
                            itemBuilder: (context, index) {
                              final contact = contacts[index];

                              final contactData = _getContactData(
                                contact,
                                currentUserId,
                              );

                              return _contactShareTile(
                                name: contactData.name,
                                photo: contactData.photo,
                                isDarkMode: isDarkMode,
                                textColor: textColor,
                                subtitleColor: subtitleColor,
                                onTap: () {
                                  Navigator.pop(context);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Publicación enviada a ${contactData.name}',
                                      ),
                                      backgroundColor: const Color(0xFF22C55E),
                                      duration: const Duration(
                                        milliseconds: 1200,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  _ContactShareData _getContactData(
    ContactRequestModel contact,
    String currentUserId,
  ) {
    final isRequester = contact.requesterId == currentUserId;

    if (isRequester) {
      return _ContactShareData(
        id: contact.receiverId,
        name: contact.receiverName,
        photo: contact.receiverPhoto,
      );
    }

    return _ContactShareData(
      id: contact.requesterId,
      name: contact.requesterName,
      photo: contact.requesterPhoto,
    );
  }

  Widget _contactShareTile({
    required String name,
    required String photo,
    required bool isDarkMode,
    required Color textColor,
    required Color subtitleColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF121212) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        onTap: onTap,
        leading: _buildContactAvatar(photo),
        title: Text(
          name,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Enviar publicación',
          style: TextStyle(color: subtitleColor, fontSize: 12),
        ),
        trailing: const Icon(Icons.send_rounded, color: Color(0xFF22C55E)),
      ),
    );
  }

  Widget _buildContactAvatar(String photo) {
    if (photo.isEmpty) {
      return const CircleAvatar(
        radius: 23,
        backgroundColor: Color(0xFFE5E7EB),
        child: Icon(Icons.person, color: Colors.grey),
      );
    }

    if (photo.startsWith('/')) {
      return CircleAvatar(radius: 23, backgroundImage: FileImage(File(photo)));
    }

    return CircleAvatar(
      radius: 23,
      backgroundImage: NetworkImage(photo),
      onBackgroundImageError: (_, __) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final normalColor =
        isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700;

    final countColor = isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700;

    return Column(
      children: [
        if (likes > 0 || commentsCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _buildStatsText(),
                style: TextStyle(
                  color: countColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _actionButton(
              icon: isLiked ? Icons.favorite : Icons.favorite_border,
              text: 'Me gusta',
              color: isLiked ? Colors.red : normalColor,
              onTap: _toggleLike,
            ),

            _actionButton(
              icon: Icons.comment_outlined,
              text: 'Comentar',
              color: normalColor,
              onTap: _showCommentsSheet,
            ),

            _actionButton(
              icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
              text: 'Guardar',
              color: isSaved ? const Color(0xFF10B970) : normalColor,
              onTap: _toggleSave,
            ),

            _actionButton(
              icon: Icons.share_outlined,
              text: 'Compartir',
              color: normalColor,
              onTap: _showShareMenu,
            ),
          ],
        ),
      ],
    );
  }

  String _buildStatsText() {
    final parts = <String>[];

    if (likes > 0) {
      parts.add('$likes me gusta');
    }

    if (commentsCount > 0) {
      parts.add(
        commentsCount == 1 ? '1 comentario' : '$commentsCount comentarios',
      );
    }

    return parts.join(' · ');
  }

  Widget _actionButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),

            const SizedBox(width: 3),

            Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactShareData {
  final String id;
  final String name;
  final String photo;

  _ContactShareData({
    required this.id,
    required this.name,
    required this.photo,
  });
}
