import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'public_profile.dart';
import '../UserAccount/login.dart';
import '../UserAccount/splash_screen.dart';
import 'edit_profile.dart';
import 'settings.dart';
import 'apply_counsellor.dart';
import 'session_history.dart';
import 'payment_history.dart';
import 'detailed_history_screen.dart';
import 'user_analytics.dart';
import 'xp_journey.dart';
import 'reward_store.dart';
import '../services/gamification_service.dart';
import 'mood_trend.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoggingOut = false;
  User? get currentUser => FirebaseAuth.instance.currentUser;
  final ScrollController _scrollController = ScrollController();

  void scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutBack,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    setState(() => _isLoggingOut = true);
    try {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SplashTransitionScreen(isLogout: true)),
              (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoggingOut = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging out: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Text(
          'Profile',
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFF333333),
            fontWeight: FontWeight.w600,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            color: const Color(0xFF333333),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 10),
        child: Column(
          children: [
            StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C9C84)),
                    );
                  }

                  String name = 'User';
                  String? profileImageUrl;
                  List<String> followersList = [];
                  List<String> followingList = [];
                  int followersCount = 0;
                  int followingCount = 0;

                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                    String? nickname = data['nickname'] as String?;
                    if (nickname != null && nickname.trim().isNotEmpty) {
                      name = nickname;
                    } else {
                      name = data['fullName'] ?? currentUser?.displayName ?? currentUser?.email ?? 'User';
                    }
                    profileImageUrl = data['profileImageUrl'];
                    followersList = List<String>.from(data['followers'] ?? []);
                    followingList = List<String>.from(data['following'] ?? []);
                    followersCount = followersList.length;
                    followingCount = followingList.length;
                  } else {
                    name = currentUser?.displayName ?? currentUser?.email ?? 'User';
                  }

                  return Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
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
                                ? const Icon(
                              Icons.person,
                              size: 65,
                              color: Color(0xFFBBCBC2),
                            )
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.verified, color: Color(0xFF7C9C84), size: 28),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        name,
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => _showFollowList(context, 'Followers'),
                            child: Column(
                              children: [
                                Text(
                                  '$followersCount',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: const Color(0xFF333333),
                                  ),
                                ),
                                Text(
                                  'Followers',
                                  style: GoogleFonts.outfit(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 32),
                          GestureDetector(
                            onTap: () => _showFollowList(context, 'Following'),
                            child: Column(
                              children: [
                                Text(
                                  '$followingCount',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: const Color(0xFF333333),
                                  ),
                                ),
                                Text(
                                  'Following',
                                  style: GoogleFonts.outfit(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }
            ),
            const SizedBox(height: 4),
            Text(
              'Mindful Member since 2023',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const EditProfileScreen()),
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
                'Edit Profile',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF7C9C84),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Unified "My Journey" Dashboard Card
            StreamBuilder<Map<String, dynamic>>(
              stream: GamificationService.userGamificationStream(currentUser?.uid ?? ''),
              builder: (context, gSnap) {
                final int xp = gSnap.data?['xp'] ?? 0;
                final int level = gSnap.data?['level'] ?? 1;
                final int streak = gSnap.data?['streak_days'] ?? 0;
                final int xpRequired = GamificationService.xpRequiredForLevel(level);
                final String levelName = GamificationService.getLevelName(level);
                final double progress = (xp / xpRequired).clamp(0.0, 1.0);

                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const XPJourneyScreen())),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: const Color(0xFF7C9C84).withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                              child: const Icon(Icons.auto_graph_rounded, color: Color(0xFF7C9C84), size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('My Journey', style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1E2742))),
                                  Text('Level $level • $levelName', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[500])),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 14),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Divider(height: 1),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('ZEN XP', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 6,
                                      backgroundColor: const Color(0xFFF0F0F0),
                                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C9C84)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 32),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('STREAK', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent, size: 20),
                                      const SizedBox(width: 8),
                                      Text('$streak Days', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF333333))),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }
            ),

            const SizedBox(height: 30),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'ACTIVE JOURNEY',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: const Color(0xFFB0B0B0),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  _buildListTile(Icons.calendar_month_outlined, 'Session History', 'View your past sessions', false, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SessionHistoryScreen()),
                    );
                  }),
                  const Divider(height: 1, indent: 60),
                  _buildListTile(Icons.receipt_long_outlined, 'Payment History', 'View your past transactions', false, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PaymentHistoryScreen()),
                    );
                  }),
                  const Divider(height: 1, indent: 60),
                  _buildListTile(Icons.auto_graph_rounded, 'Mood & Streak Calendar', 'Visualize your emotional trends', false, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MoodTrendScreen()),
                    );
                  }),
                ],
              ),
            ),



            const SizedBox(height: 30),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'REWARDS & VOUCHERS',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: const Color(0xFFB0B0B0),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                   _buildListTile(Icons.confirmation_num_outlined, 'My Vouchers', 'View and redeem your vouchers', false, () {
                    _showVouchersBottomSheet(context);
                  }),
                ],
              ),
            ),


            const SizedBox(height: 30),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'PROFESSIONAL',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: const Color(0xFFB0B0B0),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.work_outline_rounded, color: Color(0xFF7C9C84), size: 22),
                    ),
                    title: Text(
                      'Apply for Counselor',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    subtitle: Text(
                      'Join our platform as a professional',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ApplyCounsellorScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: _isLoggingOut ? null : () => _showLogoutDialog(context),
                icon: const Icon(Icons.logout_rounded, color: Color(0xFFFF8A8A)),
                label: Text(
                  'Log Out',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFFF8A8A),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFFCDCD)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  backgroundColor: const Color(0xFFFFF5F5),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        contentPadding: const EdgeInsets.all(32),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.logout_rounded, color: Color(0xFFFF8A8A), size: 64),
            const SizedBox(height: 24),
            Text('Log Out?', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF333333))),
            const SizedBox(height: 16),
            Text(
              'Are you sure you want to log out of your account?',
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
                      _signOut();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8A8A),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text('Log Out', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBar(double height, bool isActive) {
    return Container(
      width: 30,
      height: height,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF7C9C84) : const Color(0xFFF0F2F0),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildAchievement(IconData icon, bool isUnlocked) {
    return Container(
      width: 65,
      height: 65,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: isUnlocked ? const Color(0xFF7C9C84) : Colors.grey[400], size: 28),
    );
  }

  Widget _buildListTile(IconData icon, String title, String? subtitle, bool hasBadge, [VoidCallback? onTap]) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF7C9C84), size: 22),
      ),
      title: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF333333),
        ),
      ),
      subtitle: subtitle != null ? Text(
        subtitle,
        style: GoogleFonts.outfit(
          fontSize: 12,
          color: Colors.grey[500],
        ),
      ) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasBadge)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF7C9C84),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '3 NEW',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
        ],
      ),
      onTap: onTap ?? () {},
    );
  }

  void _showFollowList(BuildContext context, String title) {
    if (currentUser == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FollowListBottomSheet(
        title: title,
        targetUserId: currentUser!.uid,
        currentUserId: currentUser!.uid,
      ),
    );
  }

  void _showVouchersBottomSheet(BuildContext context) {
    if (currentUser == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: Color(0xFFF2F1EC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
        ),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 32),
            Text('MY VOUCHERS', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.grey)),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF7C9C84)));
                  }
                  final voucherIds = List<String>.from((userSnapshot.data?.data() as Map<String, dynamic>?)?['redeemed_rewards'] ?? []);
                  
                  if (voucherIds.isEmpty) {
                    return Center(
                      child: Text(
                        'You have not claimed any vouchers yet.',
                        style: GoogleFonts.outfit(color: Colors.grey[600]),
                      ),
                    );
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('rewards')
                        .where(FieldPath.documentId, whereIn: voucherIds)
                        .snapshots(),
                    builder: (context, rewardsSnapshot) {
                      if (rewardsSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Color(0xFF7C9C84)));
                      }

                      final vouchers = rewardsSnapshot.data?.docs.where((d) {
                        final data = d.data() as Map<String, dynamic>;
                        return data['category']?.toString().toLowerCase().contains('voucher') == true;
                      }).toList() ?? [];

                      if (vouchers.isEmpty) {
                        return Center(
                          child: Text(
                            'No vouchers available.',
                            style: GoogleFonts.outfit(color: Colors.grey[600]),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: vouchers.length,
                        itemBuilder: (context, index) {
                          final v = vouchers[index].data() as Map<String, dynamic>;
                          final title = v['name'] ?? 'Discount Voucher';
                          final desc = v['description'] ?? 'Valid for counseling sessions';
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7C9C84).withOpacity(0.1), 
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(Icons.local_offer_rounded, color: Color(0xFF7C9C84), size: 28),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(title, style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold)),
                                      Text(desc, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _FollowListBottomSheet extends StatefulWidget {
  final String title;
  final String targetUserId;
  final String currentUserId;

  const _FollowListBottomSheet({
    required this.title,
    required this.targetUserId,
    required this.currentUserId,
  });

  @override
  State<_FollowListBottomSheet> createState() => _FollowListBottomSheetState();
}

class _FollowListBottomSheetState extends State<_FollowListBottomSheet> {
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color textColorMain = const Color(0xFF333333);
  bool _isInitialLoading = true;
  final Map<String, Map<String, dynamic>> _loadedUsers = {};

  Future<void> _ensureUserLoaded(String uid) async {
    if (_loadedUsers.containsKey(uid)) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      data['uid'] = doc.id;
      if (mounted) {
        setState(() {
          _loadedUsers[uid] = data;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.targetUserId).snapshots(),
      builder: (context, targetSnapshot) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(widget.currentUserId).snapshots(),
          builder: (context, currentUserSnapshot) {
            if (targetSnapshot.connectionState == ConnectionState.waiting && !targetSnapshot.hasData) {
              return Container(
                height: 300,
                decoration: const BoxDecoration(
                  color: Color(0xFFF2F1EC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: const Center(child: CircularProgressIndicator(color: Color(0xFF7C9C84))),
              );
            }

            final targetData = targetSnapshot.data?.data() as Map<String, dynamic>?;
            final currentUserData = currentUserSnapshot.data?.data() as Map<String, dynamic>?;
            final currentUserFollowing = List<String>.from(currentUserData?['following'] ?? []);

            final List<String> userIds = List<String>.from(
                (widget.title == 'Following' ? (targetData?['following'] ?? []) : (targetData?['followers'] ?? [])));

            // Pre-load missing users
            for (var uid in userIds) {
              _ensureUserLoaded(uid);
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Color(0xFFF2F1EC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.title,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: userIds.isEmpty
                        ? Center(
                      child: Text(
                        'No ${widget.title.toLowerCase()} yet.',
                        style: GoogleFonts.outfit(color: Colors.grey),
                      ),
                    )
                        : ListView.builder(
                      itemCount: userIds.length,
                      itemBuilder: (context, index) {
                        final uid = userIds[index];
                        final userData = _loadedUsers[uid];

                        if (userData == null) {
                          return const SizedBox(height: 70, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                        }

                        final nickname = userData['nickname']?.toString().trim();
                        final name = (nickname != null && nickname.isNotEmpty)
                            ? nickname
                            : (userData['fullName'] ?? 'User');
                        final email = userData['email'] ?? '';
                        final profileImageUrl = userData['profileImageUrl'];
                        final isFollowing = currentUserFollowing.contains(uid);

                        return _buildUserTile(uid, name, email, profileImageUrl, isFollowing);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUserTile(String uid, String name, String email, String? profileImageUrl, bool isFollowing) {
    ImageProvider? imageProvider;
    if (profileImageUrl != null) {
      if (profileImageUrl.startsWith('data:image')) {
        imageProvider = MemoryImage(base64Decode(profileImageUrl.split(',').last));
      } else {
        imageProvider = NetworkImage(profileImageUrl);
      }
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('from', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
          .where('to', isEqualTo: uid)
          .where('type', isEqualTo: 'friend_request')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, requestSnapshot) {
        final isRequested = requestSnapshot.hasData && requestSnapshot.data!.docs.isNotEmpty;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PublicProfileScreen(
                  uid: uid,
                  initialData: {
                    'name': name,
                    'profileImageUrl': profileImageUrl,
                    'isFollowing': isFollowing,
                    'isRequested': isRequested,
                  },
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: primaryGreen.withOpacity(0.1),
                  backgroundImage: imageProvider,
                  child: imageProvider == null ? Icon(Icons.person, color: primaryGreen) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: textColorMain,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        email,
                        style: GoogleFonts.outfit(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isFollowing)
                  IconButton(
                    icon: const Icon(Icons.person_remove_rounded, color: Color(0xFFE57373), size: 20),
                    onPressed: () {
                      _handleRequestAction(
                        context,
                        FirebaseAuth.instance.currentUser!.uid,
                        uid,
                        isFollowing,
                        isRequested,
                      );
                    },
                  )
                else
                  Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey[300], size: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

Future<void> _handleRequestAction(BuildContext context, String currentUserId, String targetUid, bool isFriends, bool isRequested) async {
  if (isFriends) {
    bool confirm = await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F1EC),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_remove_rounded,
                  color: Color(0xFFE57373),
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Unfriend User?',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to remove this connection?\n\nThis person is still your trusted recipient for safety alerts.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: const Color(0xFF666666),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Keep Friend',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF888888),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE57373),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Unfriend',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUserId).update({
        'following': FieldValue.arrayRemove([targetUid]),
        'followers': FieldValue.arrayRemove([targetUid])
      });
      await FirebaseFirestore.instance.collection('users').doc(targetUid).update({
        'following': FieldValue.arrayRemove([currentUserId]),
        'followers': FieldValue.arrayRemove([currentUserId])
      });
    } catch (e) {
      debugPrint("Error unfriending: $e");
    }
    return;
  }

  if (isRequested) {
    try {
      final query = await FirebaseFirestore.instance
          .collection('notifications')
          .where('from', isEqualTo: currentUserId)
          .where('to', isEqualTo: targetUid)
          .where('type', isEqualTo: 'friend_request')
          .where('status', isEqualTo: 'pending')
          .get();
      for (var doc in query.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint("Error canceling request: $e");
    }
  } else {
    try {
      final senderDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
      final senderData = senderDoc.data() as Map<String, dynamic>?;

      await FirebaseFirestore.instance.collection('notifications').add({
        'from': currentUserId,
        'to': targetUid,
        'type': 'friend_request',
        'status': 'pending',
        'isRead': false,
        'senderName': senderData?['fullName'] ?? 'Someone',
        'senderPhoto': senderData?['profileImageUrl'],
        'timestamp': FieldValue.serverTimestamp(),
        'message': '${senderData?['fullName'] ?? "Someone"} sent you a connection request.',
      });
    } catch (e) {
      debugPrint("Error sending request: $e");
    }
  }
}
