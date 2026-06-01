import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RescheduleSummaryScreen extends StatefulWidget {
  final Map<String, dynamic> counselor;
  final DateTime selectedDate;
  final String selectedTime;
  final String oldAppointmentId;

  const RescheduleSummaryScreen({
    super.key,
    required this.counselor,
    required this.selectedDate,
    required this.selectedTime,
    required this.oldAppointmentId,
  });

  @override
  State<RescheduleSummaryScreen> createState() => _RescheduleSummaryScreenState();
}

class _RescheduleSummaryScreenState extends State<RescheduleSummaryScreen> {
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFFBFBF6);
  final Color textColorMain = const Color(0xFF333333);
  final Color textColorSub = const Color(0xFF666666);
  
  bool _isProcessing = false;

  Future<void> _handleConfirmReschedule() async {
    setState(() => _isProcessing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final String dateStr = DateFormat('dd MMM yyyy').format(widget.selectedDate);

      // Check if slot has been booked by someone else
      final existingQuery = await FirebaseFirestore.instance
          .collection('counsellor_bookings')
          .where('counsellorId', isEqualTo: widget.counselor['id'])
          .where('date', isEqualTo: dateStr)
          .where('timeRange', isEqualTo: widget.selectedTime)
          .get();

      bool isDoubleBooked = false;
      for (var doc in existingQuery.docs) {
        if (doc.id == widget.oldAppointmentId) continue; // Skip the booking being rescheduled
        final status = (doc['status'] ?? '').toString().toLowerCase();
        if (status != 'cancelled' && status != 'rejected') {
          isDoubleBooked = true;
          break;
        }
      }

      if (isDoubleBooked) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('This session slot is no longer available. Please select another time.', 
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              backgroundColor: Colors.red[400],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        return;
      }

      // Parse and combine date and time
      final format = DateFormat.jm();
      final parsedTime = format.parse(widget.selectedTime);
      final finalDateTime = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
        parsedTime.hour,
        parsedTime.minute,
      );

      // Update the appointment in Firestore
      await FirebaseFirestore.instance.collection('counsellor_bookings').doc(widget.oldAppointmentId).update({
        'startTime': Timestamp.fromDate(finalDateTime),
        'date': dateStr,
        'timeRange': widget.selectedTime,
        'status': 'RESCHEDULED',
        'rescheduledBy': 'patient',
        'lastModified': FieldValue.serverTimestamp(),
      });
      
      if (mounted) _showSuccessDialog();
    } catch (e) {
      debugPrint("Error rescheduling: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reschedule session: $e', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Container(
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
                child: Icon(Icons.check_circle_rounded, color: primaryGreen, size: 40),
              ),
              const SizedBox(height: 24),
              Text('Successfully\nRescheduled!', 
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('Your session has been updated to the new time.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: textColorSub, fontSize: 14)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  child: Text('RETURN HOME', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
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
    String formattedDate = DateFormat('EEEE, MMM d, yyyy').format(widget.selectedDate);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF333333), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'RESCHEDULE SUMMARY',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: textColorMain,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              // Session Detail Card
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NEW SESSION TIME',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: primaryGreen, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(widget.counselor['image'], width: 60, height: 60, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.counselor['name'],
                                style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold, color: textColorMain),
                              ),
                              Text(
                                widget.counselor['specialty'],
                                style: GoogleFonts.outfit(fontSize: 13, color: textColorSub),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),
                    _buildInfoRow(Icons.calendar_today_rounded, 'DATE', formattedDate),
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.access_time_rounded, 'TIME', '${widget.selectedTime}'),
                  ],
                ),
              ),

              const SizedBox(height: 40),
              
              Text(
                'Note',
                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: textColorMain),
              ),
              const SizedBox(height: 8),
              Text(
                'Rescheduling is free of charge if done at least 24 hours before the original session time. Your existing payment will be applied to this new session.',
                style: GoogleFonts.outfit(fontSize: 13, color: textColorSub, height: 1.5),
              ),
              
              const SizedBox(height: 60),

              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _handleConfirmReschedule,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: _isProcessing 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Update Appointment', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: primaryGreen, size: 20),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.outfit(fontSize: 10, color: textColorSub, letterSpacing: 0.5)),
            Text(value, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: textColorMain)),
          ],
        ),
      ],
    );
  }
}
