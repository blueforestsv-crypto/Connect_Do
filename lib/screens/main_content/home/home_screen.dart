import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/screens/main_content/chats/chatlist_screen.dart';
import 'package:connect_do/screens/main_content/home/feed_screen.dart';
import 'package:connect_do/screens/main_content/profile/profile_screen.dart';
import 'package:connect_do/screens/main_content/publication/newpublication_screen.dart';
import 'package:connect_do/helpers/profile_completion.dart';
import 'package:connect_do/screens/profile_setup/complete_profile_screen.dart';
import 'package:connect_do/services/chat_service.dart';
import 'package:connect_do/services/user_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  int _unreadChatCount = 0;

  Timer? _chatUnreadTimer;

  // Tarjeta "Completa tu perfil": se oculta al cerrarla hasta la próxima sesión.
  int _profilePercent = 100;
  bool _profileCardDismissed = false;

  final ScrollController _feedScrollController = ScrollController();

  final GlobalKey<FeedScreenState> _feedKey = GlobalKey<FeedScreenState>();

  late final List<Widget> _pages = [
    FeedScreen(key: _feedKey, scrollController: _feedScrollController),

    NewPublicationScreen(
      onBackToFeed: () {
        _goToFeed(refresh: true);
      },
    ),

    const ChatListScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();

    _loadUnreadChatCount();
    _loadProfileCompletion();

    _chatUnreadTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _loadUnreadChatCount();
    });
  }

  @override
  void dispose() {
    _chatUnreadTimer?.cancel();
    _feedScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUnreadChatCount() async {
    try {
      final total = await ChatService.getTotalUnreadMessages();

      if (!mounted) return;

      setState(() {
        _unreadChatCount = total;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _unreadChatCount = 0;
      });
    }
  }

  Future<void> _loadProfileCompletion() async {
    final user = await UserService.getUser();
    if (!mounted) return;
    setState(() => _profilePercent = ProfileCompletion.percent(user));
  }

  Future<void> _openCompleteProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CompleteProfileScreen()),
    );
    _loadProfileCompletion();
  }

  Widget _buildProfileCard() {
    return Material(
      color: const Color(0xFF2563EB),
      borderRadius: BorderRadius.circular(20),
      elevation: 6,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _openCompleteProfile,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: _profilePercent / 100,
                      strokeWidth: 4,
                      backgroundColor: Colors.white24,
                      color: const Color(0xFF22C55E),
                    ),
                    Text(
                      '$_profilePercent%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Completa tu perfil',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Carrera, habilidades y CV para postularte',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Ocultar',
                icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                onPressed: () => setState(() => _profileCardDismissed = true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goToFeed({bool refresh = false}) {
    setState(() {
      _selectedIndex = 0;
    });

    if (refresh) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _feedKey.currentState?.refreshFeed();

        if (_feedScrollController.hasClients) {
          _feedScrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _goToPage(int index) {
    if (index == 0) {
      _loadProfileCompletion();
      _goToFeed(refresh: true);
      return;
    }

    setState(() {
      _selectedIndex = index;
    });

    if (index == 2) {
      Future.delayed(const Duration(milliseconds: 700), () {
        _loadUnreadChatCount();
      });
    }
  }

  Widget _buildNavItem(
    IconData iconRegular,
    IconData iconFill,
    int index, {
    int badgeCount = 0,
  }) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        _goToPage(index);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                      : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSelected ? iconFill : iconRegular,
              color: isSelected ? const Color(0xFF22C55E) : Colors.grey[400],
              size: 28,
            ),
          ),

          if (badgeCount > 0)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFF1E293B), width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  badgeCount > 99 ? '99+' : badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (_selectedIndex != 0) {
          _goToFeed();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        extendBody: true,
        body: Stack(
          children: [
            IndexedStack(index: _selectedIndex, children: _pages),
            if (_selectedIndex == 0 &&
                _profilePercent < 100 &&
                !_profileCardDismissed)
              Positioned(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).padding.bottom + 100,
                child: _buildProfileCard(),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(35),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavItem(
                  PhosphorIconsRegular.houseLine,
                  PhosphorIconsFill.houseLine,
                  0,
                ),
                _buildNavItem(
                  PhosphorIconsRegular.plusSquare,
                  PhosphorIconsFill.plusSquare,
                  1,
                ),
                _buildNavItem(
                  PhosphorIconsRegular.chatsCircle,
                  PhosphorIconsFill.chatsCircle,
                  2,
                  badgeCount: _unreadChatCount,
                ),
                _buildNavItem(
                  PhosphorIconsRegular.userCircle,
                  PhosphorIconsFill.userCircle,
                  3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
