import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFF2F1EC);
  final String? uid = FirebaseAuth.instance.currentUser?.uid;

  IconData _getIconData(String? iconName) {
    switch (iconName?.toLowerCase()) {
      case 'directions_walk':
      case 'directions_walk_rounded':
        return Icons.directions_walk_rounded;
      case 'calendar_month':
      case 'calendar_month_rounded':
        return Icons.calendar_month_rounded;
      case 'hearing':
      case 'hearing_rounded':
        return Icons.hearing_rounded;
      case 'wb_sunny':
      case 'wb_sunny_rounded':
        return Icons.wb_sunny_rounded;
      case 'auto_awesome':
      case 'auto_awesome_rounded':
        return Icons.auto_awesome_rounded;
      case 'self_improvement':
      case 'self_improvement_rounded':
        return Icons.self_improvement_rounded;
      case 'people_alt':
      case 'people_alt_rounded':
        return Icons.people_alt_rounded;
      case 'local_fire_department':
      case 'local_fire_department_rounded':
        return Icons.local_fire_department_rounded;
      case 'psychology':
      case 'psychology_rounded':
        return Icons.psychology_rounded;
      default:
        return Icons.stars_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Please log in.')));
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF333333), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'BADGES & ACHIEVEMENTS',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: const Color(0xFF333333),
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());
          
          final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
          final List<dynamic> earnedBadges = userData['badges'] ?? [];

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('badges').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    'No achievement badges configured yet.',
                    style: GoogleFonts.outfit(color: Colors.grey),
                  ),
                );
              }

              final badgeDocs = snapshot.data!.docs;

              return GridView.builder(
                padding: const EdgeInsets.all(24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 24,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.7,
                ),
                itemCount: badgeDocs.length,
                itemBuilder: (context, index) {
                  final doc = badgeDocs[index];
                  final badgeId = doc.id;
                  final badge = doc.data() as Map<String, dynamic>;
                  final bool isUnlocked = earnedBadges.contains(badgeId);
                  final unlockTimes = userData['badge_unlock_times'] as Map<String, dynamic>? ?? {};
                  final unlockTimestamp = unlockTimes[badgeId] as Timestamp?;

                  return _buildBadgeCard(badge, isUnlocked, unlockTimestamp);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBadgeCard(Map<String, dynamic> badge, bool isUnlocked, Timestamp? unlockTimestamp) {
    String tier = badge['tier'] ?? 'Novice';
    
    Color tierColor;
    Gradient badgeGradient;
    
    switch (tier) {
      case 'Legendary':
        tierColor = const Color(0xFF9C4DCC);
        badgeGradient = const LinearGradient(colors: [Color(0xFF9C4DCC), Color(0xFF6A1B9A)], begin: Alignment.topLeft, end: Alignment.bottomRight);
        break;
      case 'Master':
        tierColor = const Color(0xFFFFA000);
        badgeGradient = const LinearGradient(colors: [Color(0xFFFFA000), Color(0xFFFF6F00)], begin: Alignment.topLeft, end: Alignment.bottomRight);
        break;
      case 'Adept':
        tierColor = primaryGreen;
        badgeGradient = LinearGradient(colors: [Color(0xFF7C9C84), Color(0xFF5B7563)], begin: Alignment.topLeft, end: Alignment.bottomRight);
        break;
      default: // Novice
        tierColor = const Color(0xFF90A4AE);
        badgeGradient = const LinearGradient(colors: [Color(0xFF90A4AE), Color(0xFF607D8B)], begin: Alignment.topLeft, end: Alignment.bottomRight);
    }

    final iconData = _getIconData(badge['icon']);

    return GestureDetector(
      onTap: () => _showBadgeDetails(badge, isUnlocked, tierColor, badgeGradient, unlockTimestamp),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              if (isUnlocked)
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: tierColor.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                ),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: isUnlocked ? badgeGradient : null,
                  color: isUnlocked ? null : Colors.grey[200],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isUnlocked ? Colors.white : Colors.grey[300]!,
                    width: 3,
                  ),
                ),
                child: Center(
                  child: Icon(
                    iconData,
                    color: isUnlocked ? Colors.white : Colors.grey[400],
                    size: 36,
                  ),
                ),
              ),
              if (!isUnlocked)
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(Icons.lock_outline_rounded, color: Colors.grey[400], size: 20),
                  ),
                ),
              Positioned(
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isUnlocked ? tierColor : Colors.grey[400],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    tier.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            badge['name'] ?? 'Badge',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isUnlocked ? const Color(0xFF333333) : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  void _showBadgeDetails(Map<String, dynamic> badge, bool isUnlocked, Color tierColor, Gradient gradient, Timestamp? unlockTimestamp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(32, 32, 32, MediaQuery.of(context).padding.bottom + 32),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 32),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: isUnlocked ? gradient : null,
                color: isUnlocked ? null : Colors.grey[200],
                shape: BoxShape.circle,
                boxShadow: isUnlocked ? [
                  BoxShadow(color: tierColor.withOpacity(0.4), blurRadius: 25, offset: const Offset(0, 10))
                ] : [],
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: Center(
                child: Icon(
                  _getIconData(badge['icon']),
                  color: isUnlocked ? Colors.white : Colors.grey[400],
                  size: 56,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              badge['name'] ?? 'Badge',
              style: GoogleFonts.playfairDisplay(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF333333)),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: tierColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${badge['tier'] ?? 'Novice'} Achievement'.toUpperCase(),
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: tierColor, letterSpacing: 1),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              badge['description'] ?? '',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isUnlocked ? Icons.verified_rounded : Icons.pending_actions_rounded,
                        color: isUnlocked ? primaryGreen : Colors.amber,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isUnlocked ? 'Requirement Satisfied' : 'Work in Progress',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.grey[800]),
                      ),
                    ],
                  ),
                  if (!isUnlocked) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Requires ${badge['condition_value'] ?? 0} ${badge['condition_type'] == 'level' ? 'Levels' : badge['condition_type'] == 'streak' ? 'Streak Days' : 'XP'}',
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: tierColor),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    Text(
                      unlockTimestamp != null 
                        ? 'Earned on ${DateFormat('MMM d, yyyy h:mm a').format(unlockTimestamp.toDate())}' 
                        : 'Unlocked & active on your profile!',
                      style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[500]),
                    ),
                  ],
                ],
              ),
            ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
