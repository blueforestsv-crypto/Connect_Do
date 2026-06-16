import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:project_ena/utils/responsive_helper.dart';

import 'individual_chat_screen.dart';

// ---------------------------------------------------------------------------
// PANTALLA DE LISTA DE CHATS
// ---------------------------------------------------------------------------
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<ChatListModel> chats = [];
  List<ChatListModel> filteredChats = [];

  bool isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_onSearchChanged);

    _fetchChats();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();

    super.dispose();
  }

  void _onSearchChanged() {
    _filterChats(_searchController.text);
  }

  Future<void> _fetchChats() async {
    try {
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      setState(() {
        chats = [];
        filteredChats = chats;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error al cargar los chats")),
      );
    }
  }

  void _filterChats(String query) {
    final cleanQuery = query.trim().toLowerCase();

    setState(() {
      _searchQuery = cleanQuery;

      if (cleanQuery.isEmpty) {
        filteredChats = chats;
      } else {
        filteredChats =
            chats.where((chat) {
              final userName = chat.userName.toLowerCase();
              final lastMessage = chat.lastMessage.toLowerCase();

              return userName.contains(cleanQuery) ||
                  lastMessage.contains(cleanQuery);
            }).toList();
      }
    });
  }

  void _showOptions(BuildContext context, String name) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              0,
              16,
              0,
              ResponsiveHelper.bottomSafe(context) + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),

                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),

                Divider(
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                ),

                ListTile(
                  leading: const Icon(
                    PhosphorIconsRegular.pushPin,
                    color: Color(0xFF2563EB),
                  ),
                  title: Text(
                    "Fijar chat",
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  onTap: () => Navigator.pop(context),
                ),

                ListTile(
                  leading: const Icon(
                    PhosphorIconsRegular.bellSlash,
                    color: Colors.orange,
                  ),
                  title: Text(
                    "Silenciar",
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  onTap: () => Navigator.pop(context),
                ),

                ListTile(
                  leading: const Icon(
                    PhosphorIconsRegular.trash,
                    color: Colors.red,
                  ),
                  title: const Text(
                    "Borrar chat",
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar({
    required bool isDarkMode,
    required Color inputColor,
    required Color textColor,
    required Color hintColor,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: inputColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDarkMode ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
        child: TextField(
          controller: _searchController,
          style: TextStyle(color: textColor),
          cursorColor: const Color(0xFF22C55E),
          decoration: InputDecoration(
            hintText: 'Buscar chats...',
            hintStyle: TextStyle(fontSize: 14, color: hintColor),
            prefixIcon: const Icon(
              PhosphorIconsRegular.magnifyingGlass,
              color: Color(0xFF2563EB),
              size: 20,
            ),
            suffixIcon:
                _searchQuery.isNotEmpty
                    ? IconButton(
                      icon: Icon(
                        Icons.close,
                        color:
                            isDarkMode
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                        size: 18,
                      ),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                    : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required bool isDarkMode,
    required double bottomSpace,
  }) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(24, 80, 24, bottomSpace),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isEmpty
                ? PhosphorIconsRegular.chatsCircle
                : Icons.search_off,
            size: 60,
            color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
          ),

          const SizedBox(height: 15),

          Text(
            _searchQuery.isEmpty
                ? "No tienes mensajes aún"
                : "No se encontraron chats",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
              fontSize: 16,
              fontWeight:
                  _searchQuery.isEmpty ? FontWeight.normal : FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            _searchQuery.isEmpty
                ? "¡Conecta con empresas o talentos!"
                : "Prueba con otro nombre o palabra clave.",
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

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor = isDarkMode ? const Color(0xFF121212) : Colors.white;

    final Color appBarColor =
        isDarkMode ? const Color(0xFF121212) : Colors.white;

    final Color textColor = isDarkMode ? Colors.white : Colors.black87;

    final Color searchBgColor =
        isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade100;

    final Color hintColor =
        isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500;

    final bottomSpace = ResponsiveHelper.appBottomNavSpace(context);

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          "Mensajes",
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              PhosphorIconsRegular.pencilSimple,
              color: textColor,
              size: 26,
            ),
            onPressed: () {
              // Abrir pantalla para buscar e iniciar un nuevo chat
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(
            isDarkMode: isDarkMode,
            inputColor: searchBgColor,
            textColor: textColor,
            hintColor: hintColor,
          ),

          Expanded(
            child:
                isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF10B970),
                      ),
                    )
                    : filteredChats.isEmpty
                    ? _buildEmptyState(
                      isDarkMode: isDarkMode,
                      bottomSpace: bottomSpace,
                    )
                    : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.only(bottom: bottomSpace),
                      itemCount: filteredChats.length,
                      itemBuilder: (context, index) {
                        return _buildChatTile(filteredChats[index]);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTile(ChatListModel chat) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final Color textColor = isDarkMode ? Colors.white : Colors.black87;

    final Color subtitleColor =
        isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => IndividualChatScreen(
                  chatId: chat.chatId,
                  chatName: chat.userName,
                  chatAvatar: chat.userAvatar,
                ),
          ),
        );
      },
      onLongPress: () => _showOptions(context, chat.userName),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor:
                      isDarkMode ? Colors.grey[800] : Colors.grey[200],
                  backgroundImage:
                      chat.userAvatar.isNotEmpty
                          ? NetworkImage(chat.userAvatar)
                          : null,
                  onBackgroundImageError: (_, __) {},
                  child:
                      chat.userAvatar.isEmpty
                          ? Icon(
                            PhosphorIconsRegular.user,
                            color:
                                isDarkMode
                                    ? Colors.grey[500]
                                    : Colors.grey[600],
                          )
                          : null,
                ),

                if (chat.isOnline)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B970),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              isDarkMode
                                  ? const Color(0xFF121212)
                                  : Colors.white,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 15),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          chat.userName,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      const SizedBox(width: 10),

                      Text(
                        chat.lastMessageTime,
                        style: TextStyle(
                          color:
                              chat.unreadCount > 0
                                  ? const Color(0xFF10B970)
                                  : subtitleColor,
                          fontSize: 12,
                          fontWeight:
                              chat.unreadCount > 0
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.lastMessage,
                          style: TextStyle(
                            color:
                                chat.unreadCount > 0
                                    ? textColor
                                    : subtitleColor,
                            fontSize: 14,
                            fontWeight:
                                chat.unreadCount > 0
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      if (chat.unreadCount > 0) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B970),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            chat.unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MODELO DE DATOS
// ---------------------------------------------------------------------------
class ChatListModel {
  final String chatId;
  final String userId;
  final String userName;
  final String userAvatar;
  final String lastMessage;
  final String lastMessageTime;
  final int unreadCount;
  final bool isOnline;

  ChatListModel({
    required this.chatId,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isOnline = false,
  });

  factory ChatListModel.fromJson(Map<String, dynamic> json) {
    return ChatListModel(
      chatId: json['chat_id'] ?? '',
      userId: json['user_id'] ?? '',
      userName: json['user_name'] ?? 'Usuario Desconocido',
      userAvatar: json['user_avatar'] ?? '',
      lastMessage: json['last_message'] ?? '',
      lastMessageTime: json['last_message_time'] ?? '',
      unreadCount: json['unread_count'] ?? 0,
      isOnline: json['is_online'] ?? false,
    );
  }
}
