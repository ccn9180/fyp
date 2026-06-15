import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class GamificationService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ─────────────────────────────────────────────────────────────
  // LEVEL FORMULA  →  required_xp = level * 100 + (level-1) * 50
  // ─────────────────────────────────────────────────────────────
  static int xpRequiredForLevel(int level) => level * 100 + (level - 1) * 50;

  static String getLevelName(int level) {
    const names = [
      '',                  // 0 (unused)
      'Seed Seeker',       // 1
      'Gentle Wanderer',   // 2
      'Quiet Grower',      // 3
      'Steady Explorer',   // 4
      'Mindful Traveller', // 5
      'Calm Keeper',       // 6
      'Peaceful Seeker',   // 7
      'Inner Gardener',    // 8
      'Soul Nurturer',     // 9
      'Balanced Bloomer',  // 10
      'Deep Rooted',       // 11
      'Silent Sage',       // 12
      'Wise Wanderer',     // 13
      'Healing Heart',     // 14
      'Light Bearer',      // 15
      'Serene Guide',      // 16
      'Lotus Walker',      // 17
      'Eternal Grower',    // 18
      'Zenith Keeper',     // 19
      'Eunoia Master',     // 20
    ];
    if (level < 1) return 'Seed Seeker';
    if (level >= names.length) return 'Eunoia Master';
    return names[level];
  }

  /// Growth stage emoji + label for wellness journey visualization
  static Map<String, String> getGrowthStage(int level) {
    if (level <= 2)  return {'emoji': '🌱', 'label': 'Seed',     'stage': 'seed'};
    if (level <= 5)  return {'emoji': '🌿', 'label': 'Growing',  'stage': 'growing'};
    if (level <= 9)  return {'emoji': '🌸', 'label': 'Blooming', 'stage': 'blooming'};
    if (level <= 14) return {'emoji': '🌳', 'label': 'Balanced', 'stage': 'balanced'};
    return               {'emoji': '✨', 'label': 'Radiant',  'stage': 'radiant'};
  }

  // ─────────────────────────────────────────────────────────────
  // INITIALISE user gamification fields on first login
  // ─────────────────────────────────────────────────────────────
  static Future<void> initUserGamification(String uid) async {
    final ref = _db.collection('users').doc(uid);
    final snap = await ref.get();
    if (!snap.exists) return;

    final data = snap.data()!;
    final updates = <String, dynamic>{};

    if (!data.containsKey('xp'))           updates['xp']           = 0;
    if (!data.containsKey('level'))        updates['level']        = 1;
    if (!data.containsKey('coins'))        updates['coins']        = 0;
    if (!data.containsKey('streak_days'))  updates['streak_days']  = 0;
    if (!data.containsKey('badges'))       updates['badges']       = [];
    if (!data.containsKey('redeemed_rewards')) updates['redeemed_rewards'] = [];
    if (!data.containsKey('last_active_date')) {
      updates['last_active_date'] = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 1)),
      );
    }

    if (updates.isNotEmpty) await ref.update(updates);
  }

  // ─────────────────────────────────────────────────────────────
  // STREAK  — call when a user records their daily mood
  // ─────────────────────────────────────────────────────────────
  static Future<bool> updateStreak(String uid) async {
    final ref  = _db.collection('users').doc(uid);
    final snap = await ref.get();
    if (!snap.exists) return false;

    final data      = snap.data()!;
    final now       = DateTime.now();
    final todayStr  = DateFormat('yyyy-MM-dd').format(now);
    final lastRaw   = data['last_active_date'];
    DateTime? lastActive;
    if (lastRaw is Timestamp) lastActive = lastRaw.toDate();

    final lastStr = lastActive != null
        ? DateFormat('yyyy-MM-dd').format(lastActive)
        : '';

    if (lastStr == todayStr) return false; // already updated today

    int streak = (data['streak_days'] ?? 0) as int;
    final yesterday = DateFormat('yyyy-MM-dd')
        .format(now.subtract(const Duration(days: 1)));

    if (lastStr == yesterday) {
      streak += 1;          // consecutive day
    } else {
      streak = 1;           // gap — restart gently (no punishment text)
    }

    await ref.update({
      'streak_days':      streak,
      'last_active_date': Timestamp.fromDate(now),
    });

    // Daily login XP (fetch dynamically)
    int loginXp = 5; // fallback
    try {
      final ruleSnap = await _db.collection('xp_rules').where('action', isEqualTo: 'Daily Login Streak').limit(1).get();
      if (ruleSnap.docs.isNotEmpty) {
        loginXp = (ruleSnap.docs.first.data()['xp'] ?? 5) as int;
      }
    } catch (e) {
      print("Error fetching daily login xp: $e");
    }
    await awardXP(uid, loginXp, 'Daily Mood Check-in Streak', coinsToAdd: 2);

    // Check streak badges
    await checkAndUnlockBadges(uid);
    return true;
  }

  // ─────────────────────────────────────────────────────────────
  // AWARD XP  (and optional coins)
  // Returns true if user levelled up
  // ─────────────────────────────────────────────────────────────
  static Future<bool> awardXP(
    String uid,
    int xpAmount,
    String source, {
    int coinsToAdd = 0,
  }) async {
    final ref  = _db.collection('users').doc(uid);
    final snap = await ref.get();
    if (!snap.exists) return false;

    final data    = snap.data()!;
    int currentXP = (data['xp'] ?? 0) as int;
    int level     = (data['level'] ?? 1) as int;
    int coins     = (data['coins'] ?? 0) as int;

    currentXP += xpAmount;
    coins     += coinsToAdd;
    bool levelledUp = false;

    // Level-up loop (can level up multiple times)
    while (currentXP >= xpRequiredForLevel(level)) {
      currentXP -= xpRequiredForLevel(level);
      level     += 1;
      levelledUp = true;
    }

    await ref.update({
      'xp':     currentXP,
      'level':  level,
      'coins':  coins,
    });

    // Log entry
    await _db
        .collection('xp_logs')
        .doc(uid)
        .collection('entries')
        .add({
      'source':    source,
      'xp':        xpAmount,
      'coins':     coinsToAdd,
      'earned_at': FieldValue.serverTimestamp(),
    });

    return levelledUp;
  }

  // ─────────────────────────────────────────────────────────────
  // AWARD XP FROM RULE (Generic implicit actions)
  // ─────────────────────────────────────────────────────────────
  static Future<bool> awardXPFromAction(String uid, String actionName, {int fallbackCoins = 0}) async {
    int xpAmount = 0;
    try {
      final snap = await _db.collection('xp_rules').where('action', isEqualTo: actionName).limit(1).get();
      if (snap.docs.isNotEmpty) {
        xpAmount = (snap.docs.first.data()['xp'] ?? 0) as int;
      }
    } catch (e) {
      print("Error fetching XP rule for $actionName: $e");
    }

    if (xpAmount > 0 || fallbackCoins > 0) {
      return await awardXP(uid, xpAmount, actionName, coinsToAdd: fallbackCoins);
    }
    return false;
  }

  // ─────────────────────────────────────────────────────────────
  // COMPLETE TASK  — idempotent per day (or week for weekly tasks)
  // ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> completeTask(
    String uid,
    String taskId,
  ) async {
    // Fetch task definition
    final taskSnap = await _db.collection('tasks').doc(taskId).get();
    if (!taskSnap.exists) {
      return {'success': false, 'reason': 'Task not found'};
    }
    final task      = taskSnap.data()!;
    final frequency = task['frequency'] ?? 'daily';
    final xpReward  = (task['xp_reward']   ?? 10) as int;
    final coinReward= (task['coin_reward']  ?? 5)  as int;

    // Build idempotent document ID: uid_taskId_YYYY-MM-DD (daily) or uid_taskId_YYYY-Www (weekly)
    final now      = DateTime.now();
    final periodKey = frequency == 'weekly'
        ? '${now.year}-W${_weekNumber(now)}'
        : DateFormat('yyyy-MM-dd').format(now);
    final logDocId  = '${uid}_${taskId}_$periodKey';

    final logRef = _db.collection('user_tasks').doc(logDocId);
    final logSnap = await logRef.get();
    if (logSnap.exists) {
      return {'success': false, 'reason': 'Already completed'};
    }

    // Mark completed
    await logRef.set({
      'user_id':       uid,
      'task_id':       taskId,
      'task_title':    task['title'] ?? '',
      'completed_at':  FieldValue.serverTimestamp(),
      'xp_awarded':    xpReward,
      'coins_awarded': coinReward,
    });

    // Award XP + coins
    final levelledUp = await awardXP(
      uid, xpReward, task['title'] ?? 'Task',
      coinsToAdd: coinReward,
    );

    // Check badges
    await checkAndUnlockBadges(uid);

    return {
      'success':    true,
      'xp':         xpReward,
      'coins':      coinReward,
      'levelled_up': levelledUp,
    };
  }

  // ─────────────────────────────────────────────────────────────
  // COMPLETE TASKS BY TYPE  — completes all tasks of a given type
  // ─────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> completeTasksByType(
    String uid,
    String taskType,
  ) async {
    final List<Map<String, dynamic>> results = [];
    try {
      final tasksSnap = await _db
          .collection('tasks')
          .where('task_type', isEqualTo: taskType)
          .get();

      for (final doc in tasksSnap.docs) {
        final taskId = doc.id;
        final result = await completeTask(uid, taskId);
        results.add({
          'taskId': taskId,
          ...result,
        });
      }
    } catch (e) {
      results.add({'success': false, 'reason': e.toString()});
    }
    return results;
  }

  // ─────────────────────────────────────────────────────────────
  // CHECK + UNLOCK BADGES
  // ─────────────────────────────────────────────────────────────
  static Future<List<String>> checkAndUnlockBadges(String uid) async {
    final userRef  = _db.collection('users').doc(uid);
    final userSnap = await userRef.get();
    if (!userSnap.exists) return [];

    final userData   = userSnap.data()!;
    final List<dynamic> earned = List<dynamic>.from(userData['badges'] ?? []);
    final int level            = (userData['level']       ?? 1) as int;
    final int streakDays       = (userData['streak_days'] ?? 0) as int;
    final int currentXP        = (userData['xp']          ?? 0) as int;

    // Total lifetime XP (rough — sum logs)
    // For performance, we use level * avg instead of scanning all logs
    int lifetimeXP = 0;
    for (int l = 1; l < level; l++) {
      lifetimeXP += xpRequiredForLevel(l);
    }
    lifetimeXP += currentXP;

    final badgesSnap = await _db.collection('badges').get();
    final newlyUnlocked = <String>[];

    for (final doc in badgesSnap.docs) {
      final badge = doc.data();
      final badgeId = doc.id;
      if (earned.contains(badgeId)) continue;

      final condType  = badge['condition_type'] as String? ?? '';
      final condValue = (badge['condition_value'] ?? 0) as int;
      bool unlocked   = false;

      switch (condType) {
        case 'level':
          unlocked = level >= condValue;
          break;
        case 'streak':
          unlocked = streakDays >= condValue;
          break;
        case 'xp_total':
          unlocked = lifetimeXP >= condValue;
          break;
        case 'task_count':
          final taskType = badge['condition_task_type'] as String? ?? '';
          unlocked = await _countCompletedTaskType(uid, taskType) >= condValue;
          break;
        case 'task_id':
          final taskId = badge['condition_task_id'] as String? ?? '';
          unlocked = await _hasCompletedTask(uid, taskId);
          break;
      }

      if (unlocked) {
        earned.add(badgeId);
        newlyUnlocked.add(badgeId);
      }
    }

    if (newlyUnlocked.isNotEmpty) {
      final updates = <String, dynamic>{'badges': earned};
      for (final b in newlyUnlocked) {
        updates['badge_unlock_times.$b'] = FieldValue.serverTimestamp();
      }
      await userRef.update(updates);
    }
    return newlyUnlocked;
  }

  static Future<int> _countCompletedTaskType(String uid, String taskType) async {
    if (taskType.isEmpty) return 0;
    // Get task IDs matching the type
    final tasksSnap = await _db
        .collection('tasks')
        .where('task_type', isEqualTo: taskType)
        .get();
    final taskIds = tasksSnap.docs.map((d) => d.id).toSet();

    // Count user_tasks docs for this user that match those task IDs
    final logsSnap = await _db
        .collection('user_tasks')
        .where('user_id', isEqualTo: uid)
        .get();

    return logsSnap.docs
        .where((d) => taskIds.contains(d.data()['task_id']))
        .length;
  }

  static Future<bool> _hasCompletedTask(String uid, String taskId) async {
    final snap = await _db
        .collection('user_tasks')
        .where('user_id', isEqualTo: uid)
        .where('task_id', isEqualTo: taskId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  // ─────────────────────────────────────────────────────────────
  // REDEEM REWARD
  // ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> redeemReward(
    String uid,
    String rewardId,
    int coinCost,
  ) async {
    final userRef  = _db.collection('users').doc(uid);
    final userSnap = await userRef.get();
    if (!userSnap.exists) return {'success': false, 'reason': 'User not found'};

    final data = userSnap.data()!;
    int coins  = (data['coins'] ?? 0) as int;
    final List<dynamic> redeemed = List<dynamic>.from(data['redeemed_rewards'] ?? []);

    if (redeemed.contains(rewardId)) {
      return {'success': false, 'reason': 'Already redeemed'};
    }
    if (coins < coinCost) {
      return {'success': false, 'reason': 'Insufficient coins'};
    }

    coins -= coinCost;
    redeemed.add(rewardId);

    await userRef.update({'coins': coins, 'redeemed_rewards': redeemed});

    // Log redemption
    await _db
        .collection('xp_logs')
        .doc(uid)
        .collection('entries')
        .add({
      'source':    'reward_redeemed',
      'xp':        0,
      'coins':     -coinCost,
      'reward_id': rewardId,
      'earned_at': FieldValue.serverTimestamp(),
    });

    return {'success': true, 'remaining_coins': coins};
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────
  static int _weekNumber(DateTime date) {
    final dayOfYear = int.parse(DateFormat('D').format(date));
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  /// Check if a specific task was completed today
  static Future<bool> isTaskCompletedToday(String uid, String taskId) async {
    final today  = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final docId  = '${uid}_${taskId}_$today';
    final snap   = await _db.collection('user_tasks').doc(docId).get();
    return snap.exists;
  }

  /// Calculate the real streak (resetting to 0 if missed yesterday)
  static int getRealStreak(Map<String, dynamic> d) {
    int streak = (d['streak_days'] ?? 0) as int;
    final lastRaw = d['last_active_date'];
    if (lastRaw is Timestamp && streak > 0) {
      final lastActive = lastRaw.toDate();
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final yesterdayStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));
      final lastStr = DateFormat('yyyy-MM-dd').format(lastActive);
      
      if (lastStr != todayStr && lastStr != yesterdayStr) {
        return 0;
      }
    }
    return streak;
  }

  /// Quick stream of user gamification fields
  static Stream<Map<String, dynamic>> userGamificationStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return {};
      final d = snap.data()!;
      int streak = getRealStreak(d);

      return {
        'xp':           (d['xp']           ?? 0) as int,
        'level':        (d['level']        ?? 1) as int,
        'coins':        (d['coins']        ?? 0) as int,
        'streak_days':  streak,
        'badges':       (d['badges']       ?? []) as List<dynamic>,
        'redeemed_rewards': (d['redeemed_rewards'] ?? []) as List<dynamic>,
      };
    });
  }

  static String? get currentUid => _auth.currentUser?.uid;
}
