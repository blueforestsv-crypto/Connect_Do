import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/models/publication_model.dart';
import 'package:connect_do/services/theme_service.dart';
import 'package:connect_do/services/publication_api_service.dart';
import 'package:connect_do/services/saved_publication_service.dart';

import 'package:connect_do/screens/main_content/contacts/contacts_screen.dart';
import 'package:connect_do/screens/auth/login/login_screen.dart';

import 'package:connect_do/widgets/publication_card.dart';
import 'package:connect_do/utils/responsive_helper.dart';

import 'widgets/profile_header.dart';
import 'widgets/profile_technical_tab.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isDarkMode = false;
  bool _isPrivateProfile = false;

  @override
  void initState() {
    super.initState();

    _isDarkMode = ThemeService.isDarkMode;
    _loadProfileSettings();
  }

  // ============================
  // CARGAR AJUSTES DEL PERFIL
  // ============================
  Future<void> _loadProfileSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      _isPrivateProfile = prefs.getBool('isPrivateProfile') ?? false;
    });
  }

  // ============================
  // GUARDAR PERFIL PRIVADO
  // ============================
  Future<void> _savePrivateProfile(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('isPrivateProfile', value);
  }

  // ============================
  // CERRAR SESIÓN
  // ============================
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();

    // Cerramos sesión real para que no quede token activo en el front.
    await prefs.setBool('sesion_activa', false);
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('accessToken');
    await prefs.remove('token');

    // No borramos usuario_actual para que siga apareciendo "Entrar como..."
    // si tu login rápido todavía lo usa.

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isDarkMode ? const Color(0xFF121212) : Colors.white;

    final tabTextColor = _isDarkMode ? Colors.white : const Color(0xFF2563EB);

    final unselectedTabColor =
        _isDarkMode ? Colors.white70 : const Color(0xFF22C55E);

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      body: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            // ================= HEADER =================
            ProfileHeader(isDarkMode: _isDarkMode, onMenuTap: _showMainMenu),

            // ================= TABS =================
            Container(
              color: bgColor,
              child: TabBar(
                isScrollable: true,
                indicatorColor: const Color(0xFF2563EB),
                labelColor: tabTextColor,
                unselectedLabelColor: unselectedTabColor,
                tabs: const [
                  Tab(text: "Perfil técnico"),
                  Tab(text: "Publicaciones"),
                  Tab(text: "Red"),
                  Tab(text: "Guardadas"),
                ],
              ),
            ),

            // ================= TAB CONTENT =================
            Expanded(
              child: TabBarView(
                children: [
                  ProfileTechnicalTab(
                    isDarkMode: _isDarkMode,
                    isPrivateProfile: _isPrivateProfile,
                  ),

                  const UserPublicationsTab(),

                  const ContactsScreen(),

                  const SavedPublicationsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= MENU PRINCIPAL =================
  void _showMainMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              0,
              12,
              0,
              ResponsiveHelper.bottomSafe(context) + 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),

                ListTile(
                  leading: Icon(
                    Icons.settings,
                    color: _isDarkMode ? Colors.white : const Color(0xFF2563EB),
                  ),
                  title: Text(
                    "Configuración",
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showConfigMenu();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ================= CONFIRMAR CIERRE DE SESIÓN =================
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text(
            "Cerrar sesión",
            style: TextStyle(
              color: _isDarkMode ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            "¿Seguro que quieres cerrar sesión?",
            style: TextStyle(
              color: _isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _logout();
              },
              child: const Text(
                "Cerrar sesión",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  // ================= CONFIGURACIÓN =================
  void _showConfigMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  ResponsiveHelper.bottomSafe(context) + 20,
                ),
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
                      "Configuración",
                      style: TextStyle(
                        color: _isDarkMode ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),

                    const SizedBox(height: 12),

                    SwitchListTile(
                      activeThumbColor: const Color(0xFF22C55E),
                      title: Text(
                        "Modo Oscuro",
                        style: TextStyle(
                          color: _isDarkMode ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        "Aplicar tema oscuro en toda la app",
                        style: TextStyle(
                          color: _isDarkMode ? Colors.white60 : Colors.grey,
                        ),
                      ),
                      value: _isDarkMode,
                      onChanged: (val) async {
                        setModalState(() {
                          _isDarkMode = val;
                        });

                        setState(() {
                          _isDarkMode = val;
                        });

                        await ThemeService.setDarkMode(val);
                      },
                    ),

                    SwitchListTile(
                      activeThumbColor: const Color(0xFF22C55E),
                      title: Text(
                        "Perfil Privado",
                        style: TextStyle(
                          color: _isDarkMode ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        "Ocultar información personal del perfil",
                        style: TextStyle(
                          color: _isDarkMode ? Colors.white60 : Colors.grey,
                        ),
                      ),
                      value: _isPrivateProfile,
                      onChanged: (val) async {
                        setModalState(() {
                          _isPrivateProfile = val;
                        });

                        setState(() {
                          _isPrivateProfile = val;
                        });

                        await _savePrivateProfile(val);
                      },
                    ),

                    const SizedBox(height: 8),

                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: const Text(
                        "Cerrar sesión",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _confirmLogout();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// =====================================================
// TAB DE PUBLICACIONES DEL USUARIO
// =====================================================
class UserPublicationsTab extends StatefulWidget {
  const UserPublicationsTab({super.key});

  @override
  State<UserPublicationsTab> createState() => _UserPublicationsTabState();
}

class _UserPublicationsTabState extends State<UserPublicationsTab> {
  bool isLoading = true;

  final PublicationApiService _publicationApiService = PublicationApiService();

  String currentUserName = '';
  List<PublicationModel> userPosts = [];

  @override
  void initState() {
    super.initState();
    _loadUserPublications();
  }

  Future<void> _loadUserPublications() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final userJson = prefs.getString('usuario_actual');

      String userName = '';
      String userEmail = '';

      if (userJson != null && userJson.isNotEmpty) {
        final userData = jsonDecode(userJson);

        final firstName = userData['firstName']?.toString() ?? '';
        final lastName = userData['lastName']?.toString() ?? '';
        final fullName = '$firstName $lastName'.trim();

        userEmail = userData['email']?.toString() ?? '';

        if (fullName.isNotEmpty) {
          userName = fullName;
        } else if (userEmail.isNotEmpty) {
          userName = userEmail;
        }
      }

      final publications = await _publicationApiService.getPublications();

      final filtered =
          publications.where((post) {
            final postUserName = post.userName.trim().toLowerCase();
            final currentName = userName.trim().toLowerCase();
            final currentEmail = userEmail.trim().toLowerCase();

            return postUserName == currentName || postUserName == currentEmail;
          }).toList();

      if (!mounted) return;

      setState(() {
        currentUserName = userName;
        userPosts = filtered;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar tus publicaciones: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deletePublication(PublicationModel post) async {
    // Eliminación visual por ahora.
    // Luego conectamos esto con DELETE /publications/{id}.
    setState(() {
      userPosts.removeWhere((item) => item.id == post.id);
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Publicación eliminada visualmente'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDarkMode ? const Color(0xFF121212) : Colors.white;

    final textColor = isDarkMode ? Colors.white : Colors.black87;

    final subtitleColor =
        isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;

    final iconColor = isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300;

    final bottomSpace = ResponsiveHelper.appBottomNavSpace(context);

    if (isLoading) {
      return Container(
        color: bgColor,
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF22C55E)),
        ),
      );
    }

    if (userPosts.isEmpty) {
      return Container(
        color: bgColor,
        child: RefreshIndicator(
          color: const Color(0xFF22C55E),
          backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          onRefresh: _loadUserPublications,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(35, 0, 35, bottomSpace),
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.20),

              Icon(Icons.article_outlined, size: 70, color: iconColor),

              const SizedBox(height: 16),

              Text(
                'Aún no tienes publicaciones',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Cuando publiques algo aparecerá aquí.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: bgColor,
      child: RefreshIndicator(
        color: const Color(0xFF22C55E),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        onRefresh: _loadUserPublications,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(0, 12, 0, bottomSpace),
          itemCount: userPosts.length,
          itemBuilder: (context, index) {
            final post = userPosts[index];

            return PublicationCard(
              post: post,
              onDelete: () {
                _deletePublication(post);
              },
              onSavedChanged: () {
                setState(() {});
              },
            );
          },
        ),
      ),
    );
  }
}

// =====================================================
// TAB DE PUBLICACIONES GUARDADAS
// =====================================================
class SavedPublicationsTab extends StatefulWidget {
  const SavedPublicationsTab({super.key});

  @override
  State<SavedPublicationsTab> createState() => _SavedPublicationsTabState();
}

class _SavedPublicationsTabState extends State<SavedPublicationsTab> {
  bool isLoading = true;

  List<PublicationModel> savedPosts = [];

  @override
  void initState() {
    super.initState();
    _loadSavedPublications();
  }

  Future<void> _loadSavedPublications() async {
    final data = await SavedPublicationService.getSavedPublications();

    if (!mounted) return;

    setState(() {
      savedPosts = data;
      isLoading = false;
    });
  }

  Future<void> _removeSavedPublication(PublicationModel post) async {
    await SavedPublicationService.removeSavedPublication(post.id);

    await _loadSavedPublications();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Se eliminó de guardados'),
        backgroundColor: Color(0xFF22C55E),
        duration: Duration(milliseconds: 900),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDarkMode ? const Color(0xFF121212) : Colors.white;

    final textColor = isDarkMode ? Colors.white : Colors.black87;

    final subtitleColor =
        isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;

    final iconColor = isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300;

    final bottomSpace = ResponsiveHelper.appBottomNavSpace(context);

    if (isLoading) {
      return Container(
        color: bgColor,
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF22C55E)),
        ),
      );
    }

    if (savedPosts.isEmpty) {
      return Container(
        color: bgColor,
        child: RefreshIndicator(
          color: const Color(0xFF22C55E),
          backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          onRefresh: _loadSavedPublications,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(35, 0, 35, bottomSpace),
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.20),

              Icon(Icons.bookmark_border, size: 70, color: iconColor),

              const SizedBox(height: 16),

              Text(
                'No tienes publicaciones guardadas',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Cuando guardes una publicación aparecerá aquí.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: bgColor,
      child: RefreshIndicator(
        color: const Color(0xFF22C55E),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        onRefresh: _loadSavedPublications,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(0, 12, 0, bottomSpace),
          itemCount: savedPosts.length,
          itemBuilder: (context, index) {
            final post = savedPosts[index];

            return PublicationCard(
              post: post,
              onDelete: () {
                _removeSavedPublication(post);
              },
              onSavedChanged: _loadSavedPublications,
            );
          },
        ),
      ),
    );
  }
}
