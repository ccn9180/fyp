
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SessionDetailScreen extends StatelessWidget {
  final Map<String, dynamic> bookingData;
  final String bookingId;

  const SessionDetailScreen({super.key, required this.bookingData, required this.bookingId});

  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = const Color(0xFF7C9C84);
    final Color backgroundColor = const Color(0xFFFBFBF6);
    final Color textColorMain = const Color(0xFF333333);
    
    // Safer data extraction
    final dynamic rawStartTime = bookingData['startTime'];
    final DateTime startTime = (rawStartTime is Timestamp) 
        ? rawStartTime.toDate() 
        : (rawStartTime is DateTime ? rawStartTime : DateTime.now());

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF333333), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'SESSION DETAILS',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: textColorMain,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Client Header (Matching User Side Style)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: primaryGreen.withOpacity(0.1),
                    child: Text(
                      bookingData['patientName']?[0].toUpperCase() ?? 'P',
                      style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: primaryGreen),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    bookingData['patientName'] ?? bookingData['userName'] ?? 'Member',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textColorMain,
                    ),
                  ),
                  Text(
                    'Client ID: ${bookingData['patientId'] ?? 'N/A'}',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildInfoTip(Icons.videocam_rounded, 'Video Call', primaryGreen),
                      const SizedBox(width: 12),
                      _buildInfoTip(Icons.timer_rounded, '60 Minutes', primaryGreen),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Appointment Info Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'APPOINTMENT TIME',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildDetailRow(Icons.calendar_month_rounded, 'Date', DateFormat('EEEE, MMMM dd').format(startTime), textColorMain),
                  const SizedBox(height: 16),
                  _buildDetailRow(Icons.access_time_filled_rounded, 'Time', '${DateFormat('hh:mm a').format(startTime)} — ${DateFormat('hh:mm a').format(startTime.add(const Duration(hours: 1)))}', textColorMain),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 20),
                  Text(
                    'PRIVATE CLINICAL NOTES',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[400],
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    bookingData['notes'] ?? 'No clinical notes recorded for this session yet. Notes are private and only visible to you.',
                    style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600], height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Recommend Resources (Refined Action Card)
            GestureDetector(
              onTap: () => _showResourceSelector(context),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primaryGreen, const Color(0xFF6A8671)]),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: primaryGreen.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Recommend Support', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('Share relevant articles or guides with this client', style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Primary Start Session Button
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  // Navigator to Video Call logic here
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_arrow_rounded, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'START VIDEO SESSION',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Reschedule Button (Counselor Side)
            SizedBox(
              width: double.infinity,
              height: 60,
              child: OutlinedButton(
                onPressed: () => _handleReschedule(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: primaryGreen.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: Text(
                  'RESCHEDULE APPOINTMENT',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryGreen,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  void _handleReschedule(BuildContext context) {
    final Color primaryGreen = const Color(0xFF7C9C84);
    final Color textColorMain = const Color(0xFF333333);
    DateTime tempSelectedDate = DateTime.now();
    DateTime tempMonthView = DateTime(DateTime.now().year, DateTime.now().month);
    String? tempSelectedTime;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Color(0xFFF2F1EC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
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
                        Text('Reschedule', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold)),
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Month Selector
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(DateFormat('MMMM yyyy').format(tempMonthView), 
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF666666))),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () => setModalState(() => tempMonthView = DateTime(tempMonthView.year, tempMonthView.month - 1)),
                                    icon: const Icon(Icons.chevron_left_rounded, size: 20),
                                  ),
                                  IconButton(
                                    onPressed: () => setModalState(() => tempMonthView = DateTime(tempMonthView.year, tempMonthView.month + 1)),
                                    icon: const Icon(Icons.chevron_right_rounded, size: 20),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // Calendar Box
                          _buildCalendarBox(context, tempMonthView, tempSelectedDate, (date) {
                            setModalState(() => tempSelectedDate = date);
                          }),

                          const SizedBox(height: 32),
                          Text('Select New Time', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 16),
                          
                          // Time Grid
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: ['09:00 AM', '10:00 AM', '11:00 AM', '02:00 PM', '03:00 PM', '04:00 PM'].map((time) {
                              bool isSelected = tempSelectedTime == time;
                              return GestureDetector(
                                onTap: () => setModalState(() => tempSelectedTime = time),
                                child: Container(
                                  width: (MediaQuery.of(context).size.width - 48 - 12) / 2,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    color: isSelected ? primaryGreen : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: isSelected ? null : Border.all(color: Colors.grey.withOpacity(0.1)),
                                  ),
                                  child: Center(
                                    child: Text(time, style: GoogleFonts.outfit(
                                      color: isSelected ? Colors.white : textColorMain,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    )),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Action
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: tempSelectedTime == null ? null : () async {
                          final DateFormat timeFormat = DateFormat('hh:mm a');
                          final DateTime timeParts = timeFormat.parse(tempSelectedTime!);
                          final finalDateTime = DateTime(
                            tempSelectedDate.year, 
                            tempSelectedDate.month, 
                            tempSelectedDate.day, 
                            timeParts.hour, 
                            timeParts.minute
                          );

                          // Confirmation Dialog
                          _confirmAndSubmitReschedule(context, finalDateTime);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          disabledBackgroundColor: Colors.grey[300],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Text('Confirm Reschedule', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCalendarBox(BuildContext context, DateTime monthView, DateTime selectedDate, Function(DateTime) onDateSelected) {
    final Color primaryGreen = const Color(0xFF7C9C84);
    final Color textColorMain = const Color(0xFF333333);
    final daysHeader = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

    final firstDayOfMonth = DateTime(monthView.year, monthView.month, 1);
    final lastDayOfMonth = DateTime(monthView.year, monthView.month + 1, 0);
    final leadingPadding = firstDayOfMonth.weekday - 1;
    final prevMonthLastDay = DateTime(monthView.year, monthView.month, 0).day;
    
    final List<int?> calendarDays = [];
    for (int i = leadingPadding - 1; i >= 0; i--) calendarDays.add(prevMonthLastDay - i);
    for (int i = 1; i <= lastDayOfMonth.day; i++) calendarDays.add(i);
    while (calendarDays.length % 7 != 0) calendarDays.add(null);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: daysHeader.map((d) => SizedBox(
              width: 35,
              child: Center(
                child: Text(d, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFAAAAAA))),
              ),
            )).toList(),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: (MediaQuery.of(context).size.width - 48 - 40 - (35 * 7)) / 6,
            runSpacing: 20,
            children: calendarDays.asMap().entries.map((entry) {
              final idx = entry.key;
              final d = entry.value;
              if (d == null) return const SizedBox(width: 35, height: 35);
              
              final isPreviousMonth = idx < leadingPadding;
              final isNextMonth = idx >= leadingPadding + lastDayOfMonth.day;
              
              final isSelectedInView = d == selectedDate.day && 
                                       selectedDate.month == monthView.month && 
                                       selectedDate.year == monthView.year;
              
              final isCurrent = isSelectedInView && !isPreviousMonth && !isNextMonth;
              
              final DateTime now = DateTime.now();
              final bool isToday = d == now.day && 
                                   now.month == monthView.month && 
                                   now.year == monthView.year &&
                                   !isPreviousMonth && !isNextMonth;
              
              final bool isSelectable = !isPreviousMonth && !isNextMonth;

              return InkWell(
                onTap: isSelectable ? () => onDateSelected(DateTime(monthView.year, monthView.month, d)) : null,
                child: Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    color: isCurrent ? primaryGreen : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          d.toString(),
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            color: isCurrent 
                              ? Colors.white 
                              : (isSelectable ? textColorMain : const Color(0xFFCCCCCC)),
                          ),
                        ),
                        if (isToday)
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isCurrent ? Colors.white : primaryGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _confirmAndSubmitReschedule(BuildContext context, DateTime finalDateTime) {
    final Color primaryGreen = const Color(0xFF7C9C84);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('Confirm Changes', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        content: Text(
          'Move this session for ${bookingData['patientName'] ?? 'this member'} to ${DateFormat('EEEE, MMM dd').format(finalDateTime)} at ${DateFormat('hh:mm a').format(finalDateTime)}?',
          style: GoogleFonts.outfit(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL', style: GoogleFonts.outfit(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Pop dialog
              try {
                await FirebaseFirestore.instance.collection('counsellor_bookings').doc(bookingId).update({
                  'startTime': Timestamp.fromDate(finalDateTime),
                  'date': DateFormat('dd MMM yyyy').format(finalDateTime),
                  'status': 'RESCHEDULED',
                  'rescheduledBy': 'counsellor',
                  'lastModified': FieldValue.serverTimestamp(),
                });

                if (context.mounted) {
                  Navigator.pop(context); // Pop reschedule modal
                  Navigator.pop(context); // Pop detail screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Session rescheduled successfully.'), backgroundColor: primaryGreen),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to reschedule.')));
                }
              }
            },
            child: Text('CONFIRM', style: GoogleFonts.outfit(color: primaryGreen, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color textColor) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.withOpacity(0.5)),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey)),
            Text(value, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
          ],
        ),
      ],
    );
  }

  void _showResourceSelector(BuildContext context) async {
    final Color primaryGreen = const Color(0xFF7C9C84);
    
    // Show a loading indicator dialog
    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (c) => const Center(child: CircularProgressIndicator())
    );

    final Set<String> initialRecommendedIds = {};
    final Map<String, String> recommendationDocIds = {};

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('recommendations')
          .where('patientId', isEqualTo: bookingData['patientId'])
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final resId = data['resourceId'] as String;
        initialRecommendedIds.add(resId);
        recommendationDocIds[resId] = doc.id;
      }
    } catch (e) {
      debugPrint("Error fetching recommendations: $e");
    }

    // Dismiss loading indicator
    if (context.mounted) {
      Navigator.pop(context);
    }

    final Set<String> selectedIds = Set.from(initialRecommendedIds);
    final List<Map<String, dynamic>> selectedResources = [];

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final int addedCount = selectedIds.difference(initialRecommendedIds).length;
            final int removedCount = initialRecommendedIds.difference(selectedIds).length;
            final bool hasChanges = addedCount > 0 || removedCount > 0;

            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: const BoxDecoration(
                color: Color(0xFFF2F1EC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
              ),
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                    
                    // ── Header ──────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Recommend Resources',
                                      style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Tap a resource to recommend or un-recommend it for ${bookingData['patientName'] ?? 'this client'}.',
                                      style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600], height: 1.4),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Changes summary pill
                          if (hasChanges)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: primaryGreen.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.pending_actions_rounded, size: 16, color: Color(0xFF7C9C84)),
                                  const SizedBox(width: 8),
                                  if (addedCount > 0)
                                    Text(
                                      '+$addedCount to recommend',
                                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF7C9C84)),
                                    ),
                                  if (addedCount > 0 && removedCount > 0)
                                    Text('  •  ', style: GoogleFonts.outfit(color: Colors.grey)),
                                  if (removedCount > 0)
                                    Text(
                                      '-$removedCount to remove',
                                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent),
                                    ),
                                ],
                              ),
                            )
                          else if (selectedIds.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: primaryGreen.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, size: 16, color: primaryGreen),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${selectedIds.length} resource${selectedIds.length > 1 ? 's' : ''} currently recommended',
                                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: primaryGreen),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey[500]),
                                  const SizedBox(width: 8),
                                  Text(
                                    'No resources recommended yet',
                                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Tabs ─────────────────────────────────────────────────
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TabBar(
                        indicatorColor: primaryGreen,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: primaryGreen,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.grey,
                        dividerColor: Colors.transparent,
                        labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                        unselectedLabelStyle: GoogleFonts.outfit(fontSize: 13),
                        tabs: const [
                          Tab(text: 'Articles'),
                          Tab(text: 'Meditations'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildResourceList(context, 'articles', 'article', selectedIds, selectedResources, setModalState, initialRecommendedIds),
                          _buildResourceList(context, 'meditation_guides', 'meditation', selectedIds, selectedResources, setModalState, initialRecommendedIds),
                        ],
                      ),
                    ),
                    
                    // ── Footer Save Button ──────────────────────────────────
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF2F1EC),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: !hasChanges ? null : () async {
                            showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
                            
                            try {
                              final batch = FirebaseFirestore.instance.batch();
                              int addedCount = 0;
                              for (var res in selectedResources) {
                                if (!initialRecommendedIds.contains(res['id'])) {
                                  final ref = FirebaseFirestore.instance.collection('recommendations').doc();
                                  batch.set(ref, {
                                    'patientId': bookingData['patientId'],
                                    'counsellorId': bookingData['counsellorId'],
                                    'resourceId': res['id'],
                                    'resourceTitle': res['title'],
                                    'resourceType': res['type'],
                                    'recommendedAt': FieldValue.serverTimestamp(),
                                  });
                                  addedCount++;
                                }
                              }

                              int removedCount = 0;
                              for (var resId in initialRecommendedIds) {
                                if (!selectedIds.contains(resId)) {
                                  final docId = recommendationDocIds[resId];
                                  if (docId != null) {
                                    final ref = FirebaseFirestore.instance.collection('recommendations').doc(docId);
                                    batch.delete(ref);
                                    removedCount++;
                                  }
                                }
                              }

                              if (addedCount > 0) {
                                final notifRef = FirebaseFirestore.instance.collection('notifications').doc();
                                batch.set(notifRef, {
                                  'from': bookingData['counsellorId'],
                                  'to': bookingData['patientId'],
                                  'type': 'recommendation',
                                  'status': 'sent',
                                  'isRead': false,
                                  'senderName': bookingData['counsellorName'] ?? 'Counsellor',
                                  'timestamp': FieldValue.serverTimestamp(),
                                  'message': '${bookingData['counsellorName'] ?? "Your counsellor"} has recommended new support resources for you.',
                                });
                              }

                              await batch.commit();
                              
                              if (context.mounted) {
                                Navigator.pop(context); // Pop loading
                                Navigator.pop(context); // Pop modal
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Updated support recommendations successfully'),
                                    backgroundColor: primaryGreen,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update recommendations')));
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasChanges ? primaryGreen : Colors.grey[300],
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                hasChanges ? Icons.save_rounded : Icons.check_rounded,
                                color: hasChanges ? Colors.white : Colors.grey[600],
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                hasChanges ? 'Save Changes' : 'No Changes to Save',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: hasChanges ? Colors.white : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  Widget _buildResourceList(
    BuildContext context, 
    String collection, 
    String typeLabel, 
    Set<String> selectedIds, 
    List<Map<String, dynamic>> selectedResources,
    StateSetter setModalState,
    Set<String> initialRecommendedIds,
  ) {
    final Color primaryGreen = const Color(0xFF7C9C84);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collection).limit(20).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
 
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return Center(child: Text('No resources found.', style: GoogleFonts.outfit(color: Colors.grey)));
 
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final id = docs[index].id;
            final isSelected = selectedIds.contains(id);
            final isInitiallyRecommended = initialRecommendedIds.contains(id);
            final title = data['title'] ?? 'Untitled';
            final imageUrl = data['imageUrl'] ?? '';

            // Determine visual state
            final bool willBeAdded = isSelected && !isInitiallyRecommended;
            final bool willBeRemoved = !isSelected && isInitiallyRecommended;
            final bool unchanged = isSelected && isInitiallyRecommended;

            Color cardBorderColor = Colors.transparent;
            Color cardBgColor = Colors.white;
            if (willBeAdded) {
              cardBorderColor = primaryGreen;
              cardBgColor = const Color(0xFFEDF4EF);
            } else if (willBeRemoved) {
              cardBorderColor = Colors.redAccent.withOpacity(0.5);
              cardBgColor = const Color(0xFFFFF5F5);
            } else if (unchanged) {
              cardBorderColor = const Color(0xFFC5A880).withOpacity(0.5);
              cardBgColor = const Color(0xFFFBF8F4);
            }

            return GestureDetector(
              onTap: () {
                setModalState(() {
                  if (isSelected) {
                    selectedIds.remove(id);
                    selectedResources.removeWhere((res) => res['id'] == id);
                  } else {
                    selectedIds.add(id);
                    if (!isInitiallyRecommended) {
                      selectedResources.add({'id': id, 'title': title, 'type': typeLabel});
                    }
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: cardBorderColor,
                    width: 1.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(
                                width: 60, height: 60,
                                color: Colors.grey[100],
                                child: Icon(
                                  typeLabel == 'article' ? Icons.article_rounded : Icons.headphones_rounded,
                                  color: Colors.grey[400], size: 28,
                                ),
                              ),
                            )
                          : Container(
                              width: 60, height: 60,
                              decoration: BoxDecoration(
                                color: primaryGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                typeLabel == 'article' ? Icons.article_rounded : Icons.headphones_rounded,
                                color: primaryGreen, size: 28,
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                    // Text info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Type pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: typeLabel == 'article'
                                  ? const Color(0xFF86A588).withOpacity(0.15)
                                  : const Color(0xFF7C9C84).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              typeLabel == 'article' ? 'ARTICLE' : 'MEDITATION',
                              style: GoogleFonts.outfit(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: primaryGreen,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            title,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: const Color(0xFF333333),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Action button
                    _buildActionButton(isSelected, isInitiallyRecommended, willBeRemoved, primaryGreen),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionButton(bool isSelected, bool isInitiallyRecommended, bool willBeRemoved, Color primaryGreen) {
    if (willBeRemoved) {
      // Was recommended, now unselected → will be removed
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent.withOpacity(0.4), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.remove_circle_rounded, color: Colors.redAccent, size: 20),
            const SizedBox(height: 2),
            Text(
              'REMOVE',
              style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.redAccent),
            ),
          ],
        ),
      );
    } else if (isSelected && isInitiallyRecommended) {
      // Currently recommended and still selected → tap to un-recommend
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFC5A880).withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFC5A880).withOpacity(0.5), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, color: Color(0xFFC5A880), size: 20),
            const SizedBox(height: 2),
            Text(
              'SENT',
              style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFFC5A880)),
            ),
          ],
        ),
      );
    } else if (isSelected && !isInitiallyRecommended) {
      // New selection → will be added
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: primaryGreen.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primaryGreen.withOpacity(0.5), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, color: primaryGreen, size: 20),
            const SizedBox(height: 2),
            Text(
              'ADDED',
              style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: primaryGreen),
            ),
          ],
        ),
      );
    } else {
      // Not selected, never recommended → tap to recommend
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_circle_outline_rounded, color: Colors.grey[500], size: 20),
            const SizedBox(height: 2),
            Text(
              'ADD',
              style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }
  }
}
