
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'mood_trend.dart';
import 'report_generator_service.dart';

import 'package:fl_chart/fl_chart.dart';

class UserAnalyticsScreen extends StatefulWidget {
  const UserAnalyticsScreen({super.key});

  @override
  State<UserAnalyticsScreen> createState() => _UserAnalyticsScreenState();
}

class _UserAnalyticsScreenState extends State<UserAnalyticsScreen> {
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFF2F1EC);
  final Color textColorMain = const Color(0xFF333333);
  final Color accentGold = const Color(0xFFFFD700);

  String _rangeLabel = 'Weekly'; 
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );
  bool _isLoading = true;

  int _chatCount = 0;
  int _diaryCount = 0;
  int _resourceCount = 0;
  int _counselCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    if (mounted) setState(() => _isLoading = true);
    
    try {
      final start = Timestamp.fromDate(_selectedDateRange.start);
      final end = Timestamp.fromDate(_selectedDateRange.end.add(const Duration(days: 1)));

      // Diary - fallback to client side filtering if no composite index
      int dCount = 0;
      try {
        final diarySnap = await FirebaseFirestore.instance.collection('users').doc(uid).collection('diary_entries')
            .where('timestamp', isGreaterThanOrEqualTo: start)
            .where('timestamp', isLessThanOrEqualTo: end)
            .get();
        dCount = diarySnap.docs.length;
      } catch (e) {
        final allDiary = await FirebaseFirestore.instance.collection('users').doc(uid).collection('diary_entries').get();
        dCount = allDiary.docs.where((doc) {
          final ts = doc.data()['timestamp'] as Timestamp?;
          if (ts == null) return false;
          return ts.compareTo(start) >= 0 && ts.compareTo(end) <= 0;
        }).length;
      }
      
      // Chat - using createdAt instead of startedAt
      int chCount = 0;
      try {
        final chatSnap = await FirebaseFirestore.instance.collection('chat_sessions')
            .where('userId', isEqualTo: uid)
            .where('createdAt', isGreaterThanOrEqualTo: start)
            .where('createdAt', isLessThanOrEqualTo: end)
            .get();
        chCount = chatSnap.docs.length;
      } catch (e) {
        final allChats = await FirebaseFirestore.instance.collection('chat_sessions')
            .where('userId', isEqualTo: uid)
            .get();
        chCount = allChats.docs.where((doc) {
          final ts = doc.data()['createdAt'] as Timestamp?;
          if (ts == null) return false;
          return ts.compareTo(start) >= 0 && ts.compareTo(end) <= 0;
        }).length;
      }

      // Counseling sessions
      final counselSnap = await FirebaseFirestore.instance.collection('counsellor_bookings')
          .where('patientId', isEqualTo: uid)
          .get();
          
      int cCount = 0;
      for (var doc in counselSnap.docs) {
        final dData = doc.data();
        if (dData.containsKey('startTime')) {
          final ts = dData['startTime'] as Timestamp?;
          if (ts != null && ts.compareTo(start) >= 0 && ts.compareTo(end) <= 0) {
            cCount++;
          }
        }
      }
      
      // Resource (Favorites approximation)
      final resSnap = await FirebaseFirestore.instance.collection('users').doc(uid).collection('favorited_resources').get();

      if (mounted) {
        setState(() {
          _diaryCount = dCount;
          _chatCount = chCount;
          _counselCount = cCount;
          _resourceCount = resSnap.docs.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching analytics: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
          'ACTIVITY SUMMARY',
          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2, color: textColorMain),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, color: Color(0xFF333333), size: 20),
            onPressed: _showExportDialog,
          ),
        ],
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator(color: primaryGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderSection(),
                  const SizedBox(height: 32),
                  _buildTimeFilter(),
                  const SizedBox(height: 32),
                  _buildCombinedDataStream(),
                  const SizedBox(height: 32),
                  _buildMoodTrendSummaryCard(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderSection() {
    final rangeStr = "${DateFormat('MMM d').format(_selectedDateRange.start)} - ${DateFormat('MMM d').format(_selectedDateRange.end)}";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Engagement Pulse', style: GoogleFonts.playfairDisplay(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 12, color: primaryGreen),
            const SizedBox(width: 8),
            Text(rangeStr, style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeFilter() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
      child: Row(
        children: ['Weekly', 'Monthly', 'Custom'].map((label) {
          bool isSelected = _rangeLabel == label;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (label == 'Custom') {
                  _showCustomRangePicker(context);
                } else {
                  setState(() {
                    _rangeLabel = label;
                    if (label == 'Weekly') {
                      _selectedDateRange = DateTimeRange(start: DateTime.now().subtract(const Duration(days: 7)), end: DateTime.now());
                    } else if (label == 'Monthly') {
                      _selectedDateRange = DateTimeRange(start: DateTime.now().subtract(const Duration(days: 30)), end: DateTime.now());
                    }
                  });
                  _fetchData();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: isSelected ? primaryGreen : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                child: Center(
                  child: Text(label, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey[400])),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showCustomRangePicker(BuildContext context) {
    DateTime? start = _selectedDateRange.start;
    DateTime? end = _selectedDateRange.end;
    DateTime monthView = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(color: Color(0xFFF2F1EC), borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildRangeCalendar(monthView, start, end, (date) {
                  setModalState(() {
                    if (start == null || (start != null && end != null)) {
                      start = date; end = null;
                    } else {
                      if (date.isBefore(start!)) { start = date; } else { end = date; }
                    }
                  });
                }),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Selected Period', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
                          Text(
                            start != null && end != null 
                              ? "${DateFormat('MMM d').format(start!)} - ${DateFormat('MMM d').format(end!)}" 
                              : (start != null ? "Starting ${DateFormat('MMM d').format(start!)}" : "Select dates"),
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      onPressed: start != null && end != null ? () {
                         setState(() {
                           _selectedDateRange = DateTimeRange(start: start!, end: end!);
                           _rangeLabel = 'Custom';
                         });
                         _fetchData();
                         Navigator.pop(context);
                      } : null,
                      child: Text('Apply Filter', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _buildRangeCalendar(DateTime month, DateTime? start, DateTime? end, Function(DateTime) onSelect) {
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final firstDay = DateTime(month.year, month.month, 1);
    final offset = firstDay.weekday - 1;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 42,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
      itemBuilder: (context, i) {
        if (i < offset || i >= daysInMonth + offset) return const SizedBox();
        final date = DateTime(month.year, month.month, i - offset + 1);
        final isSelected = (start != null && date.isAtSameMomentAs(start)) || (end != null && date.isAtSameMomentAs(end));
        final isInRange = start != null && end != null && date.isAfter(start) && date.isBefore(end);
        
        return GestureDetector(
          onTap: () => onSelect(date),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected ? primaryGreen : (isInRange ? primaryGreen.withOpacity(0.1) : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                "${date.day}",
                style: GoogleFonts.outfit(
                  color: isSelected ? Colors.white : (isInRange ? primaryGreen : textColorMain),
                  fontWeight: isSelected || isInRange ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCombinedDataStream() {

    return Column(
      children: [
        _buildMetricsGrid(_chatCount, _diaryCount, _resourceCount, _counselCount),
        const SizedBox(height: 32),
        _buildComparisonChart(_chatCount, _diaryCount, _resourceCount, _counselCount),
        const SizedBox(height: 32),
        _buildAIInsightsSection(_chatCount, _diaryCount),
        const SizedBox(height: 32),
        _buildDetailedList(_chatCount, _diaryCount, _resourceCount, _counselCount),
      ],
    );
  }

  Widget _buildMetricsGrid(int chat, int diary, int resource, int counsel) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.3,
      children: [
        _buildMetricCard(Icons.chat_bubble_outline_rounded, 'Chatbot', chat.toString()),
        _buildMetricCard(Icons.edit_note_rounded, 'Diary', diary.toString()),
        _buildMetricCard(Icons.menu_book_rounded, 'Resources', resource.toString()),
        _buildMetricCard(Icons.people_outline_rounded, 'Sessions', counsel.toString()),
      ],
    );
  }

  Widget _buildMetricCard(IconData icon, String label, String val) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: primaryGreen.withOpacity(0.5)),
          const Spacer(),
          Text(val, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label, style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildComparisonChart(int chat, int diary, int res, int coun) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Activity Distribution', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 48),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) {
                    const labels = ['Chat', 'Diary', 'Res', 'Sess'];
                    if (v.toInt() >= 0 && v.toInt() < labels.length) {
                      return Text(labels[v.toInt()], style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey));
                    }
                    return const Text('');
                  })),
                ),
                borderData: FlBorderData(show: false),
                maxY: ([chat, diary, res, coun].reduce((a, b) => a > b ? a : b) + 5).toDouble(),
                barGroups: [
                  _makeGroup(0, chat.toDouble(), primaryGreen),
                  _makeGroup(1, diary.toDouble(), const Color(0xFFBBCBC2)),
                  _makeGroup(2, res.toDouble(), const Color(0xFFE8E7DF)),
                  _makeGroup(3, coun.toDouble(), const Color(0xFF7C9C84)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _makeGroup(int x, double y, Color color) {
    return BarChartGroupData(x: x, barRods: [BarChartRodData(toY: y, color: color, width: 22, borderRadius: BorderRadius.circular(6))]);
  }

  Widget _buildAIInsightsSection(int chat, int diary) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: primaryGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(32)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: primaryGreen, size: 20),
              const SizedBox(width: 12),
              Text('System Insights', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: primaryGreen)),
            ],
          ),
          const SizedBox(height: 24),
          _buildInsightPoint(chat > 10 ? "You used the chatbot most frequently in this period." : "Chatbot usage is steady, providing constant support."),
          const SizedBox(height: 12),
          _buildInsightPoint(diary > 5 ? "Journaling frequency is significantly high lately." : "Regular journaling is helping stabilize your emotional trend."),
        ],
      ),
    );
  }

  Widget _buildInsightPoint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.only(top: 6.0), child: Icon(Icons.circle, size: 6, color: Colors.grey)),
        const SizedBox(width: 16),
        Expanded(child: Text(text, style: GoogleFonts.outfit(fontSize: 14, color: textColorMain, height: 1.5))),
      ],
    );
  }

  Widget _buildDetailedList(int chat, int diary, int res, int coun) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Detailed Breakdown', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _buildBreakdownItem(Icons.chat_bubble_outline_rounded, 'AI Support Sessions', chat, 'sessions'),
        _buildBreakdownItem(Icons.edit_note_rounded, 'Reflective Entries', diary, 'entries'),
        _buildBreakdownItem(Icons.menu_book_rounded, 'Resources Viewed', res, 'articles'),
        _buildBreakdownItem(Icons.people_outline_rounded, 'Counseling Attended', coun, 'sessions'),
      ],
    );
  }

  Widget _buildBreakdownItem(IconData icon, String label, int count, String unit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle), child: Icon(icon, size: 18, color: primaryGreen)),
          const SizedBox(width: 20),
          Expanded(child: Text(label, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600))),
          Text('$count $unit', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: primaryGreen)),
        ],
      ),
    );
  }

  Widget _buildMoodTrendSummaryCard() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MoodTrendScreen())),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32)),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: primaryGreen.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.auto_graph_rounded, color: primaryGreen)),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Detailed Mood Trends', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('Explore your emotional arc and AI insights.', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }

  void _showExportDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 48),
        decoration: const BoxDecoration(
          color: Color(0xFFF2F1EC),
          borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Text('Export Report', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Choose an institutional audit format to export your clinical findings and activity engagement metrics.', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[600], height: 1.5)),
            const SizedBox(height: 32),
            _buildExportOption(Icons.summarize_rounded, 'Activity Summary', 'Detailed engagement audit'),
            const SizedBox(height: 16),
            _buildExportOption(Icons.image_rounded, 'Activity Snapshot', 'Export as captured image'),
            const SizedBox(height: 16),
            _buildShareOption(),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption() {
    return InkWell(
      onTap: () async {
        Navigator.pop(context);
        _showCounsellorSelectionDialog();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: primaryGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.send_rounded, color: primaryGreen),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Share with Counsellor', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Directly send data to your counsellor', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  void _showCounsellorSelectionDialog() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final snap = await FirebaseFirestore.instance.collection('counsellor_bookings')
          .where('patientId', isEqualTo: uid)
          .get();
          
      Navigator.pop(context); // pop loading
      
      final Map<String, String> counsellors = {};
      for (var doc in snap.docs) {
        if (doc.data().containsKey('counsellorId') && doc.data().containsKey('counsellorName')) {
          counsellors[doc.data()['counsellorId']] = doc.data()['counsellorName'];
        }
      }
      
      if (counsellors.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No past counsellors found to share with.', style: GoogleFonts.outfit())));
        return;
      }
      
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select Counsellor', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ...counsellors.entries.map((e) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(backgroundColor: primaryGreen.withOpacity(0.2), child: Icon(Icons.person, color: primaryGreen)),
                  title: Text(e.value, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.send_rounded, size: 20),
                  onTap: () {
                    Navigator.pop(context);
                    _shareReportWithCounsellor(e.key, e.value);
                  },
                )).toList(),
                const SizedBox(height: 16),
              ],
            ),
          );
        }
      );

    } catch (e) {
      Navigator.pop(context);
      debugPrint('Error loading counsellors: $e');
    }
  }

  Future<void> _shareReportWithCounsellor(String counsellorId, String counsellorName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    String userName = user.displayName ?? 'Patient Recovery';
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists) userName = doc.data()?['fullName'] ?? userName;

    try {
      await FirebaseFirestore.instance.collection('shared_chats').add({
        'counsellorId': counsellorId,
        'patientId': user.uid,
        'userName': userName,
        'sharedAt': FieldValue.serverTimestamp(),
        'type': 'report',
        'reportType': 'Activity Summary',
        'dateRangeStart': Timestamp.fromDate(_selectedDateRange.start),
        'dateRangeEnd': Timestamp.fromDate(_selectedDateRange.end),
        'stats': {
          'diary': _diaryCount,
          'chatbot': _chatCount,
          'resources': _resourceCount,
          'appointments': _counselCount,
          'xp': 450,
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Report successfully shared with $counsellorName', style: GoogleFonts.outfit()),
          backgroundColor: primaryGreen,
        ));
      }
    } catch (e) {
      debugPrint('Share error: $e');
    }
  }

  Widget _buildExportOption(IconData icon, String title, String sub) {
    return InkWell(
      onTap: () async {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Generating $title...', style: GoogleFonts.outfit()), 
          backgroundColor: primaryGreen, 
          behavior: SnackBarBehavior.floating
        ));
        
        final user = FirebaseAuth.instance.currentUser;
        String userName = user?.displayName ?? 'Patient Recovery';
        
        // Fetch full name if available
        if (user?.uid != null) {
          final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
          if (doc.exists) userName = doc.data()?['fullName'] ?? userName;
        }

        if (title.contains('Activity Summary')) {
          await ReportGeneratorService.generateActivitySummaryReport(
            userName: userName,
            dateRange: _selectedDateRange,
            stats: {
              'diary': _diaryCount,
              'chatbot': _chatCount,
              'resources': _resourceCount,
              'appointments': _counselCount,
              'xp': 450,
            },
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: primaryGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: primaryGreen),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(sub, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
