import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/models/comment_model.dart';
import 'package:connect_do/models/publication_model.dart';
import 'package:connect_do/services/comment_service.dart';
import 'package:connect_do/utils/responsive_helper.dart';

class CommentSheet extends StatefulWidget {
  final PublicationModel post;
  final bool isDarkMode;

  const CommentSheet({super.key, required this.post, this.isDarkMode = false});

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  final TextEditingController _commentController = TextEditingController();

  List<CommentModel> comments = [];

  bool isLoading = true;
  bool isSending = false;

  String currentUserId = 'local_user';
  String currentUserName = 'Usuario';
  String currentUserAvatar = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentUserAndComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // ===============================
  // CARGAR USUARIO Y COMENTARIOS
  // ===============================
  Future<void> _loadCurrentUserAndComments() async {
    await _loadCurrentUser();
    await _loadComments();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('usuario_actual');

    if (userJson == null) return;

    final userData = jsonDecode(userJson);

    final email = userData['email'] ?? 'local_user';

    final firstName = userData['firstName'] ?? '';
    final lastName = userData['lastName'] ?? '';
    final fullName = '$firstName $lastName'.trim();

    String name = 'Usuario';

    if (fullName.isNotEmpty) {
      name = fullName;
    } else if (email.toString().isNotEmpty) {
      name = email.toString().split('@')[0];
    }

    String avatar = '';

    if ((userData['profile_image_path'] ?? '').toString().isNotEmpty) {
      avatar = userData['profile_image_path'];
    } else if ((userData['google_photo_url'] ?? '').toString().isNotEmpty) {
      avatar = userData['google_photo_url'];
    }

    if (!mounted) return;

    setState(() {
      currentUserId = email;
      currentUserName = name;
      currentUserAvatar = avatar;
    });
  }

  // ===============================
  // CARGAR COMENTARIOS
  // ===============================
  Future<void> _loadComments() async {
    final data = await CommentService.getComments(widget.post.id);

    if (!mounted) return;

    setState(() {
      comments = data;
      isLoading = false;
    });
  }

  // ===============================
  // ENVIAR COMENTARIO
  // ===============================
  Future<void> _sendComment() async {
    final text = _commentController.text.trim();

    if (text.isEmpty || isSending) return;

    setState(() {
      isSending = true;
    });

    final comment = CommentModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      publicationId: widget.post.id,
      userId: currentUserId,
      userName: currentUserName,
      userAvatar: currentUserAvatar,
      text: text,
      timeAgo: 'Ahora',
      createdAt: DateTime.now(),
    );

    await CommentService.addComment(comment);

    if (!mounted) return;

    _commentController.clear();

    await _loadComments();

    if (!mounted) return;

