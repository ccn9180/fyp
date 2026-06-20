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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _shareDiaries = false;
  bool _shareChats = false;
  bool _shareAnalytics = false;
  bool _shareMoods = false;
  bool _isShared = false;
  bool _isEditingShare = false;

  @override
  void initState() {
    super.initState();
    _checkSharedState();
  }

  Future<void> _checkSharedState() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('shared_chats')
          .where('bookingId', isEqualTo: widget.sessionData['id'])
          .get();

      if (snap.docs.isNotEmpty) {
        setState(() {
          _isShared = true;
          for (var doc in snap.docs) {
            final type = doc.data()['type'];
            if (type == 'diary') _shareDiaries = true;
            if (type == 'chat') _shareChats = true;
            if (type == 'report') {
              _shareAnalytics = true;
              _shareMoods = true;
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error checking shared state: $e");
    }
  }

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
    final String statusRaw = widget.sessionData['status']?.toString().toLowerCase() ?? 'upcoming';
    
    return Scaffold(
      key: _scaffoldKey,
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
        actions: [
          if (!isSessionPassed)
            IconButton(
              icon: Icon(Icons.share_outlined, color: primaryGreen),
              tooltip: 'Share Records',
              onPressed: () {
                _showShareBottomSheet(context);
              },
            ),
        ],
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
                    statusRaw == 'missed' ? 'Reason for Missed Session' : 'Important Note',
                    style: GoogleFonts.outfit(
                      fontSize: 13, 
                      fontWeight: FontWeight.bold, 
                      color: statusRaw == 'missed' ? Colors.red.shade400 : textColorMain
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    statusRaw == 'missed' 
                      ? (widget.sessionData['missedReason'] ?? 'This session was marked as missed by the counsellor.')
                      : 'Ensure you are in a quiet, private space with a stable internet connection. You can join the session 10 minutes before the scheduled time.',
                    style: GoogleFonts.outfit(fontSize: 13, color: textColorSub, height: 1.5),
                  ),
                  if (now.isBefore(startTime) && statusRaw != 'completed' && statusRaw != 'missed' && statusRaw != 'cancelled') ...[
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
            const SizedBox(height: 24),
            // The PrepareSessionCard was removed from here.
            const SizedBox(height: 24),
            
            if (!isSessionPassed && statusRaw != 'completed' && statusRaw != 'missed' && statusRaw != 'cancelled') ...[
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
              
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
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
                                  rating: '4.9',
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          'RESCHEDULE',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: canReschedule ? primaryGreen : Colors.grey,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () => _handleCancelSession(canReschedule, startTime),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red.shade300.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          'CANCEL',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade400,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (statusRaw == 'completed' || statusRaw == 'missed' || statusRaw == 'cancelled') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    'This session is $statusRaw.',
                    style: GoogleFonts.outfit(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
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

  void _showShareBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // Need StatefulBuilder since bottom sheet has its own state
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            // Helper function to update both modal and parent state
            void updateState(VoidCallback fn) {
              setModalState(fn);
              setState(fn);
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Prepare for Your Session',
                              style: GoogleFonts.playfairDisplay(fontSize: 26, fontWeight: FontWeight.bold, color: textColorMain),
                            ),
                          ),
                        ],
                      ),
          const SizedBox(height: 8),
          Text(
            'Share Information with Counsellor',
            style: GoogleFonts.outfit(fontSize: 14, color: primaryGreen, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          
          if (_isShared && !_isEditingShare) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: primaryGreen),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Information has been shared for this session.',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: primaryGreen),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => updateState(() => _isEditingShare = true),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primaryGreen.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('Edit Sharing', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: primaryGreen)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing ? null : () {
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
                              Text('Unshare All Data?', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: textColorMain)),
                              const SizedBox(height: 16),
                              Text('Are you sure you want to stop sharing all information with this counsellor? They will no longer have access to any previously shared data.', textAlign: TextAlign.center, style: GoogleFonts.outfit(color: textColorSub, height: 1.5)),
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
                                      onPressed: () async {
                                        Navigator.pop(context); // Close dialog
                                        updateState(() => _isProcessing = true);
                                        await _handleUnshareAll();
                                        if (mounted) updateState(() {});
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
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('Unshare All', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.red.shade400)),
                  ),
                ),
              ],
            ),
          ] else ...[
            _buildCheckbox('Recent Diaries (Last 7 days)', _shareDiaries, (v) => updateState(() => _shareDiaries = v ?? false)),
            _buildCheckbox('Chatbot Conversations (Last 7 days)', _shareChats, (v) => updateState(() => _shareChats = v ?? false)),
            _buildCheckbox('Analytics Summary', _shareAnalytics, (v) => updateState(() => _shareAnalytics = v ?? false)),
            _buildCheckbox('Mood Trends', _shareMoods, (v) => updateState(() => _shareMoods = v ?? false)),
            
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : () async {
                      updateState(() => _isProcessing = true);
                      await _handleShareSelected();
                      if (mounted) updateState(() {});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isProcessing 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Share Selected', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  ),
                ),
                if (_isEditingShare) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: TextButton(
                      onPressed: () {
                        updateState(() {
                          _isEditingShare = false;
                          _shareDiaries = false; _shareChats = false; _shareAnalytics = false; _shareMoods = false;
                        });
                        _checkSharedState().then((_) {
                          updateState(() {});
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        backgroundColor: Colors.grey.shade100,
                      ),
                      child: Text('Cancel', style: GoogleFonts.outfit(color: textColorSub, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
      ),
      ),
            );
          },
        );
      },
    );
  }

  Widget _buildCheckbox(String title, bool value, void Function(bool?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16),
          decoration: BoxDecoration(
            color: value ? primaryGreen.withOpacity(0.08) : Colors.transparent,
            border: Border.all(color: value ? primaryGreen.withOpacity(0.3) : Colors.grey.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: value ? primaryGreen : Colors.transparent,
                  border: Border.all(color: value ? primaryGreen : Colors.grey.withOpacity(0.4), width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: value ? const Icon(Icons.check_rounded, color: Colors.white, size: 16) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    color: value ? primaryGreen : textColorMain,
                    fontWeight: value ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleUnshareAll() async {
    setState(() => _isProcessing = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snap = await FirebaseFirestore.instance
          .collection('shared_chats')
          .where('counsellorId', isEqualTo: widget.sessionData['counsellorId'])
          .get();
      
      for (var doc in snap.docs) {
        final data = doc.data();
        final pId = data['patientId'] ?? data['userId'];
        if (pId == user.uid) {
          await doc.reference.delete();
        }
      }

      setState(() {
        _isShared = false;
        _isEditingShare = false;
        _shareDiaries = false;
        _shareChats = false;
        _shareAnalytics = false;
        _shareMoods = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully unshared information.', style: GoogleFonts.outfit()), backgroundColor: primaryGreen));
      }
    } catch (e) {
      debugPrint("Error unsharing: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleShareSelected() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    if (!_shareDiaries && !_shareChats && !_shareAnalytics && !_shareMoods) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select at least one item to share.', style: GoogleFonts.outfit())));
      return;
    }

    setState(() => _isProcessing = true);
    
    try {
      String userName = user.displayName ?? 'Patient Recovery';
      final uDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (uDoc.exists) userName = uDoc.data()?['fullName'] ?? userName;

      final batch = FirebaseFirestore.instance.batch();
      final collection = FirebaseFirestore.instance.collection('shared_chats');

      // 1. Delete existing for this booking to overwrite cleanly
      final existing = await collection.where('bookingId', isEqualTo: widget.sessionData['id']).get();
      for (var doc in existing.docs) {
        batch.delete(doc.reference);
      }

      final sevenDaysAgo = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7)));

      // 2. Add Diaries
      if (_shareDiaries) {
        final diariesSnap = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('diary_entries')
            .where('timestamp', isGreaterThanOrEqualTo: sevenDaysAgo)
            .get();
        for (var doc in diariesSnap.docs) {
          final data = doc.data();
          final newDoc = collection.doc();
          batch.set(newDoc, {
            'counsellorId': widget.sessionData['counsellorId'],
            'patientId': user.uid,
            'userName': userName,
            'sharedAt': FieldValue.serverTimestamp(),
            'type': 'diary',
            'diaryId': doc.id,
            'content': data['content'],
            'emotions': data['emotions'] ?? data['emotionTags'],
            'timestamp': data['timestamp'],
            'aiSummary': data['analysis'] ?? data['aiSummary'],
            'tags': data['tags'] ?? data['keywords'],
            'isCrisis': data['isCrisis'] ?? data['crisisDetected'] ?? false,
            'bookingId': widget.sessionData['id'],
          });
        }
      }

      // 3. Add Chats
      if (_shareChats) {
        final chatsSnap = await FirebaseFirestore.instance.collection('chat_sessions')
            .where('userId', isEqualTo: user.uid)
            .where('createdAt', isGreaterThanOrEqualTo: sevenDaysAgo)
            .get();
        for (var doc in chatsSnap.docs) {
          final data = doc.data();
          final newDoc = collection.doc();
          batch.set(newDoc, {
            'counsellorId': widget.sessionData['counsellorId'],
            'patientId': user.uid,
            'userName': userName,
            'sharedAt': FieldValue.serverTimestamp(),
            'type': 'chat',
            'chatId': doc.id,
            'messages': data['messages'] ?? [],
            'createdAt': data['createdAt'],
            'isCrisis': data['isCrisis'] ?? data['crisisDetected'] ?? false,
            'bookingId': widget.sessionData['id'],
          });
        }
      }

      // 4. Add Report (Analytics + Moods)
      if (_shareAnalytics || _shareMoods) {
        final newDoc = collection.doc();
        batch.set(newDoc, {
          'counsellorId': widget.sessionData['counsellorId'],
          'patientId': user.uid,
          'userName': userName,
          'sharedAt': FieldValue.serverTimestamp(),
          'type': 'report',
          'reportType': 'Activity Summary',
          'dateRangeStart': sevenDaysAgo,
          'dateRangeEnd': Timestamp.now(),
          'stats': {
            'diary': _shareDiaries ? 1 : 0,
            'chatbot': _shareChats ? 1 : 0,
            'resources': 0,
            'appointments': 0,
            'xp': 100,
          },
          'bookingId': widget.sessionData['id'],
        });
      }

      await batch.commit();

      setState(() {
        _isShared = true;
        _isEditingShare = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully shared information.', style: GoogleFonts.outfit()), backgroundColor: primaryGreen));
      }
    } catch (e) {
      debugPrint("Error sharing: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to share information.', style: GoogleFonts.outfit()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}

