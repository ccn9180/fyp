import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
  bool _isProcessing = false;

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

  void _handleCancelSession(bool canReschedule, DateTime startTime) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        contentPadding: const EdgeInsets.all(32),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 64),
            const SizedBox(height: 24),
            Text('Cancel Session?', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: textColorMain)),
            const SizedBox(height: 16),
            Text(
              canReschedule 
                ? 'You are cancelling more than 24 hours in advance. You are eligible for a full refund.'
                : 'You are cancelling with less than 24 hours notice. No refund will be issued.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: textColorSub, height: 1.5),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Go Back', style: GoogleFonts.outfit(color: textColorSub, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : () {
                      Navigator.pop(context);
                      _executeCancellation(canReschedule);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade400,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text('Confirm', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeCancellation(bool canReschedule) async {
    setState(() => _isProcessing = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      // Update booking status
      await FirebaseFirestore.instance
          .collection('counsellor_bookings')
          .doc(widget.sessionData['id'])
          .update({'status': 'cancelled'});

      // Trigger Refund if eligible
      bool refundProcessed = false;
      if (canReschedule) {
        final paymentIntentId = widget.sessionData['paymentIntentId'];
        if (paymentIntentId != null) {
          final url = Uri.parse('https://us-central1-hifyp-ea16a.cloudfunctions.net/refundStripePayment');
          final response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'paymentIntentId': paymentIntentId}),
          );
          if (response.statusCode == 200) {
            refundProcessed = true;
          }
        }
      }

      // Notify counsellor
      await FirebaseFirestore.instance.collection('notifications').add({
        'from': user.uid,
        'to': widget.sessionData['counsellorId'],
        'type': 'cancellation',
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        'title': 'Session Cancelled',
        'message': 'A session scheduled for ${widget.sessionData['date']} at ${widget.sessionData['timeRange']} has been cancelled by the user.',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              refundProcessed ? 'Session cancelled and refund processed.' : 'Session cancelled successfully.',
              style: GoogleFonts.outfit(),
            ),
          ),
        );
        Navigator.pop(context); // Go back to history
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel session.', style: GoogleFonts.outfit())),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _launchGoogleCalendar(DateTime startTime) async {
    setState(() => _isProcessing = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['https://www.googleapis.com/auth/calendar.events'],
      );
      
      GoogleSignInAccount? account = googleSignIn.currentUser;
      account ??= await googleSignIn.signIn();

      if (account == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sign in aborted. Cannot add to calendar.', style: GoogleFonts.outfit())),
          );
        }
        return;
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final String? token = auth.accessToken;

      if (token == null) {
        throw Exception('Failed to get access token');
      }

      final endTime = startTime.add(const Duration(hours: 1));
      final String counsellorName = widget.sessionData['counsellorName'] ?? 'Counsellor';

      final Map<String, dynamic> event = {
        'summary': 'Therapy Session with $counsellorName',
        'description': 'Mental Health Therapy Session via Eunoia App',
        'start': {
          'dateTime': startTime.toUtc().toIso8601String(),
        },
        'end': {
          'dateTime': endTime.toUtc().toIso8601String(),
        },
        'reminders': {
          'useDefault': false,
          'overrides': [
            {'method': 'popup', 'minutes': 10},
          ],
        }
      };

      final response = await http.post(
        Uri.parse('https://www.googleapis.com/calendar/v3/calendars/primary/events'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(event),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully added to Google Calendar!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
              backgroundColor: primaryGreen,
            ),
          );
        }
      } else {
        throw Exception('Failed to create event: ${response.body}');
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add event: $e', style: GoogleFonts.outfit(color: Colors.white)),
            backgroundColor: Colors.red[400],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final startTime = (widget.sessionData['startTime'] as Timestamp).toDate();
    final now = DateTime.now();
    final bool isSessionPassed = now.isAfter(startTime.add(const Duration(minutes: 60)));
    final bool canReschedule = now.isBefore(startTime.subtract(const Duration(hours: 24)));
    
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
                    backgroundImage: (widget.sessionData['counsellorImageUrl']?.toString() ?? '').startsWith('data:image')
                        ? MemoryImage(base64Decode(widget.sessionData['counsellorImageUrl'].split(',').last)) as ImageProvider
                        : NetworkImage((widget.sessionData['counsellorImageUrl']?.toString() ?? '').isNotEmpty 
                            ? widget.sessionData['counsellorImageUrl'] 
                            : 'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?auto=format&fit=crop&q=80&w=2000'),
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
                  if (!isSessionPassed) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () => _launchGoogleCalendar(startTime),
                        icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                        label: Text('Add to Google Calendar', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4285F4),
                          side: BorderSide(color: const Color(0xFF4285F4).withOpacity(0.3)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 40),
            
            if (!isSessionPassed) ...[
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
                    if (canReschedule) {
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
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sessions can only be rescheduled at least 24 hours in advance.')),
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: canReschedule ? primaryGreen.withOpacity(0.3) : Colors.grey.withOpacity(0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text(
                    'RESCHEDULE APPOINTMENT',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: canReschedule ? primaryGreen : Colors.grey,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Cancel Button
              SizedBox(
                width: double.infinity,
                height: 60,
                child: TextButton(
                  onPressed: () => _handleCancelSession(canReschedule, startTime),
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text(
                    'CANCEL APPOINTMENT',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade300,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    'This session has ended.',
                    style: GoogleFonts.outfit(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
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
