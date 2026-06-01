import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_counsellor_profile.dart';
import 'counsellor_availability_management.dart';
import 'counsellor_history.dart';
import 'counsellor_deactivation.dart';

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
          final List<dynamic> specs = data['specializations'] ?? ['Mental Health Specialist'];
          final String specialty = specs.isNotEmpty ? specs[0].toString() : 'Mental Health Specialist';
          final String? profileImageUrl = data['counsellorImageUrl'] ?? user?.photoURL;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Column(
              children: [
                // Expert Header (Clean Centered Identity)
                Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8)),
                            ],
                            image: profileImageUrl != null
                                ? (profileImageUrl.startsWith('data:image')
                                ? DecorationImage(image: MemoryImage(base64Decode(profileImageUrl.split(',').last)), fit: BoxFit.cover)
                                : DecorationImage(image: NetworkImage(profileImageUrl), fit: BoxFit.cover))
                                : null,
                          ),
                          child: profileImageUrl == null ? const Icon(Icons.person, size: 50, color: Color(0xFFBDBDBD)) : null,
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Color(0xFF7C9C84), shape: BoxShape.circle),
                          child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: GoogleFonts.playfairDisplay(fontSize: 26, fontWeight: FontWeight.bold, color: textColorMain),
                    ),
                    Text(
                      specialty.toUpperCase(),
                      style: GoogleFonts.outfit(fontSize: 12, color: primaryGreen, fontWeight: FontWeight.w600, letterSpacing: 1.1),
                    ),
                    const SizedBox(height: 24),
                    // Large Centered "Edit Professional Profile" Button (Restored Design)
                    ElevatedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EditCounsellorProfileScreen())),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE3E8E4),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      ),
                      child: Text(
                        'Edit Professional Profile',
                        style: GoogleFonts.outfit(color: primaryGreen, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
                
                const SizedBox(height: 48),

                // MANAGEMENT TOOLS Group
                _buildGroupHeader('PRACTICE TOOLS'),
                const SizedBox(height: 16),
                _buildSectionContainer([
                  _buildListTile(Icons.calendar_month_rounded, 'Schedule Management', 'Setup your booking slots', () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const CounsellorAvailabilityManagement()));
                  }),
                  const Divider(height: 1, indent: 60),
                  _buildListTile(Icons.history_rounded, 'Clinical History', 'View completed consultations', () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SessionHistoryScreen()));
                  }),
                ]),

                const SizedBox(height: 32),
                
                // STATUS Group
                _buildGroupHeader('ACCOUNT & STATUS'),
                const SizedBox(height: 16),
                _buildSectionContainer([
                  _buildListTile(
                    Icons.no_accounts_outlined, 
                    'Retire / Deactivate Profile', 
                    'Send formal retirement request for review', 
                    () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CounsellorDeactivationScreen())),
                    isWarning: true,
                  ),
                ]),

                const SizedBox(height: 48),

                // Logout Action
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: () => _showLogoutDialog(context),
                    icon: const Icon(Icons.logout_rounded, color: Color(0xFFFF8A8A)),
                    label: Text(
                      'Log Out',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFFFF8A8A)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFFCDCD)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      backgroundColor: const Color(0xFFFFF5F5),
                    ),
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

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Log Out', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to log out from your expert session?', style: GoogleFonts.outfit()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey))),
          TextButton(onPressed: () => FirebaseAuth.instance.signOut(), child: Text('Log Out', style: GoogleFonts.outfit(color: Colors.red))),
        ],
      ),
    );
  }

  Widget _buildGroupHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: const Color(0xFFB0B0B0)),
      ),
    );
  }

  Widget _buildSectionContainer(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildListTile(IconData icon, String title, String subtitle, VoidCallback onTap, {bool isWarning = false}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isWarning ? const Color(0xFFFFF5F5) : const Color(0xFFF5F7F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: isWarning ? Colors.red[400] : primaryGreen, size: 22),
      ),
      title: Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: isWarning ? Colors.red[400] : textColorMain)),
      subtitle: Text(subtitle, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[500])),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
      onTap: onTap,
    );
  }
}
