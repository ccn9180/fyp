import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EC), // Already applying the darker color
      appBar: AppBar(
        title: Text('Privacy Policy', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSection('1. Data Collection', 'We collect minimal data to provide you with the best mindfulness experience. This includes your diary entries, progress in meditations, and basic profile information.'),
          _buildSection('2. Data Usage', 'Your data is used to personalize your journey, track your growth, and provide recommended content. We do not sell your personal data to third parties.'),
          _buildSection('3. Security', 'We implement industry-standard security measures to protect your data. Your diary entries are private and only accessible by you.'),
          _buildSection('4. Your Rights', 'You can request to delete your account and all associated data at any time through the Settings screen.'),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF7C9C84))),
          const SizedBox(height: 8),
          Text(content, style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF333333), height: 1.5)),
        ],
      ),
    );
  }
}
