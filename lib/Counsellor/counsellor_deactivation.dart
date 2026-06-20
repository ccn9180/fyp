import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp/UserAccount/splash_screen.dart';

class CounsellorDeactivationScreen extends StatefulWidget {
  const CounsellorDeactivationScreen({super.key});

  @override
  State<CounsellorDeactivationScreen> createState() => _CounsellorDeactivationScreenState();
}

class _CounsellorDeactivationScreenState extends State<CounsellorDeactivationScreen> {
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _commonReasons = [
    'Career Change',
    'Personal / Health Reasons',
    'Taking a Break',
    'Moving to Private Practice',
    'Temporary Break',
    'Other',
  ];
  String? _selectedReason;

  @override
  void initState() {
    super.initState();
    _detailsController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  bool get _isFormValid => _selectedReason != null && _detailsController.text.trim().isNotEmpty;

  Future<void> _confirmSubmission() async {
    setState(() => _isSubmitting = true);
    final user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      try {
        final activeBookingsSnap = await FirebaseFirestore.instance
            .collection('counsellor_bookings')
            .where('counsellorId', isEqualTo: user.uid)
            .where('status', whereIn: ['approved', 'pending', 'rescheduled', 'upcoming', 'APPROVED', 'PENDING', 'RESCHEDULED', 'UPCOMING'])
            .get();
            
        bool hasActiveBookings = false;
        for (var doc in activeBookingsSnap.docs) {
          final data = doc.data();
          if (data['startTime'] != null) {
            final startTime = (data['startTime'] as Timestamp).toDate();
            if (startTime.isAfter(DateTime.now())) {
              hasActiveBookings = true;
              break;
            }
          } else {
            hasActiveBookings = true;
            break;
          }
        }

        if (hasActiveBookings) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                contentPadding: const EdgeInsets.all(32),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF5F5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.block_rounded, color: Color(0xFFD32F2F), size: 48),
                    ),
                    const SizedBox(height: 24),
                    Text('Action Blocked', textAlign: TextAlign.center, style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF333333))),
                    const SizedBox(height: 16),
                    Text(
                      'You currently have upcoming or pending bookings with clients. Please complete or cancel all active bookings before retiring your profile.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(color: Colors.grey[600], height: 1.5),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF333333),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text('OK', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          setState(() => _isSubmitting = false);
          return;
        }
      } catch (e) {
        // Continue to confirm if check fails
      }
    }
    
    setState(() => _isSubmitting = false);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        contentPadding: const EdgeInsets.all(32),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5F5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFD32F2F), size: 48),
            ),
            const SizedBox(height: 24),
            Text('Confirm Submission', textAlign: TextAlign.center, style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF333333))),
            const SizedBox(height: 16),
            Text(
              'Are you sure you want to deactivate your profile? Your data is kept safe, and you can simply log back in to reactivate it.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _submitRequest();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
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

  Future<void> _submitRequest() async {
    if (_selectedReason == null || _detailsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide all required information.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);
      final appRef = FirebaseFirestore.instance.collection('counsellor_applications').doc(user.uid);
      
      final batch = FirebaseFirestore.instance.batch();
      
      final reqRef = FirebaseFirestore.instance.collection('deactivation_requests').doc();
      batch.set(reqRef, {
        'counsellorId': user.uid,
        'counsellorName': user.displayName,
        'reason': _selectedReason,
        'details': _detailsController.text.trim(),
        'status': 'Approved',
        'requestedAt': FieldValue.serverTimestamp(),
      });
      
      batch.set(userRef, {'role': 'user'}, SetOptions(merge: true));
      batch.set(appRef, {'status': 'deactivated'}, SetOptions(merge: true));
      
      await batch.commit();

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
            contentPadding: const EdgeInsets.all(32),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF7C9C84), size: 48),
                ),
                const SizedBox(height: 24),
                Text('Account Deactivated', textAlign: TextAlign.center, style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF333333))),
                const SizedBox(height: 16),
                Text(
                  'Your counsellor account has been successfully deactivated. You will now be logged out. If you wish to reactivate, please apply again.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: Colors.grey[600], height: 1.5),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context); // Close dialog
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const SplashTransitionScreen(isLogout: true)),
                          (route) => false,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C9C84),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text('OK', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF7C9C84);
    const Color textColorMain = Color(0xFF333333);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textColorMain, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'DEACTIVATE PROFILE',
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
        child: _buildForm(textColorMain),
      ),
    );
  }

  Widget _buildForm(Color textColorMain) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Soft Empathetic Warning Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            children: [
               Container(
                 padding: const EdgeInsets.all(16),
                 decoration: const BoxDecoration(
                   color: Color(0xFFFFF5F5),
                   shape: BoxShape.circle,
                 ),
                 child: const Icon(Icons.favorite_border_rounded, color: Color(0xFFFF8A8A), size: 36),
               ),
               const SizedBox(height: 20),
               Text('Take a Step Back', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold, color: textColorMain)),
               const SizedBox(height: 12),
               Text(
                 'Deactivating your counsellor profile is a temporary action. Your profile will be hidden from the directory, but your data is kept safe. You can log back in and reactivate your profile whenever you are ready to resume.',
                 textAlign: TextAlign.center,
                 style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600], height: 1.5),
               ),
            ],
          ),
        ),
        const SizedBox(height: 40),

        Text('PRIMARY REASON', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey[500])),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 8)),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: ButtonTheme(
              alignedDropdown: true,
              child: DropdownButton<String>(
                value: _selectedReason,
                isExpanded: true,
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(24),
                icon: const Icon(Icons.expand_more_rounded, color: Color(0xFF7C9C84), size: 28),
                hint: Text('Select Reason', style: GoogleFonts.outfit(fontSize: 15, color: Colors.grey[400])),
                items: _commonReasons.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: GoogleFonts.outfit(fontSize: 15, color: textColorMain, fontWeight: FontWeight.w500)),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedReason = val),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Elevated Text Area
        Text('DETAILED EXPLANATION', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey[500])),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 8)),
            ],
          ),
          child: TextField(
            controller: _detailsController,
            maxLines: 6,
            style: GoogleFonts.outfit(fontSize: 14, color: textColorMain),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: 'Please share your experience with us, or note any specific handover requirements for your clients...',
              hintStyle: GoogleFonts.outfit(color: Colors.grey[400], height: 1.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
        ),
        const SizedBox(height: 48),

        // Premium CTA Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: (_isSubmitting || !_isFormValid) ? null : _confirmSubmission,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFFFCDCD),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: _isSubmitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('Submit Deactivation Request', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}
