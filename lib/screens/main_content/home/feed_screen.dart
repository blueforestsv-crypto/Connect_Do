import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/models/publication_model.dart';
import 'package:connect_do/screens/main_content/notification/notifications_screen.dart';
import 'package:connect_do/services/application_service.dart';
import 'package:connect_do/services/notification_service.dart';
import 'package:connect_do/services/publication_api_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/utils/responsive_helper.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/publication_card.dart';

class FeedScreen extends StatefulWidget {
  final ScrollController scrollController;

  const FeedScreen({super.key, required this.scrollController});

  @override
  State<FeedScreen> createState() => FeedScreenState();
}

/// Filtros por tipo; el filtrado lo hace el servidor.
const List<({String? type, String label, IconData icon})> _filters = [
  (type: null, label: 'Todo', icon: PhosphorIconsRegular.squaresFour),
  (type: 'job', label: 'Empleos', icon: PhosphorIconsRegular.briefcase),
  (type: 'internship', label: 'Pasantías', icon: PhosphorIconsRegular.student),
  (
    type: 'social_service',
    label: 'Servicio social',
    icon: PhosphorIconsRegular.handHeart,
  ),
  (type: 'freelance', label: 'Freelance', icon: PhosphorIconsRegular.laptop),
  (
    type: 'announcement',
    label: 'Convocatorias',
    icon: PhosphorIconsRegular.megaphone,
  ),
  (type: 'general', label: 'Posts', icon: PhosphorIconsRegular.newspaper),
];

class FeedScreenState extends State<FeedScreen> {
  static const int _pageSize = 10;
  static const String _hiddenKey = 'feed_publicaciones_ocultas';

  final TextEditingController _searchController = TextEditingController();
  final PublicationApiService _api = PublicationApiService();
  Timer? _searchDebounce;

  List<PublicationModel> _posts = [];
  Set<String> _hiddenIds = {};

  bool _isLoading = true;
  String? _error;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  /// Evita que una respuesta vieja pise una nueva al cambiar de filtro.
  int _requestId = 0;

  String? _type;
  String _searchQuery = '';
  int _unreadNotifications = 0;

