import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'counsellor_analytics.dart';
import 'counsellor_feedback.dart';
import 'counsellor_schedule.dart';
import 'shared_chats.dart';

class CounsellorDashboardScreen extends StatelessWidget {
  final Function(int)? onTabChange;
  const CounsellorDashboardScreen({super.key, this.onTabChange});

  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = const Color(0xFF7C9C84);
    final Color backgroundColor = const Color(0xFFF2F1EC);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expert Dashboard',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E2742),
                    ),
                  ),
                  Text(
                    'Performance and stats at a glance',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatCard('Analysis', '\$ 1,240', Icons.account_balance_wallet_outlined, primaryGreen, () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const CounsellorAnalyticsScreen()));
                  }),
                  _buildStatCard('Reviews', '4.9', Icons.star_outline_rounded, Colors.amber, () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const CounsellorFeedbackScreen()));
                  }),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatCard('Upcoming', '3', Icons.today_outlined, Colors.blue, () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const CounsellorScheduleScreen()));
                  }),
                  _buildStatCard('Completed', '42', Icons.task_alt_rounded, Colors.green, () {}),
                ],
              ),
              const SizedBox(height: 40),

              Text(
                'QUICK ACTIONS',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 16),

              _buildActionItem(Icons.calendar_month_rounded, 'Schedule Sessions', 'Update your availability', () {
                onTabChange?.call(3); // Navigate to Profile tab (index 3)
              }),
              _buildActionItem(Icons.chat_bubble_outline_rounded, 'Shared Insights', 'Review client AI chatbot sessions', () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SharedChatsScreen()));
              }),
              _buildActionItem(Icons.analytics_outlined, 'Performance Metrics', 'View growth and session trends', () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const CounsellorAnalyticsScreen()));
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 12),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF333333),
                ),
              ),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF7C9C84), size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}
