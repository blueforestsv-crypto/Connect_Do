import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:connect_do/screens/settings/account_type_screen.dart';
import 'package:connect_do/services/user_service.dart';
import 'package:connect_do/screens/settings/delete_account_screen.dart';
import 'package:connect_do/screens/settings/blocked_users_screen.dart';
import 'package:connect_do/screens/admin/moderation_screen.dart';
import 'package:connect_do/core/api/api_config.dart';
import 'package:connect_do/models/publication_model.dart';
import 'package:connect_do/screens/account/change_email_screen.dart';
import 'package:connect_do/screens/account/change_password_screen.dart';
import 'package:connect_do/screens/auth/login/login_screen.dart';
import 'package:connect_do/screens/main_content/contacts/contacts_screen.dart';
import 'package:connect_do/screens/profile_setup/complete_profile_screen.dart';
import 'package:connect_do/services/auth_service.dart';
import 'package:connect_do/services/profile_service.dart';
import 'package:connect_do/services/publication_api_service.dart';
import 'package:connect_do/services/saved_publication_service.dart';
import 'package:connect_do/services/theme_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/utils/responsive_helper.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/publication_card.dart';

import 'widgets/profile_header.dart';
import 'widgets/profile_technical_tab.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// Sube cada vez que el perfil cambia, para que encabezado y pestaña
  /// vuelvan a leer los datos.
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _syncFromServer();
  }

  Future<void> _syncFromServer() async {
    await AuthService.refreshProfileFromBackend();
    if (mounted) setState(() => _refreshKey++);
  }

  Future<void> _openEditProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CompleteProfileScreen()),
    );
    if (mounted) setState(() => _refreshKey++);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        bottom: false,
        child: DefaultTabController(
          length: 4,
          child: NestedScrollView(
            headerSliverBuilder:
                (context, _) => [
                  SliverToBoxAdapter(
                    child: ProfileHeader(
                      refreshKey: _refreshKey,
                      onEditProfile: _openEditProfile,
                      onOpenSettings: _openSettings,
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabBarDelegate(palette: palette),
                  ),
                ],
            body: TabBarView(
              children: [
                ProfileTechnicalTab(
                  refreshKey: _refreshKey,
                  onEditProfile: _openEditProfile,
                  onProfileChanged: () => setState(() => _refreshKey++),
                ),
                const UserPublicationsTab(),
                const ContactsScreen(showAppBar: false),
                const SavedPublicationsTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =====================================================
  // CONFIGURACIÓN
  // =====================================================
  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder:
          (sheetContext) => _SettingsSheet(
            onEditProfile: () {
              Navigator.pop(sheetContext);
              _openEditProfile();
            },
            onChangeEmail: () async {
              Navigator.pop(sheetContext);
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const ChangeEmailScreen()),
              );
              if (changed == true && mounted) setState(() => _refreshKey++);
            },
            onChangePassword: () {
              Navigator.pop(sheetContext);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
              );
            },
            onLogout: () {
              Navigator.pop(sheetContext);
              _confirmLogout();
            },
          ),
    );
  }

  void _confirmLogout() {
    final palette = AuthPalette.of(context);

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: palette.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Brand.radiusLg),
            ),
            title: Text(
              '¿Cerrar sesión?',
              style: TextStyle(
                fontFamily: Brand.displayFont,
                fontWeight: FontWeight.w700,
                color: palette.title,
              ),
            ),
            content: Text(
              'Podrás volver a entrar con tu correo o con Google.',
              style: TextStyle(
                fontFamily: Brand.displayFont,
                height: 1.4,
                color: palette.body,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('Cancelar', style: TextStyle(color: palette.body)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Brand.danger,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Brand.radiusSm),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _logout();
                },
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
    );
  }

  Future<void> _logout() async {
    // Se conserva la tarjeta "Hola de nuevo" del login.
    await AuthService.logout(forgetUser: false);

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}

