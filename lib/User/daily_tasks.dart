import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/gamification_service.dart';
import '../widgets/level_up_dialog.dart';
import 'active_chat.dart';
import 'add_diary.dart';
import 'selfHelp.dart';

import 'xp_history_screen.dart';
import 'main_screen.dart';

class DailyTasksScreen extends StatefulWidget {
  final int initialTab;
  const DailyTasksScreen({super.key, this.initialTab = 0});

  @override
  State<DailyTasksScreen> createState() => _DailyTasksScreenState();
}

class _DailyTasksScreenState extends State<DailyTasksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFF2F1EC);
  final Color accentGold = const Color(0xFFFFD700);

  final String? uid = FirebaseAuth.instance.currentUser?.uid;



  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  IconData _getIconData(String? iconName) {
    switch (iconName?.toLowerCase()) {
      case 'mood':
        return Icons.mood_rounded;
      case 'breathing':
      case 'meditation':
        return Icons.self_improvement_rounded;
      case 'journal':
      case 'diary':
        return Icons.edit_note_rounded;
      case 'chat':
      case 'chatbot':
        return Icons.forum_rounded;
      case 'community':
      case 'social':
        return Icons.people_alt_rounded;
      case 'water':
        return Icons.local_drink_rounded;
      case 'sleep':
        return Icons.bedtime_rounded;
      case 'exercise':
      case 'walk':
        return Icons.directions_run_rounded;
      default:
        return Icons.assignment_turned_in_rounded;
    }
  }

  void _onTaskAction(Map<String, dynamic> task, String taskId, bool isCompleted) async {
    if (isCompleted) return;

    final String taskType = task['task_type'] ?? '';
    final String title = task['title'] ?? 'Task';
    final int xpReward = task['xp_reward'] ?? 0;
    final int coinReward = task['coin_reward'] ?? 0;

    // Show a clean bottom sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFFFAF9F6),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag indicator & Close Row
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
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryGreen.withOpacity(0.12),
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
                        title,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 2),
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
            const SizedBox(height: 20),
            Text(
              task['description'] ?? 'Complete this activity to earn mental wellbeing rewards.',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            // Metrics row showing XP and Coin rewards
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2EB),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: primaryGreen.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.auto_graph_rounded, color: primaryGreen, size: 20),
                        const SizedBox(height: 12),
                        Text(
                          '+$xpReward XP',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2E3D32),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'XP Reward',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (coinReward > 0) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF9E6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFFF2CC)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.monetization_on_rounded, color: Color(0xFFB58A3D), size: 20),
                          const SizedBox(height: 12),
                          Text(
                            '+$coinReward Coins',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF4A3E25),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Coin Reward',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primaryGreen),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.outfit(
                        color: primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _executeTask(taskId, taskType, title);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(
                      _getActionText(taskType),
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  String _getActionText(String taskType) {
    switch (taskType) {
      case 'mood':
        return 'Go to Home';
      case 'journal':
      case 'diary':
        return 'Write Entry';
      case 'chat':
      case 'chatbot':
        return 'Chat with Bot';
      case 'meditation':
        return 'Meditate';
      default:
        return 'Complete Task';
    }
  }

  void _executeTask(String taskId, String taskType, String title) async {
    if (uid == null) return;

    // For tasks that can be completed directly
    if (taskType != 'journal' && taskType != 'chat' && taskType != 'mood' && taskType != 'meditation') {
      _triggerCompletion(taskId);
      return;
    }

    // For specific task types, we guide the user to the feature
    if (taskType == 'mood') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perform mood check-in on the Home screen to complete!'),
          backgroundColor: Color(0xFF7C9C84),
        ),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
        (route) => false,
      );
    } else if (taskType == 'journal') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AddDiaryScreen()),
      );
    } else if (taskType == 'chat' || taskType == 'chatbot') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ActiveChatScreen()),
      );
    } else if (taskType == 'meditation') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SelfHelpScreen()),
      );
    }
  }

  void _triggerCompletion(String taskId) async {
    if (uid == null) return;
    
    final result = await GamificationService.completeTask(uid!, taskId);
    if (!mounted) return;

    if (result['success'] == true) {
      // Show reward notification dialog
      _showRewardDialog(
        result['xp'] ?? 0,
        result['coins'] ?? 0,
        result['levelled_up'] ?? false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['reason'] ?? 'Failed to complete task'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showRewardDialog(int xp, int coins, bool levelledUp) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Reward',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
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
                  Text(
                    '🏆 TASK COMPLETED!',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Wonderful Progress!',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You are doing great on your wellness journey.',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildRewardPill('+$xp', 'XP', Icons.auto_graph_rounded),
                      _buildRewardPill('+$coins', 'COINS', Icons.monetization_on_rounded),
                    ],
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        if (levelledUp && uid != null) {
                          _showLevelUpDialog();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Text(
                        'Awesome',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRewardPill(String amount, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F1EC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: primaryGreen, size: 24),
          const SizedBox(height: 4),
          Text(
            amount,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF333333),
            ),
          ),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showLevelUpDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const LevelUpDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view tasks.')),
      );
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
          'DAILY & WEEKLY QUESTS',
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
            icon: const Icon(Icons.history_rounded, color: Color(0xFF333333), size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const XPHistoryScreen()),
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: GamificationService.userGamificationStream(uid!),
        builder: (context, userSnap) {
          final int coins = userSnap.data?['coins'] ?? 0;
          final int streak = userSnap.data?['streak_days'] ?? 0;

          return Column(
            children: [
              _buildHeaderCard(coins, streak),
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFE5E4DE), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD9D7CE).withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: primaryGreen,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey[600],
                  labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                  unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'DAILY TASKS'),
                    Tab(text: 'WEEKLY QUESTS'),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('tasks').snapshots(),
                  builder: (context, tasksSnap) {
                    if (tasksSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!tasksSnap.hasData || tasksSnap.data!.docs.isEmpty) {
                      return TabBarView(
                        controller: _tabController,
                        children: [
                          Center(child: Text('No daily tasks found', style: GoogleFonts.outfit(color: Colors.grey))),
                          Center(child: Text('No weekly tasks found', style: GoogleFonts.outfit(color: Colors.grey))),
                        ],
                      );
                    }

                    // Format dates for idempotent checking
                    final now = DateTime.now();
                    final todayStr = DateFormat('yyyy-MM-dd').format(now);
                    final weekNum = ((int.parse(DateFormat('D').format(now)) - now.weekday + 10) / 7).floor();
                    final weekStr = '${now.year}-W$weekNum';

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('user_tasks')
                          .where('user_id', isEqualTo: uid)
                          .snapshots(),
                      builder: (context, userTasksSnap) {
                        final completedDocIds = (userTasksSnap.data?.docs ?? [])
                            .map((doc) => doc.id)
                            .toSet();

                        final List<DocumentSnapshot> dailyTasks = [];
                        final List<DocumentSnapshot> weeklyTasks = [];

                        for (final doc in tasksSnap.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          final String freq = data['frequency'] ?? 'daily';
                          if (freq == 'weekly') {
                            weeklyTasks.add(doc);
                          } else {
                            dailyTasks.add(doc);
                          }
                        }

                        return TabBarView(
                          controller: _tabController,
                          children: [
                            _buildTaskList(dailyTasks, completedDocIds, todayStr, 'daily'),
                            _buildTaskList(weeklyTasks, completedDocIds, weekStr, 'weekly'),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(int coins, int streak) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          _buildHeaderStat('$streak Days', '🔥'),
          const SizedBox(width: 8),
          _buildHeaderStat('$coins Coins', '🪙'),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String label, String icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E4DE), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$icon ',
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2E3D32),
            ),
          ),
        ],
      ),
    );
  }

  /// Renders the list from Firestore documents
  Widget _buildTaskList(
    List<DocumentSnapshot> tasks,
    Set<String> completedDocIds,
    String periodKey,
    String frequency,
  ) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              frequency == 'weekly' ? 'No weekly quests yet.' : 'No daily tasks yet.',
              style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Check back soon — tasks will appear here.',
              style: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final taskDoc = tasks[index];
        final taskId = taskDoc.id;
        final task = taskDoc.data() as Map<String, dynamic>;

        // Idempotency check key format: uid_taskId_periodKey
        final expectedDocId = '${uid}_${taskId}_$periodKey';
        final isCompleted = completedDocIds.contains(expectedDocId);

        return _buildTaskCard(task, taskId, isCompleted);
      },
    );
  }

  /// Renders the hardcoded mock list (shown when Firestore has no tasks)
  Widget _buildTaskCard(Map<String, dynamic> task, String taskId, bool isCompleted) {
    final Color cardBg = isCompleted ? const Color(0xFFF9FAF8) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isCompleted ? primaryGreen.withOpacity(0.2) : const Color(0xFFE5E4DE),
          width: 1.5,
        ),
        boxShadow: isCompleted
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFFD9D7CE).withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                )
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          onTap: isCompleted ? null : () => _onTaskAction(task, taskId, isCompleted),
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                // Left Icon in styled circular container
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFFEBF2EE)
                        : const Color(0xFFF3F2EC),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCompleted ? Icons.check_circle_rounded : _getIconData(task['icon']),
                    color: primaryGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Middle Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task['title'] ?? 'Quest',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isCompleted ? Colors.grey[400] : const Color(0xFF2E2E2E),
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task['description'] ?? '',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: isCompleted ? Colors.grey[300] : Colors.grey[500],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Reward Tags Column or completed badge
                isCompleted
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEBF2EE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'DONE',
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: primaryGreen,
                            letterSpacing: 1,
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF2EB),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '+${task['xp_reward']} XP',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF5B7A63),
                              ),
                            ),
                          ),
                          if (task['coin_reward'] != null && task['coin_reward'] > 0) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF9E6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '+${task['coin_reward']} 🪙',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFB58A3D),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
