import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookingSummaryScreen extends StatefulWidget {
  final Map<String, dynamic> counselor;
  final DateTime selectedDate;
  final String selectedTime;

  const BookingSummaryScreen({
    super.key,
    required this.counselor,
    required this.selectedDate,
    required this.selectedTime,
  });

  @override
  State<BookingSummaryScreen> createState() => _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends State<BookingSummaryScreen> {
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color primaryButtonColor = const Color(0xFF86A590);
  final Color backgroundCream = const Color(0xFFFBFBF6);
  final Color lightestSage = const Color(0xFFEAF2ED);
  final Color textColorMain = const Color(0xFF333333);
  final Color textColorSub = const Color(0xFF666666);
  
  bool _isProcessing = false;

  double get sessionPrice {
    final rawPrice = widget.counselor['price']?.toString() ?? 'Free';
    final cleaned = rawPrice.replaceAll(RegExp(r'[^\d.]'), '');
    if (cleaned.isEmpty || rawPrice.toLowerCase() == 'free') {
      return 0.0;
    }
    return double.tryParse(cleaned) ?? 0.0;
  }

  double get serviceFee {
    return sessionPrice == 0.0 ? 0.0 : 4.50;
  }

  double get totalAmount {
    return sessionPrice + serviceFee;
  }

  Future<void> _handleConfirmBooking() async {
    setState(() => _isProcessing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final String dateStr = DateFormat('dd MMM yyyy').format(widget.selectedDate);

      // Check if slot has been booked in the meantime
      final existingQuery = await FirebaseFirestore.instance
          .collection('counsellor_bookings')
          .where('counsellorId', isEqualTo: widget.counselor['id'])
          .where('date', isEqualTo: dateStr)
          .where('timeRange', isEqualTo: widget.selectedTime)
          .get();

      bool isDoubleBooked = false;
      for (var doc in existingQuery.docs) {
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

      // Fetch user's full name
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final String patientName = userDoc.data()?['fullName'] ?? 'Patient';

      // Parse and combine date and time
      final format = DateFormat.jm();
      final parsedTime = format.parse(widget.selectedTime);
      final startDateTime = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
        parsedTime.hour,
        parsedTime.minute,
      );

      await FirebaseFirestore.instance.collection('counsellor_bookings').add({
        'patientId': user.uid,
        'patientName': patientName,
        'counsellorId': widget.counselor['id'],
        'counsellorName': widget.counselor['name'],
        'counsellorSpecialty': widget.counselor['specialty'],
        'counsellorImageUrl': widget.counselor['image'],
        'date': dateStr,
        'timeRange': widget.selectedTime,
        'startTime': Timestamp.fromDate(startDateTime),
        'status': 'upcoming',
        'createdAt': FieldValue.serverTimestamp(),
        'amount': totalAmount,
        'type': 'Video Call',
      });

      if (mounted) _showSuccessDialog();
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to confirm booking: $e', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
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
              Icon(Icons.check_circle_rounded, color: primaryGreen, size: 64),
              const SizedBox(height: 24),
              Text('Confirmed!', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  style: ElevatedButton.styleFrom(backgroundColor: primaryButtonColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  child: Text('Return Home', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
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
      backgroundColor: backgroundCream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Navigation Bar
              Row(
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
                    'BOOKING SUMMARY',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: const Color(0xFF5D6D66),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 44), // Balanced placeholder
                ],
              ),
              const SizedBox(height: 40),
              // Scheduled Session Card
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SCHEDULED SESSION',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade400, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: widget.counselor['image'].startsWith('data:image')
                              ? Image.memory(base64Decode(widget.counselor['image'].split(',').last), width: 70, height: 70, fit: BoxFit.cover)
                              : Image.network(widget.counselor['image'], width: 70, height: 70, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.counselor['name'],
                                style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold, color: textColorMain),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.counselor['specialty'],
                                style: GoogleFonts.outfit(fontSize: 14, color: textColorSub),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(color: Color(0xFFF0F0F0)),
                    const SizedBox(height: 24),
                    _buildIconDetail(Icons.calendar_today_rounded, 'DATE', formattedDate),
                    const SizedBox(height: 20),
                    _buildIconDetail(Icons.access_time_rounded, 'TIME', '${widget.selectedTime} (GMT)'),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Secure Notice
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F1EF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified_user_rounded, color: primaryGreen.withOpacity(0.6), size: 18),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Your payment is processed through a secure, encrypted gateway. We prioritize your privacy and data security above all.',
                        style: GoogleFonts.outfit(fontSize: 11, color: textColorSub, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Payment Summary Container
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Summary',
                      style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: textColorMain),
                    ),
                    const SizedBox(height: 24),
                    _buildSummaryRow('Individual Session (60m)', sessionPrice == 0.0 ? 'Free' : 'RM${sessionPrice.toStringAsFixed(2)}'),
                    const SizedBox(height: 12),
                    _buildSummaryRow('Service Fee', serviceFee == 0.0 ? 'Free' : 'RM${serviceFee.toStringAsFixed(2)}'),
                    const SizedBox(height: 24),
                    
                    Text(
                      'VOUCHER OR DISCOUNT',
                      style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade400, letterSpacing: 1),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 50,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(color: const Color(0xFFE5E5E3), borderRadius: BorderRadius.circular(12)),
                            child: TextField(
                              decoration: InputDecoration(hintText: 'Enter code', hintStyle: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 13), border: InputBorder.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          decoration: BoxDecoration(color: lightestSage, borderRadius: BorderRadius.circular(12)),
                          child: Center(child: Text('Apply', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: primaryGreen))),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Total Amount', style: GoogleFonts.outfit(fontSize: 14, color: textColorSub)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              totalAmount == 0.0 ? 'Free' : 'RM${totalAmount.toStringAsFixed(2)}',
                              style: GoogleFonts.playfairDisplay(fontSize: 36, fontWeight: FontWeight.w900, color: const Color(0xFF5D6D66)),
                            ),
                            Text('TAX INCLUDED WHERE APPLICABLE', style: GoogleFonts.outfit(fontSize: 8, color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _handleConfirmBooking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryButtonColor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: _isProcessing 
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 12),
                                Text('Pay Now', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                              ],
                            ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    
                    // Payment Icons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.credit_card_rounded, color: Colors.grey.shade400, size: 24),
                        const SizedBox(width: 16),
                        Icon(Icons.credit_score_rounded, color: Colors.grey.shade400, size: 24),
                        const SizedBox(width: 16),
                        Icon(Icons.apple_rounded, color: Colors.grey.shade400, size: 24),
                      ],
                    ),

                    const SizedBox(height: 24),
                    Center(
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey.shade400, height: 1.5),
                          children: [
                            const TextSpan(text: 'By completing this payment, you agree to\nEunoia\'s '),
                            TextSpan(text: 'Terms of Service', style: TextStyle(color: textColorSub, decoration: TextDecoration.underline)),
                            const TextSpan(text: ' and '),
                            TextSpan(text: 'Cancellation\nPolicy', style: TextStyle(color: textColorSub, decoration: TextDecoration.underline)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconDetail(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: lightestSage, shape: BoxShape.circle),
          child: Center(child: Icon(icon, color: primaryGreen, size: 18)),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1)),
            Text(value, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: textColorMain)),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 14, color: textColorSub)),
        Text(value, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: textColorMain)),
      ],
    );
  }
}
