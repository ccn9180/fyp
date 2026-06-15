import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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
  Map<String, dynamic>? selectedVoucher;

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
    double base = sessionPrice + serviceFee;
    if (selectedVoucher != null) {
      double discount = (selectedVoucher!['discountValue'] ?? 0.0).toDouble();
      if (discount == 0.0 && selectedVoucher!['name'] != null) {
        // Try parsing from name if discountValue isn't explicitly set (e.g. "RM 10 Off" or "rm10")
        final match = RegExp(r'RM\s*(\d+)', caseSensitive: false).firstMatch(selectedVoucher!['name']);
        if (match != null) {
          discount = double.tryParse(match.group(1)!) ?? 0.0;
        }
      }
      base -= discount;
    }
    return base < 0 ? 0.0 : base;
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

      // --- STRIPE PAYMENT FLOW ---
      String? paymentIntentId;
      if (totalAmount > 0) {
        // Fetch counsellor's connected Stripe account ID
        final counsellorDoc = await FirebaseFirestore.instance.collection('users').doc(widget.counselor['id']).get();
        final stripeAccountId = counsellorDoc.data()?['stripeAccountId'];
        
        if (stripeAccountId == null) {
          throw Exception('This counsellor has not set up their payment account yet.');
        }

        final url = Uri.parse('https://us-central1-hifyp-ea16a.cloudfunctions.net/createStripePaymentIntent');
        
        // Note: amount is in smallest currency unit (sen). 10.00 MYR = 1000 sen
        final int amountInSen = (totalAmount * 100).round();
        
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'amount': amountInSen,
            'currency': 'myr',
            'destinationAccountId': stripeAccountId,
          }),
        );
        
        if (response.statusCode != 200) {
          throw Exception('Failed to generate client secret from backend: ${response.body}');
        }

        final responseData = jsonDecode(response.body);
        final clientSecret = responseData['clientSecret'];
        paymentIntentId = responseData['paymentIntentId'];
        
        if (clientSecret == null) {
          throw Exception('Failed to parse client secret from backend response');
        }
        
        // 2. Initialize the Payment Sheet
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: clientSecret,
            merchantDisplayName: 'Eunoia Platform',
            style: ThemeMode.light,
          ),
        );
        
        // 3. Present the Payment Sheet (Wait for user to complete or cancel)
        await Stripe.instance.presentPaymentSheet();
      }
      // ----------------------------

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
        if (paymentIntentId != null) 'paymentIntentId': paymentIntentId,
        if (selectedVoucher != null) 'voucherName': selectedVoucher!['name'],
        if (selectedVoucher != null) 'discountAmount': (sessionPrice + serviceFee) - totalAmount,
      });

      // Remove the used voucher from the user's redeemed_rewards
      if (selectedVoucher != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'redeemed_rewards': FieldValue.arrayRemove([selectedVoucher!['id']])
        });
      }

      // Send income notification to the counsellor
      await FirebaseFirestore.instance.collection('notifications').add({
        'from': user.uid,
        'to': widget.counselor['id'],
        'type': 'income',
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        'message': 'New booking confirmed with $patientName. You have earned RM ${totalAmount.toStringAsFixed(2)} for this session.',
      });

      final prefs = await SharedPreferences.getInstance();
      final bool syncToCalendar = prefs.getBool('sync_google_calendar') ?? true;

      // Attempt to auto-add to Google Calendar
      if (syncToCalendar) {
        try {
          final String counsellorName = widget.counselor['name'] ?? 'Counsellor';
          final endTime = startDateTime.add(const Duration(hours: 1));
          
          final String encodedTitle = Uri.encodeComponent('Therapy Session with $counsellorName');
          final String encodedDetails = Uri.encodeComponent('Mental Health Therapy Session via Eunoia App');
          final DateFormat format = DateFormat("yyyyMMdd'T'HHmmss'Z'");
          
          final String startStr = format.format(startDateTime.toUtc());
          final String endStr = format.format(endTime.toUtc());

          final Uri url = Uri.parse('https://calendar.google.com/calendar/render?action=TEMPLATE&text=$encodedTitle&dates=$startStr/$endStr&details=$encodedDetails');

          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        } catch (e) {
          debugPrint('Failed to launch Google Calendar intent: $e');
        }
      }

      if (mounted) _showSuccessDialog(synced: syncToCalendar);
    } catch (e) {
      debugPrint("Error: $e");
      
      String errorMsg = 'Failed to confirm booking: $e';
      if (e is StripeException) {
        errorMsg = 'Payment cancelled or failed.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
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

  void _showSuccessDialog({bool synced = true}) {
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
                  color: primaryGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_rounded, color: primaryGreen, size: 48),
              ),
              const SizedBox(height: 24),
              Text(
                'Payment\nConfirmed!',
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                synced 
                  ? 'Your session has been successfully booked and automatically synced to your Google Calendar. You will receive a reminder soon.'
                  : 'Your session has been successfully booked. You will receive a reminder soon.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  color: const Color(0xFF666666),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text(
                    'Return Home',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
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
                    GestureDetector(
                      onTap: _showVoucherSelection,
                      child: Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: selectedVoucher != null ? lightestSage : const Color(0xFFE5E5E3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: selectedVoucher != null ? primaryGreen : Colors.transparent),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.confirmation_number_rounded, 
                                color: selectedVoucher != null ? primaryGreen : Colors.grey.shade500, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                selectedVoucher != null ? selectedVoucher!['name'] : 'Select a voucher',
                                style: GoogleFonts.outfit(
                                  color: selectedVoucher != null ? primaryGreen : Colors.grey.shade600,
                                  fontWeight: selectedVoucher != null ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (selectedVoucher != null)
                              GestureDetector(
                                onTap: () => setState(() => selectedVoucher = null),
                                child: Icon(Icons.close_rounded, color: primaryGreen, size: 20),
                              )
                            else
                              Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.shade500, size: 16),
                          ],
                        ),
                      ),
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

  void _showVoucherSelection() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Color(0xFFFBFBF6),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Text('Select a Voucher', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: textColorMain)),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
                  builder: (context, userSnap) {
                    if (userSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    if (!userSnap.hasData || !userSnap.data!.exists) return const Center(child: Text('No user data.'));

                    final userData = userSnap.data!.data() as Map<String, dynamic>;
                    final List<dynamic> redeemedRewards = userData['redeemed_rewards'] ?? [];

                    if (redeemedRewards.isEmpty) {
                      return Center(child: Text('You have not claimed any vouchers yet.', style: GoogleFonts.outfit(color: textColorSub)));
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('rewards').where(FieldPath.documentId, whereIn: redeemedRewards).snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                        
                        final vouchers = snapshot.data?.docs.where((d) => (d.data() as Map<String, dynamic>)['category']?.toString().toLowerCase().contains('voucher') == true).toList() ?? [];

                        if (vouchers.isEmpty) {
                          return Center(child: Text('No discount vouchers available.', style: GoogleFonts.outfit(color: textColorSub)));
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: vouchers.length,
                          itemBuilder: (context, index) {
                            final voucher = vouchers[index].data() as Map<String, dynamic>;
                            final String title = voucher['name'] ?? 'Discount Voucher';

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedVoucher = {
                                    ...voucher,
                                    'id': vouchers[index].id,
                                  };
                                });
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Voucher applied!', style: GoogleFonts.outfit())));
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: lightestSage)),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                                        Text('Tap to apply', style: GoogleFonts.outfit(color: primaryGreen, fontWeight: FontWeight.w600, fontSize: 12)),
                                      ],
                                    ),
                                    Icon(Icons.arrow_forward_ios_rounded, size: 16, color: primaryGreen),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
