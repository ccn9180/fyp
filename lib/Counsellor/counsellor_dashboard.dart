import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'counsellor_history.dart';
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dynamic Welcome Header
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  String name = 'Expert';
                  String? profileUrl;

                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    name = data['fullName']?.split(' ')[0] ?? 'Expert';
                    profileUrl = data['profileImageUrl'];
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, Dr. $name',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E2742),
                            ),
                          ),
                          Text(
                            'Your clinical overview for today',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFFBBCBC2),
                        backgroundImage: profileUrl != null
                            ? (profileUrl.startsWith('data:image')
                                ? MemoryImage(base64Decode(profileUrl.split(',').last)) as ImageProvider
                                : NetworkImage(profileUrl))
                            : const NetworkImage('https://images.unsplash.com/photo-1559839734-2b71ea197ec2?auto=format&fit=crop&q=80&w=2000'),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),

              // Next Session Card
              Text(
                'NEXT SESSION',
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey[500]),
              ),
              const SizedBox(height: 12),
              _buildNextSessionCard(primaryGreen),
              
              const SizedBox(height: 32),

              // Summary Stats Row
              Row(
                children: [
                  _buildMiniStat('Today', '4 Sessions', Icons.timer_outlined, primaryGreen),
                  const SizedBox(width: 16),
                  _buildMiniStat('Rating', '4.8 ⭐', Icons.star_outline_rounded, const Color(0xFFFFD700)),
                ],
              ),

              const SizedBox(height: 40),

              Text(
                'MANAGEMENT TOOLS',
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey[500]),
              ),
              const SizedBox(height: 16),

              _buildActionItem(Icons.calendar_month_rounded, 'Update Availability', 'Manage your booking slots', () => onTabChange?.call(3)),
              _buildActionItem(Icons.analytics_rounded, 'Performance Insights', 'View your clinical growth', () => onTabChange?.call(2)),
              _buildActionItem(Icons.history_rounded, 'Session History', 'Audit past clinical sessions', () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SessionHistoryScreen()));
              }),
              _buildActionItem(Icons.chat_bubble_outline_rounded, 'Client Shared Section', 'Review client shared diary, chatbot, mood trend', () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SharedChatsScreen()));
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextSessionCard(Color primaryGreen) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundImage: NetworkImage('https://images.unsplash.com/photo-1438761681033-6461ffad8d80?auto=format&fit=crop&q=80&w=2000'),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sarah Jenkins', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Anxiety Protocol • 45m', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'IN 15 MIN',
              style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: primaryGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String val, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(val, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold)),
                Text(label, style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String title, String subtitle, VoidCallback onTap) {
    final Color primaryGreen = const Color(0xFF7C9C84);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: primaryGreen, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[500])),
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
