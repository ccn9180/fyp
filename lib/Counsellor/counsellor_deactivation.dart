import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    'Retirement',
    'Moving to Private Practice',
    'Temporary Break',
    'Other',
  ];
  String? _selectedReason;

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
      await FirebaseFirestore.instance.collection('deactivation_requests').add({
        'counsellorId': user?.uid,
        'counsellorName': user?.displayName,
        'reason': _selectedReason,
        'details': _detailsController.text.trim(),
        'status': 'Pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text('Request Submitted', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
            content: Text(
              'Your retirement request has been sent to the Admin for review. You will be notified once the deactivation process is finalized.',
              style: GoogleFonts.outfit(),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Back to profile
                },
                child: Text('OK', style: GoogleFonts.outfit(color: const Color(0xFF7C9C84), fontWeight: FontWeight.bold)),
              ),
            ],
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
        title: Text('Retire Profile', style: GoogleFonts.playfairDisplay(color: textColorMain, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textColorMain, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
              child: Column(
                children: [
                   Icon(Icons.warning_amber_rounded, color: Colors.orange[400], size: 48),
                   const SizedBox(height: 16),
                   Text(
                     'Retiring your counsellor profile is a permanent action. This request must be reviewed and approved by the Eunoia Sage administrative board.',
                     textAlign: TextAlign.center,
                     style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600], height: 1.5),
                   ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text('PRIMARY REASON', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey[500])),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedReason,
                  isExpanded: true,
                  hint: Text('Select Reason', style: GoogleFonts.outfit(fontSize: 14)),
                  items: _commonReasons.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value, style: GoogleFonts.outfit(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedReason = val),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text('DETAILED EXPLANATION', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey[500])),
            const SizedBox(height: 12),
            TextField(
              controller: _detailsController,
              maxLines: 6,
              style: GoogleFonts.outfit(fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: 'Please describe your reason for retirement and any handover requirements...',
                hintStyle: GoogleFonts.outfit(color: Colors.grey[400]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8A8A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('Submit Retirement Request', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
