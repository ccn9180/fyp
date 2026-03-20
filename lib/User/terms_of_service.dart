import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EC), // Darker color applied
      appBar: AppBar(
        title: Text('Terms of Service', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
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
          _buildSection('1. Acceptance of Terms', 'By using Eunoia, you agree to these Terms of Service. If you do not agree, you should not use the application.'),
          _buildSection('2. User Conduct', 'You are responsible for your own content. Do not post illegal, harmful, or offensive content in your diary or community posts.'),
          _buildSection('3. Content Ownership', 'You own the content you create. Eunoia has a license to use your content only for providing services to you.'),
          _buildSection('4. Disclaimers', 'Eunoia is a mindfulness tool, not a substitute for professional mental health advice. Please consult with a qualified professional for any critical health needs.'),
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
