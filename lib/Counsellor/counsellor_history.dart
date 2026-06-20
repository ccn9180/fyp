
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SessionHistoryScreen extends StatefulWidget {
  const SessionHistoryScreen({super.key});

  @override
  State<SessionHistoryScreen> createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends State<SessionHistoryScreen> {
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFF2F1EC);
  final Color textColorMain = const Color(0xFF333333);
  final Color textColorSub = const Color(0xFF888888);

  String _searchQuery = "";
  DateTimeRange? _dateRange;

  // Real data is fetched via StreamBuilder

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
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
          // Search and Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'Search patients or type...',
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
                      color: _dateRange != null ? primaryGreen : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
                    ),
                    child: Icon(Icons.tune_rounded, size: 20, color: _dateRange != null ? Colors.white : Colors.grey),
                  ),
                ),
              ],
            ),
          ),

          if (_dateRange != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 14, color: primaryGreen),
                    const SizedBox(width: 8),
                    Text(
                      '${DateFormat('MMM dd').format(_dateRange!.start)} — ${DateFormat('MMM dd').format(_dateRange!.end)}',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: primaryGreen),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _dateRange = null),
                      child: Icon(Icons.close_rounded, size: 16, color: primaryGreen),
                    ),
                  ],
                ),
              ),
            ),

          // List of History Items
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('counsellor_bookings')
                  .where('counsellorId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                  .where('status', whereIn: ['completed', 'missed', 'cancelled', 'COMPLETED', 'MISSED', 'CANCELLED'])
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF7C9C84)));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                List<Map<String, dynamic>> filteredHistory = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final startTime = data['startTime'] != null ? (data['startTime'] as Timestamp).toDate() : DateTime.now();
                  
                  return {
                    'id': doc.id,
                    'patientName': data['patientName'] ?? data['userName'] ?? 'Unknown Patient',
                    'date': DateFormat('dd MMM yyyy').format(startTime),
                    'dateTime': startTime,
                    'timeRange': data['timeRange'] ?? DateFormat('hh:mm a').format(startTime),
                    'type': data['type'] ?? 'Session',
                    'status': data['status']?.toString().toLowerCase() ?? 'completed',
                    'notes': data['notes'] ?? data['sessionSummary'] ?? data['missedReason'] ?? data['reason'] ?? data['cancelReason'],
                    'feedback': data['feedback'],
                  };
                }).where((item) {
                  final matchesSearch = (item['patientName'] as String).toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      (item['type'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
                  
                  bool matchesDate = true;
                  if (_dateRange != null) {
                    final dateTime = item['dateTime'] as DateTime;
                    matchesDate = dateTime.isAfter(_dateRange!.start.subtract(const Duration(days: 1))) &&
                        dateTime.isBefore(_dateRange!.end.add(const Duration(days: 1)));
                  }

                  return matchesSearch && matchesDate;
                }).toList()
                  ..sort((a, b) => (b['dateTime'] as DateTime).compareTo(a['dateTime'] as DateTime));

                if (filteredHistory.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: filteredHistory.length,
                  itemBuilder: (context, index) {
                    final item = filteredHistory[index];
                    return _buildHistoryCard(item);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 48, color: primaryGreen.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'No history found.',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColorMain,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or date range.',
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
            Text('Filter History', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _buildFilterOption(Icons.today_rounded, 'Today', () {
              final now = DateTime.now();
              setState(() => _dateRange = DateTimeRange(start: now, end: now));
              Navigator.pop(context);
            }),
            _buildFilterOption(Icons.date_range_rounded, 'Last 7 Days', () {
              final now = DateTime.now();
              setState(() => _dateRange = DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now));
              Navigator.pop(context);
            }),
            _buildFilterOption(Icons.calendar_view_week_rounded, 'Last 30 Days', () {
              final now = DateTime.now();
              setState(() => _dateRange = DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now));
              Navigator.pop(context);
            }),
            _buildFilterOption(Icons.edit_calendar_rounded, 'Custom Date Range', () {
              Navigator.pop(context);
              _showCustomRangePicker(context);
            }, isLast: true),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showCustomRangePicker(BuildContext context) {
    DateTime? start;
    DateTime? end;
    DateTime monthView = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Color(0xFFF2F1EC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Select Range', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
              ),

              // Month Selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat('MMMM yyyy').format(monthView), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                    Row(
                      children: [
                        IconButton(onPressed: () => setModalState(() => monthView = DateTime(monthView.year, monthView.month - 1)), icon: const Icon(Icons.chevron_left_rounded)),
                        IconButton(onPressed: () => setModalState(() => monthView = DateTime(monthView.year, monthView.month + 1)), icon: const Icon(Icons.chevron_right_rounded)),
                      ],
                    ),
                  ],
                ),
              ),

              // Calendar Grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildRangeCalendar(monthView, start, end, (date) {
                  setModalState(() {
                    if (start == null || (start != null && end != null)) {
                      start = date;
                      end = null;
                    } else {
                      if (date.isBefore(start!)) {
                        start = date;
                      } else {
                        end = date;
                      }
                    }
                  });
                }),
              ),

              const Spacer(),

              // Selected Info & Apply
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('DATES SELECTED', style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            const SizedBox(height: 4),
                            Text(
                              start == null ? 'None' : (end == null ? DateFormat('MMM dd').format(start!) : '${DateFormat('MMM dd').format(start!)} - ${DateFormat('MMM dd').format(end!)}'),
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: textColorMain),
                            ),
                          ],
                        ),
                        if (start != null)
                          TextButton(onPressed: () => setModalState(() { start = null; end = null; }), child: Text('RESET', style: GoogleFonts.outfit(color: Colors.red[300], fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: (start == null || end == null) ? null : () {
                          setState(() => _dateRange = DateTimeRange(start: start!, end: end!));
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          disabledBackgroundColor: Colors.grey[200],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Text('Apply Filter', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRangeCalendar(DateTime monthView, DateTime? start, DateTime? end, Function(DateTime) onDateTap) {
    final daysInMonth = DateTime(monthView.year, monthView.month + 1, 0).day;
    final firstWeekday = DateTime(monthView.year, monthView.month, 1).weekday;
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 0),
      itemCount: daysInMonth + (firstWeekday - 1),
      itemBuilder: (context, index) {
        if (index < firstWeekday - 1) return const SizedBox.shrink();
        
        final day = index - (firstWeekday - 2);
        final date = DateTime(monthView.year, monthView.month, day);
        
        bool isStart = start != null && date.year == start.year && date.month == start.month && date.day == start.day;
        bool isEnd = end != null && date.year == end.year && date.month == end.month && date.day == end.day;
        bool inRange = start != null && end != null && date.isAfter(start) && date.isBefore(end);

        return GestureDetector(
          onTap: () => onDateTap(date),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (inRange || isStart || isEnd)
                Container(
                  margin: EdgeInsets.only(
                    left: isStart ? 17.5 : 0, 
                    right: isEnd ? 17.5 : 0,
                  ),
                  decoration: BoxDecoration(
                    color: primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.horizontal(
                      left: isStart ? const Radius.circular(20) : Radius.zero,
                      right: isEnd ? const Radius.circular(20) : Radius.zero,
                    ),
                  ),
                ),
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: (isStart || isEnd) ? primaryGreen : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    day.toString(),
                    style: GoogleFonts.outfit(
                      color: (isStart || isEnd) ? Colors.white : textColorMain,
                      fontWeight: (isStart || isEnd || inRange) ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterOption(IconData icon, String label, VoidCallback onTap, {bool isLast = false}) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          leading: Icon(icon, color: primaryGreen, size: 20),
          title: Text(label, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500)),
          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 18),
          contentPadding: EdgeInsets.zero,
        ),
        if (!isLast) Divider(color: Colors.grey.withOpacity(0.1)),
      ],
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showHistoryDetail(item),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item['date'],
                        style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: primaryGreen),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: item['status'] == 'completed' ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item['status'].toString().toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 10, 
                          fontWeight: FontWeight.bold, 
                          color: item['status'] == 'completed' ? const Color(0xFF166534) : Colors.redAccent
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  item['patientName'],
                  style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold, color: textColorMain),
                ),
                const SizedBox(height: 4),
                Text(
                  item['type'],
                  style: GoogleFonts.outfit(fontSize: 13, color: textColorSub),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 14, color: textColorSub),
                    const SizedBox(width: 8),
                    Text(item['timeRange'], style: GoogleFonts.outfit(fontSize: 12, color: textColorSub)),
                    const Spacer(),
                    if (item['feedback'] != null)
                      Row(
                        children: [
                          Icon(Icons.star_rounded, size: 14, color: Colors.amber[600]),
                          const SizedBox(width: 4),
                          Text(
                            item['feedback']['rating'].toString(),
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textColorMain),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showHistoryDetail(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF2F1EC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: primaryGreen.withOpacity(0.1),
                      child: Text(
                        item['patientName'][0].toUpperCase(),
                        style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: primaryGreen),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(item['patientName'], style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold)),
                    Text(item['type'], style: GoogleFonts.outfit(color: textColorSub)),
                  ],
                ),
              ),

              // Summary Section
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(
                      item['status'] == 'completed' ? 'SESSION SUMMARY' : 
                      item['status'] == 'missed' ? 'REASON FOR MISSED SESSION' : 
                      'REASON FOR CANCELLATION'
                    ),
                    const SizedBox(height: 16),
                    Text(
                      item['notes'] ?? (item['status'] == 'completed' ? 'No notes recorded for this session.' : 'No reason provided.'),
                      style: GoogleFonts.outfit(fontSize: 14, color: textColorMain, height: 1.6),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),
                    _buildDetailRow(Icons.calendar_month_rounded, 'Date', item['date']),
                    const SizedBox(height: 16),
                    _buildDetailRow(Icons.access_time_rounded, 'Time', item['timeRange']),
                  ],
                ),
              ),

              // Feedback Section
              if (item['feedback'] != null) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.amber.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildSectionTitle('CLIENT FEEDBACK'),
                          const Spacer(),
                          Row(
                            children: List.generate(5, (index) => Icon(
                              Icons.star_rounded, 
                              size: 16, 
                              color: index < item['feedback']['rating'] ? Colors.amber[600] : Colors.grey[200],
                            )),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '"${item['feedback']['comment']}"',
                          style: GoogleFonts.outfit(
                            fontSize: 14, 
                            color: textColorMain, 
                            fontStyle: FontStyle.italic,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Shared on ${item['feedback']['date']}',
                        style: GoogleFonts.outfit(fontSize: 11, color: textColorSub),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: primaryGreen,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.withOpacity(0.3)),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.outfit(fontSize: 11, color: textColorSub)),
            Text(value, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: textColorMain)),
          ],
        ),
      ],
    );
  }
}
