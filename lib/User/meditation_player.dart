import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MeditationPlayerScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final String imageUrl;
  final String duration;
  final String? audioUrl;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  const MeditationPlayerScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.duration,
    this.audioUrl,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  @override
  State<MeditationPlayerScreen> createState() => _MeditationPlayerScreenState();
}

class _MeditationPlayerScreenState extends State<MeditationPlayerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _breathingController;
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  late bool _isFavorite;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.isFavorite;
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _audioPlayer = AudioPlayer();

    // Listen to player state
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          if (_isPlaying) {
            _breathingController.repeat(reverse: true);
          } else {
            _breathingController.stop();
          }
        });
      }
    });

    // Listen to duration
    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() {
          _duration = newDuration;
        });
      }
    });

    // Listen to position
    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() {
          _position = newPosition;
        });
      }
    });

    // Listen to completion
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted && !_isCompleted) {
        setState(() => _isCompleted = true);
        _recordActivity(); // Auto-record on completion
        _showCompletionDialog();
      }
    });

    _setupAudio();
  }

  Future<void> _setupAudio() async {
    if (widget.audioUrl != null && widget.audioUrl!.isNotEmpty) {
      try {
        await _audioPlayer.setSource(UrlSource(widget.audioUrl!));
      } catch (e) {
        debugPrint("Error setting audio source: $e");
      }
    }
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (widget.audioUrl != null && widget.audioUrl!.isNotEmpty) {
        await _audioPlayer.resume();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No audio track available for this session.")),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  void _showExitDialog(BuildContext context, Color primaryColor, Color textColorMain) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close_rounded, color: primaryColor, size: 32),
                ),
                const SizedBox(height: 24),
                Text(
                  'End Session?',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: textColorMain,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Are you sure you want to leave your meditation session? Your progress will be saved based on your active mindfulness time.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: const Color(0xFF888888),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: primaryColor.withOpacity(0.2)),
                          ),
                        ),
                        child: Text(
                          'Continue',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _recordActivity();
                          _audioPlayer.stop();
                          Navigator.pop(context); // Close dialog
                          Navigator.pop(context); // Exit player
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Quit',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _submitRating(int rating, String type) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('resource_ratings').add({
        'userId': user.uid,
        'type': type,
        'title': widget.title,
        'rating': rating,
        'timestamp': FieldValue.serverTimestamp(),
      });

      final String collectionName = type == 'article' ? 'articles' : 'meditation_guides';
      final snapshot = await FirebaseFirestore.instance
          .collection(collectionName)
          .where('title', isEqualTo: widget.title)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();

        int currentCount = data.containsKey('ratingCount') ? data['ratingCount'] as int : 0;
        double currentRating = data.containsKey('rating') ? (data['rating'] as num).toDouble() : 0.0;

        double newRating = ((currentRating * currentCount) + rating) / (currentCount + 1);

        await doc.reference.update({
          'rating': newRating,
          'ratingCount': currentCount + 1,
        });
      }
    }
  }

  void _showCompletionDialog() {
    int rating = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final primaryColor = const Color(0xFF7C9C84);
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check_circle_rounded, color: primaryColor, size: 48),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Mindfulness Complete',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'You took a beautiful moment for yourself. How would you rate this session?',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          color: const Color(0xFF666666),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                rating = index + 1;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Icon(
                                index < rating ? Icons.star_rounded : Icons.star_border_rounded,
                                color: const Color(0xFFFFC107),
                                size: 36,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: () {
                          if (rating > 0) {
                            _submitRating(rating, 'meditation');
                          }
                          Navigator.pop(context); // Close dialog
                          Navigator.pop(context); // Return to hub
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Text(
                          'Return to Hub',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                    ],
                  );
                }
            ),
          ),
        );
      },
    );
  }

  bool _isRecordDone = false;

  void _recordActivity() async {
    if (_isRecordDone) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _position.inSeconds > 0) {
      _isRecordDone = true;
      final mins = _position.inMinutes;
      final secs = _position.inSeconds.remainder(60);
      final durationStr = "$mins:${secs.toString().padLeft(2, '0')}";

      FirebaseFirestore.instance.collection('user_activity').add({
        'userId': user.uid,
        'type': 'meditation',
        'title': widget.title,
        'imageUrl': widget.imageUrl,
        'duration': durationStr,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF7C9C84); // Sage Green
    const Color backgroundColor = Color(0xFFF2F1EC);
    const Color textColorMain = Color(0xFF333333);
    const Color textColorSub = Color(0xFF9E9E9E);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitDialog(context, primaryColor, textColorMain);
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: child,
            );
          },
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => _showExitDialog(context, primaryColor, textColorMain),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ]
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, color: textColorMain, size: 20),
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            'NOW PLAYING',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.0,
                              color: const Color(0xFF88958D),
                            ),
                          ),
                          Text(
                            'Meditation Room',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textColorMain,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() => _isFavorite = !_isFavorite);
                          widget.onFavoriteToggle();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_isFavorite ? "Saved to your favorites." : "Removed from favorites."),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ]
                          ),
                          child: Icon(
                            _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: _isFavorite ? Colors.redAccent : textColorMain,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(flex: 1),

                  // Main Image Circle with Breathing Effect
                  AnimatedBuilder(
                    animation: _breathingController,
                    builder: (context, child) {
                      return Container(
                        width: 280 + (20 * _breathingController.value),
                        height: 280 + (20 * _breathingController.value),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.15 * _breathingController.value),
                              blurRadius: 40,
                              spreadRadius: 10 * _breathingController.value,
                            ),
                          ],
                          border: Border.all(
                              color: Colors.white,
                              width: 8 - (2 * _breathingController.value)
                          ),
                        ),
                        child: Stack(
                          children: [
                            ClipOval(
                              child: Image.network(
                                widget.imageUrl,
                                width: 300,
                                height: 300,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const Spacer(flex: 1),

                  // Titles
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 34,
                      fontWeight: FontWeight.w500,
                      color: textColorMain,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: textColorSub,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const Spacer(flex: 1),

                  // Progress Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(_position),
                              style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: textColorSub
                              ),
                            ),
                            Text(
                              _formatDuration(_duration),
                              style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: textColorSub
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 12,
                              thumbColor: primaryColor,
                              activeTrackColor: primaryColor,
                              inactiveTrackColor: const Color(0xFFE0E4DF),
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                            ),
                            child: Slider(
                              value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0),
                              max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                              min: 0,
                              onChanged: (value) {
                                _audioPlayer.seek(Duration(seconds: value.toInt()));
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () => _audioPlayer.seek(_position - const Duration(seconds: 10)),
                        icon: const Icon(Icons.replay_10_rounded, color: Color(0xFFBBCBC2), size: 36),
                      ),
                      const SizedBox(width: 40),
                      GestureDetector(
                        onTap: _togglePlay,
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              )
                            ],
                          ),
                          child: Icon(
                              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 48
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                      IconButton(
                        onPressed: () => _audioPlayer.seek(_position + const Duration(seconds: 10)),
                        icon: const Icon(Icons.forward_10_rounded, color: Color(0xFFBBCBC2), size: 36),
                      ),
                    ],
                  ),

                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
