import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../User/report_generator_service.dart';

// ─── Data Models ────────────────────────────────────────────────────────────

class _ClientData {
  final String id;
  String name;
  int totalSessions;
  int completedSessions;
  DateTime? lastSessionDate;
  List<Map<String, dynamic>> sessions;
  List<Map<String, dynamic>> sharedInsights;
  bool hasCrisisAlert;

  _ClientData({
    required this.id,
    required this.name,
    this.totalSessions = 0,
    this.completedSessions = 0,
    this.lastSessionDate,
    List<Map<String, dynamic>>? sessions,
    List<Map<String, dynamic>>? sharedInsights,
    this.hasCrisisAlert = false,
  })  : sessions = sessions ?? [],
        sharedInsights = sharedInsights ?? [];
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class SharedChatsScreen extends StatefulWidget {
  const SharedChatsScreen({super.key});

  @override
  State<SharedChatsScreen> createState() => _SharedChatsScreenState();
}

class _SharedChatsScreenState extends State<SharedChatsScreen> {
  static const Color _green = Color(0xFF7C9C84);
  static const Color _bg = Color(0xFFF2F1EC);
  static const Color _textMain = Color(0xFF333333);
  static const Color _textDim = Color(0xFF888888);
  static const Color _red = Color(0xFFDC2626);

  bool _loading = true;
  List<_ClientData> _clients = [];
  Set<String> _crisisClientIds = {};

  // List page state
  String _search = '';
  String _listFilter = 'all'; // 'all' | 'shared' | 'crisis'

  // Detail page state
  _ClientData? _selected;
  String _activeTab = 'sessions'; // 'sessions' | 'insights'
  String _sessionFilter = 'all'; // 'all' | 'upcoming' | 'completed' | 'cancelled'
  String _insightFilter = 'all'; // 'all' | 'chat' | 'diary' | 'report' | 'crisis'

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final bookingsSnap = await FirebaseFirestore.instance
          .collection('counsellor_bookings')
          .where('counsellorId', isEqualTo: uid)
          .get();

      final insightsSnap = await FirebaseFirestore.instance
          .collection('shared_chats')
          .where('counsellorId', isEqualTo: uid)
          .get();

      final crisisSnap = await FirebaseFirestore.instance
          .collection('crisis_alerts')
          .get();

      final Map<String, _ClientData> clientMap = {};

      // Process bookings
      for (final doc in bookingsSnap.docs) {
        final data = doc.data();
        final pId = data['patientId'] ?? data['userId'];
        if (pId == null) continue;

        DateTime? apptDate;
        if (data['startTime'] != null) {
          apptDate = (data['startTime'] as Timestamp).toDate();
        } else if (data['date'] != null) {
          apptDate = DateTime.tryParse(data['date'].toString());
        }

        clientMap.putIfAbsent(
          pId,
          () => _ClientData(
            id: pId,
            name: data['patientName'] ?? data['userName'] ?? 'Unknown Client',
          ),
        );

        final client = clientMap[pId]!;
        client.totalSessions++;
        if ((data['status']?.toString().toUpperCase()) == 'COMPLETED') {
          client.completedSessions++;
        }
        client.sessions.add({...data, 'id': doc.id, '_date': apptDate});
        if (apptDate != null &&
            (client.lastSessionDate == null ||
                apptDate.isAfter(client.lastSessionDate!))) {
          client.lastSessionDate = apptDate;
        }
      }

      // Process shared insights
      for (final doc in insightsSnap.docs) {
        final data = doc.data();
        final pId = data['patientId'] ?? data['userId'];
        if (pId == null) continue;

        DateTime? sharedAt;
        if (data['sharedAt'] != null) {
          sharedAt = (data['sharedAt'] as Timestamp).toDate();
        }

        clientMap.putIfAbsent(
          pId,
          () => _ClientData(
            id: pId,
            name: data['patientName'] ?? data['userName'] ?? 'Unknown Client',
          ),
        );

        clientMap[pId]!.sharedInsights.add({
          ...data,
          'id': doc.id,
          '_sharedAt': sharedAt,
        });
      }

