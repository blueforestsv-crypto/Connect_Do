import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/models/contact_request_model.dart';
import 'package:connect_do/services/contact_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/utils/responsive_helper.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/auth/auth_layout.dart';
import 'package:connect_do/widgets/feed/user_avatar.dart';

/// Red de contactos: buscar personas, contactos y solicitudes.
class ContactsScreen extends StatefulWidget {
  final int initialTabIndex;
  final bool showAppBar;

  const ContactsScreen({
    super.key,
    this.initialTabIndex = 0,
    this.showAppBar = true,
  });

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;

  bool isLoading = true;
  bool isSearching = false;

  String _searchQuery = '';

  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _contacts = [];
  List<ContactRequestModel> _receivedRequests = [];
  List<ContactRequestModel> _sentRequests = [];

  /// Solicitudes con una acción en curso (para no tocar dos veces).
  final Set<String> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadContactsData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query == _searchQuery) return;

    setState(() => _searchQuery = query);

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), _searchUsers);
  }

  // ===============================
  // DATOS
  // ===============================
  Future<void> _loadContactsData({bool showLoader = true}) async {
    if (!mounted) return;
    if (showLoader) setState(() => isLoading = true);

    try {
      final contacts = await ContactService.getAcceptedContacts();
      final received = await ContactService.getIncomingRequests();
      final sent = await ContactService.getOutgoingRequests();

      List<Map<String, dynamic>> searchResults = [];
      try {
        searchResults = await ContactService.searchUsers(query: _searchQuery);
      } catch (_) {
        searchResults = [];
      }

      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _receivedRequests = received;
        _sentRequests = sent;
        _searchResults = searchResults;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
      showAuthMessage(context, 'No se pudo cargar tu red. Revisa tu conexión.');
    }
  }

  Future<void> _searchUsers() async {
    if (!mounted) return;
    setState(() => isSearching = true);

    try {
      final results = await ContactService.searchUsers(query: _searchQuery);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        isSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => isSearching = false);
      showAuthMessage(context, 'No se pudo buscar en este momento.');
    }
  }

  Future<void> _runAction(
    String id,
    Future<void> Function() action, {
    required String success,
    required String failure,
    AuthMessageType successType = AuthMessageType.success,
  }) async {
    if (_busyIds.contains(id)) return;
    setState(() => _busyIds.add(id));

    try {
      await action();
      await _loadContactsData(showLoader: false);
      if (mounted) showAuthMessage(context, success, type: successType);
    } catch (_) {
      if (mounted) showAuthMessage(context, failure);
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Future<void> _sendRequest(Map<String, dynamic> user) async {
    final receiverId = user['id']?.toString() ?? '';
    if (receiverId.isEmpty) return;

    await _runAction(
      receiverId,
      () => ContactService.sendContactRequest(receiverId: receiverId),
      success: 'Solicitud enviada',
      failure: 'No se pudo enviar la solicitud.',
    );
  }

  Future<void> _acceptRequest(ContactRequestModel request) => _runAction(
    request.id,
    () => ContactService.acceptRequest(request.id),
    success: '¡Ahora son contactos!',
    failure: 'No se pudo aceptar la solicitud.',
  );

  Future<void> _rejectRequest(ContactRequestModel request) => _runAction(
    request.id,
    () => ContactService.rejectRequest(request.id),
    success: 'Solicitud rechazada',
    failure: 'No se pudo rechazar la solicitud.',
    successType: AuthMessageType.info,
  );

  // ===============================
  // FILTROS
  // ===============================
  List<Map<String, dynamic>> get _filteredContacts {
    if (_searchQuery.isEmpty) return _contacts;
    final query = _searchQuery.toLowerCase();

    return _contacts.where((contact) {
      final name = _buildUserName(contact).toLowerCase();
      final email = contact['email']?.toString().toLowerCase() ?? '';
      return name.contains(query) || email.contains(query);
    }).toList();
  }

  List<ContactRequestModel> get _filteredReceivedRequests {
    if (_searchQuery.isEmpty) return _receivedRequests;
    final query = _searchQuery.toLowerCase();

    return _receivedRequests.where((request) {
      return request.requesterName.toLowerCase().contains(query) ||
          request.requesterId.toLowerCase().contains(query);
    }).toList();
  }

  List<ContactRequestModel> get _filteredSentRequests {
    if (_searchQuery.isEmpty) return _sentRequests;
    final query = _searchQuery.toLowerCase();

    return _sentRequests.where((request) {
      return request.receiverName.toLowerCase().contains(query) ||
          request.receiverId.toLowerCase().contains(query);
    }).toList();
  }

  int get _safeInitialTabIndex => widget.initialTabIndex.clamp(0, 3);

  // ===============================
  // UI
  // ===============================
  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      resizeToAvoidBottomInset: true,
      appBar:
          widget.showAppBar
              ? AppBar(
                backgroundColor: palette.background,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                automaticallyImplyLeading: false,
                titleSpacing: 12,
                title: Row(
                  children: [
                    if (Navigator.of(context).canPop()) ...[
                      AuthBackButton(onTap: () => Navigator.maybePop(context)),
                      const SizedBox(width: 12),
                    ],
                    Text(
                      'Mi red',
                      style: TextStyle(
                        fontFamily: Brand.displayFont,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: palette.title,
                      ),
                    ),
                  ],
                ),
              )
              : null,
      body:
          isLoading
              ? const Center(
                child: CircularProgressIndicator(
                  color: Brand.blue,
                  strokeWidth: 2.5,
                ),
              )
              : DefaultTabController(
                length: 4,
                initialIndex: _safeInitialTabIndex,
                child: Column(
                  children: [
                    _buildSearchBar(palette),
                    _buildTabs(palette),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildPeopleSearchList(),
                          _buildContactsList(),
                          _buildReceivedRequests(),
                          _buildSentRequests(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildSearchBar(AuthPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(Brand.radiusMd),
          border: Border.all(color: palette.cardBorder),
        ),
        child: TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          cursorColor: Brand.blue,
          style: TextStyle(
            fontFamily: Brand.displayFont,
            fontSize: 15,
            color: palette.title,
          ),
          decoration: InputDecoration(
            hintText: 'Buscar por nombre o correo…',
            hintStyle: TextStyle(
              fontFamily: Brand.displayFont,
              fontSize: 14.5,
              color: palette.muted,
            ),
            prefixIcon:
                isSearching
                    ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Brand.blue,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                    : Icon(
                      PhosphorIconsRegular.magnifyingGlass,
                      size: 20,
                      color: palette.muted,
                    ),
            suffixIcon:
                _searchQuery.isEmpty
                    ? null
                    : IconButton(
                      tooltip: 'Borrar búsqueda',
                      icon: Icon(
                        PhosphorIconsRegular.x,
                        size: 18,
                        color: palette.muted,
                      ),
                      onPressed: _searchController.clear,
                    ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildTabs(AuthPalette palette) {
    Tab tab(String label, int count, {bool highlight = false}) {
      return Tab(
        height: 36,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 20),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color:
                      highlight
                          ? Brand.danger
                          : Brand.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: highlight ? Colors.white : Brand.blue,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: Brand.blue.withValues(alpha: palette.isDark ? 0.22 : 0.10),
          borderRadius: BorderRadius.circular(999),
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 14),
        labelColor: Brand.blue,
        unselectedLabelColor: palette.body,
        labelStyle: const TextStyle(
          fontFamily: Brand.displayFont,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: Brand.displayFont,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        tabs: [
          tab('Personas', _searchResults.length),
          tab('Contactos', _filteredContacts.length),
          tab('Recibidas', _filteredReceivedRequests.length, highlight: true),
          tab('Enviadas', _filteredSentRequests.length),
        ],
      ),
    );
  }

  Widget _list({required int itemCount, required IndexedWidgetBuilder item}) {
    return RefreshIndicator(
      color: Brand.blue,
      onRefresh: () => _loadContactsData(showLoader: false),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          ResponsiveHelper.appBottomNavSpace(context),
        ),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: item,
      ),
    );
  }

  Widget _buildPeopleSearchList() {
    final people = _searchResults;

    if (people.isEmpty) {
      return _buildEmptyState(
        icon:
            _searchQuery.isEmpty
                ? PhosphorIconsRegular.usersThree
                : PhosphorIconsRegular.magnifyingGlass,
        title:
            _searchQuery.isEmpty
                ? 'Encuentra a tu comunidad'
                : 'No encontramos a nadie',
        subtitle:
            _searchQuery.isEmpty
                ? 'Busca compañeros o empresas por nombre o correo.'
                : 'Prueba con otro nombre o correo.',
      );
    }

    return _list(
      itemCount: people.length,
      item: (context, index) => _buildSearchUserTile(people[index]),
    );
  }

  Widget _buildSearchUserTile(Map<String, dynamic> user) {
    final name = _buildUserName(user);
    final email = user['email']?.toString() ?? '';
    final career = user['career']?.toString() ?? '';
    final photo = user['profile_image_base64']?.toString() ?? '';
    final status = user['contact_status']?.toString();
    final userId = user['id']?.toString() ?? '';

    final Widget trailing;
    if (status == null || status.isEmpty || status == 'null') {
      trailing = _SmallButton(
        label: 'Agregar',
        icon: PhosphorIconsRegular.userPlus,
        isLoading: _busyIds.contains(userId),
        onTap: () => _sendRequest(user),
      );
    } else if (status == 'pending') {
      trailing = const _StatusChip(label: 'Pendiente', color: Brand.warning);
    } else if (status == 'accepted') {
      trailing = const _StatusChip(label: 'Contacto', color: Brand.success);
    } else if (status == 'rejected') {
      trailing = const _StatusChip(label: 'Rechazada', color: Brand.danger);
    } else {
      trailing = _StatusChip(label: status, color: Colors.grey);
    }

    return _UserTile(
      name: name,
      photo: photo,
      subtitle: career.isNotEmpty ? career : email,
      trailing: trailing,
    );
  }

  Widget _buildContactsList() {
    final contacts = _filteredContacts;

    if (contacts.isEmpty) {
      return _buildEmptyState(
        icon: PhosphorIconsRegular.usersThree,
        title:
            _searchQuery.isEmpty
                ? 'Aún no tienes contactos'
                : 'No encontramos contactos',
        subtitle:
            _searchQuery.isEmpty
                ? 'Busca personas en la pestaña "Personas" y envíales una '
                    'solicitud.'
                : 'Prueba con otro nombre.',
      );
    }

    return _list(
      itemCount: contacts.length,
      item: (context, index) {
        final contact = contacts[index];
        final career = contact['career']?.toString() ?? '';

        return _UserTile(
          name: _buildUserName(contact),
          photo: contact['profile_image_base64']?.toString() ?? '',
          subtitle:
              career.isNotEmpty ? career : contact['email']?.toString() ?? '',
          trailing: const Icon(
            PhosphorIconsFill.checkCircle,
            color: Brand.green,
            size: 22,
          ),
        );
      },
    );
  }

  Widget _buildReceivedRequests() {
    final requests = _filteredReceivedRequests;

    if (requests.isEmpty) {
      return _buildEmptyState(
        icon: PhosphorIconsRegular.envelopeOpen,
        title: 'No tienes solicitudes nuevas',
        subtitle: 'Cuando alguien quiera conectar contigo, aparecerá aquí.',
      );
    }

    return _list(
      itemCount: requests.length,
      item: (context, index) => _buildRequestTile(requests[index]),
    );
  }

  Widget _buildSentRequests() {
    final requests = _filteredSentRequests;

    if (requests.isEmpty) {
      return _buildEmptyState(
        icon: PhosphorIconsRegular.paperPlaneTilt,
        title: 'No has enviado solicitudes',
        subtitle: 'Las solicitudes que envíes esperarán respuesta aquí.',
      );
    }

    return _list(
      itemCount: requests.length,
      item: (context, index) {
        final request = requests[index];
        return _UserTile(
          name: request.receiverName,
          photo: request.receiverPhoto,
          subtitle: 'Esperando respuesta',
          trailing: const _StatusChip(label: 'Pendiente', color: Brand.warning),
        );
      },
    );
  }

  Widget _buildRequestTile(ContactRequestModel request) {
    final palette = AuthPalette.of(context);
    final busy = _busyIds.contains(request.id);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              UserAvatar(
                name: request.requesterName,
                photo: request.requesterPhoto,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.requesterName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: Brand.displayFont,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: palette.title,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Quiere conectar contigo',
                      style: TextStyle(
                        fontFamily: Brand.displayFont,
                        fontSize: 13,
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : () => _rejectRequest(request),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.body,
                    side: BorderSide(color: palette.fieldBorder),
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Brand.radiusSm),
                    ),
                  ),
                  child: const Text(
                    'Rechazar',
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : () => _acceptRequest(request),
                  style: FilledButton.styleFrom(
                    backgroundColor: Brand.blue,
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Brand.radiusSm),
                    ),
                  ),
                  child:
                      busy
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Text(
                            'Aceptar',
                            style: TextStyle(
                              fontFamily: Brand.displayFont,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final palette = AuthPalette.of(context);

    return RefreshIndicator(
      color: Brand.blue,
      onRefresh: () => _loadContactsData(showLoader: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          40,
          40,
          40,
          ResponsiveHelper.appBottomNavSpace(context),
        ),
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Brand.blue.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: Brand.blue),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: Brand.displayFont,
              fontSize: 16.5,
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
      ),
    );
  }

  String _buildUserName(Map<String, dynamic> user) {
    final firstName = user['first_name']?.toString() ?? '';
    final lastName = user['last_name']?.toString() ?? '';
    final email = user['email']?.toString() ?? '';

    final fullName = '$firstName $lastName'.trim();
    if (fullName.isNotEmpty) return fullName;
    if (email.isNotEmpty) return email;
    return 'Usuario de Connect Do';
  }
}

// =====================================================
// PIEZAS
// =====================================================
class _UserTile extends StatelessWidget {
  final String name;
  final String photo;
  final String subtitle;
  final Widget trailing;

  const _UserTile({
    required this.name,
    required this.photo,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        children: [
          UserAvatar(name: name, photo: photo),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: Brand.displayFont,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: palette.title,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 13,
                      color: palette.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onTap;

  const _SmallButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: isLoading ? null : onTap,
      style: FilledButton.styleFrom(
        backgroundColor: Brand.blue,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Brand.radiusSm),
        ),
      ),
      icon:
          isLoading
              ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
              : Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(
          fontFamily: Brand.displayFont,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = AuthPalette.of(context).isDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.20 : 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: Brand.displayFont,
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
