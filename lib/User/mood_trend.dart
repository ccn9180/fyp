import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'report_generator_service.dart';
import 'widgets/mood_calendar_widget.dart';

class MoodTrendScreen extends StatefulWidget {
  const MoodTrendScreen({super.key});

  @override
  State<MoodTrendScreen> createState() => _MoodTrendScreenState();
}

class _MoodTrendScreenState extends State<MoodTrendScreen> {
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color accentGold = const Color(0xFFFFD700);
  final Color backgroundColor = const Color(0xFFF2F1EC);
  final Color textColorMain = const Color(0xFF333333);

  String _selectedFilter = 'Weekly'; 
  String _chartType = 'Line'; // Line, Bar
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );
  bool _isLoading = true;
  List<FlSpot> _chartSpots = [];
  
  Map<String, dynamic> _stats = {
    'avgMood': 'Neutral',
    'frequent': 'Neutral',
    'highest': 'N/A',
    'lowest': 'N/A',
    'consistency': '0%',
    'pieA': 33,
    'pieB': 34,
    'pieC': 33,
  };
  bool _isGrouped = false;

  @override
  void initState() {
    super.initState();
    _loadMoodData();
  }

  List<Map<String, dynamic>> _monthlyRecords = [];

  Future<void> _loadMoodData() async {
    setState(() => _isLoading = true);
    
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final now = DateTime.now();
      
      final fetchStart = DateTime(_selectedDateRange.start.year, _selectedDateRange.start.month, _selectedDateRange.start.day);
      final fetchEnd = DateTime(_selectedDateRange.end.year, _selectedDateRange.end.month, _selectedDateRange.end.day, 23, 59, 59);

      // Fetch Mood Check-ins
      final checkinsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('mood_checkins')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(fetchStart))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(fetchEnd))
          .get();

      // Fetch Diary Entries
      final diarySnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('diary_entries')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(fetchStart))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(fetchEnd))
          .get();

      // Fetch Chat Sessions
      final chatSnap = await FirebaseFirestore.instance
          .collection('chat_sessions')
          .where('userId', isEqualTo: uid)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(fetchStart))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(fetchEnd))
          .get();

      List<Map<String, dynamic>> records = [];

      for (var doc in checkinsSnap.docs) {
        final data = doc.data();
        if (data['timestamp'] != null) {
          records.add({
            'date': (data['timestamp'] as Timestamp).toDate(),
            'mood': data['emotion'] ?? 'Neutral',
            'source': 'Daily Check-in',
          });
        }
      }

      for (var doc in diarySnap.docs) {
        final data = doc.data();
        if (data['timestamp'] != null) {
          records.add({
            'date': (data['timestamp'] as Timestamp).toDate(),
            'mood': data['mood'] ?? 'Neutral',
            'source': 'Diary AI',
          });
        }
      }

      for (var doc in chatSnap.docs) {
        final data = doc.data();
        if (data['createdAt'] != null) {
          records.add({
            'date': (data['createdAt'] as Timestamp).toDate(),
            'mood': data['tag'] ?? 'Neutral',
            'source': 'AI Chat',
          });
        }
      }

      // Sort by date
      records.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

      // Calculate chart spots based on selected date range
      List<FlSpot> newSpots = [];
      final daysDiff = _selectedDateRange.end.difference(_selectedDateRange.start).inDays + 1;
      
      bool isWeeklyGrouped = _selectedFilter == 'Monthly' || daysDiff > 14;
      _isGrouped = isWeeklyGrouped;
      
      int binSize = 7;
      int numBins = isWeeklyGrouped ? (daysDiff / binSize).ceil() : daysDiff;

      int daysWithRecord = 0;
      double maxDayAvg = -1;
      double minDayAvg = 10;
      int maxDayIndex = -1;
      int minDayIndex = -1;

      for (int i = 0; i < numBins; i++) {
        int startDay = isWeeklyGrouped ? i * binSize : i;
        int endDay = isWeeklyGrouped ? startDay + binSize : startDay + 1;
        if (endDay > daysDiff) endDay = daysDiff;
        
        double sum = 0;
        int count = 0;
        
        for (int j = startDay; j < endDay; j++) {
          final targetDate = _selectedDateRange.start.add(Duration(days: j));
          final dayRecords = records.where((r) {
            final d = r['date'] as DateTime;
            return d.year == targetDate.year && d.month == targetDate.month && d.day == targetDate.day;
          }).toList();

          if (dayRecords.isNotEmpty) {
            if (!isWeeklyGrouped) daysWithRecord++;
            double dSum = 0;
            for (var r in dayRecords) {
              final m = (r['mood'] as String).toLowerCase();
              double score = 3;
              if (m.contains('happy') || m.contains('joy') || m.contains('great')) score = 5;
              else if (m.contains('calm') || m.contains('grateful') || m.contains('peace')) score = 4;
              else if (m.contains('neutral') || m.contains('focus')) score = 3;
              else if (m.contains('anxious') || m.contains('sleepy')) score = 2;
              else if (m.contains('angry') || m.contains('sad') || m.contains('low')) score = 1;
              dSum += score;
            }
            double dAvg = dSum / dayRecords.length;
            sum += dSum;
            count += dayRecords.length;
            
            if (dAvg > maxDayAvg) { maxDayAvg = dAvg; maxDayIndex = j; }
            if (dAvg < minDayAvg) { minDayAvg = dAvg; minDayIndex = j; }
          }
        }
        
        double binAvg = count > 0 ? sum / count : 3.0; // Default 3
        newSpots.add(FlSpot(i.toDouble(), binAvg));
      }

      if (isWeeklyGrouped) {
        for (int j = 0; j < daysDiff; j++) {
          final targetDate = _selectedDateRange.start.add(Duration(days: j));
          if (records.any((r) {
            final d = r['date'] as DateTime;
            return d.year == targetDate.year && d.month == targetDate.month && d.day == targetDate.day;
          })) {
            daysWithRecord++;
          }
        }
      }

      // Calculate Stats
      if (records.isNotEmpty) {
        Map<String, int> moodCounts = {};
        double totalScore = 0;
        int catA = 0, catB = 0, catC = 0;
        
        for (var r in records) {
          final m = (r['mood'] as String);
          moodCounts[m] = (moodCounts[m] ?? 0) + 1;
          
          double score = 3;
          final ml = m.toLowerCase();
          if (ml.contains('happy') || ml.contains('joy') || ml.contains('great')) score = 5;
          else if (ml.contains('calm') || ml.contains('grateful') || ml.contains('peace')) score = 4;
          else if (ml.contains('neutral') || ml.contains('focus')) score = 3;
          else if (ml.contains('anxious') || ml.contains('sleepy')) score = 2;
          else if (ml.contains('angry') || ml.contains('sad') || ml.contains('low')) score = 1;
          
          if (score >= 4) catA++;
          else if (score == 3) catB++;
          else catC++;
          
          totalScore += score;
        }
        
        String mostFrequent = moodCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
        double avgScore = totalScore / records.length;
        String highestDateStr = maxDayIndex >= 0 ? DateFormat('MMM d').format(_selectedDateRange.start.add(Duration(days: maxDayIndex))) : 'N/A';
        String lowestDateStr = minDayIndex >= 0 ? DateFormat('MMM d').format(_selectedDateRange.start.add(Duration(days: minDayIndex))) : 'N/A';
        
        int totalCat = catA + catB + catC;
        
        _stats = {
          'avgMood': _getMoodLabel(avgScore),
          'frequent': mostFrequent.length > 15 ? mostFrequent.substring(0, 15) : mostFrequent,
          'highest': highestDateStr,
          'lowest': lowestDateStr,
          'consistency': '${((daysWithRecord / daysDiff) * 100).toInt()}%',
          'pieA': totalCat > 0 ? ((catA / totalCat) * 100).toInt() : 33,
          'pieB': totalCat > 0 ? ((catB / totalCat) * 100).toInt() : 34,
          'pieC': totalCat > 0 ? ((catC / totalCat) * 100).toInt() : 33,
        };
      } else {
        _stats = {
          'avgMood': 'No Data',
          'frequent': 'No Data',
          'highest': 'No Data',
          'lowest': 'No Data',
          'consistency': '0%',
          'pieA': 33, 'pieB': 34, 'pieC': 33,
        };
      }

      if (mounted) {
        setState(() {
          _monthlyRecords = records;
          _chartSpots = newSpots;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading mood data: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
          'ANALYTICS & TRENDS',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: textColorMain,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, color: Color(0xFF333333), size: 20),
            onPressed: _showExportOptions,
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
                  const SizedBox(height: 12),
                  _buildTimeFilter(),
                  const SizedBox(height: 32),
                  _buildChartCard(),
                  const SizedBox(height: 32),
                  _buildInsightSummary(),
                  const SizedBox(height: 32),
                  _buildStatsGrid(),
                  const SizedBox(height: 32),
                  _buildEmotionalVarietyAnalysis(),
                  const SizedBox(height: 32),
                  const MoodCalendarWidget(),
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
        Text('Daily Recoveries', style: GoogleFonts.playfairDisplay(fontSize: 28, fontWeight: FontWeight.bold)),
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

  void _showFilterOptionsSheet(BuildContext context) {
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
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Text('Filter Analytics', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _buildFilterOption(Icons.today_rounded, 'Today', () {
              final now = DateTime.now();
              setState(() => _selectedDateRange = DateTimeRange(start: now, end: now));
              _loadMoodData(); Navigator.pop(context);
            }),
            _buildFilterOption(Icons.date_range_rounded, 'Last 7 Days', () {
              final now = DateTime.now();
              setState(() => _selectedDateRange = DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now));
              _loadMoodData(); Navigator.pop(context);
            }),
            _buildFilterOption(Icons.calendar_view_week_rounded, 'Last 30 Days', () {
              final now = DateTime.now();
              setState(() => _selectedDateRange = DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now));
              _loadMoodData(); Navigator.pop(context);
            }),
            _buildFilterOption(Icons.edit_calendar_rounded, 'Custom Date Range', () {
              Navigator.pop(context);
              _showCustomRangePicker(context);
            }, isLast: true),
          ],
        ),
      ),
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

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: Color(0xFFF2F1EC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Text('Export Report', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Export a full 8-section Mood Trend Analysis PDF with charts, emotion distribution, risk analysis, and AI insights.', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[600], height: 1.5), textAlign: TextAlign.center),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
                label: Text('Export Mood Trend PDF', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Generating Mood Trend Report...', style: GoogleFonts.outfit()),
                      backgroundColor: primaryGreen,
                      duration: const Duration(seconds: 2),
                    ),
                  );

                  // Fetch user name from Firestore
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  String userName = 'User';
                  if (uid != null) {
                    try {
                      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
                      if (doc.exists) userName = doc.data()?['fullName'] ?? 'User';
                    } catch (_) {}
                  }

                  await ReportGeneratorService.generateMoodTrendReport(
                    userName: userName,
                    dateRange: _selectedDateRange,
                    stats: _stats,
                    chartSpots: _chartSpots,
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 14)),
            ),
          ],
        ),
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
                decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(32)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))]),
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
                          setState(() {
                            _selectedDateRange = DateTimeRange(start: start!, end: end!);
                            _selectedFilter = 'Custom';
                          });
                          _loadMoodData(); Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, disabledBackgroundColor: Colors.grey[200], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
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
                  margin: EdgeInsets.only(left: isStart ? 17.5 : 0, right: isEnd ? 17.5 : 0),
                  decoration: BoxDecoration(color: primaryGreen.withOpacity(0.1), borderRadius: BorderRadius.horizontal(left: isStart ? const Radius.circular(20) : Radius.zero, right: isEnd ? const Radius.circular(20) : Radius.zero)),
                ),
              Container(
                width: 35, height: 35,
                decoration: BoxDecoration(color: (isStart || isEnd) ? primaryGreen : Colors.transparent, shape: BoxShape.circle),
                child: Center(child: Text(day.toString(), style: GoogleFonts.outfit(color: (isStart || isEnd) ? Colors.white : textColorMain, fontWeight: (isStart || isEnd || inRange) ? FontWeight.bold : FontWeight.normal, fontSize: 13))),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeFilter() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
      child: Row(
        children: ['Weekly', 'Monthly', 'Custom'].map((label) {
          bool isSelected = _selectedFilter == label;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (label == 'Custom') {
                  _showCustomRangePicker(context);
                } else {
                  setState(() {
                    _selectedFilter = label;
                    final now = DateTime.now();
                    if (label == 'Weekly') {
                      _selectedDateRange = DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
                    } else if (label == 'Monthly') {
                      _selectedDateRange = DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now);
                    }
                  });
                  _loadMoodData();
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

  Widget _buildChartCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Intensity Trend', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: textColorMain.withOpacity(0.5))),
              Row(
                children: [
                  _buildTypeToggle(Icons.show_chart_rounded, 'Line'),
                  const SizedBox(width: 8),
                  _buildTypeToggle(Icons.bar_chart_rounded, 'Bar'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 48),
          _isGrouped 
          ? SizedBox(
              height: 220,
              child: _chartType == 'Line' ? _buildLineChart() : _buildBarChart(),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                height: 220,
                width: _chartSpots.length > 7 ? _chartSpots.length * 40.0 : MediaQuery.of(context).size.width - 96,
                child: _chartType == 'Line' ? _buildLineChart() : _buildBarChart(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypeToggle(IconData icon, String type) {
    bool isSelected = _chartType == type;
    return GestureDetector(
      onTap: () => setState(() => _chartType = type),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: isSelected ? primaryGreen.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: isSelected ? primaryGreen : Colors.grey[300]),
      ),
    );
  }

  Widget _buildLineChart() {
    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => primaryGreen,
            getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
              String xLabel = _isGrouped ? "Week ${spot.x.toInt() + 1}" : DateFormat('MMM d').format(_selectedDateRange.start.add(Duration(days: spot.x.toInt())));
              return LineTooltipItem("$xLabel\n${_getMoodLabel(spot.y)}", GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11));
            }).toList(),
          ),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 1, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey[100]!, strokeWidth: 1)),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 1, getTitlesWidget: (v, m) => Text(_getMoodEmoji(v), style: const TextStyle(fontSize: 14)), reservedSize: 30)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, 
            interval: _isGrouped ? 1 : (_chartSpots.length > 7 ? (_chartSpots.length / 5).ceilToDouble() : 1),
            getTitlesWidget: (v, m) {
              if (v < 0 || v >= _chartSpots.length) return const SizedBox.shrink();
              String xLabel = _isGrouped ? "W${v.toInt() + 1}" : DateFormat('dd').format(_selectedDateRange.start.add(Duration(days: v.toInt())));
              return Text(xLabel, style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey));
            }, 
            reservedSize: 22
          )),
        ),
        borderData: FlBorderData(show: false),
        minX: 0, maxX: _chartSpots.isEmpty ? 6 : (_chartSpots.length - 1).toDouble(), minY: 0, maxY: 5.5,
        lineBarsData: [
          LineChartBarData(
            spots: _chartSpots, isCurved: true, color: primaryGreen, barWidth: 4, isStrokeCapRound: true,
            dotData: FlDotData(show: true, getDotPainter: (s, p, b, i) => FlDotCirclePainter(radius: 4, color: Colors.white, strokeWidth: 2, strokeColor: primaryGreen)),
            belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [primaryGreen.withOpacity(0.15), primaryGreen.withOpacity(0)])),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    return BarChart(
      BarChartData(
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => primaryGreen,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String xLabel = _isGrouped ? "Week ${group.x.toInt() + 1}" : DateFormat('MMM d').format(_selectedDateRange.start.add(Duration(days: group.x.toInt())));
              return BarTooltipItem(
                "$xLabel\n${_getMoodLabel(rod.toY)}",
                GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)
              );
            }
          )
        ),
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 1, getTitlesWidget: (v, m) => Text(_getMoodEmoji(v), style: const TextStyle(fontSize: 14)), reservedSize: 30)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, 
            getTitlesWidget: (v, m) {
              if (v < 0 || v >= _chartSpots.length) return const SizedBox.shrink();
              String xLabel = _isGrouped ? "W${v.toInt() + 1}" : DateFormat('dd').format(_selectedDateRange.start.add(Duration(days: v.toInt())));
              return Text(xLabel, style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey));
            },
            reservedSize: 22
          )),
        ),
        borderData: FlBorderData(show: false),
        barGroups: _chartSpots.map((spot) => BarChartGroupData(x: spot.x.toInt(), barRods: [BarChartRodData(toY: spot.y, color: primaryGreen, width: _isGrouped ? 20 : 14, borderRadius: BorderRadius.circular(6), backDrawRodData: BackgroundBarChartRodData(show: true, toY: 5, color: const Color(0xFFFBFBF6)))] )).toList(),
        maxY: 5,
      ),
    );
  }

  String _getMoodLabel(double val) => val > 4 ? 'Great' : (val > 3 ? 'Stable' : 'Low');
  String _getMoodEmoji(double val) {
    if (val.toInt() == 1) return '😞';
    if (val.toInt() == 3) return '😐';
    if (val.toInt() == 5) return '😊';
    return '';
  }

  Widget _buildInsightSummary() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: primaryGreen, size: 20),
              const SizedBox(width: 12),
              Text('Psychological Pattern', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: primaryGreen)),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _monthlyRecords.isEmpty 
              ? "No sufficient data to generate insights for this period. Try checking in or logging more diaries!"
              : "Your average mood is ${_stats['avgMood']}, with '${_stats['frequent']}' being your most common state. Your mood peaked on ${_stats['highest']} and dropped on ${_stats['lowest']}. Keep checking in to build better resilience patterns!",
            style: GoogleFonts.outfit(fontSize: 14, color: textColorMain, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.3,
      children: [
        _buildStatCard('Most Frequent', _stats['frequent'], Icons.favorite_outline),
        _buildStatCard('Consistency', _stats['consistency'], Icons.check_circle_outline),
      ],
    );
  }

  Widget _buildStatCard(String label, String val, IconData icon) {
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

  Widget _buildEmotionalVarietyAnalysis() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Emotional Variety', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          SizedBox(
            height: 140,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 30,
                sections: [
                  PieChartSectionData(value: _stats['pieA'].toDouble(), color: primaryGreen, title: '${_stats['pieA']}%', radius: 40, titleStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  PieChartSectionData(value: _stats['pieB'].toDouble(), color: const Color(0xFFBBCBC2), title: '${_stats['pieB']}%', radius: 35, titleStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  PieChartSectionData(value: _stats['pieC'].toDouble(), color: const Color(0xFFF0EFE9), title: '${_stats['pieC']}%', radius: 30, titleStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: primaryGreen)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildLegendRow('Optimism & High Energy', primaryGreen),
          _buildLegendRow('Peaceful & Contemplative', const Color(0xFFBBCBC2)),
          _buildLegendRow('Restless & Low Energy', const Color(0xFFF0EFE9)),
        ],
      ),
    );
  }

  Widget _buildLegendRow(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }
}
