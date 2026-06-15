import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:share_plus/share_plus.dart';
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
      FirebaseFirestore.instance.collection('user_activity').add({
        'userId': user.uid,
        'type': 'article',
        'title': widget.title,
        'imageUrl': widget.imageUrl,
        'progress': (_progress * 100).toInt(),
        'timestamp': FieldValue.serverTimestamp(),
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
          'How was this article?',
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
              onTap: () {
                setState(() {
                  _userRating = index + 1;
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Thank you for rating $_userRating stars!'),
                    backgroundColor: const Color(0xFF7C9C84),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Icon(
                  index < _userRating ? Icons.star_rounded : Icons.star_border_rounded,
                  color: const Color(0xFFEAB308), // Gold color
                  size: 32,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
