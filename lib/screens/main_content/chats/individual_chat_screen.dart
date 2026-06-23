import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

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

  bool isTyping = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    _fetchMessages();

    _messageController.addListener(_onMessageChanged);
  }

  void _onMessageChanged() {
    setState(() {
      isTyping = _messageController.text.trim().isNotEmpty;
    });
  }

  Future<void> _fetchMessages() async {
    try {
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      setState(() {
        messages = [];
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error al cargar los mensajes")),
      );
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onMessageChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();

    if (text.isEmpty) return;

    setState(() {
      messages.insert(
        0,
        ChatMessageModel(
          id: "temp_${DateTime.now().millisecondsSinceEpoch}",
          text: text,
          time: "Ahora",
          isMe: true,
        ),
      );
    });

    _messageController.clear();

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    // BACKEND:
    // SocketService.emit('send_message', {
    //   'chatId': widget.chatId,
    //   'text': text,
    // });
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
            // ================= MENSAJES =================
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
                      : ListView.builder(
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

            // ================= INPUT =================
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
                backgroundImage:
                    widget.chatAvatar.isNotEmpty
                        ? NetworkImage(widget.chatAvatar)
                        : null,
                onBackgroundImageError: (_, __) {},
                child:
                    widget.chatAvatar.isEmpty
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
                  "En línea",
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
          onPressed: () {},
        ),
        IconButton(
          icon: Icon(
            PhosphorIconsRegular.videoCamera,
            color: textColor,
            size: 24,
          ),
          onPressed: () {},
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
            "No hay mensajes aún.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            "¡Envía el primero!",
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
              child: Icon(
                PhosphorIconsRegular.user,
                size: 14,
                color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
              ),
            ),

            const SizedBox(width: 8),
          ],

          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
          ),

          if (message.isMe) ...[
            const SizedBox(width: 8),

            Text(
              message.time,
              style: TextStyle(
                fontSize: 10,
                color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
          ],
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
            onPressed: () {},
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
                style: TextStyle(color: textColor),
                cursorColor: const Color(0xFF10B970),
                decoration: InputDecoration(
                  hintText: "Escribe un mensaje.",
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
              icon: Icon(
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
              onPressed: isTyping ? _sendMessage : _handleVoiceMessage,
            ),
          ),
        ],
      ),
    );
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

  factory ChatMessageModel.fromJson(
    Map<String, dynamic> json,
    String myUserId,
  ) {
    return ChatMessageModel(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      time: json['time'] ?? '',
      isMe: json['sender_id'] == myUserId,
    );
  }
}
