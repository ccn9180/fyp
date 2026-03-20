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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoggingOut = false;
  User? get currentUser => FirebaseAuth.instance.currentUser;

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
      backgroundColor: const Color(0xFFEAE9E4),
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
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
                    name = data['fullName'] ?? currentUser?.displayName ?? currentUser?.email ?? 'User';
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
                            width: 100,
                            height: 100,
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
                              size: 50,
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
                            child: const Icon(Icons.verified, color: Color(0xFF7C9C84), size: 20),
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

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.spa, color: Color(0xFF7C9C84), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'ZEN PROGRESS',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: const Color(0xFF1E2742),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Level 12',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF555555),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Peaceful Seeker',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '850',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF333333),
                              ),
                            ),
                            TextSpan(
                              text: ' / 1000 XP',
                              style: GoogleFonts.outfit(
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: const LinearProgressIndicator(
                      value: 0.85,
                      minHeight: 8,
                      backgroundColor: Color(0xFFF0F0F0),
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C9C84)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bar_chart_rounded, color: Colors.grey, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'MOOD STATS',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: const Color(0xFF1E2742),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '7 DAY AVG',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildBar(30, false),
                      _buildBar(45, false),
                      _buildBar(35, false),
                      _buildBar(65, true),
                      _buildBar(50, false),
                      _buildBar(55, false),
                      _buildBar(45, false),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ACHIEVEMENTS',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: const Color(0xFFB0B0B0),
                  ),
                ),
                Text(
                  'SEE ALL',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: const Color(0xFF7C9C84),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildAchievement(Icons.local_fire_department_rounded, true),
                _buildAchievement(Icons.self_improvement, false),
                _buildAchievement(Icons.groups_rounded, false),
                _buildAchievement(Icons.eco_rounded, false),
              ],
            ),

            const SizedBox(height: 30),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'ACCOUNT & SAFETY',
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
                  _buildListTile(Icons.admin_panel_settings_outlined, 'Account Management', 'Identity & Security', false),
                  const Divider(height: 1, indent: 60),
                  _buildListTile(Icons.calendar_month_outlined, 'Session History', null, false),
                  const Divider(height: 1, indent: 60),
                  _buildListTile(Icons.account_balance_wallet_outlined, 'Voucher Wallet', null, true),
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
                onPressed: _isLoggingOut ? null : _signOut,
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
            const SizedBox(height: 100),
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

  Widget _buildListTile(IconData icon, String title, String? subtitle, bool hasBadge) {
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
      onTap: () {},
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
                  color: Color(0xFFEAE9E4),
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
                color: Color(0xFFEAE9E4),
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

                        final name = userData['fullName'] ?? 'User';
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
            Navigator.pop(context);
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
            color: const Color(0xFFEAE9E4),
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
                'Are you sure you want to remove this connection? You won\'t be able to see their private updates.',
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
