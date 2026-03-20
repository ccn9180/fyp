
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home.dart';
import 'community.dart';
import 'selfHelp.dart';
import 'counsellor.dart';
import 'profile.dart';
import '../Counsellor/counsellor_main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _isCounsellor = false;

  @override
  void initState() {
    super.initState();
    _checkCounsellorStatus();
  }

  Future<void> _checkCounsellorStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data()?['role'] == 'counsellor') {
        if (mounted) setState(() => _isCounsellor = true);
      }
    }
  }

  final List<Widget> _pages = [
    const HomeScreen(),
    const CounsellorScreen(),
    const CommunityScreen(),
    const SelfHelpScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: Color(0xFFEAE9E4),
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
    return Scaffold(
      backgroundColor: const Color(0xFFEAE9E4), // Light beige/cream background consistent with app theme
      extendBody: false, // Prevents body from extending behind the navbar
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, "Home"),
              _buildNavItem(1, Icons.medical_services_rounded, Icons.medical_services_outlined, "Counselor"),
              _buildNavItem(2, Icons.groups_rounded, Icons.groups_outlined, "Community", hasNotification: true),
              _buildNavItem(3, Icons.menu_book_rounded, Icons.menu_book_outlined, "Self-Help"),
              _buildNavItem(4, Icons.person_rounded, Icons.person_outline_rounded, "Profile"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label, {bool hasNotification = false}) {
    bool isSelected = _selectedIndex == index;
    final currentUser = FirebaseAuth.instance.currentUser;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      onLongPress: index == 4 ? _handleProfileLongPress : null,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                isSelected ? activeIcon : inactiveIcon,
                color: isSelected ? const Color(0xFF7C9C84) : const Color(0xFFBDBDBD),
                size: 26,
              ),
              if (hasNotification && currentUser != null)
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('notifications')
                      .where('to', isEqualTo: currentUser.uid)
                      .where('isRead', isEqualTo: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                      return Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? const Color(0xFF7C9C84) : const Color(0xFFBDBDBD),
            ),
          ),
        ],
      ),
    );
  }

  void _handleProfileLongPress() {
    if (!_isCounsellor) {
      // Logic for users who are NOT counselors
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Become a counselor to unlock the professional portal!'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Instagram style switch
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: const BoxDecoration(
          color: Color(0xFFEAE9E4),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Switch Account Side',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E2742),
              ),
            ),
            const SizedBox(height: 24),

            // Current User Account
            _buildSwitchItem(
              title: "User Side (Current)",
              subtitle: "Browse community & resources",
              icon: Icons.person_outline_rounded,
              isActive: true,
              onTap: () => Navigator.pop(context),
            ),

            const SizedBox(height: 12),

            _buildSwitchItem(
              title: "Counsellor Side",
              subtitle: "Manage your sessions",
              icon: Icons.medical_services_outlined,
              isActive: false,
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('last_used_side', 'counsellor');
                if (mounted) {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CounsellorMainScreen()),
                  );
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF7C9C84).withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive ? const Color(0xFF7C9C84) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isActive ? Colors.white : const Color(0xFFF5F7F6),
                shape: BoxShape.circle,
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
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF333333),
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
            if (isActive)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF7C9C84), size: 20),
          ],
        ),
      ),
    );
  }
}
