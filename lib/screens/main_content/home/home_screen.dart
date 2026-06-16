import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:connect_do/screens/main_content/chats/chatlist_screen.dart';
import 'package:connect_do/screens/main_content/home/feed_screen.dart';
import 'package:connect_do/screens/main_content/profile/profile_screen.dart';
import 'package:connect_do/screens/main_content/publication/newpublication_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

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
  void dispose() {
    _feedScrollController.dispose();
    super.dispose();
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

  Widget _buildNavItem(IconData iconRegular, IconData iconFill, int index) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        if (index == 0) {
          _goToFeed(refresh: true);
          return;
        }

        setState(() {
          _selectedIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? const Color(0xFF10B970).withValues(alpha: 0.15)
                  : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isSelected ? iconFill : iconRegular,
          color: isSelected ? const Color(0xFF10B970) : Colors.grey[400],
          size: 28,
        ),
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
        body: IndexedStack(index: _selectedIndex, children: _pages),
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
