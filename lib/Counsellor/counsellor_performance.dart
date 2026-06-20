
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../User/report_generator_service.dart';

class CounsellorPerformanceScreen extends StatefulWidget {
  const CounsellorPerformanceScreen({super.key});

  @override
  State<CounsellorPerformanceScreen> createState() => _CounsellorPerformanceScreenState();
}

class _CounsellorPerformanceScreenState extends State<CounsellorPerformanceScreen> {
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFF2F1EC);
  final Color textColorMain = const Color(0xFF333333);
  final Color accentGold = const Color(0xFFFFD700);

  String _rangeLabel = 'Weekly';
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );
  bool _isLoading = false;

  DateTime _parseAnyDate(dynamic val) {
    if (val == null) return DateTime.now();
    if (val is Timestamp) return val.toDate();
    String s = val.toString();
    try {
      return DateTime.parse(s);
    } catch (_) {
      try {
        return DateFormat('dd MMM yyyy').parse(s);
      } catch (_) {
        try {
          return DateFormat('d MMM yyyy').parse(s);
        } catch (_) {
          return DateTime.now();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        top: true,
        child: _isLoading 
            ? Center(child: CircularProgressIndicator(color: primaryGreen))
            : SingleChildScrollView(
                padding: const EdgeInsets.only(left: 24, right: 24, top: 20),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('counsellor_bookings')
                      .where('counsellorId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                      .snapshots(),
                  builder: (context, snapshotBookings) {
                    if (snapshotBookings.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    List<Map<String, dynamic>> allBookings = [];
                    if (snapshotBookings.hasData) {
                      allBookings = snapshotBookings.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
                    }
                    
                    List<Map<String, dynamic>> allReviews = allBookings
                        .where((b) => b['rating'] != null && (b['rating'] is int ? b['rating'] : int.tryParse(b['rating'].toString()) ?? 0) > 0)
                        .map((b) {
                      return {
                        'rating': b['rating'],
                        'comment': b['feedback'] is Map ? (b['feedback']['comment'] ?? '') : '',
                        'timestamp': b['feedbackSubmittedAt'] ?? b['startTime'] ?? b['date'],
                      };
                    }).toList();

                    // Filter by date range
                    List<Map<String, dynamic>> rangeBookings = allBookings.where((b) {
                      if (b['startTime'] == null && b['date'] == null) return false;
                      DateTime date = b['startTime'] != null ? _parseAnyDate(b['startTime']) : _parseAnyDate(b['date']);
                      return date.isAfter(_selectedDateRange.start.subtract(const Duration(days: 1))) &&
                             date.isBefore(_selectedDateRange.end.add(const Duration(days: 1)));
                    }).toList();

                    List<Map<String, dynamic>> completedRangeBookings = rangeBookings.where((b) => b['status']?.toString().toUpperCase() == 'COMPLETED').toList();
                    List<Map<String, dynamic>> allCompletedBookings = allBookings.where((b) => b['status']?.toString().toUpperCase() == 'COMPLETED').toList();

                    List<Map<String, dynamic>> rangeReviews = allReviews.where((r) {
                      if (r['timestamp'] == null) return true;
                      DateTime date = r['timestamp'] is Timestamp ? (r['timestamp'] as Timestamp).toDate() : DateTime.parse(r['timestamp'].toString());
                      return date.isAfter(_selectedDateRange.start.subtract(const Duration(days: 1))) &&
                             date.isBefore(_selectedDateRange.end.add(const Duration(days: 1)));
                    }).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMainTitleRow(completedRangeBookings.length, rangeReviews, rangeBookings),
                        const SizedBox(height: 24),
                        _buildTimeFilter(),
                        const SizedBox(height: 32),
                        _buildSummaryCards(rangeBookings, completedRangeBookings, rangeReviews),
                        const SizedBox(height: 16),
                        _buildSecondaryMetricsRow(rangeBookings),
                        const SizedBox(height: 32),
                        _buildSessionTrendChart(allBookings),
                        const SizedBox(height: 32),
                        const SizedBox(height: 32),
                        _buildRatingDistribution(allReviews),
                        const SizedBox(height: 32),
                        _ClientVoiceSection(reviews: allReviews, parseDate: _parseAnyDate),
                        const SizedBox(height: 32),
                        _buildFeedbackInsights(),
                        const SizedBox(height: 100),
                      ],
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildMainTitleRow(int sessions, List<Map<String, dynamic>> rangeReviews, List<Map<String, dynamic>> rangeBookings) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Clinical Performance',
          style: GoogleFonts.playfairDisplay(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: textColorMain,
          ),
        ),
        GestureDetector(
          onTap: () async {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Generating report...', style: GoogleFonts.outfit()),
                backgroundColor: primaryGreen,
                duration: const Duration(seconds: 2),
              ),
            );

            final uid = FirebaseAuth.instance.currentUser?.uid;
            String counsellorName = 'Expert';
            if (uid != null) {
              final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
              if (doc.exists) {
                counsellorName = doc.data()?['fullName'] ?? 'Expert';
              }
            }

            // ── Compute real stats for the PDF ───────────────────
            final bookingsSnap = await FirebaseFirestore.instance
                .collection('counsellor_bookings')
                .where('counsellorId', isEqualTo: uid)
                .get();

            final allDocs = bookingsSnap.docs.map((d) => d.data()).toList();

            final rangeDocs = allDocs.where((b) {
              if (b['startTime'] == null && b['date'] == null) return false;
              DateTime dt = b['startTime'] != null ? _parseAnyDate(b['startTime']) : _parseAnyDate(b['date']);
              return dt.isAfter(_selectedDateRange.start.subtract(const Duration(days: 1))) &&
                     dt.isBefore(_selectedDateRange.end.add(const Duration(days: 1)));
            }).toList();

            final completedRange = rangeBookings.where((b) => b['status']?.toString().toUpperCase() == 'COMPLETED').toList();

            // Avg rating
            double totalRating = 0;
            for (final r in rangeReviews) {
              totalRating += ((r['rating'] ?? 5) as num).toDouble();
            }
            final computedAvgRating = rangeReviews.isEmpty
                ? 'N/A'
                : (totalRating / rangeReviews.length).toStringAsFixed(1);

            // Completion rate
            final completionPct = rangeBookings.isEmpty
                ? '0'
                : ((completedRange.length / rangeBookings.length) * 100).toStringAsFixed(0);

            // Retention rate (patients with >1 booking in range)
            final Map<String, int> patientCounts = {};
            for (final b in rangeBookings) {
              final pid = b['patientId']?.toString() ?? b['userId']?.toString() ?? 'unknown';
              patientCounts[pid] = (patientCounts[pid] ?? 0) + 1;
            }
            final retentionCount = patientCounts.values.where((c) => c > 1).length;
            final retentionPct = patientCounts.isEmpty
                ? '0'
                : ((retentionCount / patientCounts.length) * 100).toStringAsFixed(0);

            // Clinical hours (assume 1h per session)
            final computedHours = completedRange.length.toStringAsFixed(1);
            // ─────────────────────────────────────────────────────

            await ReportGeneratorService.generateCounsellorPerformanceReport(
              counsellorName: counsellorName,
              totalSessions: sessions.toString(),
              avgRating: computedAvgRating,
              feedbackCount: rangeReviews.length.toString(),
              clinicalHours: computedHours,
              completionRate: '$completionPct%',
              retentionRate: '$retentionPct%',
              rangeLabel: _rangeLabel,
              dateRange: _selectedDateRange,
            );
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Icon(Icons.ios_share_outlined, color: primaryGreen, size: 24),
          ),
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

  Widget _buildSummaryCards(List<Map<String, dynamic>> allRangeBookings, List<Map<String, dynamic>> completedRangeBookings, List<Map<String, dynamic>> reviews) {
    final sessions = completedRangeBookings.length;
    double hours = sessions * 1.0; 
    
    double rating = 0.0;
    if (reviews.isNotEmpty) {
      double totalRating = 0;
      for (var r in reviews) {
        totalRating += (r['rating'] ?? 5).toDouble();
      }
      rating = totalRating / reviews.length;
    }

    double completionRate = allRangeBookings.isEmpty ? 0 : (completedRangeBookings.length / allRangeBookings.length) * 100;

    Map<String, int> patientCounts = {};
    for (var b in allRangeBookings) {
      String pId = b['patientId'] ?? b['userId'] ?? 'unknown';
      patientCounts[pId] = (patientCounts[pId] ?? 0) + 1;
    }
    int retentionCount = patientCounts.values.where((c) => c > 1).length;
    double retentionRate = patientCounts.isEmpty ? 0 : (retentionCount / patientCounts.length) * 100;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.3,
      children: [
        _buildMetricCard(Icons.star_rounded, 'Client Satisfaction', rating.toStringAsFixed(1), color: accentGold),
        _buildMetricCard(Icons.timer_rounded, 'Clinical Hours', '${hours.toStringAsFixed(1)}h', color: primaryGreen),
        _buildMetricCard(Icons.check_circle_outline_rounded, 'Completion Rate', '${completionRate.toStringAsFixed(0)}%', color: Colors.blue),
        _buildMetricCard(Icons.replay_circle_filled_rounded, 'Client Retention', '${retentionRate.toStringAsFixed(0)}%', color: Colors.purple),
      ],
    );
  }

  Widget _buildSecondaryMetricsRow(List<Map<String, dynamic>> allRangeBookings) {
    int cancelledCount = allRangeBookings.where((b) => b['status']?.toString().toUpperCase() == 'CANCELLED').length;
    double cancelRate = allRangeBookings.isEmpty ? 0 : (cancelledCount / allRangeBookings.length) * 100;

    Map<int, int> dayCounts = {};
    for (var b in allRangeBookings) {
      if (b['status']?.toString().toUpperCase() == 'COMPLETED') {
        if (b['startTime'] != null || b['date'] != null) {
          DateTime date = b['startTime'] != null ? _parseAnyDate(b['startTime']) : _parseAnyDate(b['date']);
          int weekday = date.weekday;
          dayCounts[weekday] = (dayCounts[weekday] ?? 0) + 1;
        }
      }
    }
    
    String peakDayStr = 'None';
    if (dayCounts.isNotEmpty) {
      int peakDay = dayCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      peakDayStr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][peakDay - 1];
    }

    return Row(
      children: [
        _buildSuccessChip('Peak Day: $peakDayStr', Icons.trending_up_rounded),
        const SizedBox(width: 12),
        _buildSuccessChip('${cancelRate.toStringAsFixed(1)}% Cancel Rate', Icons.cancel_outlined),
      ],
    );
  }



  Widget _buildSuccessChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryGreen.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: primaryGreen),
          const SizedBox(width: 8),
          Text(text, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textColorMain)),
        ],
      ),
    );
  }

  Widget _buildMetricCard(IconData icon, String label, String val, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color ?? primaryGreen.withOpacity(0.5)),
          const Spacer(),
          Text(val, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label, style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildRatingDistribution(List<Map<String, dynamic>> reviews) {
    double avgRating = 0;
    List<int> starCounts = [0, 0, 0, 0, 0];
    if (reviews.isNotEmpty) {
      double total = 0;
      for (var f in reviews) {
        double r = (f['rating'] ?? 5).toDouble();
        total += r;
        if (r >= 1 && r <= 5) starCounts[(r.round()) - 1]++;
      }
      avgRating = total / reviews.length;
    }

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rating Breakdown', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Row(
            children: [
              Column(
                children: [
                  Text(avgRating > 0 ? avgRating.toStringAsFixed(1) : '0.0', style: GoogleFonts.outfit(fontSize: 48, fontWeight: FontWeight.bold, color: textColorMain)),
                  Row(children: List.generate(5, (i) => Icon(Icons.star_rounded, color: i < avgRating.floor() ? accentGold : Colors.grey[200], size: 16))),
                  const SizedBox(height: 4),
                  Text('${reviews.length} reviews', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const SizedBox(width: 32),
              Expanded(
                child: reviews.isEmpty ? const Text('No ratings yet') : Column(
                  children: [
                    _buildRatingBar(5, starCounts[4] / reviews.length),
                    _buildRatingBar(4, starCounts[3] / reviews.length),
                    _buildRatingBar(3, starCounts[2] / reviews.length),
                    _buildRatingBar(2, starCounts[1] / reviews.length),
                    _buildRatingBar(1, starCounts[0] / reviews.length),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }



  Widget _buildCommentCard(String text, String date, int stars) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: List.generate(5, (i) => Icon(Icons.star_rounded, color: i < stars ? accentGold : Colors.grey[100], size: 10))),
              Text(date, style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          Text(text, style: GoogleFonts.outfit(fontSize: 13, height: 1.4, color: textColorMain.withOpacity(0.8))),
        ],
      ),
    );
  }

  Widget _buildRatingBar(int star, double pct) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text('$star', style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey)),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: pct, backgroundColor: backgroundColor, color: star >= 4 ? primaryGreen : Colors.grey[300], minHeight: 4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTrendChart(List<Map<String, dynamic>> allBookings) {
    bool isShortRange = _rangeLabel == 'Weekly' || (_rangeLabel == 'Custom' && _selectedDateRange.duration.inDays <= 14);

    List<double> counts = isShortRange ? List.filled(7, 0) : List.filled(6, 0);
    List<String> labels = [];

    if (isShortRange) {
      List<String> dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      for (int i = 6; i >= 0; i--) {
        DateTime d = _selectedDateRange.end.subtract(Duration(days: i));
        labels.add(dayNames[d.weekday % 7]);

        int count = allBookings.where((b) {
          if (b['status']?.toString().toUpperCase() != 'COMPLETED') return false;
          if (b['startTime'] == null && b['date'] == null) return false;
          DateTime bd = b['startTime'] != null ? _parseAnyDate(b['startTime']) : _parseAnyDate(b['date']);
          return bd.year == d.year && bd.month == d.month && bd.day == d.day;
        }).length;
        counts[6 - i] = count.toDouble();
      }
    } else {
      List<String> monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      for (int i = 5; i >= 0; i--) {
        DateTime d = DateTime(_selectedDateRange.end.year, _selectedDateRange.end.month - i, 1);
        labels.add(monthNames[d.month - 1]);

        int count = allBookings.where((b) {
          if (b['status']?.toString().toUpperCase() != 'COMPLETED') return false;
          if (b['startTime'] == null && b['date'] == null) return false;
          DateTime bd = b['startTime'] != null ? _parseAnyDate(b['startTime']) : _parseAnyDate(b['date']);
          return bd.year == d.year && bd.month == d.month;
        }).length;
        counts[5 - i] = count.toDouble();
      }
    }

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Session Productivity', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold)),
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
                    if (v.toInt() >= 0 && v.toInt() < labels.length) {
                      return Text(labels[v.toInt()], style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey));
                    }
                    return const Text('');
                  })),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(labels.length, (index) {
                  return _makeGroup(index, counts[index], counts[index] > 0 ? primaryGreen : Colors.grey[300]!);
                }),
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

  Widget _buildFeedbackInsights() {
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
              Text('Feedback Insights', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: primaryGreen)),
            ],
          ),
          const SizedBox(height: 24),
          _buildInsightPoint("Clients frequently mentioned your 'Active Listening' as a key strength."),
          const SizedBox(height: 12),
          _buildInsightPoint("90% of sessions resulted in positive mood improvements."),
          const SizedBox(height: 12),
          _buildInsightPoint("Suggestion: Several users expressed a wish for more late-evening slots."),
        ],
      ),
    );
  }

  Widget _buildInsightPoint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 6.0), child: Icon(Icons.circle, size: 6, color: primaryGreen.withOpacity(0.4))),
        const SizedBox(width: 16),
        Expanded(child: Text(text, style: GoogleFonts.outfit(fontSize: 14, color: textColorMain, height: 1.5))),
      ],
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
          height: MediaQuery.of(context).size.height * 0.7,
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
              const SizedBox(height: 16),
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
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 4),
      itemBuilder: (context, i) {
        if (i < offset || i >= daysInMonth + offset) return const SizedBox();
        final date = DateTime(month.year, month.month, i - offset + 1);
        
        final isStart = start != null && date.isAtSameMomentAs(start);
        final isEnd = end != null && date.isAtSameMomentAs(end);
        final isSelected = isStart || isEnd;
        final isInRange = start != null && end != null && date.isAfter(start) && date.isBefore(end);
        
        return GestureDetector(
          onTap: () => onSelect(date),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isInRange || isStart || isEnd)
                Container(
                  margin: EdgeInsets.only(
                    left: isStart ? 20 : 0,
                    right: isEnd ? 20 : 0,
                  ),
                  decoration: BoxDecoration(
                    color: primaryGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.horizontal(
                      left: isStart ? const Radius.circular(24) : Radius.zero,
                      right: isEnd ? const Radius.circular(24) : Radius.zero,
                    ),
                  ),
                ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isSelected ? primaryGreen : Colors.transparent,
                  shape: BoxShape.circle,
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
            ],
          ),
        );
      },
    );
  }
}