  /// La búsqueda la hace el servidor (en todas las publicaciones, no solo
  /// en las ya cargadas); aquí solo se quitan las ocultas.
  List<PublicationModel> get _visiblePosts =>
      _posts.where((post) => !_hiddenIds.contains(post.id)).toList();

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
    _loadHidden().then((_) => _loadFirstPage());
    _loadUnreadNotifications();
    _loadMyApplications();
  }

  /// Para que las oportunidades ya postuladas digan "Postulado".
  Future<void> _loadMyApplications() async {
    try {
      await ApplicationService.getMyApplications();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  /// Lo llama el Home al tocar la pestaña de inicio.
  Future<void> refreshFeed() async {
    await Future.wait([_loadFirstPage(), _loadUnreadNotifications()]);
  }

  // ===============================
  // CARGA DE DATOS
  // ===============================
  Future<void> _loadHidden() async {
    final prefs = await SharedPreferences.getInstance();
    _hiddenIds = (prefs.getStringList(_hiddenKey) ?? const []).toSet();
  }

  Future<void> _loadFirstPage({bool showSkeleton = false}) async {
    final requestId = ++_requestId;

    setState(() {
      if (showSkeleton || _posts.isEmpty) _isLoading = true;
      _error = null;
    });

    try {
      final page = await _api.getPublications(
        type: _type,
        query: _searchQuery,
        limit: _pageSize,
      );
      if (!mounted || requestId != _requestId) return;

      setState(() {
        _posts = page;
        _hasMore = page.length == _pageSize;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _isLoading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;

    final requestId = _requestId;
    setState(() => _isLoadingMore = true);

    try {
      final page = await _api.getPublications(
        type: _type,
        query: _searchQuery,
        limit: _pageSize,
        offset: _posts.length,
      );
      if (!mounted || requestId != _requestId) return;

      final knownIds = _posts.map((p) => p.id).toSet();
      setState(() {
        _posts.addAll(page.where((p) => !knownIds.contains(p.id)));
        _hasMore = page.length == _pageSize;
      });
    } catch (_) {
      // Se reintenta al seguir desplazándose.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadUnreadNotifications() async {
    final unread = await NotificationService.getUnreadCount();
    if (mounted) setState(() => _unreadNotifications = unread);
  }

  void _onScroll() {
    final position = widget.scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  // ===============================
  // ACCIONES
  // ===============================
  void _selectType(String? type) {
    if (type == _type) return;
    setState(() {
      _type = type;
      _posts = [];
      _hasMore = true;
    });
    _loadFirstPage(showSkeleton: true);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      final query = value.trim();
      if (!mounted || query == _searchQuery) return;
      setState(() {
        _searchQuery = query;
        _posts = [];
        _hasMore = true;
      });
      _loadFirstPage(showSkeleton: true);
    });
  }

  void _replacePost(PublicationModel updated) {
    final index = _posts.indexWhere((p) => p.id == updated.id);
    if (index != -1) _posts[index] = updated;
  }

  Future<void> _deletePost(PublicationModel post) async {
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

  Future<void> _hidePost(PublicationModel post) async {
    setState(() => _hiddenIds.add(post.id));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_hiddenKey, _hiddenIds.toList());

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Brand.radiusMd),
          ),
          backgroundColor: const Color(0xFF1E293B),
          content: const Text('Publicación ocultada'),
          action: SnackBarAction(
            label: 'Deshacer',
            textColor: Brand.green,
            onPressed: () async {
              setState(() => _hiddenIds.remove(post.id));
              await prefs.setStringList(_hiddenKey, _hiddenIds.toList());
            },
          ),
        ),
      );
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    await _loadUnreadNotifications();
  }

  // ===============================
  // UI
  // ===============================
  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final bottomSpace = ResponsiveHelper.appBottomNavSpace(context);
    final posts = _visiblePosts;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: Brand.blue,
          backgroundColor: palette.card,
          edgeOffset: 150,
          onRefresh: refreshFeed,
          child: CustomScrollView(
            controller: widget.scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildAppBar(palette),
              if (_isLoading)
                SliverList.builder(
                  itemCount: 3,
                  itemBuilder: (_, __) => const _SkeletonCard(),
                )
              else if (_error != null && _posts.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _FeedMessage(
                    icon: PhosphorIconsRegular.cloudSlash,
                    title: 'No pudimos cargar el inicio',
                    subtitle: 'Revisa tu conexión e inténtalo de nuevo.',
                    actionLabel: 'Reintentar',
                    onAction: () => _loadFirstPage(showSkeleton: true),
                  ),
                )
              else if (posts.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child:
                      _searchQuery.isNotEmpty
                          ? const _FeedMessage(
                            icon: PhosphorIconsRegular.magnifyingGlass,
                            title: 'Sin resultados',
                            subtitle: 'Prueba con otra palabra.',
                          )
                          : _FeedMessage(
                            icon: PhosphorIconsRegular.newspaper,
                            title:
                                _type == null
                                    ? 'Todavía no hay publicaciones'
                                    : 'Nada en esta categoría por ahora',
                            subtitle:
                                'Cuando tus contactos o empresas publiquen, '
                                'lo verás aquí.',
                          ),
                )
              else
                SliverList.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];

                    return PublicationCard(
                      key: ValueKey(post.id),
                      post: post,
                      index: index,
                      onDelete: () => _deletePost(post),
                      onHide: () => _hidePost(post),
                      onChanged: _replacePost,
                    );
                  },
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 8, bottom: bottomSpace),
                  child:
                      _isLoadingMore
                          ? const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Brand.blue,
                                strokeWidth: 2.5,
                              ),
                            ),
                          )
                          : (!_hasMore && posts.length > 3)
                          ? Center(
                            child: Text(
                              'Estás al día',
                              style: TextStyle(
                                fontFamily: Brand.displayFont,
                                fontSize: 13,
                                color: palette.muted,
                              ),
                            ),
                          )
                          : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(AuthPalette palette) {
    return SliverAppBar(
      floating: true,
      snap: true,
      automaticallyImplyLeading: false,
      backgroundColor: palette.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 60,
      titleSpacing: 16,
      title: Row(
        children: [
          Image.asset('assets/images/Connect Do-01.png', height: 26),
          const SizedBox(width: 10),
          Text(
            'Inicio',
            style: TextStyle(
              fontFamily: Brand.displayFont,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: palette.title,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _NotificationButton(
            count: _unreadNotifications,
            onTap: _openNotifications,
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(108),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: _buildSearch(palette),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  return _FilterChip(
                    label: filter.label,
                    icon: filter.icon,
                    selected: filter.type == _type,
                    onTap: () => _selectType(filter.type),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch(AuthPalette palette) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(Brand.radiusMd),
        border: Border.all(color: palette.cardBorder),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        cursorColor: Brand.blue,
        style: TextStyle(
          fontFamily: Brand.displayFont,
          fontSize: 15,
          color: palette.title,
        ),
        decoration: InputDecoration(
          hintText: 'Buscar personas, empleos, pasantías…',
          hintStyle: TextStyle(
            fontFamily: Brand.displayFont,
            fontSize: 14.5,
            color: palette.muted,
          ),
          prefixIcon: Icon(
            PhosphorIconsRegular.magnifyingGlass,
            size: 20,
            color: palette.muted,
          ),
          suffixIcon:
              _searchController.text.isEmpty
                  ? null
                  : IconButton(
                    tooltip: 'Borrar búsqueda',
                    icon: Icon(
                      PhosphorIconsRegular.x,
                      size: 18,
                      color: palette.muted,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }
}

// =====================================================
// PIEZAS DEL FEED
// =====================================================
class _NotificationButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _NotificationButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: palette.card,
          shape: CircleBorder(side: BorderSide(color: palette.cardBorder)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 42,
              height: 42,
              child: Icon(
                count > 0
                    ? PhosphorIconsFill.bellSimple
                    : PhosphorIconsRegular.bellSimple,
                size: 21,
                color: count > 0 ? Brand.blue : palette.title,
              ),
            ),
          ),
        ),
        if (count > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18),
              height: 18,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Brand.danger,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: palette.background, width: 2),
              ),
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? Brand.blue : palette.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? Brand.blue : palette.cardBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : palette.body,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: Brand.displayFont,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : palette.label,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _FeedMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 48, 40, 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Brand.blue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: Brand.blue),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: Brand.displayFont,
              fontSize: 18,
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
          if (actionLabel != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              child: GradientButton(
                text: actionLabel!,
                trailingIcon: PhosphorIconsRegular.arrowClockwise,
                onPressed: onAction,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tarjeta de carga con brillo animado.
class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    Widget box(double width, double height, {double radius = 8}) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value * 3 - 1;
          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: LinearGradient(
                begin: Alignment(t - 1, 0),
                end: Alignment(t, 0),
                colors: [
                  palette.fieldFill,
                  palette.cardBorder,
                  palette.fieldFill,
                ],
              ),
            ),
          );
        },
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              box(44, 44, radius: 22),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  box(140, 13),
                  const SizedBox(height: 7),
                  box(70, 10),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          box(double.infinity, 15),
          const SizedBox(height: 8),
          box(220, 13),
          const SizedBox(height: 14),
          box(double.infinity, 160, radius: 16),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(4, (_) => box(60, 14)),
          ),
        ],
      ),
    );
  }
}
