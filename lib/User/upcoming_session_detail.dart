import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'video_call.dart';
import 'book_session.dart';

class UpcomingSessionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> sessionData;
  const UpcomingSessionDetailScreen({super.key, required this.sessionData});

  @override
  State<UpcomingSessionDetailScreen> createState() => _UpcomingSessionDetailScreenState();
}

class _UpcomingSessionDetailScreenState extends State<UpcomingSessionDetailScreen> {
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = Colors.white; // Pure white for a cleaner look
  final Color textColorMain = const Color(0xFF333333);
  final Color textColorSub = const Color(0xFF888888);

  void _handleJoinSession() {
    final startTime = (widget.sessionData['startTime'] as Timestamp).toDate();
    final now = DateTime.now();
    
    // Allow joining 10 minutes before the session starts
    final allowJoinTime = startTime.subtract(const Duration(minutes: 10));

    if (now.isBefore(allowJoinTime)) {
      _showEarlyMessage(startTime);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoCallScreen(sessionData: widget.sessionData),
        ),
      );
    }
  }

  void _showEarlyMessage(DateTime startTime) {
    final format = DateFormat('hh:mm a');
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3EE),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.access_time_rounded, color: primaryGreen, size: 40),
              ),
              const SizedBox(height: 24),
              Text(
                'Too Early',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColorMain,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your session is scheduled for ${format.format(startTime)}. You can join the call 10 minutes before the start time.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: textColorSub,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'GOT IT',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final startTime = (widget.sessionData['startTime'] as Timestamp).toDate();
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
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
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Counselor Info Header
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
                    backgroundImage: NetworkImage(widget.sessionData['counsellorImageUrl']),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.sessionData['counsellorName'],
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textColorMain,
                    ),
                  ),
                  Text(
                    widget.sessionData['counsellorSpecialty'],
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: textColorSub,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildInfoTip(Icons.videocam_rounded, 'Video Call'),
                      const SizedBox(width: 12),
                      _buildInfoTip(Icons.timer_rounded, '60 Minutes'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Appointment Details
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
                  const SizedBox(height: 16),
                  _buildDetailRow(Icons.calendar_month_rounded, 'Date', DateFormat('EEEE, MMMM dd').format(startTime)),
                  const SizedBox(height: 16),
                  _buildDetailRow(Icons.access_time_filled_rounded, 'Time', DateFormat('hh:mm a').format(startTime)),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  Text(
                    'Important Note',
                    style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: textColorMain),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ensure you are in a quiet, private space with a stable internet connection. You can join the session 10 minutes before the scheduled time.',
                    style: GoogleFonts.outfit(fontSize: 13, color: textColorSub, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            
            // Start Button
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _handleJoinSession,
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
                      'START SESSION',
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
            
            // Reschedule Button
            SizedBox(
              width: double.infinity,
              height: 60,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BookSessionScreen(
                        counsellorId: widget.sessionData['counsellorId'],
                        name: widget.sessionData['counsellorName'],
                        specialty: widget.sessionData['counsellorSpecialty'],
                        rating: '4.9', // Default or from sessionData
                        profileImage: widget.sessionData['counsellorImageUrl'],
                        sessionsCount: 120,
                        isRescheduling: true,
                        oldAppointmentId: widget.sessionData['id'],
                      ),
                    ),
                  );
                },
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
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: primaryGreen),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: primaryGreen),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: textColorSub.withOpacity(0.5)),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.outfit(fontSize: 11, color: textColorSub)),
            Text(value, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: textColorMain)),
          ],
        ),
      ],
    );
  }
}
