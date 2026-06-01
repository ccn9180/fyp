
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        toolbarHeight: 0, // Removes the height of the AppBar
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false, 
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator(color: primaryGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.only(left: 24, right: 24, top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMainTitleRow(),
                  const SizedBox(height: 24),
                  _buildTimeFilter(),
                  const SizedBox(height: 32),
                  _buildSummaryCards(),
                  const SizedBox(height: 32),
                  _buildSuccessMetricsRow(),
                  const SizedBox(height: 32),
                  _buildRatingDistribution(),
                  const SizedBox(height: 32),
                  _buildRecentCommentsSection(),
                  const SizedBox(height: 32),
                  _buildSessionTrendChart(),
                  const SizedBox(height: 32),
                  _buildFeedbackInsights(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }

  Widget _buildMainTitleRow() {
    final days = _selectedDateRange.duration.inDays.clamp(1, 100);
    final sessions = (days * 1.5).toInt() + 2;
    final feedback = (sessions * 0.7).toInt();
    final hours = (sessions * 0.8).toStringAsFixed(1);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Clinical Performance',
          style: GoogleFonts.playfairDisplay(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: textColorMain,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: IconButton(
            onPressed: () async {
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

              await ReportGeneratorService.generateCounsellorPerformanceReport(
                counsellorName: counsellorName,
                totalSessions: sessions.toString(),
                avgRating: '4.8',
                feedbackCount: feedback.toString(),
                clinicalHours: hours,
                completionRate: '94%',
                retentionRate: '82%',
                rangeLabel: _rangeLabel,
                dateRange: _selectedDateRange,
              );
            },
            icon: Icon(Icons.ios_share_rounded, size: 20, color: primaryGreen),
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

  Widget _buildSummaryCards() {
    final days = _selectedDateRange.duration.inDays.clamp(1, 100);
    final sessions = (days * 1.5).toInt() + 2;
    final rating = 4.8;
    final feedback = (sessions * 0.7).toInt();
    final hours = sessions * 0.8;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.3,
      children: [
        _buildMetricCard(Icons.star_rounded, 'Avg Rating', rating.toString(), color: accentGold),
        _buildMetricCard(Icons.trending_up_rounded, 'Peak Day', 'Tuesday', color: Colors.blue),
        _buildMetricCard(Icons.forum_rounded, 'Feedbacks', feedback.toString()),
        _buildMetricCard(Icons.timer_rounded, 'Clinical Hours', '${hours.toStringAsFixed(1)}h'),
      ],
    );
  }

  Widget _buildSuccessMetricsRow() {
    return Row(
      children: [
        _buildSuccessChip('94% Completion', Icons.check_circle_outline_rounded),
        const SizedBox(width: 12),
        _buildSuccessChip('82% Retention', Icons.replay_circle_filled_rounded),
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

  Widget _buildRatingDistribution() {
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
                  Text('4.8', style: GoogleFonts.outfit(fontSize: 48, fontWeight: FontWeight.bold, color: textColorMain)),
                  Row(children: List.generate(5, (i) => Icon(Icons.star_rounded, color: i < 4 ? accentGold : Colors.grey[200], size: 16))),
                  const SizedBox(height: 4),
                  Text('124 reviews', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  children: [
                    _buildRatingBar(5, 0.85),
                    _buildRatingBar(4, 0.10),
                    _buildRatingBar(3, 0.03),
                    _buildRatingBar(2, 0.01),
                    _buildRatingBar(1, 0.01),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentCommentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Client Voice', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildCommentCard("The sessions felt very safe and I felt heard for the first time.", "Oct 12", 5),
        _buildCommentCard("Active listening was great, but I'd love more homework exercises.", "Oct 09", 4),
        _buildCommentCard("Always professional and calm. Highly recommended.", "Oct 05", 5),
      ],
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

  Widget _buildSessionTrendChart() {
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
                    const labels = ['Week 1', 'Week 2', 'Week 3', 'Week 4'];
                    if (v.toInt() >= 0 && v.toInt() < labels.length) {
                      return Text(labels[v.toInt()], style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey));
                    }
                    return const Text('');
                  })),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _makeGroup(0, 12, primaryGreen),
                  _makeGroup(1, 18, primaryGreen),
                  _makeGroup(2, 15, primaryGreen),
                  _makeGroup(3, 22, accentGold),
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
