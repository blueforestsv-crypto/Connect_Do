import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:connect_do/models/contact_request_model.dart';
import 'package:connect_do/services/contact_service.dart';
import 'package:connect_do/utils/responsive_helper.dart';

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

    setState(() {
      _searchQuery = query;
    });

    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      _searchUsers();
    });
  }

  Future<void> _loadContactsData() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

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
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar contactos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _searchUsers() async {
    if (!mounted) return;

    setState(() {
      isSearching = true;
    });

    try {
      final results = await ContactService.searchUsers(query: _searchQuery);

      if (!mounted) return;

      setState(() {
        _searchResults = results;
        isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSearching = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al buscar usuarios: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendRequest(Map<String, dynamic> user) async {
    final receiverId = user['id']?.toString() ?? '';

    if (receiverId.isEmpty) return;

    try {
      await ContactService.sendContactRequest(receiverId: receiverId);

      await _loadContactsData();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud enviada'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo enviar la solicitud: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _acceptRequest(ContactRequestModel request) async {
    try {
      await ContactService.acceptRequest(request.id);

      await _loadContactsData();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud aceptada'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo aceptar la solicitud: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectRequest(ContactRequestModel request) async {
    try {
      await ContactService.rejectRequest(request.id);

      await _loadContactsData();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud rechazada'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo rechazar la solicitud: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredContacts {
    if (_searchQuery.isEmpty) {
      return _contacts;
    }

    final query = _searchQuery.toLowerCase();

    return _contacts.where((contact) {
      final name = _buildUserName(contact).toLowerCase();
      final email = contact['email']?.toString().toLowerCase() ?? '';

      return name.contains(query) || email.contains(query);
    }).toList();
  }

  List<ContactRequestModel> get _filteredReceivedRequests {
    if (_searchQuery.isEmpty) {
      return _receivedRequests;
    }

    final query = _searchQuery.toLowerCase();

    return _receivedRequests.where((request) {
      return request.requesterName.toLowerCase().contains(query) ||
          request.requesterId.toLowerCase().contains(query);
    }).toList();
  }

  List<ContactRequestModel> get _filteredSentRequests {
    if (_searchQuery.isEmpty) {
      return _sentRequests;
    }

    final query = _searchQuery.toLowerCase();

    return _sentRequests.where((request) {
      return request.receiverName.toLowerCase().contains(query) ||
          request.receiverId.toLowerCase().contains(query);
    }).toList();
  }

  int get _safeInitialTabIndex {
    if (widget.initialTabIndex < 0) return 0;
    if (widget.initialTabIndex > 3) return 3;

    return widget.initialTabIndex;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDarkMode ? const Color(0xFF121212) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      appBar:
          widget.showAppBar
              ? AppBar(
                backgroundColor: const Color(0xFF2563EB),
                elevation: 0,
                centerTitle: true,
                iconTheme: const IconThemeData(color: Colors.white),
                title: const Text(
                  'Mi red',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
              : null,
      body:
          isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF22C55E)),
              )
              : DefaultTabController(
                length: 4,
                initialIndex: _safeInitialTabIndex,
                child: Column(
                  children: [
                    _buildSearchBar(isDarkMode),

                    Container(
                      color: bgColor,
                      child: TabBar(
                        isScrollable: true,
                        indicatorColor: const Color(0xFF2563EB),
                        labelColor:
                            isDarkMode ? Colors.white : const Color(0xFF2563EB),
                        unselectedLabelColor:
                            isDarkMode
                                ? Colors.grey.shade400
                                : const Color(0xFF22C55E),
                        tabs: [
                          Tab(text: 'Personas (${_searchResults.length})'),
                          Tab(text: 'Contactos (${_filteredContacts.length})'),
                          Tab(
                            text:
                                'Recibidas (${_filteredReceivedRequests.length})',
                          ),
                          Tab(
                            text: 'Enviadas (${_filteredSentRequests.length})',
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildPeopleSearchList(textColor, isDarkMode),
                          _buildContactsList(textColor, isDarkMode),
                          _buildReceivedRequests(textColor, isDarkMode),
                          _buildSentRequests(textColor, isDarkMode),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildSearchBar(bool isDarkMode) {
    final inputColor =
        isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade100;

    final textColor = isDarkMode ? Colors.white : Colors.black87;

    final hintColor = isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
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
            hintText: 'Buscar personas o contactos...',
            hintStyle: TextStyle(color: hintColor),
            prefixIcon:
                isSearching
                    ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          color: Color(0xFF2563EB),
                          strokeWidth: 2,
                        ),
                      ),
                    )
                    : const Icon(Icons.search, color: Color(0xFF2563EB)),
            suffixIcon:
                _searchQuery.isNotEmpty
                    ? IconButton(
                      icon: Icon(
                        Icons.close,
                        color:
                            isDarkMode
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
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

  Widget _buildPeopleSearchList(Color textColor, bool isDarkMode) {
    final people = _searchResults;

    if (people.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return _buildEmptyState(
          icon: Icons.search_off,
          title: 'No encontramos usuarios',
          subtitle: 'Prueba buscando por nombre o correo.',
          isDarkMode: isDarkMode,
        );
      }

      return _buildEmptyState(
        icon: Icons.person_search_outlined,
        title: 'Busca personas registradas',
        subtitle: 'Aquí aparecerán usuarios reales del backend.',
        isDarkMode: isDarkMode,
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF22C55E),
      onRefresh: _loadContactsData,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          ResponsiveHelper.appBottomNavSpace(context),
        ),
        itemCount: people.length,
        itemBuilder: (context, index) {
          final user = people[index];

          return _buildSearchUserTile(
            user: user,
            textColor: textColor,
            isDarkMode: isDarkMode,
          );
        },
      ),
    );
  }

  Widget _buildSearchUserTile({
    required Map<String, dynamic> user,
    required Color textColor,
    required bool isDarkMode,
  }) {
    final name = _buildUserName(user);
    final email = user['email']?.toString() ?? '';
    final career = user['career']?.toString() ?? '';
    final photo = user['profile_image_base64']?.toString() ?? '';
    final contactStatus = user['contact_status']?.toString();
    final requestId = user['request_id']?.toString();

    final subtitle =
        career.isNotEmpty
            ? career
            : email.isNotEmpty
            ? email
            : 'Usuario';

    Widget trailing;

    if (contactStatus == null ||
        contactStatus.isEmpty ||
        contactStatus == 'null') {
      trailing = ElevatedButton(
        onPressed: () => _sendRequest(user),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: const Text(
          'Agregar',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      );
    } else if (contactStatus == 'pending') {
      trailing = _statusChip(
        label:
            requestId == null || requestId.isEmpty ? 'Pendiente' : 'Pendiente',
        color: Colors.orange,
        isDarkMode: isDarkMode,
      );
    } else if (contactStatus == 'accepted') {
      trailing = const Icon(Icons.check_circle, color: Color(0xFF22C55E));
    } else if (contactStatus == 'rejected') {
      trailing = _statusChip(
        label: 'Rechazada',
        color: Colors.red,
        isDarkMode: isDarkMode,
      );
    } else {
      trailing = _statusChip(
        label: contactStatus,
        color: Colors.grey,
        isDarkMode: isDarkMode,
      );
    }

    return _buildUserTile(
      name: name,
      photo: photo,
      subtitle: subtitle,
      trailing: trailing,
      textColor: textColor,
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildContactsList(Color textColor, bool isDarkMode) {
    final contacts = _filteredContacts;

    if (contacts.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return _buildEmptyState(
          icon: Icons.search_off,
          title: 'No encontramos contactos',
          subtitle: 'Prueba con otro nombre.',
          isDarkMode: isDarkMode,
        );
      }

      return _buildEmptyState(
        icon: Icons.people_alt_outlined,
        title: 'Aún no tienes contactos',
        subtitle: 'Cuando aceptes solicitudes aparecerán aquí.',
        isDarkMode: isDarkMode,
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF22C55E),
      onRefresh: _loadContactsData,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          ResponsiveHelper.appBottomNavSpace(context),
        ),
        itemCount: contacts.length,
        itemBuilder: (context, index) {
          final contact = contacts[index];

          final name = _buildUserName(contact);
          final email = contact['email']?.toString() ?? '';
          final career = contact['career']?.toString() ?? '';
          final photo = contact['profile_image_base64']?.toString() ?? '';

          return _buildUserTile(
            name: name,
            photo: photo,
            subtitle: career.isNotEmpty ? career : email,
            trailing: const Icon(Icons.check_circle, color: Color(0xFF22C55E)),
            textColor: textColor,
            isDarkMode: isDarkMode,
          );
        },
      ),
    );
  }

  Widget _buildReceivedRequests(Color textColor, bool isDarkMode) {
    final receivedRequests = _filteredReceivedRequests;

    if (receivedRequests.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return _buildEmptyState(
          icon: Icons.search_off,
          title: 'No encontramos solicitudes',
          subtitle: 'Prueba con otro nombre.',
          isDarkMode: isDarkMode,
        );
      }

      return _buildEmptyState(
        icon: Icons.mark_email_unread_outlined,
        title: 'No tienes solicitudes',
        subtitle: 'Las solicitudes que recibas aparecerán aquí.',
        isDarkMode: isDarkMode,
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF22C55E),
      onRefresh: _loadContactsData,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          ResponsiveHelper.appBottomNavSpace(context),
        ),
        itemCount: receivedRequests.length,
        itemBuilder: (context, index) {
          final request = receivedRequests[index];

          return _buildRequestTile(
            request: request,
            textColor: textColor,
            isDarkMode: isDarkMode,
          );
        },
      ),
    );
  }

  Widget _buildSentRequests(Color textColor, bool isDarkMode) {
    final sentRequests = _filteredSentRequests;

    if (sentRequests.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return _buildEmptyState(
          icon: Icons.search_off,
          title: 'No encontramos solicitudes',
          subtitle: 'Prueba con otro nombre.',
          isDarkMode: isDarkMode,
        );
      }

      return _buildEmptyState(
        icon: Icons.outgoing_mail,
        title: 'No has enviado solicitudes',
        subtitle: 'Cuando contactes a alguien aparecerá aquí.',
        isDarkMode: isDarkMode,
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF22C55E),
      onRefresh: _loadContactsData,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          ResponsiveHelper.appBottomNavSpace(context),
        ),
        itemCount: sentRequests.length,
        itemBuilder: (context, index) {
          final request = sentRequests[index];

          return _buildUserTile(
            name: request.receiverName,
            photo: request.receiverPhoto,
            subtitle: 'Solicitud pendiente',
            trailing: _statusChip(
              label: 'Pendiente',
              color: Colors.orange,
              isDarkMode: isDarkMode,
            ),
            textColor: textColor,
            isDarkMode: isDarkMode,
          );
        },
      ),
    );
  }

  Widget _buildRequestTile({
    required ContactRequestModel request,
    required Color textColor,
    required bool isDarkMode,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _buildAvatar(request.requesterPhoto),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.requesterName,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 4),

                Text(
                  'Quiere agregarte como contacto',
                  style: TextStyle(
                    color:
                        isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _rejectRequest(request),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text('Rechazar'),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _acceptRequest(request),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text('Aceptar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile({
    required String name,
    required String photo,
    required String subtitle,
    required Widget trailing,
    required Color textColor,
    required bool isDarkMode,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: _buildAvatar(photo),
        title: Text(
          name,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: trailing,
      ),
    );
  }

  Widget _statusChip({
    required String label,
    required Color color,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDarkMode ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAvatar(String photo) {
    if (photo.isEmpty) {
      return const CircleAvatar(
        radius: 25,
        backgroundColor: Color(0xFFE5E7EB),
        child: Icon(Icons.person, color: Colors.grey),
      );
    }

    if (photo.startsWith('http://') || photo.startsWith('https://')) {
      return CircleAvatar(
        radius: 25,
        backgroundImage: NetworkImage(photo),
        onBackgroundImageError: (_, __) {},
      );
    }

    try {
      final cleanBase64 = photo.contains(',') ? photo.split(',').last : photo;

      final Uint8List bytes = base64Decode(cleanBase64);

      return CircleAvatar(radius: 25, backgroundImage: MemoryImage(bytes));
    } catch (_) {
      return const CircleAvatar(
        radius: 25,
        backgroundColor: Color(0xFFE5E7EB),
        child: Icon(Icons.person, color: Colors.grey),
      );
    }
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDarkMode,
  }) {
    return RefreshIndicator(
      color: const Color(0xFF22C55E),
      onRefresh: _loadContactsData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          bottom: ResponsiveHelper.appBottomNavSpace(context),
        ),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.22),

          Icon(
            icon,
            size: 65,
            color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
          ),

          const SizedBox(height: 16),

          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),

          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 35),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: 14,
                height: 1.4,
              ),
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

    if (fullName.isNotEmpty) {
      return fullName;
    }

    if (email.isNotEmpty) {
      return email;
    }

    return 'Usuario de Connect Do';
  }
}