// =====================================================
// BARRA DE PESTAÑAS FIJA
// =====================================================
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final AuthPalette palette;

  _TabBarDelegate({required this.palette});

  @override
  double get minExtent => 60;

  @override
  double get maxExtent => 60;

  @override
  Widget build(context, shrinkOffset, overlapsContent) {
    return Container(
      color: palette.background,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: palette.fieldFill,
          borderRadius: BorderRadius.circular(Brand.radiusMd),
          border: Border.all(color: palette.cardBorder),
        ),
        child: TabBar(
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(Brand.radiusSm),
            boxShadow: [
              BoxShadow(
                color: palette.shadow,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          labelColor: palette.title,
          unselectedLabelColor: palette.muted,
          labelPadding: EdgeInsets.zero,
          labelStyle: const TextStyle(
            fontFamily: Brand.displayFont,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: Brand.displayFont,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Perfil'),
            Tab(text: 'Posts'),
            Tab(text: 'Red'),
            Tab(text: 'Guardadas'),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) =>
      oldDelegate.palette.isDark != palette.isDark;
}

// =====================================================
// HOJA DE CONFIGURACIÓN
// =====================================================
class _SettingsSheet extends StatefulWidget {
  final VoidCallback onEditProfile;
  final VoidCallback onChangeEmail;
  final VoidCallback onChangePassword;
  final VoidCallback onLogout;

  const _SettingsSheet({
    required this.onEditProfile,
    required this.onChangeEmail,
    required this.onChangePassword,
    required this.onLogout,
  });

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  bool _isDark = ThemeService.isDarkMode;
  bool _isAdmin = false;

  void _open(Widget screen) {
    // Se toma el navegador antes de cerrar la hoja (su contexto se va).
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(MaterialPageRoute(builder: (_) => screen));
  }

  bool? _isPrivate; // null mientras carga
  bool _savingPrivacy = false;

  @override
  void initState() {
    super.initState();
    // Rol actualizado (para mostrar "Moderación" a los administradores).
    AuthService.refreshAccount().then((_) => UserService.getUser()).then((
      user,
    ) {
      if (mounted) setState(() => _isAdmin = user['role'] == 'admin');
    });
    ProfileService.getMyProfile().then((profile) {
      if (mounted) {
        setState(() => _isPrivate = profile?['is_private'] == true);
      }
    });
  }

  Future<void> _setPrivate(bool value) async {
    setState(() {
      _isPrivate = value;
      _savingPrivacy = true;
    });
    try {
      await ProfileService.updateMyProfile(isPrivate: value);
      if (!mounted) return;
      showAuthMessage(
        context,
        value
            ? 'Perfil privado: solo tus contactos ven tu información'
            : 'Perfil público',
        type: AuthMessageType.success,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isPrivate = !value);
      showAuthMessage(context, 'No se pudo cambiar. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _savingPrivacy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        ResponsiveHelper.bottomSafe(context) + 16,
      ),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Brand.radiusLg),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.fieldBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Configuración',
              style: TextStyle(
                fontFamily: Brand.displayFont,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: palette.title,
              ),
            ),
            const SizedBox(height: 16),
            _group(palette, 'Cuenta', [
              _SettingsTile(
                icon: PhosphorIconsRegular.userCircle,
                title: 'Editar perfil',
                subtitle: 'Estudios, habilidades, teléfono y CV',
                onTap: widget.onEditProfile,
              ),
              _SettingsTile(
                icon: PhosphorIconsRegular.envelopeSimple,
                title: 'Cambiar correo',
                subtitle: 'Te enviaremos un código al correo nuevo',
                onTap: widget.onChangeEmail,
              ),
              _SettingsTile(
                icon: PhosphorIconsRegular.lockSimple,
                title: 'Cambiar contraseña',
                onTap: widget.onChangePassword,
              ),
              _SettingsTile(
                icon: PhosphorIconsRegular.buildings,
                title: 'Tipo de cuenta',
                subtitle: 'Personal o empresa (para publicar empleos)',
                onTap: () => _open(const AccountTypeScreen()),
              ),
            ]),
            _group(palette, 'Preferencias', [
              _SettingsTile(
                icon: PhosphorIconsRegular.moon,
                title: 'Modo oscuro',
                trailing: Switch.adaptive(
                  value: _isDark,
                  activeTrackColor: Brand.blue,
                  onChanged: (value) async {
                    setState(() => _isDark = value);
                    await ThemeService.setDarkMode(value);
                  },
                ),
              ),
              _SettingsTile(
                icon: PhosphorIconsRegular.eyeSlash,
                title: 'Perfil privado',
                subtitle: 'Solo tus contactos ven tu información y posts',
                trailing:
                    _isPrivate == null
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Brand.blue,
                          ),
                        )
                        : Switch.adaptive(
                          value: _isPrivate!,
                          activeTrackColor: Brand.blue,
                          onChanged: _savingPrivacy ? null : _setPrivate,
                        ),
              ),
            ]),
            _group(palette, 'Privacidad y seguridad', [
              _SettingsTile(
                icon: PhosphorIconsRegular.prohibit,
                title: 'Personas bloqueadas',
                onTap: () => _open(const BlockedUsersScreen()),
              ),
              _SettingsTile(
                icon: PhosphorIconsRegular.fileText,
                title: 'Términos y privacidad',
                onTap: () {
                  Navigator.pop(context);
                  launchUrl(
                    Uri.parse('${ApiConfig.baseUrl}/privacidad'),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
              if (_isAdmin)
                _SettingsTile(
                  icon: PhosphorIconsRegular.shieldCheck,
                  title: 'Moderación',
                  subtitle: 'Revisar reportes',
                  onTap: () => _open(const ModerationScreen()),
                ),
            ]),
            _group(palette, null, [
              _SettingsTile(
                icon: PhosphorIconsRegular.signOut,
                title: 'Cerrar sesión',
                danger: true,
                onTap: widget.onLogout,
              ),
              _SettingsTile(
                icon: PhosphorIconsRegular.trash,
                title: 'Eliminar mi cuenta',
                danger: true,
                onTap: () => _open(const DeleteAccountScreen()),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _group(AuthPalette palette, String? title, List<Widget> tiles) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontFamily: Brand.displayFont,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: palette.muted,
                ),
              ),
            ),
          // Material (no Container) para que se vea el efecto al tocar.
          Material(
            color: palette.card,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Brand.radiusLg),
              side: BorderSide(color: palette.cardBorder),
            ),
            child: Column(
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, indent: 60, color: palette.cardBorder),
                  tiles[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool danger;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final color = danger ? Brand.danger : palette.title;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: (danger ? Brand.danger : Brand.blue).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 19, color: danger ? Brand.danger : Brand.blue),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: Brand.displayFont,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      subtitle:
          subtitle == null
              ? null
              : Text(
                subtitle!,
                style: TextStyle(
                  fontFamily: Brand.displayFont,
                  fontSize: 12.5,
                  color: palette.muted,
                ),
              ),
      trailing:
          trailing ??
          (onTap == null || danger
              ? null
              : Icon(
                PhosphorIconsRegular.caretRight,
                size: 18,
                color: palette.muted,
              )),
    );
  }
}

// =====================================================
// PESTAÑA: MIS PUBLICACIONES
// =====================================================
class UserPublicationsTab extends StatefulWidget {
  const UserPublicationsTab({super.key});

  @override
  State<UserPublicationsTab> createState() => _UserPublicationsTabState();
}

class _UserPublicationsTabState extends State<UserPublicationsTab>
    with AutomaticKeepAliveClientMixin {
  final PublicationApiService _api = PublicationApiService();

  bool _isLoading = true;
  bool _hasError = false;
  List<PublicationModel> _posts = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final posts = await _api.getPublications(mine: true, limit: 50);
      if (!mounted) return;
      setState(() {
        // Por si el servidor aún no conoce el filtro "mine".
        _posts = posts.where((post) => post.isMine).toList();
        _isLoading = false;
        _hasError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _delete(PublicationModel post) async {
    final index = _posts.indexOf(post);
    setState(() => _posts.remove(post));

    try {
      await _api.deletePublication(post.id);
      if (mounted) {
        showAuthMessage(
          context,
          'Publicación eliminada',
          type: AuthMessageType.info,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _posts.insert(index.clamp(0, _posts.length), post));
      showAuthMessage(context, 'No se pudo eliminar la publicación.');
    }
  }

  void _replace(PublicationModel updated) {
    final index = _posts.indexWhere((p) => p.id == updated.id);
    if (index != -1) _posts[index] = updated;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) return const _TabLoading();

    return RefreshIndicator(
      color: Brand.blue,
      onRefresh: _load,
      child:
          _posts.isEmpty
              ? _TabMessage(
                icon:
                    _hasError
                        ? PhosphorIconsRegular.cloudSlash
                        : PhosphorIconsRegular.newspaper,
                title:
                    _hasError
                        ? 'No se pudieron cargar'
                        : 'Aún no has publicado',
                subtitle:
                    _hasError
                        ? 'Desliza hacia abajo para reintentar.'
                        : 'Comparte un logro, un proyecto o una oportunidad '
                            'desde el botón + de abajo.',
              )
              : ListView.builder(
                padding: EdgeInsets.only(
                  top: 8,
                  bottom: ResponsiveHelper.appBottomNavSpace(context),
                ),
                itemCount: _posts.length,
                itemBuilder: (context, index) {
                  final post = _posts[index];
                  return PublicationCard(
                    key: ValueKey(post.id),
                    post: post,
                    index: index,
                    onDelete: () => _delete(post),
                    onChanged: _replace,
                  );
                },
              ),
    );
  }
}

// =====================================================
// PESTAÑA: GUARDADAS
// =====================================================
class SavedPublicationsTab extends StatefulWidget {
  const SavedPublicationsTab({super.key});

  @override
  State<SavedPublicationsTab> createState() => _SavedPublicationsTabState();
}

class _SavedPublicationsTabState extends State<SavedPublicationsTab> {
  bool _isLoading = true;
  List<PublicationModel> _posts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<PublicationModel> posts;
    try {
      // Lo guardado antes solo en el teléfono se pasa al servidor una vez.
      await SavedPublicationService.migrateToServer();
      posts = await PublicationApiService().getPublications(
        saved: true,
        limit: 100,
      );
    } catch (_) {
      posts = _posts;
    }
    if (!mounted) return;
    setState(() {
      _posts = posts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const _TabLoading();

    return RefreshIndicator(
      color: Brand.blue,
      onRefresh: _load,
      child:
          _posts.isEmpty
              ? const _TabMessage(
                icon: PhosphorIconsRegular.bookmarkSimple,
                title: 'Nada guardado todavía',
                subtitle:
                    'Toca el ícono de guardar en una publicación para '
                    'encontrarla aquí después.',
              )
              : ListView.builder(
                padding: EdgeInsets.only(
                  top: 8,
                  bottom: ResponsiveHelper.appBottomNavSpace(context),
                ),
                itemCount: _posts.length,
                itemBuilder: (context, index) {
                  final post = _posts[index];
                  // Sin onDelete: aquí solo se puede quitar de guardados
                  // (con el ícono), no borrar la publicación.
                  return PublicationCard(
                    key: ValueKey(post.id),
                    post: post,
                    index: index,
                    onSavedChanged: _load,
                  );
                },
              ),
    );
  }
}

// =====================================================
// ESTADOS DE LAS PESTAÑAS
// =====================================================
class _TabLoading extends StatelessWidget {
  const _TabLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: Brand.blue, strokeWidth: 2.5),
    );
  }
}

class _TabMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _TabMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    // ListView para que el "deslizar para actualizar" funcione.
    return ListView(
      padding: const EdgeInsets.fromLTRB(40, 48, 40, 120),
      children: [
        Center(
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Brand.blue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: Brand.blue),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: Brand.displayFont,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: palette.title,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: Brand.displayFont,
            fontSize: 14,
            height: 1.4,
            color: palette.body,
          ),
        ),
      ],
    );
  }
}
