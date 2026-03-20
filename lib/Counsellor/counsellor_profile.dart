import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'edit_counsellor_profile.dart';
import 'counsellor_availability_management.dart';

class CounsellorProfileScreen extends StatefulWidget {
  final Function(int)? onTabChange;
  const CounsellorProfileScreen({super.key, this.onTabChange});

  @override
  State<CounsellorProfileScreen> createState() => _CounsellorProfileScreenState();
}

class _CounsellorProfileScreenState extends State<CounsellorProfileScreen> {
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFF2F1EC);
  final Color textColorMain = const Color(0xFF333333);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Text(
          'Profile',
          style: GoogleFonts.playfairDisplay(
            color: textColorMain,
            fontWeight: FontWeight.w600,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF7C9C84)));
          }

          final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final String name = data['fullName'] ?? user?.displayName ?? 'Expert Counselor';
          final String bio = data['counsellorBio'] ?? 'Dedicated to helping individuals achieve mental well-being and emotional balance through professional guidance.';
          final List<dynamic> specs = data['specializations'] ?? ['Mental Health Specialist'];
          final String specialty = specs.isNotEmpty ? specs[0].toString() : 'Mental Health Specialist';
          final String experience = data['experience'] ?? '0';
          final String? profileImageUrl = data['counsellorImageUrl'] ?? user?.photoURL;
          final String languages = data['languages'] ?? 'English, Malay, Mandarin';

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                // Expert Header
                Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                            image: profileImageUrl != null
                                ? (profileImageUrl.startsWith('data:image')
                                ? DecorationImage(
                              image: MemoryImage(base64Decode(profileImageUrl.split(',').last)),
                              fit: BoxFit.cover,
                            )
                                : DecorationImage(
                              image: NetworkImage(profileImageUrl),
                              fit: BoxFit.cover,
                            ))
                                : null,
                          ),
                          child: profileImageUrl == null
                              ? const Icon(Icons.person, size: 60, color: Color(0xFFBDBDBD))
                              : null,
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF7C9C84),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      name,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: textColorMain,
                      ),
                    ),
                    Text(
                      specialty.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: primaryGreen,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Edit Profile Button
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const EditCounsellorProfileScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE3E8E4),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      ),
                      child: Text(
                        'Edit Professional Profile',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF7C9C84),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Bio Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        bio,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // Performance Bar
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetric('4.9', 'Rating'),
                      _buildMetric('124', 'Sessions'),
                      _buildMetric('98%', 'Approval'),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Professional Details
                _buildSectionHeader('PROFESSIONAL PROFILE'),
                const SizedBox(height: 16),
                _buildInfoTile(Icons.history_edu_rounded, 'Experience', '$experience Years', () {}),
                _buildInfoTile(Icons.language_rounded, 'Languages', languages, () {}),
                _buildInfoTile(Icons.medical_services_outlined, 'Specialty', specs.join(', '), () {}),

                // Grouped Availability Section
                const SizedBox(height: 32),
                _buildSectionHeader('AVAILABILITY'),
                const SizedBox(height: 16),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('counsellor_availability')
                      .where('counsellorId', isEqualTo: user?.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    String summary = 'No slots set';
                    if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                      final docs = snapshot.data!.docs;
                      final days = docs.map((d) => (d.data() as Map<String, dynamic>)['day']?.toString().substring(0, 3)).toSet().toList();
                      summary = '${days.join(", ")} available';
                    }
                    return _buildInfoTile(
                      Icons.calendar_month_rounded,
                      'Schedule Management',
                      summary,
                          () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CounsellorAvailabilityManagement())
                      ),
                    );
                  },
                ),

                const SizedBox(height: 40),

                // Switch Hint
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: primaryGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: primaryGreen.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: primaryGreen, size: 24),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Hold profile icon to switch back to User view',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: textColorMain,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetric(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textColorMain,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value, VoidCallback onTap) {
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
            Icon(icon, color: primaryGreen, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColorMain,
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