      // Crisis alerts
      final crisisIds = <String>{};
      for (final doc in crisisSnap.docs) {
        final cid = doc.data()['userId'];
        if (cid != null && clientMap.containsKey(cid)) crisisIds.add(cid);
      }

      // Resolve unknown names
      for (final c in clientMap.values) {
        if (c.name == 'Unknown Client' || c.name == 'Valued Client') {
          try {
            final uDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(c.id)
                .get();
            if (uDoc.exists) {
              c.name = uDoc.data()?['fullName'] ?? uDoc.data()?['name'] ?? 'Client';
            }
          } catch (_) {}
        }
        c.sessions.sort((a, b) => (b['_date'] ?? DateTime(0))
            .compareTo(a['_date'] ?? DateTime(0)));
        c.sharedInsights.sort((a, b) => (b['_sharedAt'] ?? DateTime(0))
            .compareTo(a['_sharedAt'] ?? DateTime(0)));
        c.hasCrisisAlert = crisisIds.contains(c.id);
      }

      final clientList = clientMap.values.toList()
        ..sort((a, b) => (b.lastSessionDate ?? DateTime(0))
            .compareTo(a.lastSessionDate ?? DateTime(0)));

      setState(() {
        _clients = clientList;
        _crisisClientIds = crisisIds;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error fetching client data: $e');
      setState(() => _loading = false);
    }
  }

