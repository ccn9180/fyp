import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp/app_localizations.dart';
import 'package:intl/intl.dart';
import 'diary_list.dart';
import 'chat_history.dart';
import 'shared_with_me.dart';
import 'video_call.dart';
import 'upcoming_session_detail.dart';
import 'all_upcoming_sessions.dart';
import 'session_history.dart';
import 'user_analytics.dart';
import 'mood_trend.dart';
import 'xp_journey.dart';
import 'daily_tasks.dart';
import 'session_feedback.dart';
import 'selfHelp.dart';
import 'meditation_player.dart';
import 'widgets/mood_calendar_widget.dart';
import '../services/gamification_service.dart';
import '../widgets/quest_completed_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color accentGold = const Color(0xFFFFD700);
  final Color textColorMain = const Color(0xFF333333);
  final Color textColorSub = const Color(0xFF888888);

  late Stream<QuerySnapshot> _bookingsStream;

  bool _isLoadingMood = true;
  String? _todayMood;
  final List<String> emotions = ['Happy', 'Calm', 'Neutral', 'Anxious', 'Angry'];
  final List<IconData> emotionIcons = [
    Icons.sentiment_very_satisfied_rounded,
    Icons.sentiment_satisfied_rounded,
    Icons.sentiment_neutral_rounded,
    Icons.sentiment_dissatisfied_rounded,
    Icons.sentiment_very_dissatisfied_rounded,
  ];

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _bookingsStream = FirebaseFirestore.instance
        .collection('counsellor_bookings')
        .where('patientId', isEqualTo: uid)
        .snapshots();
        
    _checkTodayMood();
    _fetchUserProgress();
  }

  int _diaryCount = 0;
  int _chatCount = 0;
  int _counselCount = 0;
  int _moodCount = 0;

  Future<void> _fetchUserProgress() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final diarySnap = await FirebaseFirestore.instance.collection('users').doc(uid).collection('diary_entries').get();
      final chatSnap = await FirebaseFirestore.instance.collection('chat_sessions').where('userId', isEqualTo: uid).get();
      final counselSnap = await FirebaseFirestore.instance.collection('counsellor_bookings').where('patientId', isEqualTo: uid).get();
      final moodSnap = await FirebaseFirestore.instance.collection('users').doc(uid).collection('mood_checkins').get();
      
      if (mounted) {
        setState(() {
          _diaryCount = diarySnap.docs.length;
          _chatCount = chatSnap.docs.length;
          _counselCount = counselSnap.docs.length;
          _moodCount = moodSnap.docs.length;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user progress: $e');
    }
  }
  
  Future<void> _checkTodayMood() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoadingMood = false);
      return;
    }
    
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('mood_checkins')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
          
      if (snap.docs.isNotEmpty) {
        _todayMood = snap.docs.first['emotion'];
      }
    } catch (e) {
      debugPrint('Error checking today mood: $e');
    }
    
    if (mounted) {
      setState(() {
        _isLoadingMood = false;
      });
    }
  }

  Future<void> _saveMood(String mood) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    setState(() {
      _isLoadingMood = true;
    });
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('mood_checkins')
          .add({
        'emotion': mood,
        'timestamp': Timestamp.now(),
      });
      
      _todayMood = mood;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thanks for checking in today!'), 
            backgroundColor: Color(0xFF7C9C84)
          ),
        );
      }
      
      // Check and update streak
      final bool streakUpdated = await GamificationService.updateStreak(uid);
      
      // Also complete gamification tasks
      final results = await GamificationService.completeTasksByType(uid, 'mood');
      int totalXp = 5; // Default fallback if no task is returned
      int totalCoins = 2; // Default fallback if no task is returned
      bool taskCompleted = false;
      for (final res in results) {
        if (res['success'] == true) {
          taskCompleted = true;
          totalXp += (res['xp'] ?? 0) as int;
          totalCoins += (res['coins'] ?? 0) as int;
        }
      }

      if ((streakUpdated || taskCompleted) && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => QuestCompletedDialog(
            xpEarned: totalXp,
            coinsEarned: totalCoins,
            title: 'Daily Check-In',
            subtitle: 'Consistency is key. Keep it up!',
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving mood: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save mood: $e'), backgroundColor: Colors.red),
        );
      }
    }
    
    if (mounted) {
      setState(() {
        _isLoadingMood = false;
      });
    }
  }

  String _getQuoteForMood(String? mood) {
    if (mood == null) {
      return "\"Be gentle with yourself. You are a work in progress, and every day you show up is a beautiful achievement.\"";
    }
    
    switch (mood.toLowerCase()) {
      case 'happy':
        return "\"Joy is a net of love by which you can catch souls. Keep shining your bright light today.\"";
      case 'calm':
        return "\"Peace comes from within. Do not seek it without. Enjoy this beautiful moment of serenity.\"";
      case 'neutral':
        return "\"Every day may not be good, but there's something good in every day. Take it one step at a time.\"";
      case 'anxious':
        return "\"You don't have to control your thoughts. You just have to stop letting them control you. Breathe.\"";
      case 'angry':
        return "\"For every minute you remain angry, you give up sixty seconds of peace of mind. Be kind to yourself today.\"";
      default:
        return "\"Be gentle with yourself. You are a work in progress, and every day you show up is a beautiful achievement.\"";
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EC), // Light beige/cream background
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header area
              StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser?.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    String name = 'Friend';
                    String? profileUrl;

                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data = snapshot.data!.data() as Map<String, dynamic>;
                      String? nickname = data['nickname'] as String?;
                      if (nickname != null && nickname.trim().isNotEmpty) {
                        name = nickname.split(' ')[0];
                      } else {
                        name = data['fullName']?.split(' ')[0] ?? 'Friend';
                      }
                      profileUrl = data['profileImageUrl'];
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${AppLocalizations.of(context)!.translate('peaceful_morning')}, $name',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF333333),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                AppLocalizations.of(context)!.translate('ready_calm'),
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  color: Colors.grey[500],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFFBBCBC2),
                          backgroundImage: profileUrl != null
                              ? (profileUrl.startsWith('data:image')
                              ? MemoryImage(base64Decode(profileUrl.split(',').last)) as ImageProvider
                              : NetworkImage(profileUrl))
                              : null,
                          child: profileUrl == null
                              ? const Icon(Icons.person, color: Colors.white, size: 24)
                              : null,
                        ),
                      ],
                    );
                  }
              ),

              const SizedBox(height: 30),

              // Mindfulness Journey Level
              StreamBuilder<Map<String, dynamic>>(
                stream: GamificationService.userGamificationStream(FirebaseAuth.instance.currentUser?.uid ?? ''),
                builder: (context, gSnap) {
                  final int xp = gSnap.data?['xp'] ?? 0;
                  final int level = gSnap.data?['level'] ?? 1;
                  final int xpRequired = GamificationService.xpRequiredForLevel(level);
                  final double progress = (xp / xpRequired).clamp(0.0, 1.0);

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const XPJourneyScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBFBF6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'EUNOIA JOURNEY',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                      color: const Color(0xFFA3A3A3),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const DailyTasksScreen()),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: primaryGreen.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.assignment_rounded, size: 10, color: primaryGreen),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Quests',
                                            style: GoogleFonts.outfit(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: primaryGreen,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'Level $level',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: primaryGreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: const Color(0xFFEBEBE6),
                              valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '$xp / $xpRequired XP',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                'Tap to view journey 🌿',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  color: primaryGreen,
                                  fontWeight: FontWeight.w500,
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
              const SizedBox(height: 20),
              
              _buildMoodCheckin(),
              // Weekly Harmony Card (As Quote Section)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
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
                    const Icon(Icons.format_quote_rounded, color: Color(0xFFBBCBC2), size: 32),
                    const SizedBox(height: 12),
                    Text(
                      _getQuoteForMood(_todayMood),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                        color: const Color(0xFF333333),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Main Actions (AI Chat & Diary)
              Row(
                children: [
                  Expanded(
                    child: _buildActionCircle(
                      'AI Chat',
                      'Guided support\nanytime',
                      Icons.chat_bubble,
                      const Color(0xFFF0EFE9), // Slightly different white/beige
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ChatHistoryScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildActionCircle(
                      'Diary',
                      'Reflect and release',
                      Icons.menu_book_rounded, // Book icon
                      const Color(0xFFE9E8EE), // Lilac tint
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const DiaryListScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Shared Journeys (Inner Circle) Section
              Text(
                'SHARED JOURNEYS',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: const Color(0xFFB0B0B0),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SharedWithMeScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F3EE),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.people_alt_rounded, color: Color(0xFF7C9C84), size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Inner Circle',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF333333),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Diary & Conversations shared with you',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: const Color(0xFF888888),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFB0B0B0)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              _buildUpcomingSessionCard(),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'YOUR WELLNESS SUMMARY',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: const Color(0xFFB0B0B0),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MoodTrendScreen())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'View Trends',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: primaryGreen,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded, size: 12, color: primaryGreen),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const MoodCalendarWidget(),
              const SizedBox(height: 24),

              _buildActivityReportSection(),

              const SizedBox(height: 35),

              Text(
                'FOR YOUR FOCUS',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: const Color(0xFFB0B0B0),
                ),
              ),
              const SizedBox(height: 16),

              // Dynamic Meditation Card
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('meditation_guides').where('status', isEqualTo: 'published').limit(1).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      height: 250,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Center(child: CircularProgressIndicator(color: Color(0xFF7C9C84))),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  final doc = snapshot.data!.docs.first;
                  final data = doc.data() as Map<String, dynamic>;
                  final title = data['title'] ?? 'Meditation';
                  final duration = data['duration'] ?? '10:00';
                  final category = data['category'] ?? 'RELAX';
                  final imageUrl = data['imageUrl'] ?? 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?q=80&w=2560&auto=format&fit=crop';
                  final audioUrl = data['audioUrl']?.toString();

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MeditationPlayerScreen(
                            title: title,
                            subtitle: '$duration • $category',
                            imageUrl: imageUrl,
                            duration: duration,
                            audioUrl: audioUrl,
                            isFavorite: false, // We'd need to fetch user favorites to know for sure, but false is fine for preview
                            onFavoriteToggle: () {},
                          ),
                        ),
                      );
                    },
                    child: Container(
                      height: 250,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        image: DecorationImage(
                          image: NetworkImage(imageUrl),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.1),
                              Colors.black.withOpacity(0.6),
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.spa, color: Colors.white70, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'SUGGESTED SESSION',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              title,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: Colors.white.withOpacity(0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.play_arrow_rounded, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Practice Now',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32), // Space for bottom nav
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoodItem(String label, IconData icon, bool isSelected) {
    return Column(
      children: [
        Container(
          width: 65,
          height: 65,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF7C9C84) : Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              if (!isSelected)
                BoxShadow(
                  color: Colors.grey.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.white : const Color(0xFF888888),
            size: 28,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isSelected ? const Color(0xFF7C9C84) : const Color(0xFFAAAAAA),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCircle(String title, String subtitle, IconData icon, Color bgColor, {VoidCallback? onTap}) {
    return AspectRatio(
      aspectRatio: 1, // Square/Circle
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 15,
                offset: const Offset(0, 5),
              )
            ],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF707070), size: 28),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: const Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingSessionCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _bookingsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink(); // Show nothing if no upcoming session
        }

        final now = DateTime.now();
        // Filter to only upcoming bookings and NOT cancelled
        final upcomingDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final rawStartTime = data['startTime'];
          final startTime = (rawStartTime is Timestamp) ? rawStartTime.toDate() : null;
          final status = (data['status'] ?? '').toString().toLowerCase();
          return startTime != null && status != 'cancelled' && status != 'completed' && status != 'missed' && status != 'rejected';
        }).toList();

        if (upcomingDocs.isEmpty) {
          return const SizedBox.shrink(); // Show nothing if no upcoming session
        }

        // Sort ascending to get the earliest upcoming booking
        upcomingDocs.sort((a, b) {
          final aTime = ((a.data() as Map<String, dynamic>)['startTime'] as Timestamp).toDate();
          final bTime = ((b.data() as Map<String, dynamic>)['startTime'] as Timestamp).toDate();
          return aTime.compareTo(bTime);
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'UPCOMING SESSIONS',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: const Color(0xFFB0B0B0),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AllUpcomingSessionsScreen()),
                    );
                  },
                  child: Text(
                    'View All',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF7C9C84),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 156,
              child: PageView.builder(
                controller: PageController(viewportFraction: 1.0),
                itemCount: upcomingDocs.length,
                itemBuilder: (context, index) {
                  final bookingData = {
                    ...(upcomingDocs[index].data() as Map<String, dynamic>),
                    'id': upcomingDocs[index].id,
                  };
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: _buildSingleSessionCard(bookingData),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
          ],
        );
      }
    );
  }

  Widget _buildSingleSessionCard(Map<String, dynamic> bookingData) {
    final name = bookingData['counsellorName'] ?? 'Counsellor';
    final specialty = bookingData['counsellorSpecialty'] ?? 'Mental Wellness Counselor';
    final rawImageUrl = bookingData['counsellorImageUrl']?.toString() ?? '';
    final imageUrl = rawImageUrl.isNotEmpty ? rawImageUrl : 'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?auto=format&fit=crop&q=80&w=2000';
    final rawStartTime = bookingData['startTime'];
    final DateTime startTime = (rawStartTime is Timestamp) 
        ? rawStartTime.toDate() 
        : (rawStartTime is DateTime ? rawStartTime : DateTime.now());

    final int diffInMinutes = startTime.difference(DateTime.now()).inMinutes;
    String tagText = 'UPCOMING';
    if (diffInMinutes <= 0 && diffInMinutes >= -60) {
      tagText = 'ON-GOING';
    } else if (diffInMinutes < -60) {
      tagText = 'PENDING REVIEW';
    } else if (diffInMinutes <= 60) {
      tagText = 'LIVE SOON';
    }
    final String displayDate = DateFormat('MMM dd, hh:mm a').format(startTime);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UpcomingSessionDetailScreen(sessionData: bookingData),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: imageUrl.startsWith('data:image')
                      ? MemoryImage(base64Decode(imageUrl.split(',').last)) as ImageProvider
                      : NetworkImage(imageUrl),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF333333),
                        ),
                      ),
                      Text(
                        specialty,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: const Color(0xFF888888),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3EE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    tagText,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF7C9C84),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_rounded, size: 14, color: Colors.grey.shade400),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          displayDate,
                          style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'VIEW DETAILS',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF7C9C84),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityReportSection() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UserAnalyticsScreen())),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Your Progress', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: primaryGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Text('Details', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: primaryGreen)),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, size: 12, color: primaryGreen),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildModernActivityCard(Icons.edit_note_rounded, 'Diary', '$_diaryCount', const Color(0xFFF0EFE9)),
                const SizedBox(width: 12),
                _buildModernActivityCard(Icons.chat_bubble_outline_rounded, 'AI Support', '$_chatCount', const Color(0xFFE9E8EE)),
              ],
            ),
            const SizedBox(height: 24),
            _buildActivityRow('Counselor Sessions', _counselCount > 0 ? 1.0 : 0.0, '$_counselCount Total'),
            _buildActivityRow('Daily Reflections', _moodCount > 0 ? 1.0 : 0.0, '$_moodCount Total'),
          ],
        ),
      ),
    );
  }

  Widget _buildModernActivityCard(IconData icon, String label, String val, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF707070)),
            const SizedBox(height: 12),
            Text(val, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF333333))),
            Text(label, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF888888))),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityRow(String title, double progress, String stat) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF333333))),
              Text(stat, style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFFF0F0F0),
              valueColor: AlwaysStoppedAnimation<Color>(primaryGreen.withOpacity(0.6)),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMoodCheckin() {
    if (_isLoadingMood) {
      return Center(child: Padding(padding: const EdgeInsets.all(20), child: CircularProgressIndicator(color: primaryGreen)));
    }
    
    if (_todayMood != null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFEBEBE6)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              emotionIcons[emotions.indexOf(_todayMood!) != -1 ? emotions.indexOf(_todayMood!) : 2],
              color: primaryGreen,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thanks for checking in today!',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColorMain,
                    ),
                  ),
                  Text(
                    'Your mood has been recorded.',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: textColorSub,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'How are you feeling today?',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColorMain,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Check in to start your Eunoia journey',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: textColorSub,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(emotions.length, (index) {
              return GestureDetector(
                onTap: () => _saveMood(emotions[index]),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBFBF6),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFEBEBE6)),
                      ),
                      child: Icon(
                        emotionIcons[index],
                        size: 32,
                        color: const Color(0xFFB0B0B0),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      emotions[index],
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textColorSub,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
