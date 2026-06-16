import 'dart:io';

import 'package:flutter/material.dart';

import 'package:project_ena/models/publication_model.dart';

class PublicationHeader extends StatelessWidget {
  final PublicationModel post;
  final VoidCallback? onDelete;

  const PublicationHeader({super.key, required this.post, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final Color textColor = isDarkMode ? Colors.white : Colors.black87;
    final Color subtitleColor =
        isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;

    return Row(
      children: [
        _buildAvatar(isDarkMode),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.userName,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              Text(
                "Ahora",
                style: TextStyle(color: subtitleColor, fontSize: 12),
              ),
            ],
          ),
        ),

        IconButton(
          onPressed: () => _showPostOptions(context, isDarkMode),
          icon: Icon(
            Icons.more_horiz,
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
      ],
    );
  }

  // ===============================
  // AVATAR
  // ===============================
  Widget _buildAvatar(bool isDarkMode) {
    final Color avatarBgColor =
        isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200;

    if (post.userPhoto.isEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: avatarBgColor,
        child: Icon(
          Icons.person,
          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
      );
    }

    // Foto local del dispositivo
    if (post.userPhoto.startsWith('/')) {
      final file = File(post.userPhoto);

      if (file.existsSync()) {
        return CircleAvatar(
          radius: 24,
          backgroundColor: avatarBgColor,
          backgroundImage: FileImage(file),
        );
      }

      return CircleAvatar(
        radius: 24,
        backgroundColor: avatarBgColor,
        child: Icon(
          Icons.person,
          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
      );
    }

    // Foto desde internet
    return CircleAvatar(
      radius: 24,
      backgroundColor: avatarBgColor,
      backgroundImage: NetworkImage(post.userPhoto),
      onBackgroundImageError: (_, __) {},
    );
  }

  // ===============================
  // OPCIONES DE PUBLICACIÓN
  // ===============================
  void _showPostOptions(BuildContext context, bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
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
                    color: isDarkMode ? Colors.grey.shade700 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),

                _optionTile(
                  context,
                  isDarkMode: isDarkMode,
                  icon: Icons.edit_outlined,
                  title: 'Editar publicación',
                  subtitle: 'Modificar el contenido publicado',
                  color: const Color(0xFF2563EB),
                  onTap: () {
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Editar publicación próximamente'),
                      ),
                    );
                  },
                ),

                _optionTile(
                  context,
                  isDarkMode: isDarkMode,
                  icon: Icons.visibility_off_outlined,
                  title: 'Ocultar publicación',
                  subtitle: 'Dejar de ver este contenido en tu feed',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Publicación ocultada temporalmente'),
                      ),
                    );
                  },
                ),

                _optionTile(
                  context,
                  isDarkMode: isDarkMode,
                  icon: Icons.flag_outlined,
                  title: 'Reportar',
                  subtitle: 'Informar contenido inapropiado',
                  color: Colors.deepOrange,
                  onTap: () {
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reporte enviado para revisión'),
                      ),
                    );
                  },
                ),

                Divider(
                  color: isDarkMode ? Colors.white12 : Colors.grey.shade300,
                ),

                _optionTile(
                  context,
                  isDarkMode: isDarkMode,
                  icon: Icons.delete_outline,
                  title: 'Eliminar publicación',
                  subtitle: 'Borrar esta publicación del feed',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDelete(context, isDarkMode);
                  },
                ),

                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===============================
  // CONFIRMAR ELIMINACIÓN
  // ===============================
  void _confirmDelete(BuildContext context, bool isDarkMode) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text(
            'Eliminar publicación',
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            '¿Seguro que quieres eliminar esta publicación? Esta acción no se puede deshacer.',
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);

                if (onDelete != null) {
                  onDelete!();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }

  // ===============================
  // ITEM DEL MENÚ
  // ===============================
  Widget _optionTile(
    BuildContext context, {
    required bool isDarkMode,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.12),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
          fontSize: 12,
        ),
      ),
      onTap: onTap,
    );
  }
}
