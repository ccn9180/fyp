
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'counsellor_dashboard.dart';
import 'counsellor_profile.dart';
import 'counsellor_schedule.dart';
import 'counsellor_performance.dart';

class CounsellorMainScreen extends StatefulWidget {
  const CounsellorMainScreen({super.key});

  @override
  State<CounsellorMainScreen> createState() => _CounsellorMainScreenState();
}

class _CounsellorMainScreenState extends State<CounsellorMainScreen> {
  int _selectedIndex = 0; // Start on Dashboard for a fresh entry

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      CounsellorDashboardScreen(onTabChange: _onItemTapped),
      const CounsellorScheduleScreen(),
      const CounsellorPerformanceScreen(),
      CounsellorProfileScreen(onTabChange: _onItemTapped),
    ];
    _saveCurrentSide();
  }

  Future<void> _saveCurrentSide() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_used_side', 'counsellor');
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EC),
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
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.grid_view_rounded, Icons.grid_view_outlined, "Home"),
              _buildNavItem(1, Icons.calendar_month_rounded, Icons.calendar_month_outlined, "Sessions"),
              _buildNavItem(2, Icons.analytics_rounded, Icons.analytics_outlined, "Performance"),
              _buildNavItem(3, Icons.person_rounded, Icons.person_outline_rounded, "Profile"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      onLongPress: index == 3 ? () => _handleSwitchBack(context) : null,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSelected ? activeIcon : inactiveIcon,
            color: isSelected ? const Color(0xFF7C9C84) : const Color(0xFFBDBDBD),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? const Color(0xFF7C9C84) : const Color(0xFFBDBDBD),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSwitchBack(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: const BoxDecoration(
          color: Color(0xFFF2F1EC),
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
            _buildSwitchItem(
              title: "Counsellor Side (Current)",
              subtitle: "Manage your expert portal",
              icon: Icons.medical_services_outlined,
              isActive: true,
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 12),
            _buildSwitchItem(
              title: "User Side",
              subtitle: "Back to peaceful community",
              icon: Icons.person_outline_rounded,
              isActive: false,
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('last_used_side', 'user');
                if (mounted) {
                  Navigator.pop(context); 
                  Navigator.pop(context); 
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
