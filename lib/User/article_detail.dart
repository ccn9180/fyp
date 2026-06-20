import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fyp/services/gamification_service.dart';
import 'package:fyp/widgets/badge_unlocked_dialog.dart';
import 'package:fyp/widgets/quest_completed_dialog.dart';
import 'package:fyp/widgets/level_up_dialog.dart';
class ArticleDetailScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final String content;
  final String imageUrl;
  final String tag;
  final String authorName;
  final String authorRole;
  final String authorImageUrl;
  final String readingTime;
  final String? publishDate;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  const ArticleDetailScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.content,
    required this.imageUrl,
    required this.tag,
    required this.authorName,
    required this.authorRole,
    required this.authorImageUrl,
    required this.readingTime,
    this.publishDate,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  double _progress = 0.0;
  bool _isRecordDone = false;
  late bool _isFavorite;
  int _userRating = 0;
  bool _hasRated = false;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.isFavorite;
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;
      if (maxScroll > 0) {
        setState(() {
          _progress = (currentScroll / maxScroll).clamp(0.0, 1.0);
          if (_progress > 0.9 && !_isRecordDone) {
            _recordActivity();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _recordActivity() async {
    if (_isRecordDone) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _progress > 0) {
      _isRecordDone = true;
      await FirebaseFirestore.instance.collection('user_activity').add({
        'userId': user.uid,
        'type': 'article',
        'title': widget.title,
        'imageUrl': widget.imageUrl,
        'progress': 100, // Record as fully read once they cross 90%
        'timestamp': FieldValue.serverTimestamp(),
      });
      int totalXp = 0;
      int totalCoins = 0;
      bool showLevelUp = false;
      bool hasSuccessfulCompletion = false;

      try {
        final results = await GamificationService.completeTasksByType(user.uid, 'article');
        for (final res in results) {
          if (res['success'] == true) {
            hasSuccessfulCompletion = true;
            totalXp += (res['xp'] ?? 0) as int;
            totalCoins += (res['coins'] ?? 0) as int;
            if (res['levelled_up'] == true) {
              showLevelUp = true;
            }
          }
        }
      } catch (e) {
        debugPrint("Error completing article tasks: $e");
      }

      try {
        final newlyUnlocked = await GamificationService.checkAndUnlockBadges(user.uid);
        if (mounted && newlyUnlocked.isNotEmpty) {
          for (final badge in newlyUnlocked) {
            await showDialog(
              context: context,
              barrierColor: Colors.black87,
              builder: (_) => BadgeUnlockedDialog(
                badgeName: badge['name'] ?? 'Achievement Unlocked',
                badgeDescription: badge['description'] ?? 'You earned a new badge!',
                tier: badge['tier'] ?? 'Bronze',
                icon: GamificationService.getIconData(badge['icon']),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint("Error checking badges after reading article: $e");
      }

      if (mounted) {
        if (showLevelUp) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const LevelUpDialog(),
          );
        } else if (hasSuccessfulCompletion) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => QuestCompletedDialog(
              xpEarned: totalXp,
              coinsEarned: totalCoins,
              title: 'Article Completed',
              subtitle: 'Great job learning something new today!',
            ),
          );
        }
      }
    }
  }

  Future<void> _submitRating(int rating) async {
    if (_hasRated) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _hasRated = true);

    // 1. Save the individual rating record
    await FirebaseFirestore.instance.collection('resource_ratings').add({
      'userId': user.uid,
      'type': 'article',
      'title': widget.title,
      'rating': rating,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2. Recalculate the average rating in the articles collection
    final snapshot = await FirebaseFirestore.instance
        .collection('articles')
        .where('title', isEqualTo: widget.title)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      final data = doc.data();

      final int currentCount =
          data.containsKey('ratingCount') ? (data['ratingCount'] as num).toInt() : 0;
      final double currentRating =
          data.containsKey('rating') ? (data['rating'] as num).toDouble() : 0.0;

      final double newRating =
          ((currentRating * currentCount) + rating) / (currentCount + 1);

      await doc.reference.update({
        'rating': newRating,
        'ratingCount': currentCount + 1,
      });
    }
  }

  Widget _buildRoundButton({required IconData icon, required VoidCallback onTap, bool isFavorite = false, bool isHeart = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          isHeart ? (isFavorite ? Icons.favorite_rounded : Icons.favorite_outline_rounded) : icon,
          size: 20,
          color: isHeart && isFavorite ? Colors.redAccent : const Color(0xFF333333),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF7C9C84);
    const Color backgroundColor = Color(0xFFF2F1EC);
    const Color textColorMain = Color(0xFF333333);
    const Color textColorSub = Color(0xFF9E9E9E);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Standardized Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildRoundButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () {
                      _recordActivity();
                      Navigator.pop(context);
                    },
                  ),
                  Text(
                    'EUNOIA',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.0,
                      color: const Color(0xFF5D6D66),
                    ),
                  ),
                  _buildRoundButton(
                    icon: Icons.favorite_border_rounded,
                    isHeart: true,
                    isFavorite: _isFavorite,
                    onTap: () {
                      setState(() => _isFavorite = !_isFavorite);
                      widget.onFavoriteToggle();
                    },
                  ),
                ],
              ),
            ),

            Expanded(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  children: [
                    // Reading Progress Indicator
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      decoration: BoxDecoration(color: backgroundColor),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('READING PROGRESS', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF5D6D66))),
                              Text('${(_progress * 100).toInt()}%', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: primaryColor)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _progress,
                              minHeight: 6,
                              backgroundColor: const Color(0xFFE0E4DF),
                              valueColor: const AlwaysStoppedAnimation<Color>(primaryColor),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            // Featured Image
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(32),
                                child: Image.network(
                                  widget.imageUrl.isNotEmpty ? widget.imageUrl : 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b',
                                  height: 300,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            // Content
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.title,
                                    style: GoogleFonts.playfairDisplay(fontSize: 32, fontWeight: FontWeight.bold, color: textColorMain),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    widget.subtitle,
                                    style: GoogleFonts.outfit(fontSize: 16, color: textColorSub, height: 1.5),
                                  ),
                                  const SizedBox(height: 32),
                                  Html(
                                    data: widget.content,
                                    style: {
                                      "body": Style(
                                        fontFamily: 'Outfit',
                                        fontSize: FontSize(18.0),
                                        color: textColorMain,
                                        lineHeight: LineHeight(1.8),
                                        margin: Margins.zero,
                                        padding: HtmlPaddings.zero,
                                      ),
                                      "h1": Style(fontSize: FontSize(26.0), fontWeight: FontWeight.bold),
                                      "h2": Style(fontSize: FontSize(24.0), fontWeight: FontWeight.bold),
                                      "h3": Style(fontSize: FontSize(20.0), fontWeight: FontWeight.bold, margin: Margins.only(top: 16, bottom: 8)),
                                      "p": Style(margin: Margins.only(bottom: 12)),
                                    },
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 48),
                            _buildRatingSection(),
                            const SizedBox(height: 32),
                            // Interaction Buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildInteractionButton(
                                  icon: _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  label: 'FAVORITE',
                                  color: _isFavorite ? Colors.redAccent : textColorMain,
                                  onTap: () {
                                    setState(() => _isFavorite = !_isFavorite);
                                    widget.onFavoriteToggle();
                                  },
                                ),
                                _buildInteractionButton(
                                  icon: Icons.share_outlined,
                                  label: 'SHARE',
                                  color: textColorMain,
                                  onTap: () {
                                    Share.share('Check out this article on Eunoia: ${widget.title}');
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildRatingSection() {
    return Column(
      children: [
        Text(
          _hasRated ? 'Thanks for your rating!' : 'How was this article?',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            return GestureDetector(
              onTap: _hasRated
                  ? null
                  : () {
                      final selectedRating = index + 1;
                      setState(() {
                        _userRating = selectedRating;
                      });
                      _submitRating(selectedRating);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Thank you for rating $selectedRating stars!'),
                          backgroundColor: const Color(0xFF7C9C84),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Icon(
                  index < _userRating ? Icons.star_rounded : Icons.star_border_rounded,
                  color: _hasRated
                      ? const Color(0xFFEAB308)
                      : const Color(0xFFEAB308),
                  size: 32,
                ),
              ),
            );
          }),
        ),
        if (_hasRated) ...[  
          const SizedBox(height: 8),
          Text(
            'Your rating has been saved.',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: const Color(0xFF7C9C84),
            ),
          ),
        ],
      ],
    );
  }


}
