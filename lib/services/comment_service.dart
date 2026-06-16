import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/models/comment_model.dart';

class CommentService {
  static const String _storageKey = 'comments_storage';

  // ===============================
  // OBTENER TODOS LOS COMENTARIOS
  // ===============================
  static Future<List<CommentModel>> _getAllComments() async {
    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getString(_storageKey);

    if (data == null) {
      return [];
    }

    final List decoded = jsonDecode(data);

    return decoded.map((item) => CommentModel.fromJson(item)).toList();
  }

  // ===============================
  // GUARDAR TODOS LOS COMENTARIOS
  // ===============================
  static Future<void> _saveAllComments(List<CommentModel> comments) async {
    final prefs = await SharedPreferences.getInstance();

    final jsonList = comments.map((comment) => comment.toJson()).toList();

    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }

  // ===============================
  // OBTENER COMENTARIOS POR PUBLICACIÓN
  // ===============================
  static Future<List<CommentModel>> getComments(String publicationId) async {
    final comments = await _getAllComments();

    return comments
        .where((comment) => comment.publicationId == publicationId)
        .toList()
        .reversed
        .toList();
  }

  // Alias por si algún fichero lo llama así
  static Future<List<CommentModel>> getCommentsByPublication(
    String publicationId,
  ) async {
    return getComments(publicationId);
  }

  // ===============================
  // CONTAR COMENTARIOS
  // ===============================
  static Future<int> getCommentsCount(String publicationId) async {
    final comments = await getComments(publicationId);

    return comments.length;
  }

  // ===============================
  // AGREGAR COMENTARIO
  // ===============================
  static Future<void> addComment(CommentModel comment) async {
    final comments = await _getAllComments();

    comments.add(comment);

    await _saveAllComments(comments);
  }

  // ===============================
  // EDITAR COMENTARIO
  // ===============================
  static Future<void> updateComment({
    required String commentId,
    required String newText,
  }) async {
    final comments = await _getAllComments();

    final index = comments.indexWhere((comment) => comment.id == commentId);

    if (index == -1) return;

    final oldComment = comments[index];

    comments[index] = CommentModel(
      id: oldComment.id,
      publicationId: oldComment.publicationId,
      userId: oldComment.userId,
      userName: oldComment.userName,
      userAvatar: oldComment.userAvatar,
      text: newText,
      timeAgo: oldComment.timeAgo,
      createdAt: oldComment.createdAt,
    );

    await _saveAllComments(comments);
  }

  // ===============================
  // ELIMINAR COMENTARIO
  // ===============================
  static Future<void> deleteComment(String commentId) async {
    final comments = await _getAllComments();

    comments.removeWhere((comment) => comment.id == commentId);

    await _saveAllComments(comments);
  }

  // ===============================
  // ELIMINAR COMENTARIOS DE UNA PUBLICACIÓN
  // ===============================
  static Future<void> deleteCommentsByPublication(String publicationId) async {
    final comments = await _getAllComments();

    comments.removeWhere((comment) => comment.publicationId == publicationId);

    await _saveAllComments(comments);
  }

  // ===============================
  // LIMPIAR TODOS LOS COMENTARIOS
  // ===============================
  static Future<void> clearComments() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_storageKey);
  }
}