  List<_ClientData> get _filteredClients {
    return _clients.where((c) {
      final matchSearch =
          c.name.toLowerCase().contains(_search.toLowerCase());
      bool matchFilter = true;
      if (_listFilter == 'shared') matchFilter = c.sharedInsights.isNotEmpty;
      if (_listFilter == 'crisis') matchFilter = c.hasCrisisAlert;
      return matchSearch && matchFilter;
    }).toList();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _selected == null ? AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF333333), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'CLIENT DIRECTORY',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: const Color(0xFF333333),
          ),
        ),
        centerTitle: true,
      ) : null,
      body: SafeArea(
        child: _selected == null ? _buildListPage() : _buildDetailPage(),
      ),
    );
  }

  // ─── LIST PAGE ────────────────────────────────────────────────────────────

  Widget _buildListPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search and Filter Bar
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
                        ),
                        child: Center(
                          child: TextField(
                            onChanged: (val) => setState(() => _search = val),
                            decoration: InputDecoration(
                              hintText: 'Search clients by name...',
                              hintStyle: GoogleFonts.outfit(fontSize: 14, color: Colors.grey),
                              border: InputBorder.none,
                              icon: const Icon(Icons.search_rounded, size: 20, color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _showFilterSheet(context),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _listFilter != 'all' ? _green : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
                        ),
                        child: Icon(Icons.tune_rounded, size: 20, color: _listFilter != 'all' ? Colors.white : Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
              if (_listFilter != 'all')
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _listFilter == 'crisis' ? _red.withOpacity(0.1) : _green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _listFilter == 'crisis' ? Icons.warning_rounded : Icons.people_alt_rounded, 
                          size: 14, 
                          color: _listFilter == 'crisis' ? _red : _green
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _listFilter == 'crisis' ? 'Crisis Alerts' : 'Shared Records',
                          style: GoogleFonts.outfit(
                            fontSize: 12, 
                            fontWeight: FontWeight.bold, 
                            color: _listFilter == 'crisis' ? _red : _green
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() => _listFilter = 'all'),
                          child: Icon(Icons.close_rounded, size: 16, color: _listFilter == 'crisis' ? _red : _green),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: _green))
              : _filteredClients.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      itemCount: _filteredClients.length,
                      itemBuilder: (context, i) =>
                          _buildClientCard(_filteredClients[i]),
                    ),
        ),
      ],
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: Color(0xFFF2F1EC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            Text('Filter Clients', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _buildFilterOption(Icons.group_rounded, 'All Clients', () {
              setState(() => _listFilter = 'all');
              Navigator.pop(context);
            }),
            _buildFilterOption(Icons.people_alt_rounded, 'Shared Records', () {
              setState(() => _listFilter = 'shared');
              Navigator.pop(context);
            }),
            _buildFilterOption(Icons.warning_rounded, 'Crisis Alerts', () {
              setState(() => _listFilter = 'crisis');
              Navigator.pop(context);
            }, isLast: true, isCrisis: true),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(IconData icon, String label, VoidCallback onTap, {bool isLast = false, bool isCrisis = false}) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          leading: Icon(icon, color: isCrisis ? _red : _green, size: 20),
          title: Text(label, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500, color: isCrisis ? _red : _textMain)),
          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 18),
          contentPadding: EdgeInsets.zero,
        ),
        if (!isLast) Divider(color: Colors.grey.withOpacity(0.1)),
      ],
    );
  }

  Widget _buildClientCard(_ClientData client) {
    return GestureDetector(
      onTap: () => setState(() {
        _selected = client;
        _activeTab = client.hasCrisisAlert ? 'insights' : 'sessions';
        _insightFilter = client.hasCrisisAlert ? 'crisis' : 'all';
        _sessionFilter = 'all';
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: client.hasCrisisAlert
              ? Border.all(color: const Color(0xFFFCA5A5), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Crisis banner
            if (client.hasCrisisAlert)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'CRISIS ALERT',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: client.hasCrisisAlert
                          ? const Color(0xFFFEE2E2)
                          : _green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        client.name.isNotEmpty
                            ? client.name[0].toUpperCase()
                            : 'C',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: client.hasCrisisAlert ? _red : _green,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.name,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _textMain,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${client.totalSessions} Bookings',
                              style: GoogleFonts.outfit(
                                  fontSize: 12, color: Colors.grey[500]),
                            ),
                            if (client.sharedInsights.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${client.sharedInsights.length} Record${client.sharedInsights.length != 1 ? 's' : ''}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _green,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Icon(Icons.chevron_right_rounded,
                          color: Color(0xFFBDBDBD)),
                      if (client.lastSessionDate != null)
                        Text(
                          DateFormat('d MMM yy').format(client.lastSessionDate!),
                          style: GoogleFonts.outfit(
                              fontSize: 11, color: Colors.grey[400]),
                        ),
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

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded,
              size: 72, color: _green.withOpacity(0.15)),
          const SizedBox(height: 20),
          Text(
            'No clients found',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _textMain,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _search.isNotEmpty
                ? 'Try adjusting your search.'
                : _listFilter == 'crisis'
                    ? 'No clients with active crisis alerts.'
                    : 'No client history yet.',
            style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── DETAIL PAGE ──────────────────────────────────────────────────────────

  Widget _buildDetailPage() {
    final client = _selected!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => setState(() => _selected = null),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back_ios_rounded,
                        size: 16, color: Color(0xFF888888)),
                    const SizedBox(width: 4),
                    Text(
                      'Back to Directory',
                      style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF888888)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Client header card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: client.hasCrisisAlert
                      ? Border.all(color: const Color(0xFFFCA5A5), width: 1.5)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: client.hasCrisisAlert
                            ? const Color(0xFFFEE2E2)
                            : _green.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          client.name.isNotEmpty
                              ? client.name[0].toUpperCase()
                              : 'C',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            color: client.hasCrisisAlert ? _red : _green,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            client.name,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: _textMain,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '${client.completedSessions} Completed · ${client.totalSessions} Total',
                                style: GoogleFonts.outfit(
                                    fontSize: 12, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (client.hasCrisisAlert)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: _red, size: 13),
                            const SizedBox(width: 4),
                            Text(
                              'CRISIS',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _red,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Tabs
              Row(
                children: [
                  _tabButton('sessions', 'Session History'),
                  const SizedBox(width: 8),
                  _tabButton('insights', 'Shared Records'),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFEEEEEB)),
        Expanded(
          child: _activeTab == 'sessions'
              ? _buildSessionsTab(client)
              : _buildInsightsTab(client),
        ),
      ],
    );
  }

  Widget _tabButton(String id, String label) {
    final isActive = _activeTab == id;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? _green : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? _green : const Color(0xFFDDDDD8),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : _textDim,
          ),
        ),
      ),
    );
  }

  // ─── SESSIONS TAB ─────────────────────────────────────────────────────────

  Widget _buildSessionsTab(_ClientData client) {
    final filters = ['all', 'upcoming', 'completed', 'cancelled'];
    final labels = {
      'all': 'All',
      'upcoming': 'Upcoming',
      'completed': 'Completed',
      'cancelled': 'Cancelled'
    };

    final filtered = client.sessions.where((s) {
      if (_sessionFilter == 'all') return true;
      final st = (s['status'] ?? '').toString().toUpperCase();
      if (_sessionFilter == 'upcoming') {
        return ['CONFIRMED', 'PENDING', 'RESCHEDULED', 'UPCOMING'].contains(st);
      }
      if (_sessionFilter == 'completed') return st == 'COMPLETED';
      if (_sessionFilter == 'cancelled') {
        return st == 'CANCELLED' || st == 'MISSED';
      }
      return false;
    }).toList();

    return Column(
      children: [
        // Session filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((f) {
                final isActive = _sessionFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _sessionFilter = f),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: isActive ? _green : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              isActive ? _green : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Text(
                        labels[f]!,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.white : _textDim,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text('No sessions match this filter.',
                      style: GoogleFonts.outfit(
                          fontSize: 14, color: Colors.grey[500])))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => _buildSessionCard(filtered[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> sess) {
    final st = (sess['status'] ?? '').toString().toUpperCase();
    Color badgeBg = const Color(0xFFF3F4F6);
    Color badgeFg = const Color(0xFF4B5563);
    if (st == 'COMPLETED') {
      badgeBg = const Color(0xFFDCFCE7);
      badgeFg = const Color(0xFF166534);
    } else if (st == 'CANCELLED' || st == 'MISSED') {
      badgeBg = const Color(0xFFFEE2E2);
      badgeFg = const Color(0xFFDC2626);
    } else if (['CONFIRMED', 'PENDING', 'RESCHEDULED', 'UPCOMING']
        .contains(st)) {
      badgeBg = const Color(0xFFFEF3C7);
      badgeFg = const Color(0xFF92400E);
    }

    final date = sess['date']?.toString() ??
        (sess['_date'] != null
            ? DateFormat('d MMM yyyy').format(sess['_date'] as DateTime)
            : 'TBD');
    final time = sess['timeRange']?.toString() ??
        sess['time']?.toString() ??
        (sess['_date'] != null
            ? DateFormat('hh:mm a').format(sess['_date'] as DateTime)
            : 'TBD');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.event_rounded,
                size: 20, color: Color(0xFF6B7280)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date,
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                Text(time,
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              st.isEmpty ? 'PENDING' : st,
              style: GoogleFonts.outfit(
                  fontSize: 10, fontWeight: FontWeight.bold, color: badgeFg),
            ),
          ),
        ],
      ),
    );
  }

  // ─── INSIGHTS TAB ─────────────────────────────────────────────────────────

  Widget _buildInsightsTab(_ClientData client) {
    final insightFilters = ['all', 'chat', 'diary', 'report', 'crisis'];
    final insightLabels = {
      'all': 'All Records',
      'chat': 'AI Chat',
      'diary': 'Diaries',
      'report': 'Reports',
      'crisis': '🚨 Crisis',
    };

    final filtered = client.sharedInsights.where((ins) {
      if (_insightFilter == 'all') return true;
      final isReport = ins['type'] == 'report';
      final isDiary = ins['type'] == 'diary';
      final isChat = !isReport && !isDiary;
      final isCrisis = ins['isCrisis'] == true || ins['crisisDetected'] == true;
      if (_insightFilter == 'report') return isReport;
      if (_insightFilter == 'diary') return isDiary;
      if (_insightFilter == 'chat') return isChat;
      if (_insightFilter == 'crisis') return isCrisis;
      return false;
    }).toList();

    return Column(
      children: [
        // Insight filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: insightFilters.map((f) {
                final isActive = _insightFilter == f;
                final isCrisisChip = f == 'crisis';
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _insightFilter = f),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: isActive
                            ? (isCrisisChip ? _red : _green)
                            : (isCrisisChip
                                ? const Color(0xFFFFF1F1)
                                : Colors.white),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive
                              ? (isCrisisChip ? _red : _green)
                              : (isCrisisChip
                                  ? const Color(0xFFFCA5A5)
                                  : const Color(0xFFE5E7EB)),
                        ),
                      ),
                      child: Text(
                        insightLabels[f]!,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? Colors.white
                              : (isCrisisChip ? _red : _textDim),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Expanded(
          child: client.sharedInsights.isEmpty
              ? _buildNoRecords()
              : filtered.isEmpty
                  ? Center(
                      child: Text('No records match this filter.',
                          style: GoogleFonts.outfit(
                              fontSize: 14, color: Colors.grey[500])))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) =>
                          _buildInsightCard(ctx, filtered[i]),
                    ),
        ),
      ],
    );
  }

  Widget _buildNoRecords() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded,
              size: 60, color: _green.withOpacity(0.15)),
          const SizedBox(height: 16),
          Text(
            'No Shared Records',
            style: GoogleFonts.playfairDisplay(
                fontSize: 18, fontWeight: FontWeight.bold, color: _textMain),
          ),
          const SizedBox(height: 8),
          Text(
            'When this client shares diaries,\nAI chats or reports, they appear here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(BuildContext ctx, Map<String, dynamic> ins) {
    final isReport = ins['type'] == 'report';
    final isDiary = ins['type'] == 'diary';
    final isChat = !isReport && !isDiary;
    final isCrisis = ins['isCrisis'] == true || ins['crisisDetected'] == true;

    final sharedAt = ins['_sharedAt'] as DateTime?;
    final dateStr = sharedAt != null
        ? DateFormat('d MMM yyyy, hh:mm a').format(sharedAt)
        : 'Recent';

    Color accentColor = _green;
    IconData accentIcon = Icons.chat_bubble_outline_rounded;
    String typeLabel = 'AI Chat Log';
    if (isReport) {
      accentColor = const Color(0xFF0284C7);
      accentIcon = Icons.summarize_rounded;
      typeLabel = 'Activity Report';
    } else if (isDiary) {
      accentColor = const Color(0xFFD97706);
      accentIcon = Icons.book_outlined;
      typeLabel = 'Diary Entry';
    }

    return GestureDetector(
      onTap: () {
        if (isReport) {
          _openReportCard(ctx, ins);
        } else {
          _openInsightDetail(ctx, ins);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: isCrisis
              ? Border.all(color: const Color(0xFFFCA5A5), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Crisis banner
            if (isCrisis)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
                  ),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 13),
                    const SizedBox(width: 6),
                    Text(
                      'CRISIS ALERT DETECTED',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type badge + date
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(accentIcon, size: 11, color: accentColor),
                            const SizedBox(width: 4),
                            Text(
                              typeLabel.toUpperCase(),
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        dateStr,
                        style: GoogleFonts.outfit(
                            fontSize: 11, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Summary
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: accentColor.withOpacity(0.12)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded,
                                size: 13, color: accentColor),
                            const SizedBox(width: 6),
                            Text(
                              isReport
                                  ? 'PATIENT REPORT'
                                  : isDiary
                                      ? 'DIARY ENTRY'
                                      : 'AI CLINICAL SUMMARY',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isReport
                              ? (ins['reportType'] ?? 'Activity Summary')
                              : isDiary
                                  ? (ins['diaryContent'] ??
                                      ins['text'] ??
                                      'No content.')
                                  : (ins['aiSummary'] ?? 'No summary.'),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: _textMain,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Emotion tags
                  if ((ins['emotionTags'] as List?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: (ins['emotionTags'] as List)
                          .map<Widget>(
                            (tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F4F2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '#$tag',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _green,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  // Tap hint
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        isReport ? 'Download Report' : 'View Full Record',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded,
                          size: 11, color: accentColor),
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

  // ─── Bottom Sheets ────────────────────────────────────────────────────────

  void _openReportCard(
      BuildContext context, Map<String, dynamic> data) async {
    final userName = data['userName'] ?? 'User';
    final reportType = data['reportType'] ?? 'Activity Summary';

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text('Generating $reportType...', style: GoogleFonts.outfit()),
      backgroundColor: _green,
    ));

    DateTimeRange? dateRange;
    if (data['dateRangeStart'] != null && data['dateRangeEnd'] != null) {
      dateRange = DateTimeRange(
        start: (data['dateRangeStart'] as Timestamp).toDate(),
        end: (data['dateRangeEnd'] as Timestamp).toDate(),
      );
    }

    await ReportGeneratorService.generateActivitySummaryReport(
      userName: userName,
      dateRange: dateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
      stats: Map<String, dynamic>.from(data['stats'] ?? {
        'diary': 0,
        'chatbot': 0,
        'resources': 0,
        'appointments': 0,
        'xp': 0
      }),
    );
  }

  void _openInsightDetail(
      BuildContext context, Map<String, dynamic> data) {
    final isCrisis =
        data['isCrisis'] == true || data['crisisDetected'] == true;
    final isDiary = data['type'] == 'diary';
    final messages = (data['messages'] as List?) ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.92,
        decoration: const BoxDecoration(
          color: Color(0xFFF2F1EC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            // Crisis banner in sheet
            if (isCrisis)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Crisis alert was detected in this session',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDiary
                          ? 'Diary Entry Details'
                          : 'AI Conversation Insights',
                      style: GoogleFonts.playfairDisplay(
                          fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isDiary
                          ? 'Shared diary entry from ${data['userName']}'
                          : 'Confidential shared chatbot session from ${data['userName']}',
                      style: GoogleFonts.outfit(
                          color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    _buildDetailSection(
                      isDiary ? 'Diary Content' : 'Clinical Summary',
                      isDiary
                          ? (data['diaryContent'] ??
                              data['text'] ??
                              'No content.')
                          : (data['aiSummary'] ?? 'No summary.'),
                      isDiary ? const Color(0xFFD97706) : _green,
                    ),
                    if (!isDiary && (data['emotionTags'] as List?)?.isNotEmpty == true) ...[
                      const SizedBox(height: 16),
                      _buildDetailSection(
                        'Emotion Profile',
                        'Key tones: ${(data['emotionTags'] as List).join(", ")}',
                        Colors.blue,
                      ),
                    ],
                    if (messages.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        'FULL CONVERSATION LOG',
                        style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: Colors.grey[400]),
                      ),
                      const SizedBox(height: 12),
                      ...messages.map((msg) {
                        final isBot = msg['role'] == 'assistant' ||
                            msg['role'] == 'bot';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isBot
                                ? Colors.white
                                : _green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isBot ? 'EUNOIA AI' : 'CLIENT',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  color: isBot ? _green : _textMain,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                msg['text'] ?? '',
                                style: GoogleFonts.outfit(
                                    fontSize: 14, height: 1.4),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, String content, Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: accent, size: 16),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: _textMain,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
