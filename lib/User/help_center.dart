import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = const Color(0xFF7C9C84);
    final Color backgroundColor = const Color(0xFFF2F1EC);
    final Color textColorMain = const Color(0xFF333333);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF333333), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Help Center',
          style: GoogleFonts.playfairDisplay(
            color: textColorMain,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How can we help you today?',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColorMain,
              ),
            ),
            const SizedBox(height: 24),
            _buildSearchBar(),
            const SizedBox(height: 32),
            _buildSectionTitle('Frequently Asked Questions'),
            const SizedBox(height: 16),
            _buildFAQTile('How do I book a session?', 'You can book a session by navigating to the Counselors tab and selecting a professional that fits your needs.'),
            _buildFAQTile('Is my data private?', 'Yes, we use industry-standard encryption to ensure all your personal data and sessions remain confidential.'),
            _buildFAQTile('How to change my password?', 'Go to Settings > Account & Security > Change Password to update your credentials.'),
            _buildFAQTile('What is Zen Progress?', 'Zen Progress tracks your mindfulness journey, rewarding you with XP for meditations and reading articles.'),
            const SizedBox(height: 32),
            _buildSectionTitle('Contact Support'),
            const SizedBox(height: 16),
            _buildContactCard(Icons.email_outlined, 'Email Support', 'support@mindfulapp.com', primaryGreen),
            _buildContactCard(Icons.chat_bubble_outline_rounded, 'Live Chat', 'Mon-Fri, 9am - 5pm', primaryGreen),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search for articles...',
          hintStyle: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF333333),
      ),
    );
  }

  Widget _buildFAQTile(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w500, color: const Color(0xFF333333)),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: Text(
              answer,
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600], height: 1.5),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildContactCard(IconData icon, String title, String subtitle, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: primaryColor, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF333333))),
              Text(subtitle, style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[500])),
            ],
          ),
          const Spacer(),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        ],
      ),
    );
  }
}
