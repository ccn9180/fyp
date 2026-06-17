import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'session_feedback.dart';
import 'upcoming_session_detail.dart';

class SessionHistoryScreen extends StatefulWidget {
  const SessionHistoryScreen({super.key});

  @override
  State<SessionHistoryScreen> createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends State<SessionHistoryScreen> {
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFFBFBF6);
  final Color textColorMain = const Color(0xFF333333);
  final Color textColorSub = const Color(0xFF888888);

  final List<Map<String, dynamic>> _allCompletedSessions = [];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF333333), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'SESSION HISTORY',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: textColorMain,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildSearchAndFilterBar(),
          if (_statusFilter != 'All') _buildActiveFilterChip(),
          Expanded(child: _buildSessionStream(user)),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
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
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value.toLowerCase().trim()),
                  decoration: InputDecoration(
                    hintText: 'Search by counsellor or session focus...',
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
                color: _statusFilter != 'All' ? primaryGreen : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
              ),
              child: Icon(Icons.tune_rounded, size: 20, color: _statusFilter != 'All' ? Colors.white : Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterChip() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _statusFilter == 'Completed' ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
                size: 14,
                color: primaryGreen,
              ),
              const SizedBox(width: 8),
              Text(
                _statusFilter,
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: primaryGreen),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _statusFilter = 'All'),
                child: Icon(Icons.close_rounded, size: 16, color: primaryGreen),
              ),
            ],
          ),
        ),
      ),
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
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('Filter Sessions', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _buildFilterOption(Icons.list_alt_rounded, 'All Sessions', () {
              setState(() => _statusFilter = 'All');
              Navigator.pop(context);
            }),
            _buildFilterOption(Icons.check_circle_outline_rounded, 'Completed', () {
              setState(() => _statusFilter = 'Completed');
              Navigator.pop(context);
            }),
            _buildFilterOption(Icons.cancel_outlined, 'Missed', () {
              setState(() => _statusFilter = 'Missed');
              Navigator.pop(context);
            }, isLast: true),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(IconData icon, String label, VoidCallback onTap, {bool isLast = false}) {
    final bool isSelected = _statusFilter == label || (_statusFilter == 'All' && label == 'All Sessions');
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          leading: Icon(icon, color: primaryGreen, size: 20),
          title: Text(label, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500)),
          trailing: isSelected
              ? Icon(Icons.check_rounded, color: primaryGreen, size: 18)
              : const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 18),
          contentPadding: EdgeInsets.zero,
        ),
        if (!isLast) Divider(color: Colors.grey.withOpacity(0.1)),
      ],
    );
  }

  Widget _buildSessionStream(User? user) {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('counsellor_bookings')
            .where('patientId', isEqualTo: user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF7C9C84)));
          }
          
          if (snapshot.hasError) {
            debugPrint('Session History Stream Error: ${snapshot.error}');
            return Center(
              child: Text(
                'Something went wrong loading your history.',
                style: GoogleFonts.outfit(color: textColorSub, fontSize: 16),
              ),
            );
          }

          final List<Map<String, dynamic>> completedSessions = [];
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            for (var doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final startTime = (data['startTime'] as Timestamp?)?.toDate();
              final status = (data['status'] ?? '').toString().toUpperCase();

              // Include if explicitly completed or the start time has already passed
              if (status == 'COMPLETED' || (startTime != null && startTime.isBefore(DateTime.now()))) {
                final isMissed = status != 'COMPLETED';
                completedSessions.add({
                  ...data,
                  'id': doc.id,
                  'isMissed': isMissed,
                  'summary': data['summary'] ?? data['notes'] ?? (isMissed ? 'Session was missed or not attended.' : 'General counseling session to check in and monitor wellness goals.'),
                  'sessionDuration': data['sessionDuration'] ?? '60 mins',
                  'type': data['type'] ?? 'Video Call',
                });
              }
            }
          }

          completedSessions.sort((a, b) {
            final aTime = (a['startTime'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = (b['startTime'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime); // descending
          });

          final listToShow = completedSessions.where((session) {
            final matchesStatus = _statusFilter == 'All' ||
                (_statusFilter == 'Completed' && session['isMissed'] != true) ||
                (_statusFilter == 'Missed' && session['isMissed'] == true);
            final matchesSearch = _searchQuery.isEmpty ||
                (session['counsellorName'] ?? '').toString().toLowerCase().contains(_searchQuery) ||
                (session['summary'] ?? '').toString().toLowerCase().contains(_searchQuery);
            return matchesStatus && matchesSearch;
          }).toList();

          if (listToShow.isEmpty) {
            final bool hasActiveFilter = _searchQuery.isNotEmpty || _statusFilter != 'All';
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    hasActiveFilter ? Icons.search_off_rounded : Icons.history_rounded,
                    size: 48,
                    color: primaryGreen.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    hasActiveFilter ? 'No matching sessions' : 'No past sessions yet.',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColorMain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasActiveFilter
                        ? 'Try adjusting your search or filter.'
                        : 'Your completed and missed sessions will appear here.',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: textColorSub,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            itemCount: listToShow.length,
            itemBuilder: (context, index) {
              return _buildSessionCard(context, listToShow[index]);
            },
          );
        },
      );
  }

  Widget _buildSessionCard(BuildContext context, Map<String, dynamic> session) {
    final startTime = (session['startTime'] as Timestamp).toDate();
    final String imageUrl = session['counsellorImageUrl'] ?? '';
    
    return GestureDetector(
      onTap: () {
        if (session['isMissed'] == true) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UpcomingSessionDetailScreen(sessionData: session),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SessionFeedbackScreen(session: session),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFEEF3F0),
                backgroundImage: imageUrl.isNotEmpty 
                  ? (imageUrl.startsWith('data:image')
                      ? MemoryImage(base64Decode(imageUrl.split(',').last)) as ImageProvider
                      : NetworkImage(imageUrl))
                  : null,
                child: imageUrl.isEmpty ? const Icon(Icons.person, color: Color(0xFF98B3A1)) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session['counsellorName'],
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColorMain,
                      ),
                    ),
                    Text(
                      DateFormat('MMMM dd, yyyy').format(startTime),
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: textColorSub,
                      ),
                    ),
                  ],
                ),
              ),
              if (session['rating'] != null && (session['rating'] is int ? session['rating'] : int.tryParse(session['rating'].toString()) ?? 0) > 0)
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFFFB74D), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      session['rating'].toString(),
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: textColorMain,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if ((session['summary'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Session Focus:',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: primaryGreen,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              session['summary'],
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: textColorMain.withOpacity(0.8),
                height: 1.6,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              _buildMetricChip(Icons.access_time_rounded, session['sessionDuration']),
              const SizedBox(width: 8),
              _buildMetricChip(Icons.videocam_outlined, session['type']),
              const SizedBox(width: 8),
              _buildMetricChip(
                session['isMissed'] == true ? Icons.cancel_outlined : Icons.check_circle_outline, 
                session['isMissed'] == true ? 'Missed' : 'Completed',
                color: session['isMissed'] == true ? Colors.red.shade400 : primaryGreen,
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: primaryGreen),
            ],
          ),
        ],
      ),
    ));
  }

  Widget _buildMetricChip(IconData icon, String label, {Color? color}) {
    final effectiveColor = color ?? textColorSub;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: effectiveColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 11, color: effectiveColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
