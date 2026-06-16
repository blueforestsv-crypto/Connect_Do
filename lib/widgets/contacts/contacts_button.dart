import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/models/contact_request_model.dart';
import 'package:connect_do/services/contact_service.dart';

class ContactButton extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String otherUserPhoto;

  const ContactButton({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserPhoto,
  });

  @override
  State<ContactButton> createState() => _ContactButtonState();
}

class _ContactButtonState extends State<ContactButton> {
  String _status = 'none';
  bool _isLoading = true;

  String _currentUserId = '';
  String _currentUserName = 'Usuario';
  String _currentUserPhoto = '';

  @override
  void initState() {
    super.initState();
    _loadContactStatus();
  }

  Future<void> _loadContactStatus() async {
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('usuario_actual');

    if (userJson == null) {
      if (!mounted) return;

      setState(() {
        _status = 'none';
        _isLoading = false;
      });

      return;
    }

    final userData = jsonDecode(userJson);

    final email = userData['email'] ?? '';

    String firstName = userData['firstName'] ?? '';
    String lastName = userData['lastName'] ?? '';

    String fullName = '$firstName $lastName'.trim();

    if (fullName.isEmpty && email.isNotEmpty) {
      fullName = email.split('@')[0];
    }

    String photo = '';

    if ((userData['profile_image_path'] ?? '').toString().isNotEmpty) {
      photo = userData['profile_image_path'];
    } else if ((userData['google_photo_url'] ?? '').toString().isNotEmpty) {
      photo = userData['google_photo_url'];
    }

    final currentUserId = email.isNotEmpty ? email : 'local_user';

    final status = await ContactService.getContactStatus(
      currentUserId: currentUserId,
      otherUserId: widget.otherUserId,
    );

    if (!mounted) return;

    setState(() {
      _currentUserId = currentUserId;
      _currentUserName = fullName.isEmpty ? 'Usuario' : fullName;
      _currentUserPhoto = photo;
      _status = status;
      _isLoading = false;
    });
  }

  Future<void> _sendContactRequest() async {
    if (_currentUserId.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final request = ContactRequestModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      requesterId: _currentUserId,
      requesterName: _currentUserName,
      requesterPhoto: _currentUserPhoto,
      receiverId: widget.otherUserId,
      receiverName: widget.otherUserName,
      receiverPhoto: widget.otherUserPhoto,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    await ContactService.sendRequest(request);

    if (!mounted) return;

    setState(() {
      _status = 'sent';
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Solicitud de contacto enviada'),
        backgroundColor: Color(0xFF22C55E),
      ),
    );
  }

  Future<void> _acceptRequest() async {
    final requests = await ContactService.getRequests();

    final request = requests.firstWhere(
      (item) =>
          item.requesterId == widget.otherUserId &&
          item.receiverId == _currentUserId &&
          item.status == 'pending',
    );

    await ContactService.acceptRequest(request.id);

    if (!mounted) return;

    setState(() {
      _status = 'accepted';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ahora son contactos'),
        backgroundColor: Color(0xFF22C55E),
      ),
    );
  }

  Future<void> _rejectRequest() async {
    final requests = await ContactService.getRequests();

    final request = requests.firstWhere(
      (item) =>
          item.requesterId == widget.otherUserId &&
          item.receiverId == _currentUserId &&
          item.status == 'pending',
    );

    await ContactService.rejectRequest(request.id);

    if (!mounted) return;

    setState(() {
      _status = 'rejected';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Solicitud rechazada'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showRespondOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDarkMode ? Colors.white : Colors.black87;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),

                Text(
                  'Solicitud de contacto',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  '${widget.otherUserName} quiere agregarte como contacto.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 22),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _rejectRequest();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Rechazar'),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _acceptRequest();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Aceptar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 42,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFF22C55E),
            ),
          ),
        ),
      );
    }

    if (_status == 'accepted') {
      return _buildButton(
        text: 'Contacto',
        icon: Icons.check_circle,
        backgroundColor: const Color(0xFF22C55E),
        textColor: Colors.white,
        onTap: () {},
      );
    }

    if (_status == 'sent') {
      return _buildButton(
        text: 'Solicitud enviada',
        icon: Icons.schedule,
        backgroundColor: Colors.grey.shade300,
        textColor: Colors.grey.shade700,
        onTap: () {},
      );
    }

    if (_status == 'received') {
      return _buildButton(
        text: 'Responder solicitud',
        icon: Icons.person_add_alt_1,
        backgroundColor: const Color(0xFF2563EB),
        textColor: Colors.white,
        onTap: _showRespondOptions,
      );
    }

    if (_status == 'rejected') {
      return _buildButton(
        text: 'Solicitud rechazada',
        icon: Icons.block,
        backgroundColor: Colors.orange.shade100,
        textColor: Colors.orange.shade800,
        onTap: () {},
      );
    }

    return _buildButton(
      text: 'Contactar',
      icon: Icons.person_add_alt_1,
      backgroundColor: const Color(0xFF22C55E),
      textColor: Colors.white,
      onTap: _sendContactRequest,
    );
  }

  Widget _buildButton({
    required String text,
    required IconData icon,
    required Color backgroundColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 42,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }
}
