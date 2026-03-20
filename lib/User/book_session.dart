import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class BookSessionScreen extends StatefulWidget {
  final String counsellorId;
  final String name;
  final String specialty;
  final String rating;
  final String profileImage;
  final int sessionsCount;

  const BookSessionScreen({
    super.key,
    required this.counsellorId,
    required this.name,
    required this.specialty,
    required this.rating,
    required this.profileImage,
    required this.sessionsCount,
  });

  @override
  State<BookSessionScreen> createState() => _BookSessionScreenState();
}

class _BookSessionScreenState extends State<BookSessionScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonthView = DateTime(DateTime.now().year, DateTime.now().month);
  String? selectedTime;

  // Real availability data from Firestore will go here
  List<Map<String, dynamic>> _allAvailability = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAvailability();
  }

  Future<void> _fetchAvailability() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('counsellor_availability')
          .where('counsellorId', isEqualTo: widget.counsellorId)
          .get();
      
      setState(() {
        _allAvailability = snapshot.docs.map((d) => d.data()).toList();
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching availability: $e");
      setState(() => _isLoading = false);
    }
  }

  List<int> get availableDates {
    final Set<int> dates = {};
    final DateTime now = DateTime.now();
    final DateTime todayMidnight = DateTime(now.year, now.month, now.day);
    
    for (var slot in _allAvailability) {
      final Timestamp? ts = slot['sortTimestamp'];
      if (ts != null) {
        final d = ts.toDate();
        // Only include if date is today or future, and matches month view
        if (d.month == _currentMonthView.month && d.year == _currentMonthView.year) {
          if (!d.isBefore(todayMidnight)) {
            dates.add(d.day);
          }
        }
      }
    }
    return dates.toList();
  }

  List<String> get availableTimesForSelectedDate {
    final List<String> times = [];
    final DateTime now = DateTime.now();
    
    for (var slot in _allAvailability) {
      final Timestamp? ts = slot['sortTimestamp'];
      if (ts != null) {
        final d = ts.toDate();
        if (d.year == _selectedDate.year && d.month == _selectedDate.month && d.day == _selectedDate.day) {
          final String timeRange = slot['timeRange'];
          
          // Check if time has passed if it's today
          if (d.year == now.year && d.month == now.month && d.day == now.day) {
            try {
              // Convert "hh:mm a" to a DateTime for comparison
              final format = DateFormat.jm(); // matches "09:00 AM" etc.
              final DateTime slotTime = format.parse(timeRange);
              final DateTime compareTime = DateTime(now.year, now.month, now.day, slotTime.hour, slotTime.minute);
              
              if (compareTime.isAfter(now)) {
                times.add(timeRange);
              }
            } catch (e) {
              // If parsing fails for any reason, default to adding it
              times.add(timeRange);
            }
          } else {
            times.add(timeRange);
          }
        }
      }
    }
    return times;
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = const Color(0xFF7C9C84);
    final Color secondaryGreen = const Color(0xFFEAF2ED);
    final Color backgroundColor = const Color(0xFFFBFBF6);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF333333), size: 20),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'BOOK A SESSION',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: const Color(0xFF5D6D66),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 44), // Balanced placeholder for centering
                ],
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Counselor Profile Card
                    _buildCounselorCard(primaryGreen),
                    
                    const SizedBox(height: 40),
                    
                    // Select Date Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Date',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF333333),
                          ),
                        ),
                        // Month Navigation
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _currentMonthView = DateTime(_currentMonthView.year, _currentMonthView.month - 1);
                                  final DateTime now = DateTime.now();
                                  if (_currentMonthView.month == now.month && _currentMonthView.year == now.year) {
                                    _selectedDate = now;
                                  } else {
                                    _selectedDate = DateTime(_currentMonthView.year, _currentMonthView.month, 1);
                                  }
                                  selectedTime = null;
                                });
                              },
                              icon: const Icon(Icons.chevron_left, size: 20, color: Color(0xFF888888)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('MMMM yyyy').format(_currentMonthView),
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF666666),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _currentMonthView = DateTime(_currentMonthView.year, _currentMonthView.month + 1);
                                  final DateTime now = DateTime.now();
                                  if (_currentMonthView.month == now.month && _currentMonthView.year == now.year) {
                                    _selectedDate = now;
                                  } else {
                                    _selectedDate = DateTime(_currentMonthView.year, _currentMonthView.month, 1);
                                  }
                                  selectedTime = null;
                                });
                              },
                              icon: const Icon(Icons.chevron_right, size: 20, color: Color(0xFF888888)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildCalendar(primaryGreen, secondaryGreen),
                    
                    const SizedBox(height: 40),
                    
                    // Select Time Section
                    Text(
                      'Select Time',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTimeSelection(primaryGreen),
                    
                    const SizedBox(height: 48),
                    
                    // Book Appointment button
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: selectedTime != null ? () {
                          // TODO: Implement booking confirmation
                        } : null, // Disable if no time selected
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF86A590),
                          disabledBackgroundColor: const Color(0xFF86A590).withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Book Appointment',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCounselorCard(Color primaryGreen) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(
                    image: widget.profileImage.startsWith('data:image') 
                      ? MemoryImage(base64Decode(widget.profileImage.split(',').last)) as ImageProvider
                      : NetworkImage(widget.profileImage),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Color(0xFF4C5E51), size: 16),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.name,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.specialty,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: const Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFFFFB800), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      widget.rating,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${widget.sessionsCount}+ sessions)',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: const Color(0xFF999999),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(Color primaryGreen, Color secondaryGreen) {
    final days = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
    
    // Calculate calendar grid for _currentMonthView
    final firstDayOfMonth = DateTime(_currentMonthView.year, _currentMonthView.month, 1);
    final lastDayOfMonth = DateTime(_currentMonthView.year, _currentMonthView.month + 1, 0);
    
    // Find how many days from previous month to show (to align MO at start)
    final leadingPadding = firstDayOfMonth.weekday - 1;
    final prevMonthLastDay = DateTime(_currentMonthView.year, _currentMonthView.month, 0).day;
    
    final List<int?> calendarDays = [];
    // Padding from prev month
    for (int i = leadingPadding - 1; i >= 0; i--) {
      calendarDays.add(prevMonthLastDay - i);
    }
    // Current month days
    for (int i = 1; i <= lastDayOfMonth.day; i++) {
      calendarDays.add(i);
    }
    // Padding for next month to complete the grid
    while (calendarDays.length % 7 != 0) {
      calendarDays.add(null);
    }

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
            children: days.map((d) => SizedBox(
              width: 35,
              child: Center(
                child: Text(
                  d,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFAAAAAA),
                  ),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 20),
          _isLoading 
          ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: Color(0xFF7C9C84))))
          : Wrap(
            spacing: (MediaQuery.of(context).size.width - 48 - 40 - (35 * 7)) / 6,
            runSpacing: 20,
            children: calendarDays.asMap().entries.map((entry) {
              final idx = entry.key;
              final d = entry.value;
              if (d == null) return const SizedBox(width: 35, height: 35);
              
              final isPreviousMonth = idx < leadingPadding;
              final isNextMonth = idx >= leadingPadding + lastDayOfMonth.day;
              
              final isSelectedDateInView = d == _selectedDate.day && 
                                          _selectedDate.month == _currentMonthView.month && 
                                          _selectedDate.year == _currentMonthView.year;
              
              final isCurrent = isSelectedDateInView && !isPreviousMonth && !isNextMonth;
              final isAvailable = availableDates.contains(d) && !isPreviousMonth && !isNextMonth;
              
              // Today's real date
              final DateTime now = DateTime.now();
              final bool isToday = d == now.day && 
                                  now.month == _currentMonthView.month && 
                                  now.year == _currentMonthView.year &&
                                  !isPreviousMonth && !isNextMonth;
              
              return InkWell(
                onTap: isAvailable ? () {
                  setState(() {
                    _selectedDate = DateTime(_currentMonthView.year, _currentMonthView.month, d);
                    selectedTime = null; // Reset time when date changes
                  });
                } : null,
                child: Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    color: isCurrent 
                      ? primaryGreen 
                      : (isAvailable ? secondaryGreen : Colors.transparent),
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
                            fontWeight: isCurrent || isAvailable ? FontWeight.bold : FontWeight.normal,
                            color: isCurrent 
                              ? Colors.white 
                              : (isPreviousMonth || isNextMonth 
                                  ? const Color(0xFFCCCCCC) 
                                  : (isAvailable ? const Color(0xFF333333) : const Color(0xFF333333).withOpacity(0.3))),
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

  Widget _buildTimeSelection(Color primaryGreen) {
    final times = availableTimesForSelectedDate;
    
    if (times.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.event_busy_rounded, color: Colors.grey[300], size: 40),
              const SizedBox(height: 12),
              Text(
                'No slots available on this date',
                style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: times.asMap().entries.map((entry) {
        final time = entry.value;
        final isSelected = time == selectedTime;
        
        return InkWell(
          onTap: () {
            setState(() {
              selectedTime = time;
            });
          },
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Container(
            width: (MediaQuery.of(context).size.width - 48 - 12) / 2,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: isSelected ? primaryGreen : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: !isSelected ? Border.all(color: const Color(0xFFEEEEEE)) : null,
              boxShadow: isSelected ? [
                BoxShadow(
                  color: primaryGreen.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ] : [],
            ),
            child: Center(
              child: Text(
                time,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : const Color(0xFF333333),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
