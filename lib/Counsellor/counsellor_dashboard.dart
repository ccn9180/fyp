import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'counsellor_history.dart';
import 'shared_chats.dart';
import 'counsellor_availability_management.dart';
import 'counsellor_notifications.dart';

class CounsellorDashboardScreen extends StatelessWidget {
  final Function(int)? onTabChange;
  const CounsellorDashboardScreen({super.key, this.onTabChange});

  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = const Color(0xFF7C9C84);
    final Color backgroundColor = const Color(0xFFF2F1EC);
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(currentUserId)
                .snapshots(),
            builder: (context, userSnapshot) {
              String name = 'Expert';
              String? profileUrl;
              String rating = '0.0';

              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                final data = userSnapshot.data!.data() as Map<String, dynamic>;
                name = data['fullName']?.split(' ')[0] ?? 'Expert';
                profileUrl = data['counsellorImageUrl'] ?? data['profileImageUrl'];
                if (data['rating'] != null) {
                  rating = data['rating'].toString();
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dynamic Welcome Header
                  Row(
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
                            'Ready for a calm day ahead?',
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
                        backgroundImage: profileUrl != null && profileUrl.isNotEmpty
                            ? (profileUrl.startsWith('data:image')
                                ? MemoryImage(base64Decode(profileUrl.split(',').last)) as ImageProvider
                                : NetworkImage(profileUrl))
                            : const NetworkImage('https://images.unsplash.com/photo-1559839734-2b71ea197ec2?auto=format&fit=crop&q=80&w=2000'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Next Session & Stats Streams
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('counsellor_bookings')
                        .where('counsellorId', isEqualTo: currentUserId)
                        .where('status', isEqualTo: 'approved')
                        .snapshots(),
                    builder: (context, bookingSnapshot) {
                      int todayCount = 0;
                      Map<String, dynamic>? nextSession;

                      if (bookingSnapshot.hasData) {
                        final now = DateTime.now();
                        final todayStart = DateTime(now.year, now.month, now.day);
                        final todayEnd = todayStart.add(const Duration(days: 1));

                        List<Map<String, dynamic>> upcoming = [];

                        for (var doc in bookingSnapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          if (data['startTime'] != null) {
                            final startTime = (data['startTime'] as Timestamp).toDate();
                            if (startTime.isAfter(todayStart) && startTime.isBefore(todayEnd)) {
                              todayCount++;
                            }
                            if (startTime.isAfter(now)) {
                              upcoming.add(data);
                            }
                          }
                        }

                        upcoming.sort((a, b) => (a['startTime'] as Timestamp).compareTo(b['startTime'] as Timestamp));
                        if (upcoming.isNotEmpty) {
                          nextSession = upcoming.first;
                        }
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NEXT SESSION',
                            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey[500]),
                          ),
                          const SizedBox(height: 12),
                          _buildNextSessionCard(primaryGreen, nextSession),
                          
                          const SizedBox(height: 32),

                          // Summary Stats Row
                          Row(
                            children: [
                              _buildMiniStat('Today', '$todayCount Sessions', Icons.timer_outlined, primaryGreen),
                              const SizedBox(width: 16),
                              _buildMiniStat('Rating', '$rating ⭐', Icons.star_outline_rounded, const Color(0xFFFFD700)),
                            ],
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  Text(
                    'MANAGEMENT TOOLS',
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 16),

                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.15,
                    children: [
                      _buildSquareCard(Icons.calendar_month_rounded, 'Availability', 'Manage slots', () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const CounsellorAvailabilityManagement()));
                      }),
                      _buildSquareCard(Icons.analytics_rounded, 'Insights', 'Clinical growth', () => onTabChange?.call(3)),
                      _buildSquareCard(Icons.history_rounded, 'History', 'Audit sessions', () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const SessionHistoryScreen()));
                      }),
                      _buildSquareCard(Icons.chat_bubble_outline_rounded, 'Client Data', 'Shared insights', () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const SharedChatsScreen()));
                      }),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNextSessionCard(Color primaryGreen, Map<String, dynamic>? session) {
    if (session == null) {
      return Container(
        width: double.infinity,
        height: 280, // Added fixed height to make it taller
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: primaryGreen.withOpacity(0.06),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.local_cafe_rounded, color: primaryGreen, size: 52),
            ),
            const SizedBox(height: 16),
            Text(
              'No Upcoming Sessions',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E2742),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your schedule is clear for now.\nTake a deep breath and enjoy the moment.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.grey[500],
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    final patientName = session['patientName'] ?? 'Unknown Patient';
    final type = session['type'] ?? 'Session';
    final startTime = (session['startTime'] as Timestamp).toDate();
    final diff = startTime.difference(DateTime.now());
    
    String timeStr;
    if (diff.inMinutes < 60) {
      timeStr = 'IN ${diff.inMinutes} MIN';
    } else if (diff.inHours < 24) {
      timeStr = 'IN ${diff.inHours} HR';
    } else {
      timeStr = 'IN ${diff.inDays} DAYS';
    }

    final imageUrl = session['patientImageUrl'];

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
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFF0F0F0),
            backgroundImage: imageUrl != null && imageUrl.toString().isNotEmpty
                ? (imageUrl.toString().startsWith('data:image')
                    ? MemoryImage(base64Decode(imageUrl.toString().split(',').last)) as ImageProvider
                    : NetworkImage(imageUrl))
                : null,
            child: (imageUrl == null || imageUrl.toString().isEmpty) ? const Icon(Icons.person, color: Colors.grey) : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patientName, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('$type • ${DateFormat('hh:mm a').format(startTime)}', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey)),
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
              timeStr,
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(val, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(label, style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSquareCard(IconData icon, String title, String subtitle, VoidCallback onTap) {
    final Color primaryGreen = const Color(0xFF7C9C84);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: primaryGreen, size: 28),
            ),
            const SizedBox(height: 12),
            Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF333333))),
            const SizedBox(height: 4),
            Text(subtitle, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[500]), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
