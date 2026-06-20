import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CounsellorAvailabilityManagement extends StatefulWidget {
  const CounsellorAvailabilityManagement({super.key});

  @override
  State<CounsellorAvailabilityManagement> createState() => _CounsellorAvailabilityManagementState();
}

class _CounsellorAvailabilityManagementState extends State<CounsellorAvailabilityManagement> {
  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonthView = DateTime(DateTime.now().year, DateTime.now().month);
  
  StreamSubscription<DocumentSnapshot>? _userSub;
  bool _chargesEnabled = false;

  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color secondaryGreen = const Color(0xFFEAF2ED);
  final Color backgroundColor = const Color(0xFFF2F1EC);
  final Color textColorMain = const Color(0xFF333333);

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userSub = FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots().listen((doc) {
        if (doc.exists && mounted) {
          setState(() {
            _chargesEnabled = (doc.data() as Map<String, dynamic>?)?['stripeChargesEnabled'] == true;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _userSub?.cancel();
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
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF333333), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'MANAGE AVAILABILITY',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: textColorMain,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('counsellor_availability')
            .where('counsellorId', isEqualTo: user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }

          final List<Map<String, dynamic>> allAvailability = snapshot.hasData
              ? snapshot.data!.docs.map((d) => {...(d.data() as Map<String, dynamic>), 'id': d.id}).toList()
              : [];
              
          allAvailability.sort((a, b) {
            final aTs = a['sortTimestamp'] as Timestamp?;
            final bTs = b['sortTimestamp'] as Timestamp?;
            if (aTs == null || bTs == null) return 0;
            return aTs.compareTo(bTs);
          });

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_chargesEnabled)
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Wallet Setup Required',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange.shade800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Please connect your Stripe wallet in the Wallet tab to receive payments before setting availability slots.',
                                style: GoogleFonts.outfit(fontSize: 13, color: Colors.orange.shade900),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                _buildCalendarSection(allAvailability),
                const SizedBox(height: 32),
                _buildSlotsListSection(allAvailability),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (!_chargesEnabled) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Please connect your Wallet first to receive payments.', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
            return;
          }
          _showSlotDialog();
        },
        backgroundColor: _chargesEnabled ? primaryGreen : Colors.grey,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Set Availability', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildCalendarSection(List<Map<String, dynamic>> allAvailability) {
    final Set<int> availableDaysInMonth = {};
    for (var slot in allAvailability) {
      final Timestamp? ts = slot['sortTimestamp'];
      if (ts != null) {
        final d = ts.toDate();
        if (d.month == _currentMonthView.month && d.year == _currentMonthView.year) {
          availableDaysInMonth.add(d.day);
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Select Date',
              style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold, color: textColorMain),
            ),
            Row(
              children: [
                IconButton(
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(Icons.chevron_left, size: 20),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_currentMonthView),
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: primaryGreen),
                ),
                IconButton(
                  onPressed: () => _changeMonth(1),
                  icon: const Icon(Icons.chevron_right, size: 20),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildCalendarGrid(availableDaysInMonth),
      ],
    );
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentMonthView = DateTime(_currentMonthView.year, _currentMonthView.month + delta);
      final DateTime now = DateTime.now();
      if (_currentMonthView.month == now.month && _currentMonthView.year == now.year) {
        _selectedDate = now;
      } else {
        _selectedDate = DateTime(_currentMonthView.year, _currentMonthView.month, 1);
      }
    });
  }

  Widget _buildCalendarGrid(Set<int> availableDays) {
    final days = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
    final firstDayOfMonth = DateTime(_currentMonthView.year, _currentMonthView.month, 1);
    final lastDayOfMonth = DateTime(_currentMonthView.year, _currentMonthView.month + 1, 0);
    final leadingPadding = (firstDayOfMonth.weekday - 1) % 7;
    final List<int?> calendarDays = [];
    final prevMonthLastDay = DateTime(_currentMonthView.year, _currentMonthView.month, 0).day;

    for (int i = leadingPadding - 1; i >= 0; i--) calendarDays.add(prevMonthLastDay - i);
    for (int i = 1; i <= lastDayOfMonth.day; i++) calendarDays.add(i);
    while (calendarDays.length % 7 != 0) calendarDays.add(null);

    final DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days.map((d) => SizedBox(width: 35, child: Center(child: Text(d, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[400]))))).toList(),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: (MediaQuery.of(context).size.width - 48 - 40 - (35 * 7)) / 6,
            runSpacing: 12,
            children: calendarDays.asMap().entries.map((entry) {
              final idx = entry.key;
              final d = entry.value;
              if (d == null) return const SizedBox(width: 35, height: 35);

              final isPreviousMonth = idx < leadingPadding;
              final isNextMonth = idx >= leadingPadding + lastDayOfMonth.day;
              final bool isCurrentView = !isPreviousMonth && !isNextMonth;

              final DateTime currentDay = DateTime(_currentMonthView.year, _currentMonthView.month, d);
              final bool isPastDate = isCurrentView && currentDay.isBefore(today);

              final isSelected = isCurrentView && d == _selectedDate.day && _selectedDate.month == _currentMonthView.month && _selectedDate.year == _currentMonthView.year;
              final isAvailable = isCurrentView && availableDays.contains(d) && !isPastDate;

              return InkWell(
                onTap: (isCurrentView && !isPastDate) ? () {
                  setState(() {
                    _selectedDate = currentDay;
                  });
                } : null,
                child: Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    color: isSelected ? primaryGreen : (isAvailable ? secondaryGreen : Colors.transparent),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      d.toString(),
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: isSelected || isAvailable ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : (isCurrentView ? (isPastDate ? Colors.grey[200] : (isAvailable ? Colors.black : textColorMain)) : Colors.grey[300]),
                      ),
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

  Widget _buildSlotsListSection(List<Map<String, dynamic>> allAvailability) {
    final String dateStr = DateFormat('dd MMM yyyy').format(_selectedDate);
    final slotsForSelectedDate = allAvailability.where((s) => s['date'] == dateStr).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Slots for $dateStr',
              style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold, color: textColorMain),
            ),
            if (slotsForSelectedDate.isNotEmpty)
              Text(
                '${slotsForSelectedDate.length} SLOTS',
                style: GoogleFonts.outfit(fontSize: 11, color: primaryGreen, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (slotsForSelectedDate.isEmpty)
          _buildEmptySlotsState()
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: slotsForSelectedDate.map((slot) => GestureDetector(
                onTap: () {
                  if (!_chargesEnabled) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please connect your Wallet first to receive payments.', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.orange,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                    return;
                  }
                  _showSlotDialog(slot: slot);
                },
                child: _buildSlotTile(slot)
            )).toList(),
          ),
      ],
    );
  }

  Widget _buildEmptySlotsState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Icon(Icons.event_note_rounded, color: Colors.grey[200], size: 48),
          const SizedBox(height: 12),
          Text(
            'No slots set for this date',
            style: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotTile(Map<String, dynamic> slot) {
    return Container(
      width: (MediaQuery.of(context).size.width - 48 - 12) / 2,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  slot['timeRange'] ?? '00:00 AM',
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: textColorMain),
                ),
                const SizedBox(width: 8),
                Icon(Icons.edit_outlined, size: 14, color: primaryGreen.withOpacity(0.4)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _confirmDelete(slot),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.close_rounded, size: 14, color: Colors.red.withOpacity(0.4)),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> slot) {
    final Color primaryGreen = const Color(0xFF7C9C84);
    final String time = slot['timeRange'] ?? '--:--';
    final String date = slot['date'] ?? '-- --- ----';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: Color(0xFFF2F1EC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(alignment: Alignment.center, child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Text('Remove Availability', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF1E2742))),
            const SizedBox(height: 12),
            Text(
              'Are you sure you want to remove this slot? Clients will no longer be able to book this session time.',
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 32),
            
            // Slot Summary Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.red.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), shape: BoxShape.circle),
                    child: const Icon(Icons.event_busy_rounded, color: Colors.red, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(time, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF333333))),
                      Text(date, style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Keep Slot', style: GoogleFonts.outfit(color: Colors.grey[600], fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        FirebaseFirestore.instance.collection('counsellor_availability').doc(slot['id']).delete();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Availability slot removed.', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                            backgroundColor: Colors.red[400],
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[400],
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text('Remove Slot', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showSlotDialog({Map<String, dynamic>? slot}) {
    final bool isEditing = slot != null;
    DateTime modalSelectedDate = _selectedDate;

    // Initial time for Cupertino picker
    DateTime initialDateTime;
    if (isEditing) {
      initialDateTime = DateFormat('hh:mm a').parse(slot!['timeRange']);
      // Ensure date part matches for comparison
      initialDateTime = DateTime(modalSelectedDate.year, modalSelectedDate.month, modalSelectedDate.day, initialDateTime.hour, initialDateTime.minute);
    } else {
      initialDateTime = DateTime(modalSelectedDate.year, modalSelectedDate.month, modalSelectedDate.day, DateTime.now().hour, 0);
      if (initialDateTime.isBefore(DateTime.now())) {
        initialDateTime = initialDateTime.add(const Duration(hours: 1));
      }
    }

    DateTime currentSelectedDT = initialDateTime;

    bool isChecking = false;
    bool isPastTime = false;
    bool isTooSoon = false;
    bool isTooClose = false;
    bool isDuplicate = false;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        bool initialValidationDone = false;
        return StatefulBuilder(
            builder: (context, setModalState) {

              // Function to perform validations
              void performValidations(DateTime dt) async {
                setModalState(() => isChecking = true);
                final now = DateTime.now();
                final bool past = dt.isBefore(now);
                final bool tooSoon = !past && dt.isBefore(now.add(const Duration(hours: 1)));

                final String timeStr = DateFormat('hh:mm a').format(dt);
                final user = FirebaseAuth.instance.currentUser;

                final query = await FirebaseFirestore.instance.collection('counsellor_availability')
                    .where('counsellorId', isEqualTo: user?.uid).where('sortTimestamp', isEqualTo: Timestamp.fromDate(DateTime(modalSelectedDate.year, modalSelectedDate.month, modalSelectedDate.day))).get();

                bool tooClose = false;
                bool duplicate = false;

                for (var doc in query.docs) {
                  if (isEditing && doc.id == slot!['id']) continue;

                  final String existingTimeStr = doc['timeRange'];
                  if (existingTimeStr == timeStr) {
                    duplicate = true;
                    break;
                  }

                  final DateTime existingDT = DateFormat('hh:mm a').parse(existingTimeStr);
                  final DateTime selectedTimeOnly = DateFormat('hh:mm a').parse(timeStr);
                  final int diffMinutes = selectedTimeOnly.difference(existingDT).inMinutes.abs();
                  if (diffMinutes < 180) {
                    tooClose = true;
                    break;
                  }
                }

                setModalState(() {
                  isPastTime = past;
                  isTooSoon = tooSoon;
                  isTooClose = tooClose;
                  isDuplicate = duplicate;
                  isChecking = false;
                });
              }

              if (!initialValidationDone) {
                initialValidationDone = true;
                Future.microtask(() => performValidations(currentSelectedDT));
              }

              return Container(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
                decoration: BoxDecoration(color: backgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(36))),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(alignment: Alignment.center, child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(height: 16),
                      Text(isEditing ? 'Edit Session Slot' : 'Add Availability', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: textColorMain)),
                      const SizedBox(height: 24),



                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, color: primaryGreen, size: 18),
                            const SizedBox(width: 12),
                            Text(
                              DateFormat('EEEE, dd MMM yyyy').format(modalSelectedDate),
                              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: textColorMain),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text('Select Time', style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold, color: textColorMain)),
                      const SizedBox(height: 12),

                      // Cupertino Apple-style Scroll Picker
                      Container(
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.grey.withOpacity(0.05)),
                        ),
                        child: CupertinoDatePicker(
                          mode: CupertinoDatePickerMode.time,
                          initialDateTime: initialDateTime,
                          onDateTimeChanged: (DateTime newDateTime) {
                            currentSelectedDT = DateTime(modalSelectedDate.year, modalSelectedDate.month, modalSelectedDate.day, newDateTime.hour, newDateTime.minute);
                            performValidations(currentSelectedDT);
                          },
                        ),
                      ),

                      const SizedBox(height: 16),
                      if (isPastTime) _buildErrorText('Cannot select past time'),
                      if (!isPastTime && isTooSoon) _buildErrorText('Slots must be set at least 1 hour in advance'),
                      if (isDuplicate) _buildErrorText('Slot already exists for this time'),
                      if (!isDuplicate && isTooClose) _buildErrorText('Must have at least a 3-hour gap between slots'),

                      const SizedBox(height: 16),
                      Text(
                        '* Scroll to choose your start time. System enforces a 1-hour lead time and 3-hour gap from other sessions.',
                        style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[400], height: 1.4),
                      ),

                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: (!isPastTime && !isTooSoon && !isTooClose && !isDuplicate && !isChecking && !isSaving) ? () async {
                            setModalState(() => isSaving = true);
                            try {
                              final user = FirebaseAuth.instance.currentUser;
                              final String timeStr = DateFormat('hh:mm a').format(currentSelectedDT);
                              final String dayStr = DateFormat('EEEE').format(modalSelectedDate);
                              final String dateStr = DateFormat('dd MMM yyyy').format(modalSelectedDate);
                              final DateTime sortDate = DateTime(modalSelectedDate.year, modalSelectedDate.month, modalSelectedDate.day);

                              final data = {
                                'counsellorId': user?.uid,
                                'day': dayStr,
                                'date': dateStr,
                                'timeRange': timeStr,
                                'sortTimestamp': Timestamp.fromDate(sortDate),
                              };

                              if (isEditing) {
                                await FirebaseFirestore.instance.collection('counsellor_availability').doc(slot!['id']).update(data);
                              } else {
                                data['createdAt'] = FieldValue.serverTimestamp();
                                await FirebaseFirestore.instance.collection('counsellor_availability').add(data);
                              }

                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(isEditing ? 'Shift updated successfully!' : 'Availability added successfully!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                                    backgroundColor: primaryGreen,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) setModalState(() => isSaving = false);
                            }
                          } : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 0,
                            disabledBackgroundColor: Colors.grey[200],
                          ),
                          child: isChecking || isSaving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(isEditing ? 'Save Changes' : 'Confirm Availability', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
        );
      },
    );
  }

  Widget _buildErrorText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 14),
          const SizedBox(width: 6),
          Text(text, style: GoogleFonts.outfit(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