class _ClientVoiceSection extends StatefulWidget {
  final List<Map<String, dynamic>> reviews;
  final Function(dynamic) parseDate;

  const _ClientVoiceSection({Key? key, required this.reviews, required this.parseDate}) : super(key: key);

  @override
  _ClientVoiceSectionState createState() => _ClientVoiceSectionState();
}

class _ClientVoiceSectionState extends State<_ClientVoiceSection> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> feedbacks = widget.reviews.where((r) => r['comment'] != null && r['comment'].toString().isNotEmpty).toList();
    feedbacks.sort((a, b) {
      DateTime getBDate(Map<String, dynamic> bk) {
        if (bk['timestamp'] != null) return bk['timestamp'] is Timestamp ? (bk['timestamp'] as Timestamp).toDate() : DateTime.parse(bk['timestamp'].toString());
        return DateTime.now();
      }
      return getBDate(b).compareTo(getBDate(a));
    });

    if (feedbacks.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Client Voice', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text('No comments yet.', style: GoogleFonts.outfit(color: Colors.grey)),
        ],
      );
    }

    int itemsPerPage = 5;
    int totalPages = (feedbacks.length / itemsPerPage).ceil();
    
    // Ensure current page is valid
    if (_currentPage >= totalPages) {
      _currentPage = totalPages - 1 > 0 ? totalPages - 1 : 0;
    }
    
    int startIdx = _currentPage * itemsPerPage;
    int endIdx = (startIdx + itemsPerPage > feedbacks.length) ? feedbacks.length : startIdx + itemsPerPage;
    List<Map<String, dynamic>> currentFeedbacks = feedbacks.sublist(startIdx, endIdx);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Client Voice', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold)),
            if (totalPages > 1)
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                  ),
                  Text('${_currentPage + 1} / $totalPages', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 16),
        ...currentFeedbacks.map((f) {
          DateTime date = f['timestamp'] != null ? (f['timestamp'] is Timestamp ? (f['timestamp'] as Timestamp).toDate() : DateTime.parse(f['timestamp'].toString())) : DateTime.now();
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFFEEF3F0),
                      backgroundImage: (f['patientImageUrl'] ?? '').toString().isNotEmpty ? NetworkImage(f['patientImageUrl']) : null,
                      child: (f['patientImageUrl'] ?? '').toString().isEmpty ? const Icon(Icons.person, color: Color(0xFF98B3A1), size: 16) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        f['patientName'] ?? 'Anonymous',
                        style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF333333)),
                      ),
                    ),
                    Text(DateFormat('MMM dd').format(date), style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(children: List.generate(5, (i) => Icon(Icons.star_rounded, color: i < (f['rating'] ?? 5).toInt() ? const Color(0xFFD97706) : Colors.grey[100], size: 14))),
                const SizedBox(height: 8),
                Text(f['comment'], style: GoogleFonts.outfit(fontSize: 13, height: 1.4, color: const Color(0xFF2d3748).withOpacity(0.8))),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}
