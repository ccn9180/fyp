import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/gamification_service.dart';
import 'reward_store.dart';
import 'daily_tasks.dart';
import 'badges_screen.dart';

class XPJourneyScreen extends StatefulWidget {
  const XPJourneyScreen({super.key});

  @override
  State<XPJourneyScreen> createState() => _XPJourneyScreenState();
}

class _XPJourneyScreenState extends State<XPJourneyScreen> {
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFF2F1EC);
  final Color accentGold = const Color(0xFFFFD700);

  final String? uid = FirebaseAuth.instance.currentUser?.uid;
  int _selectedTab = 0; // 0 = Badges, 1 = My Vouchers

  // ── Cached state (populated once from Firestore streams) ─────────────────
  // User data
  bool _userLoaded = false;
  int _xp = 0;
  int _level = 1;
  int _streak = 0;
  int _coins = 0;
  List<dynamic> _earnedBadgeIds = [];
  List<dynamic> _redeemedRewardIds = [];

  // Badge catalogue (from 'badges' collection)
  bool _badgesLoaded = false;
  List<Map<String, dynamic>> _badgeDocs = [];

  // Voucher catalogue (from 'rewards' collection)
  bool _rewardsLoaded = false;
  List<Map<String, dynamic>> _rewardDocs = [];

  // Daily tasks
  bool _tasksLoaded = false;
  List<Map<String, dynamic>> _dailyTasks = [];
  Set<String> _completedTaskDocIds = {};

  // Stream subscriptions
  StreamSubscription<DocumentSnapshot>? _userSub;
  StreamSubscription<QuerySnapshot>? _badgesSub;
  StreamSubscription<QuerySnapshot>? _rewardsSub;
  StreamSubscription<QuerySnapshot>? _tasksSub;
  StreamSubscription<QuerySnapshot>? _userTasksSub;

  @override
  void initState() {
    super.initState();
    _subscribeStreams();
  }

  void _subscribeStreams() {
    if (uid == null) return;

    // User document
    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          _xp = (data['xp'] ?? 0) as int;
          _level = (data['level'] ?? 1) as int;
          _streak = (data['streak_days'] ?? 0) as int;
          _coins = (data['coins'] ?? 0) as int;
          _earnedBadgeIds = List<dynamic>.from(data['badges'] ?? []);
          _redeemedRewardIds = List<dynamic>.from(data['redeemed_rewards'] ?? []);
          _userLoaded = true;
        });
      }
    });

    // Badge catalogue — subscribe once, cache docs
    _badgesSub = FirebaseFirestore.instance
        .collection('badges')
        .snapshots()
        .listen((snap) {
      if (mounted) {
        setState(() {
          _badgeDocs = snap.docs
              .map((d) => {...(d.data() as Map<String, dynamic>), 'id': d.id})
              .toList();
          _badgesLoaded = true;
        });
      }
    });

    // Rewards catalogue
    _rewardsSub = FirebaseFirestore.instance
        .collection('rewards')
        .snapshots()
        .listen((snap) {
      if (mounted) {
        setState(() {
          _rewardDocs = snap.docs
              .map((d) => {...(d.data() as Map<String, dynamic>), 'id': d.id})
              .toList();
          _rewardsLoaded = true;
        });
      }
    });

    // Daily tasks
    _tasksSub = FirebaseFirestore.instance
        .collection('tasks')
        .snapshots()
        .listen((snap) {
      if (mounted) {
        setState(() {
          _dailyTasks = snap.docs
              .map((d) => {...(d.data() as Map<String, dynamic>), 'id': d.id})
              .where((t) => (t['frequency'] ?? 'daily') == 'daily')
              .toList();
          _tasksLoaded = true;
        });
      }
    });

    // Completed tasks subscription
    _userTasksSub = FirebaseFirestore.instance
        .collection('user_tasks')
        .where('user_id', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      if (mounted) {
        setState(() {
          _completedTaskDocIds = snap.docs.map((d) => d.id).toSet();
        });
      }
    });
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _badgesSub?.cancel();
    _rewardsSub?.cancel();
    _tasksSub?.cancel();
    _userTasksSub?.cancel();
    super.dispose();
  }

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
      case 'mood':
        return Icons.mood_rounded;
      case 'journal':
      case 'diary':
        return Icons.edit_note_rounded;
      case 'chat':
      case 'chatbot':
        return Icons.forum_rounded;
      case 'water':
        return Icons.local_drink_rounded;
      case 'sleep':
        return Icons.bedtime_rounded;
      default:
        return Icons.stars_rounded;
    }
  }

  int _calculateLifetimeXP(int currentLevel, int currentXP) {
    int total = 0;
    for (int l = 1; l < currentLevel; l++) {
      total += GamificationService.xpRequiredForLevel(l);
    }
    total += currentXP;
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Please log in.')));
    }

    // Show a one-time splash only on the very first load before any data arrives.
    if (!_userLoaded) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final int xpRequired = GamificationService.xpRequiredForLevel(_level);
    final String levelName = GamificationService.getLevelName(_level);
    final int lifetimeXP = _calculateLifetimeXP(_level, _xp);
    final double progress = (_xp / xpRequired).clamp(0.0, 1.0);

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
          'WELLNESS HUB',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: const Color(0xFF333333),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.redeem_rounded, color: Color(0xFF333333), size: 22),
            tooltip: 'Reward Store',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RewardStoreScreen()),
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          children: [
            _buildXPProgressHeader(_level, levelName, _xp, xpRequired, progress, _earnedBadgeIds.length, _streak, lifetimeXP, _coins),
            const SizedBox(height: 24),

            // Tasks for Today (Daily Quests only)
            _buildTodayTasks(),
            const SizedBox(height: 32),

            // Badge & Voucher tabs area
            _buildPillSelector(),
            const SizedBox(height: 16),

            _selectedTab == 0
                ? _buildBadgesPreviewTab()
                : _buildVouchersPreviewTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildXPProgressHeader(
    int level,
    String levelName,
    int xp,
    int xpRequired,
    double progress,
    int badgesCount,
    int streak,
    int lifetimeXP,
    int coins,
  ) {
    final growth = GamificationService.getGrowthStage(level);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level $level',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    Text(
                      levelName,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: primaryGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C9C84).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  growth['emoji'] ?? '🌱',
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$xp / $xpRequired XP',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              Text(
                '${xpRequired - xp} XP to Level ${level + 1}',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: const Color(0xFFF0F0F0),
              valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(badgesCount.toString(), 'Badges'),
              Container(width: 1, height: 30, color: Colors.grey[200]),
              _buildStatItem('$streak🔥', 'Streak'),
              Container(width: 1, height: 30, color: Colors.grey[200]),
              _buildStatItem('$coins🪙', 'Coins'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String val, String label) {
    return Column(
      children: [
        Text(
          val,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF333333),
          ),
        ),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewSection({
    required String title,
    String? subtitle,
    required IconData icon,
    required VoidCallback onTapViewAll,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: primaryGreen, size: 22),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF333333),
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              InkWell(
                onTap: onTapViewAll,
                child: Text('View All', style: GoogleFonts.outfit(color: primaryGreen, fontWeight: FontWeight.bold, fontSize: 12)),
              )
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // Active Quests (Daily Quests only) — driven by cached _dailyTasks
  Widget _buildTodayTasks() {
    if (!_tasksLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    // Filter, map and determine completion for the cached daily tasks list
    final List<Map<String, dynamic>> daily = _dailyTasks.map((task) {
      final taskId = task['id'] ?? '';
      final expectedDocId = '${uid}_${taskId}_$todayStr';
      final isCompleted = _completedTaskDocIds.contains(expectedDocId);
      return {...task, 'isCompleted': isCompleted};
    }).toList();

    return Column(
      children: [
        _buildPreviewSection(
          title: "Tasks for Today",
          subtitle: "This is task for today",
          icon: Icons.task_alt_rounded,
          onTapViewAll: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DailyTasksScreen(initialTab: 0)),
          ),
          child: daily.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        color: primaryGreen.withOpacity(0.4),
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'All caught up!',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No tasks scheduled for today. Take a moment to relax!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: daily.map((task) => _buildTaskRow(task)).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildTaskRow(Map<String, dynamic> task) {
    final bool isCompleted = task['isCompleted'] ?? false;
    final bool isWeekly = (task['frequency'] ?? 'daily') == 'weekly';

    final Color taskColor = isCompleted ? Colors.grey[400]! : primaryGreen;
    final Color bgColor = isCompleted ? Colors.grey[100]! : primaryGreen.withOpacity(0.1);
    final Color textColor = isCompleted ? Colors.grey[400]! : const Color(0xFF333333);
    final Color rewardBgColor = isCompleted
        ? Colors.grey[100]!
        : (isWeekly ? Colors.orange.withOpacity(0.1) : primaryGreen.withOpacity(0.1));
    final Color rewardTextColor = isCompleted
        ? Colors.grey[400]!
        : (isWeekly ? Colors.orange : primaryGreen);

    return InkWell(
      onTap: () => _showTaskHistory(task),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(
                isCompleted ? Icons.check_circle_rounded : _getIconData(task['icon']),
                color: taskColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task['title'] ?? 'Task',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: rewardBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '+${task['xp_reward']} XP',
                style: GoogleFonts.outfit(
                  color: rewardTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTaskHistory(Map<String, dynamic> task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bool isCompleted = task['isCompleted'] ?? false;
        return DraggableScrollableSheet(
          initialChildSize: 0.45,
          maxChildSize: 0.75,
          minChildSize: 0.3,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag indicator & Close
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primaryGreen.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getIconData(task['icon']),
                          color: primaryGreen,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task['title'] ?? 'Task Details',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF333333),
                              ),
                            ),
                            Text(
                              (task['frequency'] ?? 'daily').toString().toUpperCase() + ' QUEST',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: primaryGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    task['description'] ?? 'Engage in this wellbeing activity to clear your mind, earn XP, and unlock rewards in your Wellness Hub.',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      _buildMetricCard(
                        icon: Icons.auto_graph_rounded,
                        color: primaryGreen,
                        value: '+${task['xp_reward']} XP',
                        label: 'XP Reward',
                      ),
                      const SizedBox(width: 12),
                      _buildMetricCard(
                        icon: Icons.check_circle_rounded,
                        color: isCompleted ? primaryGreen : Colors.orange,
                        value: isCompleted ? 'Completed' : 'Active',
                        label: 'Status',
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 2),
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
    );
  }

  Widget _buildPillSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: primaryGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildPillButton(
              label: 'Badges',
              isSelected: _selectedTab == 0,
              onTap: () => setState(() => _selectedTab = 0),
            ),
          ),
          Expanded(
            child: _buildPillButton(
              label: 'My Vouchers',
              isSelected: _selectedTab == 1,
              onTap: () => setState(() => _selectedTab = 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadgesPreviewTab() {
    // Build the sorted list from cached state — no StreamBuilder needed.
    // Determine isUnlocked only once BOTH badge catalogue AND user data are ready.
    final bool dataReady = _badgesLoaded && _userLoaded;

    final List<Map<String, dynamic>> items = [];
    if (dataReady && _badgeDocs.isNotEmpty) {
      final unlocked = _badgeDocs
          .where((b) => _earnedBadgeIds.contains(b['id']))
          .map((b) => {...b, 'isUnlocked': true})
          .toList();
      final locked = _badgeDocs
          .where((b) => !_earnedBadgeIds.contains(b['id']))
          .map((b) => {...b, 'isUnlocked': false})
          .toList();
      items.addAll(unlocked);
      items.addAll(locked);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Journey Badges',
                style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BadgesScreen())),
                child: Text(
                  'View All',
                  style: GoogleFonts.outfit(fontSize: 12, color: primaryGreen, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Show skeleton circles while data is loading; real badges once ready.
          if (!dataReady)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(3, (_) => _buildBadgeSkeleton()),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: items.take(3).map((badge) {
                final bool isUnlocked = badge['isUnlocked'] as bool? ?? false;
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: isUnlocked
                            ? const LinearGradient(
                                colors: [Color(0xFF7C9C84), Color(0xFF5B7563)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isUnlocked ? null : Colors.grey[200],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: isUnlocked
                            ? [BoxShadow(color: primaryGreen.withOpacity(0.3), blurRadius: 8)]
                            : [],
                      ),
                      child: Icon(
                        isUnlocked ? _getIconData(badge['icon'] as String?) : Icons.lock_outline_rounded,
                        color: isUnlocked ? Colors.white : Colors.grey[400],
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 70,
                      child: Text(
                        badge['name'] as String? ?? '',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isUnlocked ? const Color(0xFF333333) : Colors.grey[400],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  /// Grey skeleton circle shown while badge data is loading.
  Widget _buildBadgeSkeleton() {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 50,
          height: 10,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(5),
          ),
        ),
      ],
    );
  }

  Widget _buildVouchersPreviewTab() {
    // Build voucher list from cached state — no StreamBuilder.
    final List<Map<String, dynamic>> vouchers = _rewardsLoaded
        ? _rewardDocs.where((r) => _redeemedRewardIds.contains(r['id'])).toList()
        : [];

    if (_userLoaded && _redeemedRewardIds.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.confirmation_number_outlined, size: 40, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(
                'No vouchers claimed yet.',
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Redeem your hard-earned coins in the Store!',
                style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      );
    }

    // Show skeleton card while rewards catalogue is still loading
    if (!_rewardsLoaded || vouchers.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 100, height: 16, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 16),
            ...List.generate(2, (_) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle)),
                  const SizedBox(width: 12),
                  Expanded(child: Container(height: 14, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(7)))),
                ],
              ),
            )),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Vouchers',
            style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: vouchers.length,
            itemBuilder: (context, index) {
              final voucher = vouchers[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryGreen.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.confirmation_number_rounded, color: primaryGreen, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            voucher['name'] as String? ?? 'Premium Reward',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: const Color(0xFF333333),
                            ),
                          ),
                          Text(
                            'Active • Valid for 30 days',
                            style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'ACTIVE',
                        style: GoogleFonts.outfit(
                          color: primaryGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

