import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'session_detail.dart';
import '../widgets/notification_bell.dart';

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
  final ScrollController _dateScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_dateScrollController.hasClients) {
        double itemWidth = (MediaQuery.of(context).size.width - 32) / 5;
        double offset = (30 * itemWidth) - (MediaQuery.of(context).size.width / 2) + (itemWidth / 2) + 16;
        _dateScrollController.jumpTo(offset);
      }
    });
  }

  // Real data is fetched directly from Firestore in the builders.

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
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
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
                            fontWeight: FontWeight.w600,
                            color: textColorMain,
                          ),
                        ),
                        // Wrap NotificationBell to counteract its internal 8px padding
                        // so it aligns perfectly with the right edge like user/counsellor.dart
                        Transform.translate(
                          offset: const Offset(8, 0),
                          child: const NotificationBell(
                            iconColor: Color(0xFF7C9C84),
                            iconSize: 24,
                            hasBackground: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Secondary Filter Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
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
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: InkWell(
                                onTap: () {
                                  setState(() => _selectedDate = DateTime.now());
                                  double itemWidth = (MediaQuery.of(context).size.width - 32) / 5;
                                  double offset = (30 * itemWidth) - (MediaQuery.of(context).size.width / 2) + (itemWidth / 2) + 16;
                                  _dateScrollController.animateTo(offset, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.02),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.today_rounded, size: 14, color: textColorMain),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Today',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: textColorMain,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
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
                        GestureDetector(
                          onTap: () => setState(() => _isMonthlyView = false),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Icon(Icons.close_rounded, color: textColorMain, size: 24),
                          ),
                        ),
                    ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('counsellor_bookings')
                        .where('counsellorId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      Set<int> futureApptDays = {};
                      Set<int> pastApptDays = {};

                      if (snapshot.hasData) {
                        for (var doc in snapshot.data!.docs) {
                          var data = doc.data() as Map<String, dynamic>;
                          if ((data['status'] as String?)?.toLowerCase() == 'cancelled') continue;
                          
                          if (data['startTime'] != null) {
                            DateTime st = (data['startTime'] as Timestamp).toDate();
                            if (st.year == _selectedDate.year && st.month == _selectedDate.month) {
                               if (st.add(const Duration(hours: 1)).isBefore(DateTime.now())) {
                                  pastApptDays.add(st.day);
                               } else {
                                  futureApptDays.add(st.day);
                               }
                            }
                          }
                        }
                      }

                      return SingleChildScrollView(
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
                                  bool hasFutureAppt = futureApptDays.contains(day); 
                                  bool hasPastAppt = pastApptDays.contains(day);
                                  bool isSelected = day == _selectedDate.day;
                                  bool isToday = day == DateTime.now().day && _selectedDate.month == DateTime.now().month && _selectedDate.year == DateTime.now().year;
                                  
                                  Color circleColor;
                                  Color textColor;
                                  Border? border;

                                  if (isSelected) {
                                      circleColor = primaryGreen;
                                      textColor = Colors.white;
                                  } else if (hasFutureAppt) {
                                      circleColor = primaryGreen.withOpacity(0.15);
                                      textColor = primaryGreen;
                                      border = Border.all(color: primaryGreen.withOpacity(0.3), width: 1);
                                  } else if (hasPastAppt) {
                                      circleColor = Colors.grey.withOpacity(0.15);
                                      textColor = Colors.grey[700]!;
                                      border = Border.all(color: Colors.grey.withOpacity(0.3), width: 1);
                                  } else if (isToday) {
                                      circleColor = primaryGreen.withOpacity(0.05);
                                      textColor = primaryGreen;
                                      border = Border.all(color: primaryGreen, width: 1.5);
                                  } else {
                                      circleColor = Colors.transparent;
                                      textColor = textColorMain;
                                  }

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
                                            color: circleColor,
                                            shape: BoxShape.circle,
                                            border: border,
                                          ),
                                          child: Center(
                                            child: Text(
                                              day.toString(),
                                              style: GoogleFonts.outfit(
                                                fontSize: 14, 
                                                fontWeight: isSelected || hasFutureAppt || hasPastAppt || isToday ? FontWeight.bold : FontWeight.normal,
                                                color: textColor,
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
                  );
                 },
                ),
              ),
            ],
        ),
    );
  }

  Widget _buildWeekDaySelector() {
    double itemWidth = (MediaQuery.of(context).size.width - 32) / 5;

    return SizedBox(
      height: 90,
      child: ListView.builder(
        controller: _dateScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 61, // 30 days past, today, 30 days future
        itemBuilder: (context, index) {
          final date = DateTime.now().add(Duration(days: index - 30));
          bool isSelected = date.day == _selectedDate.day && date.month == _selectedDate.month && date.year == _selectedDate.year;

          return GestureDetector(
            onTap: () {
               setState(() => _selectedDate = date);
               // Smooth scroll to center the tapped date
               double offset = (index * itemWidth) - (MediaQuery.of(context).size.width / 2) + (itemWidth / 2) + 16;
               _dateScrollController.animateTo(offset, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: itemWidth - 16, // minus the horizontal margins
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
        if (!snapshot.hasData) {
          return SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(40),
              child: const Center(child: CircularProgressIndicator(color: Color(0xFF7C9C84))),
            ),
          );
        }

        final List sessions = snapshot.data!.docs.map((d) => {...(d.data() as Map<String, dynamic>), 'id': d.id}).toList();

        // Filter out cancelled appointments
        sessions.removeWhere((s) => (s['status'] as String?)?.toLowerCase() == 'cancelled');

        // Organize based on timeline (sort by startTime)
        sessions.sort((a, b) {
           DateTime timeA = a['startTime'] != null ? (a['startTime'] as Timestamp).toDate() : DateTime.fromMillisecondsSinceEpoch(0);
           DateTime timeB = b['startTime'] != null ? (b['startTime'] as Timestamp).toDate() : DateTime.fromMillisecondsSinceEpoch(0);
           return timeA.compareTo(timeB);
        });

        if (sessions.isEmpty) {
            return SliverToBoxAdapter(
                child: Container(
                    margin: const EdgeInsets.only(top: 20, bottom: 40),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: primaryGreen.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.self_improvement_rounded, size: 56, color: primaryGreen),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Quiet Day Ahead',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: textColorMain,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'You have no sessions scheduled for this date. Take some time to recharge and focus on yourself.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                color: textColorSub,
                                height: 1.5,
                              ),
                            ),
                        ],
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
    
    // Dynamically calculate timeline state
    if (session['startTime'] != null) {
      DateTime startTime = (session['startTime'] as Timestamp).toDate();
      DateTime now = DateTime.now();
      
      // If the session ended (assuming 1 hour duration)
      if (now.isAfter(startTime.add(const Duration(hours: 1)))) {
        isPast = true;
        isCurrent = false;
      } 
      // If the session is currently happening
      else if (now.isAfter(startTime) && now.isBefore(startTime.add(const Duration(hours: 1)))) {
        isPast = false;
        isCurrent = true;
      }
    }
    
    String displayStatus = session['status']?.toString().toUpperCase() ?? 'PENDING';

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
                                    color: displayStatus == 'MISSED' ? Colors.red.withOpacity(0.1) : (isPast ? Colors.grey.withOpacity(0.1) : primaryGreen.withOpacity(0.1)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    displayStatus,
                                    style: GoogleFonts.outfit(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      color: displayStatus == 'MISSED' ? Colors.red : (isPast ? Colors.grey[400] : primaryGreen),
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
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF7C9C84)));
        }

        final List sessions = snapshot.data!.docs.map((d) => {...(d.data() as Map<String, dynamic>), 'id': d.id}).toList();

        // Filter out cancelled appointments
        sessions.removeWhere((s) => (s['status'] as String?)?.toLowerCase() == 'cancelled');

        // Organize based on timeline (sort by startTime)
        sessions.sort((a, b) {
           DateTime timeA = a['startTime'] != null ? (a['startTime'] as Timestamp).toDate() : DateTime.fromMillisecondsSinceEpoch(0);
           DateTime timeB = b['startTime'] != null ? (b['startTime'] as Timestamp).toDate() : DateTime.fromMillisecondsSinceEpoch(0);
           return timeA.compareTo(timeB);
        });

        if (sessions.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.spa_rounded, size: 32, color: primaryGreen.withOpacity(0.5)),
                const SizedBox(height: 12),
                Text(
                  'No sessions on this day.', 
                  style: GoogleFonts.outfit(
                    color: textColorMain.withOpacity(0.6), 
                    fontWeight: FontWeight.w600,
                  )
                ),
              ],
            )
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
