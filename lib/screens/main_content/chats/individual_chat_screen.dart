import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/services/chat_service.dart';
import 'package:connect_do/utils/responsive_helper.dart';

// ---------------------------------------------------------------------------
// PANTALLA DE CHAT INDIVIDUAL
// ---------------------------------------------------------------------------
class IndividualChatScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final String chatAvatar;

  const IndividualChatScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    required this.chatAvatar,
  });

  @override
  State<IndividualChatScreen> createState() => _IndividualChatScreenState();
}

class _IndividualChatScreenState extends State<IndividualChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessageModel> messages = [];

  Timer? _pollingTimer;

  bool isTyping = false;
  bool isLoading = true;
  bool isSending = false;

  String _currentUserId = '';

  @override
  void initState() {
    super.initState();

    _loadCurrentUserAndMessages();

    _messageController.addListener(_onMessageChanged);

    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchMessages(showLoading: false);
    });
  }

  Future<void> _loadCurrentUserAndMessages() async {
    await _loadCurrentUserId();
    await _fetchMessages();
  }

  Future<void> _loadCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();

    final userJson = prefs.getString('usuario_actual');

    if (userJson == null || userJson.isEmpty) {
      return;
    }

    try {
      final userData = jsonDecode(userJson) as Map<String, dynamic>;

      _currentUserId = userData['id']?.toString() ?? '';
    } catch (_) {
      _currentUserId = '';
    }
  }

  void _onMessageChanged() {
    setState(() {
      isTyping = _messageController.text.trim().isNotEmpty;
    });
  }

  Future<void> _fetchMessages({bool showLoading = true}) async {
    try {
      if (showLoading && mounted) {
        setState(() {
          isLoading = true;
        });
      }

      final data = await ChatService.getMessages(contactId: widget.chatId);

      final loadedMessages =
          data
              .map(
                (item) => ChatMessageModel.fromBackend(
                  item,
                  currentUserId: _currentUserId,
                ),
              )
              .toList()
              .reversed
              .toList();

      try {
        await ChatService.markAsRead(contactId: widget.chatId);
      } catch (_) {}

      if (!mounted) return;

      setState(() {
        messages = loadedMessages;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar los mensajes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.removeListener(_onMessageChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty || isSending) return;

    setState(() {
      isSending = true;
    });

    try {
      final createdMessage = await ChatService.sendMessage(
        contactId: widget.chatId,
        content: text,
      );

      final newMessage = ChatMessageModel.fromBackend(
        createdMessage,
        currentUserId: _currentUserId,
      );

      if (!mounted) return;

      setState(() {
        messages.insert(0, newMessage);
        isSending = false;
      });

      _messageController.clear();

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSending = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo enviar el mensaje: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleVoiceMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mensajes de voz próximamente'),
        duration: Duration(milliseconds: 1000),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor = isDarkMode ? const Color(0xFF121212) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(context),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child:
                  isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF10B970),
                        ),
                      )
                      : messages.isEmpty
                      ? _buildEmptyState(context)
                      : RefreshIndicator(
                        color: const Color(0xFF10B970),
                        onRefresh: () => _fetchMessages(showLoading: false),
                        child: ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.fromLTRB(
                            15,
                            20,
                            15,
                            ResponsiveHelper.bottomSafe(context) + 20,
                          ),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            return _buildMessageBubble(messages[index]);
                          },
                        ),
                      ),
            ),

            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final Color appBarColor =
        isDarkMode ? const Color(0xFF121212) : Colors.white;

    final Color textColor = isDarkMode ? Colors.white : Colors.black87;

    final avatarImage = _buildAvatarImage(widget.chatAvatar);

    return AppBar(
      backgroundColor: appBarColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(PhosphorIconsRegular.caretLeft, color: textColor, size: 30),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor:
                    isDarkMode ? Colors.grey[800] : Colors.grey[200],
                backgroundImage: avatarImage,
                child:
                    avatarImage == null
                        ? Icon(
                          PhosphorIconsRegular.user,
                          color:
                              isDarkMode ? Colors.grey[500] : Colors.grey[600],
                        )
                        : null,
              ),

              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B970),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          isDarkMode ? const Color(0xFF121212) : Colors.white,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.chatName,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const Text(
                  'Chat activo',
                  style: TextStyle(
                    color: Color(0xFF10B970),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(PhosphorIconsRegular.phone, color: textColor, size: 24),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Llamadas próximamente'),
                duration: Duration(milliseconds: 900),
              ),
            );
          },
        ),
        IconButton(
          icon: Icon(
            PhosphorIconsRegular.videoCamera,
            color: textColor,
            size: 24,
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Videollamadas próximamente'),
                duration: Duration(milliseconds: 900),
              ),
            );
          },
        ),
        const SizedBox(width: 5),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        24,
        80,
        24,
        ResponsiveHelper.bottomSafe(context) + 24,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.chatCircleText,
            size: 60,
            color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
          ),

          const SizedBox(height: 15),

          Text(
            'No hay mensajes aún.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            '¡Envía el primero!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel message) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final Color receivedBubbleColor =
        isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade100;

    final Color receivedTextColor = isDarkMode ? Colors.white : Colors.black87;

    final avatarImage = _buildAvatarImage(widget.chatAvatar);

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        mainAxisAlignment:
            message.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isMe) ...[
            CircleAvatar(
              radius: 12,
              backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
              backgroundImage: avatarImage,
              child:
                  avatarImage == null
                      ? Icon(
                        PhosphorIconsRegular.user,
                        size: 14,
                        color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                      )
                      : null,
            ),

            const SizedBox(width: 8),
          ],

          Flexible(
            child: Column(
              crossAxisAlignment:
                  message.isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color:
                        message.isMe
                            ? const Color(0xFF10B970)
                            : receivedBubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft:
                          message.isMe
                              ? const Radius.circular(20)
                              : const Radius.circular(5),
                      bottomRight:
                          message.isMe
                              ? const Radius.circular(5)
                              : const Radius.circular(20),
                    ),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: message.isMe ? Colors.white : receivedTextColor,
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  message.time,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final Color inputBgColor =
        isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade100;

    final Color containerBgColor =
        isDarkMode ? const Color(0xFF121212) : Colors.white;

    final Color borderColor =
        isDarkMode ? Colors.grey.shade900 : Colors.grey.shade200;

    final Color textColor = isDarkMode ? Colors.white : Colors.black87;

    return Container(
      padding: EdgeInsets.fromLTRB(
        15,
        10,
        15,
        ResponsiveHelper.bottomSafe(context) + 10,
      ),
      decoration: BoxDecoration(
        color: containerBgColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            icon: Icon(
              PhosphorIconsRegular.plusCircle,
              color: isDarkMode ? Colors.grey[400] : Colors.grey,
              size: 26,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Adjuntos próximamente'),
                  duration: Duration(milliseconds: 900),
                ),
              );
            },
          ),

          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: inputBgColor,
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                enabled: !isSending,
                style: TextStyle(color: textColor),
                cursorColor: const Color(0xFF10B970),
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje.',
                  hintStyle: TextStyle(
                    color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          Container(
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: isTyping ? const Color(0xFF10B970) : inputBgColor,
              shape: BoxShape.circle,
            ),
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
                      : Icon(
                        isTyping
                            ? PhosphorIconsFill.paperPlaneRight
                            : PhosphorIconsFill.microphone,
                        color:
                            isTyping
                                ? Colors.white
                                : isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                        size: 20,
                      ),
              onPressed:
                  isSending
                      ? null
                      : isTyping
                      ? _sendMessage
                      : _handleVoiceMessage,
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider? _buildAvatarImage(String value) {
    if (value.isEmpty) return null;

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return NetworkImage(value);
    }

    try {
      final cleanBase64 = value.contains(',') ? value.split(',').last : value;
      final Uint8List bytes = base64Decode(cleanBase64);

      return MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }
}

// ---------------------------------------------------------------------------
// MODELO DE DATOS DEL MENSAJE
// ---------------------------------------------------------------------------
class ChatMessageModel {
  final String id;
  final String text;
  final String time;
  final bool isMe;

  ChatMessageModel({
    required this.id,
    required this.text,
    required this.time,
    required this.isMe,
  });

  factory ChatMessageModel.fromBackend(
    Map<String, dynamic> json, {
    required String currentUserId,
  }) {
    final senderId = json['sender_id']?.toString() ?? '';

    return ChatMessageModel(
      id: json['id']?.toString() ?? '',
      text: json['content']?.toString() ?? '',
      time: _formatTime(json['created_at']?.toString()),
      isMe: senderId == currentUserId,
    );
  }

  static String _formatTime(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) {
      return '';
    }

    try {
      final date = DateTime.parse(rawDate).toLocal();

      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');

      return '$hour:$minute';
    } catch (_) {
      return '';
    }
  }
}
