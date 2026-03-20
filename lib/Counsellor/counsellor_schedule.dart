import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CounsellorScheduleScreen extends StatefulWidget {
  const CounsellorScheduleScreen({super.key});

  @override
  State<CounsellorScheduleScreen> createState() => _CounsellorScheduleScreenState();
}

class _CounsellorScheduleScreenState extends State<CounsellorScheduleScreen> {
  DateTime _selectedDate = DateTime.now();
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFF2F1EC);
  final Color textColorMain = const Color(0xFF333333);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'My Schedule',
          style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: textColorMain),
        ),
      ),
      body: Column(
        children: [
          _buildCalendarStrip(),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Booked Sessions',
                  style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold, color: textColorMain),
                ),
                Text(
                  DateFormat('EEEE, MMM dd').format(_selectedDate),
                  style: GoogleFonts.outfit(fontSize: 14, color: primaryGreen, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildBookedSessionsList()),
        ],
      ),
    );
  }

  Widget _buildBookedSessionsList() {
    final user = FirebaseAuth.instance.currentUser;
    final String selectedDateStr = DateFormat('dd MMM yyyy').format(_selectedDate);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('counsellor_bookings')
          .where('counsellorId', isEqualTo: user?.uid)
          .where('date', isEqualTo: selectedDateStr)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            Icons.event_note_rounded,
            'No Sessions Booked',
            'No one has booked a session for this date yet. Check your availability settings in Profile.',
          );
        }

        final bookings = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final data = bookings[index].data() as Map<String, dynamic>;
            final time = data['timeRange'] ?? '00:00 AM';
            final userName = data['userName'] ?? 'Patient';

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(color: primaryGreen, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          time,
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: textColorMain),
                        ),
                        Text(
                          'Session with $userName',
                          style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[300]),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: primaryGreen.withOpacity(0.1)),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold, color: textColorMain),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[400], height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarStrip() {
    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 14,
        itemBuilder: (context, index) {
          final date = DateTime.now().add(Duration(days: index));
          bool isSelected = date.day == _selectedDate.day && date.month == _selectedDate.month && date.year == _selectedDate.year;

          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: Container(
              width: 50,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected ? primaryGreen : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(date).toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    date.day.toString(),
                    style: GoogleFonts.outfit(
                      fontSize: 16,
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
}
