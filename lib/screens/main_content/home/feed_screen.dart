import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:connect_do/models/publication_model.dart';
import 'package:connect_do/screens/main_content/notification/notifications_screen.dart';
import 'package:connect_do/services/publication_service.dart';
import 'package:connect_do/services/notification_service.dart';
import 'package:connect_do/widgets/publication_card.dart';
import 'package:connect_do/utils/responsive_helper.dart';

class FeedScreen extends StatefulWidget {
  final ScrollController scrollController;

  const FeedScreen({super.key, required this.scrollController});

  @override
  State<FeedScreen> createState() => FeedScreenState();
}

class FeedScreenState extends State<FeedScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<PublicationModel> posts = [];

  bool isLoadingMore = false;
  bool hasMore = true;

  int unreadNotificationsCount = 0;

  String _searchQuery = '';

  bool get hasUnreadNotifications => unreadNotificationsCount > 0;

  List<PublicationModel> get filteredPosts {
    if (_searchQuery.isEmpty) {
      return posts;
    }

    return posts.where((post) {
      final userName = post.userName.toLowerCase();
      final description = post.description.toLowerCase();
      final fileName = (post.fileName ?? '').toLowerCase();

      return userName.contains(_searchQuery) ||
          description.contains(_searchQuery) ||
          fileName.contains(_searchQuery);
    }).toList();
  }

  Future<void> refreshFeed() async {
    await _loadPublications();
    await _loadUnreadNotificationsCount();
  }

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_onSearchChanged);

    _loadPublications();
    _loadUnreadNotificationsCount();

    widget.scrollController.addListener(() {
      if (widget.scrollController.position.pixels >=
              widget.scrollController.position.maxScrollExtent - 200 &&
          !isLoadingMore &&
          hasMore &&
          _searchQuery.isEmpty) {
        _loadMorePosts();
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();

    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  // ===============================
  // CARGAR NOTIFICACIONES NO LEÍDAS
  // ===============================
  Future<void> _loadUnreadNotificationsCount() async {
    final notifications = await NotificationService.getNotifications();

    if (!mounted) return;

    setState(() {
      unreadNotificationsCount =
          notifications.where((notification) => !notification.isRead).length;
    });
  }

  // ===============================
  // CARGAR PUBLICACIONES
  // ===============================
  Future<void> _loadPublications() async {
    final publications = await PublicationService.getPublications();

    if (!mounted) return;

    setState(() {
      posts = publications;
    });
  }

  // ===============================
  // REFRESH
  // ===============================
  Future<void> _refreshFeed() async {
    await _loadPublications();
    await _loadUnreadNotificationsCount();

    if (!mounted) return;

    setState(() {
      hasMore = true;
    });
  }

  // ===============================
  // ELIMINAR PUBLICACIÓN
  // ===============================
  Future<void> _deletePublication(PublicationModel post) async {
    await PublicationService.deletePublication(post.id);

    await _loadPublications();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Publicación eliminada'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ===============================
  // PAGINACIÓN PLACEHOLDER
  // ===============================
  Future<void> _loadMorePosts() async {
    if (isLoadingMore) return;

    setState(() {
      isLoadingMore = true;
    });

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    setState(() {
      isLoadingMore = false;
      hasMore = false;
    });
  }

  // ===============================
  // ABRIR NOTIFICACIONES
  // ===============================
  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );

    await _loadUnreadNotificationsCount();
  }

  // ===============================
  // BUSCADOR
  // ===============================
  Widget _buildSearchBar({
    required bool isDarkMode,
    required Color inputColor,
    required Color textColor,
    required Color hintColor,
  }) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: inputColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: textColor, fontSize: 14),
        cursorColor: const Color(0xFF22C55E),
        decoration: InputDecoration(
          hintText: 'Buscar publicaciones...',
          hintStyle: TextStyle(fontSize: 14, color: hintColor),
          prefixIcon: Icon(
            PhosphorIconsRegular.magnifyingGlass,
            color: const Color(0xFF2563EB),
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
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor = isDarkMode ? const Color(0xFF121212) : Colors.white;

    final Color searchBgColor =
        isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    final Color searchTextColor = isDarkMode ? Colors.white : Colors.black87;

    final Color hintColor =
        isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;

    final Color emptyTextColor =
        isDarkMode ? Colors.grey.shade400 : Colors.grey;

    final postsToShow = filteredPosts;
    final bottomSpace = ResponsiveHelper.appBottomNavSpace(context);

    return Scaffold(
      backgroundColor: bgColor,

      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(115),
        child: Container(
          padding: const EdgeInsets.only(
            top: 55,
            left: 15,
            right: 5,
            bottom: 10,
          ),
          color: const Color(0xFF2563EB),
          child: Row(
            children: [
              // ==========================
              // LOGO DE LA MARCA
              // ==========================
              Container(
                height: 40,
                width: 40,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Image.asset(
                  'assets/images/Connet Do.png',
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(width: 10),

              // ==========================
              // BUSCADOR
              // ==========================
              Expanded(
                child: _buildSearchBar(
                  isDarkMode: isDarkMode,
                  inputColor: searchBgColor,
                  textColor: searchTextColor,
                  hintColor: hintColor,
                ),
              ),

              const SizedBox(width: 5),

              // ==========================
              // NOTIFICACIONES CON BADGE
              // ==========================
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: Icon(
                      hasUnreadNotifications
                          ? PhosphorIconsFill.bellSimple
                          : PhosphorIconsRegular.bellSimple,
                      color:
                          hasUnreadNotifications
                              ? const Color(0xFF22C55E)
                              : Colors.white,
                      size: 28,
                    ),
                    onPressed: _openNotifications,
                  ),

                  if (hasUnreadNotifications)
                    Positioned(
                      right: 5,
                      top: 5,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape:
                              unreadNotificationsCount > 9
                                  ? BoxShape.rectangle
                                  : BoxShape.circle,
                          borderRadius:
                              unreadNotificationsCount > 9
                                  ? BorderRadius.circular(20)
                                  : null,
                          border: Border.all(
                            color: const Color(0xFF2563EB),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            unreadNotificationsCount > 9
                                ? '9+'
                                : unreadNotificationsCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),

      body: RefreshIndicator(
        color: const Color(0xFF10B970),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        onRefresh: _refreshFeed,

        child:
            posts.isEmpty
                ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(bottom: bottomSpace),
                  children: [
                    const SizedBox(height: 200),
                    Center(
                      child: Text(
                        'No hay publicaciones todavía',
                        style: TextStyle(fontSize: 16, color: emptyTextColor),
                      ),
                    ),
                  ],
                )
                : postsToShow.isEmpty
                ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(bottom: bottomSpace),
                  children: [
                    const SizedBox(height: 200),
                    Icon(
                      Icons.search_off,
                      size: 60,
                      color:
                          isDarkMode
                              ? Colors.grey.shade700
                              : Colors.grey.shade300,
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: Text(
                        'No encontramos publicaciones',
                        style: TextStyle(
                          fontSize: 16,
                          color: emptyTextColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Prueba con otro nombre o palabra clave.',
                        style: TextStyle(fontSize: 13, color: emptyTextColor),
                      ),
                    ),
                  ],
                )
                : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  controller: widget.scrollController,
                  padding: EdgeInsets.only(bottom: bottomSpace),
                  itemCount: postsToShow.length + 1,
                  itemBuilder: (context, index) {
                    if (index == postsToShow.length) {
                      return isLoadingMore && _searchQuery.isEmpty
                          ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF10B970),
                              ),
                            ),
                          )
                          : const SizedBox(height: 20);
                    }

                    final post = postsToShow[index];

                    return PublicationCard(
                      post: post,
                      onDelete: () {
                        _deletePublication(post);
                      },
                    );
                  },
                ),
      ),
    );
  }
}
