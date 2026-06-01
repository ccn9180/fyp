import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'session_detail.dart';

class CounsellorScheduleScreen extends StatefulWidget {
  const CounsellorScheduleScreen({super.key});

  @override
  State<CounsellorScheduleScreen> createState() => _CounsellorScheduleScreenState();
}

class _CounsellorScheduleScreenState extends State<CounsellorScheduleScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isMonthlyView = false;
  final Color primaryGreen = const Color(0xFF7C9C84); // Standard App Green
  final Color backgroundColor = const Color(0xFFF2F1EC);
  final Color textColorMain = const Color(0xFF333333);
  final Color textColorSub = const Color(0xFF888888);

  // Hardcoded mockup data for demo purposes
  final List<Map<String, dynamic>> _mockSessions = [
    {
      'id': 'm0',
      'patientName': 'Marcus Brown',
      'userName': 'Marcus Brown',
      'patientId': 'USR_000',
      'counsellorId': 'CNS_001',
      'startTime': Timestamp.fromMillisecondsSinceEpoch(DateTime.now().subtract(const Duration(hours: 3)).millisecondsSinceEpoch),
      'date': DateFormat('dd MMM yyyy').format(DateTime.now()),
      'timeRange': '07:30 AM',
      'type': 'Follow-up Session',
      'status': 'COMPLETED',
      'icon': Icons.check_circle_outline_rounded,
      'isPast': true,
    },
    {
      'id': 'm1',
      'patientName': 'Elena Rodriguez',
      'userName': 'Elena Rodriguez',
      'patientId': 'USR_001',
      'counsellorId': 'CNS_001',
      'startTime': Timestamp.fromDate(DateTime.now().copyWith(hour: 9, minute: 0)),
      'date': DateFormat('dd MMM yyyy').format(DateTime.now()),
      'timeRange': '09:00 AM',
      'type': 'Video Call',
      'status': 'CONFIRMED',
      'icon': Icons.videocam_rounded,
    },
    {
      'id': 'm2',
      'patientName': 'Julian Thorne',
      'userName': 'Julian Thorne',
      'patientId': 'USR_002',
      'counsellorId': 'CNS_001',
      'startTime': Timestamp.fromDate(DateTime.now().copyWith(hour: 11, minute: 30)),
      'date': DateFormat('dd MMM yyyy').format(DateTime.now()),
      'timeRange': '11:30 AM',
      'type': 'In-person Session',
      'status': 'CONFIRMED',
      'icon': Icons.person_rounded,
      'isCurrent': true,
      'location': 'Room 402, Studio A',
    },
    {
      'id': 'm5',
      'patientName': 'Oliver Twist',
      'userName': 'Oliver Twist',
      'patientId': 'USR_005',
      'counsellorId': 'CNS_001',
      'startTime': Timestamp.fromDate(DateTime(2026, 04, 05, 10, 0)),
      'date': '05 Apr 2026',
      'timeRange': '10:00 AM',
      'type': 'Initial Consult',
      'status': 'CONFIRMED',
      'icon': Icons.person_rounded,
    },
    {
      'id': 'm15',
      'patientName': 'Zoe Quinn',
      'userName': 'Zoe Quinn',
      'patientId': 'USR_006',
      'counsellorId': 'CNS_001',
      'startTime': Timestamp.fromDate(DateTime(2026, 04, 15, 14, 0)),
      'date': '15 Apr 2026',
      'timeRange': '02:00 PM',
      'type': 'Cognitive Therapy',
      'status': 'CONFIRMED',
      'icon': Icons.psychology_rounded,
    },
    {
      'id': 'm20',
      'patientName': 'Sarah Bell',
      'userName': 'Sarah Bell',
      'patientId': 'USR_007',
      'counsellorId': 'CNS_001',
      'startTime': Timestamp.fromDate(DateTime(2026, 04, 20, 15, 30)),
      'date': '20 Apr 2026',
      'timeRange': '03:30 PM',
      'type': 'Consultation',
      'status': 'PENDING',
      'icon': Icons.access_time_rounded,
    },
  ];

  // Dates that have appointments (day only for simplicity in demo)
  final List<int> _appointmentDates = [5, 15, 20, DateTime.now().day];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        top: true,
        child: _isMonthlyView ? _buildMonthlyCalendar() : _buildDailyView(),
      ),
    );
  }

  Widget _buildDailyView() {
      return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Date Header - Reduced Padding
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main Title Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Your Sessions',
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
                            onPressed: () {},
                            icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF333333), size: 22),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Secondary Filter Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: () => setState(() => _isMonthlyView = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                                color: primaryGreen.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Monthly',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: primaryGreen,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(Icons.calendar_month_rounded, size: 14, color: primaryGreen),
                              ],
                            ),
                          ),
                        ),
                        Text(
                          DateFormat('MMMM yyyy').format(_selectedDate).toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: primaryGreen,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Week Day Selection
            SliverToBoxAdapter(
              child: _buildWeekDaySelector(),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 30)),

            // Timeline List
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: _buildTimeline(),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        );
  }

  Widget _buildMonthlyCalendar() {
    final firstDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final lastDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final startWeekday = firstDayOfMonth.weekday; // 1 = Monday, 7 = Sunday
    
    // Adjust for grid starting on Monday (index 0)
    final offset = startWeekday - 1;
    final totalItems = daysInMonth + offset;

    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('yyyy').format(_selectedDate).toUpperCase(),
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: primaryGreen,
                                letterSpacing: 1.5,
                              ),
                            ),
                            Text('Calendar', style: GoogleFonts.playfairDisplay(fontSize: 26, fontWeight: FontWeight.bold, color: textColorMain)),
                          ],
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]
                          ),
                          child: IconButton(
                              onPressed: () => setState(() => _isMonthlyView = false),
                              icon: const Icon(Icons.close_rounded, size: 20),
                          ),
                        ),
                    ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 40, offset: const Offset(0, 10))
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    onPressed: () => setState(() => _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1)),
                                    icon: Icon(Icons.chevron_left_rounded, color: primaryGreen),
                                  ),
                                  Text(
                                    DateFormat('MMMM yyyy').format(_selectedDate),
                                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: textColorMain),
                                  ),
                                  IconButton(
                                    onPressed: () => setState(() => _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1)),
                                    icon: Icon(Icons.chevron_right_rounded, color: primaryGreen),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: ['M','T','W','T','F','S','S'].map((d) => SizedBox(width: 32, child: Center(child: Text(d, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[400], fontWeight: FontWeight.bold))))).toList(),
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 16),
                              GridView.builder(
                                shrinkWrap: true,
                                itemCount: totalItems,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 8, crossAxisSpacing: 8),
                                itemBuilder: (context, index) {
                                  if (index < offset) return const SizedBox.shrink();
                                  
                                  int day = index - offset + 1;
                                  bool hasAppt = _appointmentDates.contains(day); 
                                  bool isSelected = day == _selectedDate.day;
                                  bool isToday = day == DateTime.now().day && _selectedDate.month == DateTime.now().month && _selectedDate.year == DateTime.now().year;
                                  
                                  return GestureDetector(
                                    onTap: () => setState(() {
                                      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month, day);
                                    }),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: isSelected ? primaryGreen : (hasAppt ? primaryGreen.withOpacity(0.15) : (isToday ? primaryGreen.withOpacity(0.05) : Colors.transparent)),
                                            shape: BoxShape.circle,
                                            border: (isToday && !isSelected) ? Border.all(color: primaryGreen, width: 1.5) : (hasAppt && !isSelected ? Border.all(color: primaryGreen.withOpacity(0.3), width: 1) : null),
                                          ),
                                          child: Center(
                                            child: Text(
                                              day.toString(),
                                              style: GoogleFonts.outfit(
                                                fontSize: 14, 
                                                fontWeight: isSelected || hasAppt || isToday ? FontWeight.bold : FontWeight.normal,
                                                color: isSelected ? Colors.white : (hasAppt || isToday ? primaryGreen : textColorMain),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        // Daily breakdown for the selected day in Monthly View
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Schedule for ${DateFormat('MMM dd').format(_selectedDate)}',
                                    style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold, color: textColorMain),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () => setState(() => _isMonthlyView = false),
                                    child: Text('View Details', style: GoogleFonts.outfit(color: primaryGreen, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildDailyListInMonthlyView(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
            ],
        ),
    );
  }

  Widget _buildWeekDaySelector() {
    // Calculate the start of the week for the currently selected date
    final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));

    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 7,
        itemBuilder: (context, index) {
          final date = startOfWeek.add(Duration(days: index));
          bool isSelected = date.day == _selectedDate.day && date.month == _selectedDate.month && date.year == _selectedDate.year;

          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 55,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? primaryGreen : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                    if (isSelected) BoxShadow(color: primaryGreen.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
                    if (!isSelected) BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 4),
                ]
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(date).toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      color: isSelected ? Colors.white.withOpacity(0.8) : Colors.grey[400],
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    date.day.toString(),
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : textColorMain,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeline() {
    final user = FirebaseAuth.instance.currentUser;
    final String selectedDateStr = DateFormat('dd MMM yyyy').format(_selectedDate);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('counsellor_bookings')
          .where('counsellorId', isEqualTo: user?.uid)
          .where('date', isEqualTo: selectedDateStr)
          .snapshots(),
      builder: (context, snapshot) {
        bool useMock = !snapshot.hasData || snapshot.data!.docs.isEmpty;
        if (selectedDateStr != DateFormat('dd MMM yyyy').format(DateTime.now())) {
            useMock = snapshot.hasData ? snapshot.data!.docs.isEmpty : true;
        }

        final List sessions = useMock ? _mockSessions.where((s) => s['date'] == selectedDateStr).toList() : snapshot.data!.docs.map((d) => {...(d.data() as Map<String, dynamic>), 'id': d.id}).toList();

        if (sessions.isEmpty) {
            return SliverToBoxAdapter(
                child: Container(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                        child: Column(
                            children: [
                                Icon(Icons.calendar_today_outlined, size: 48, color: Colors.grey[200]),
                                const SizedBox(height: 16),
                                Text('Quiet day ahead.', style: GoogleFonts.outfit(color: textColorSub, fontStyle: FontStyle.italic)),
                            ],
                        )
                    )
                )
            );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final data = sessions[index];
              return _buildTimelineItem(data);
            },
            childCount: sessions.length,
          ),
        );
      },
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> session) {
    String pName = session['patientName'] ?? session['userName'] ?? 'Member';
    bool isPast = session['isPast'] ?? false;
    bool isCurrent = session['isCurrent'] ?? false;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Elegant Timeline Indicator
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: isCurrent ? primaryGreen : (isPast ? Colors.grey[300] : primaryGreen.withOpacity(0.2)),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: isCurrent ? [BoxShadow(color: primaryGreen.withOpacity(0.3), blurRadius: 10, spreadRadius: 2)] : null,
                ),
              ),
              Expanded(
                child: Container(
                  width: 1.5,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: Colors.grey.withOpacity(0.08),
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Opacity(
                opacity: isPast ? 0.7 : 1.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          session['timeRange']?.split(' — ')?.first ?? (session['startTime'] != null ? DateFormat('hh:mm a').format((session['startTime'] as Timestamp).toDate()) : '00:00 AM'),
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isCurrent ? primaryGreen : (isPast ? textColorSub : textColorMain.withOpacity(0.5)),
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: primaryGreen, borderRadius: BorderRadius.circular(20)),
                            child: Text('LIVE NOW', style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ]
                      ],
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SessionDetailScreen(
                              bookingData: session,
                              bookingId: session['id'] ?? '',
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(32),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isPast ? const Color(0xFFF9F9F9) : Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                              if (!isPast) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8)),
                          ],
                          border: Border.all(color: isPast ? Colors.grey.withOpacity(0.1) : Colors.grey.withOpacity(0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  pName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isPast ? Colors.grey[500] : textColorMain,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isPast ? Colors.grey.withOpacity(0.1) : primaryGreen.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    (session['status'] ?? 'UPCOMING').toString().toUpperCase(),
                                    style: GoogleFonts.outfit(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      color: isPast ? Colors.grey[400] : primaryGreen,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(session['icon'] ?? Icons.calendar_today_rounded, size: 14, color: isPast ? Colors.grey[300] : textColorSub),
                                const SizedBox(width: 8),
                                Text(
                                  session['type'] ?? 'Expert Consultation',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: isPast ? Colors.grey[400] : textColorSub,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                  Text(
                                    isPast ? 'REFLECTIONS SHARED' : 'PREPARATION READY',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isPast ? Colors.grey[400] : primaryGreen,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(Icons.arrow_forward_rounded, size: 14, color: isPast ? Colors.grey[300] : primaryGreen),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyListInMonthlyView() {
    final String selectedDateStr = DateFormat('dd MMM yyyy').format(_selectedDate);
    final user = FirebaseAuth.instance.currentUser;
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('counsellor_bookings')
          .where('counsellorId', isEqualTo: user?.uid)
          .where('date', isEqualTo: selectedDateStr)
          .snapshots(),
      builder: (context, snapshot) {
        bool useMock = !snapshot.hasData || snapshot.data!.docs.isEmpty;
        final List sessions = useMock ? _mockSessions.where((s) => s['date'] == selectedDateStr).toList() : snapshot.data!.docs.map((d) => {...(d.data() as Map<String, dynamic>), 'id': d.id}).toList();

        if (sessions.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 30),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text('No sessions on this day.', style: GoogleFonts.outfit(color: textColorSub, fontStyle: FontStyle.italic)),
            ),
          );
        }

        return Column(
          children: sessions.map((s) {
            bool isPast = s['isPast'] ?? false;
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isPast ? Colors.grey[300] : primaryGreen.withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(child: Container(width: 1, color: Colors.grey.withOpacity(0.1))),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 10)],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s['patientName'] ?? s['userName'] ?? 'Member', 
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold, 
                                      fontSize: 15, 
                                      color: isPast ? textColorSub : textColorMain
                                    )
                                  ),
                                  Text(s['timeRange'] ?? '00:00 AM', style: GoogleFonts.outfit(color: textColorSub, fontSize: 12)),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: Colors.grey[300], size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      }
    );
  }
}