    setState(() {
      isSending = false;
    });
  }

  // ===============================
  // OPCIONES DEL COMENTARIO
  // ===============================
  void _showCommentOptions(CommentModel comment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor:
          widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Padding(
          padding: ResponsiveHelper.sheetPadding(context),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 12),
                  decoration: BoxDecoration(
                    color:
                        widget.isDarkMode ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),

                ListTile(
                  leading: const Icon(
                    Icons.edit_outlined,
                    color: Color(0xFF2563EB),
                  ),
                  title: Text(
                    'Editar comentario',
                    style: TextStyle(
                      color: widget.isDarkMode ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditCommentDialog(comment);
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: Text(
                    'Eliminar comentario',
                    style: TextStyle(
                      color: widget.isDarkMode ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteComment(comment);
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
  // EDITAR COMENTARIO
  // ===============================
  void _showEditCommentDialog(CommentModel comment) {
    final TextEditingController editController = TextEditingController(
      text: comment.text,
    );

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor:
              widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text(
            'Editar comentario',
            style: TextStyle(
              color: widget.isDarkMode ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: editController,
            maxLines: null,
            autofocus: true,
            style: TextStyle(
              color: widget.isDarkMode ? Colors.white : Colors.black87,
            ),
            cursorColor: const Color(0xFF22C55E),
            decoration: InputDecoration(
              hintText: 'Escribe tu comentario',
              hintStyle: TextStyle(
                color: widget.isDarkMode ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final newText = editController.text.trim();

                if (newText.isEmpty) return;

                await CommentService.updateComment(
                  commentId: comment.id,
                  newText: newText,
                );

                if (!mounted) return;

                Navigator.pop(context);

                await _loadComments();
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  // ===============================
  // ELIMINAR COMENTARIO
  // ===============================
  Future<void> _deleteComment(CommentModel comment) async {
    await CommentService.deleteComment(comment.id);

    if (!mounted) return;

    await _loadComments();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Comentario eliminado'),
        backgroundColor: Colors.red,
      ),
    );
  }

  // ===============================
  // AVATAR
  // ===============================
  Widget _buildAvatar(String avatar) {
    if (avatar.isEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundColor:
            widget.isDarkMode ? Colors.grey[800] : Colors.grey[200],
        child: Icon(
          Icons.person,
          color: widget.isDarkMode ? Colors.grey[400] : Colors.grey,
          size: 20,
        ),
      );
    }

    if (avatar.startsWith('/')) {
      return CircleAvatar(radius: 18, backgroundImage: FileImage(File(avatar)));
    }

    return CircleAvatar(
      radius: 18,
      backgroundImage: NetworkImage(avatar),
      onBackgroundImageError: (_, __) {},
    );
  }

  // ===============================
  // ITEM COMENTARIO
  // ===============================
  Widget _buildCommentItem(CommentModel comment) {
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;

    final subtitleColor =
        widget.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(comment.userAvatar),

          const SizedBox(width: 10),

          Expanded(
            child: InkWell(
              onLongPress: () => _showCommentOptions(comment),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      widget.isDarkMode
                          ? const Color(0xFF1E1E1E)
                          : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            comment.userName,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        InkWell(
                          onTap: () => _showCommentOptions(comment),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.more_horiz,
                              color: subtitleColor,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Text(
                      comment.text,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      comment.timeAgo,
                      style: TextStyle(color: subtitleColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===============================
  // INPUT DE COMENTARIO
  // ===============================
  Widget _buildCommentInput({
    required Color bgColor,
    required Color inputBgColor,
    required Color textColor,
    required Color hintColor,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(
            color: widget.isDarkMode ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: inputBgColor,
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _commentController,
                minLines: 1,
                maxLines: 4,
                style: TextStyle(color: textColor),
                cursorColor: const Color(0xFF22C55E),
                decoration: InputDecoration(
                  hintText: 'Escribe un comentario...',
                  hintStyle: TextStyle(color: hintColor),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          CircleAvatar(
            backgroundColor: const Color(0xFF22C55E),
            child: IconButton(
              icon:
                  isSending
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                      : const Icon(Icons.send, color: Colors.white),
              onPressed: isSending ? null : _sendComment,
            ),
          ),
        ],
      ),
    );
  }

  // ===============================
  // BUILD
  // ===============================
  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDarkMode ? const Color(0xFF121212) : Colors.white;

    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;

    final inputBgColor =
        widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade100;

    final hintColor =
        widget.isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500;

    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),

            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: widget.isDarkMode ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(20),
              ),
            ),

            const SizedBox(height: 14),

            Text(
              'Comentarios',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child:
                  isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF22C55E),
                        ),
                      )
                      : comments.isEmpty
                      ? Center(
                        child: Text(
                          'Aún no hay comentarios',
                          style: TextStyle(
                            color:
                                widget.isDarkMode
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                          ),
                        ),
                      )
                      : ListView.builder(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          return _buildCommentItem(comments[index]);
                        },
                      ),
            ),

            _buildCommentInput(
              bgColor: bgColor,
              inputBgColor: inputBgColor,
              textColor: textColor,
              hintColor: hintColor,
            ),
          ],
        ),
      ),
    );
  }
}
