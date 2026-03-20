import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'add_diary.dart';

class DiaryDetailScreen extends StatefulWidget {
  final String docId;

  const DiaryDetailScreen({
    super.key,
    required this.docId,
  });

  @override
  State<DiaryDetailScreen> createState() => _DiaryDetailScreenState();
}

class _DiaryDetailScreenState extends State<DiaryDetailScreen> {
  late Stream<DocumentSnapshot> _documentStream;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _documentStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('diary_entries')
          .doc(widget.docId)
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('diary_entries')
          .doc(widget.docId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: const Color(0xFFF9F9F7),
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF333333)),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: const Center(
              child: CircularProgressIndicator(color: Color(0xFF7C9C84)),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: const Color(0xFFF9F9F7),
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF333333)),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: Center(
              child: Text(
                'Entry not found',
                style: GoogleFonts.outfit(fontSize: 16, color: const Color(0xFF888888)),
              ),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        return _buildContent(context, data);
      },
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> data) {
    final Color backgroundColor = const Color(0xFFF9F9F7);
    final Color textColorMain = const Color(0xFF333333);
    final Color textColorSub = const Color(0xFF888888);
    final Color aiInsightsBg = const Color(0xFFF1F3EE);
    final Color buttonGreen = const Color(0xFF84A590);

    final String title = data['title'] ?? 'Untitled Entry';
    final String content = data['content'] ?? '';
    final String mood = data['mood'] ?? 'Neutral';
    final String displayMood = data['aiMoodTitle'] ?? mood;
    final String? imageUrl = data['imageUrl'];
    final String? summary = data['summary'];
    final Timestamp? timestamp = data['timestamp'];

    String formattedDate = '';
    if (timestamp != null) {
      final DateTime dt = timestamp.toDate();
      formattedDate = DateFormat('EEEE, MMM d • hh:mm a').format(dt);
    }

    // Mood Colors & Emojis
    Color moodBgColor;
    String moodEmoji;
    switch (mood) {
      case 'Happy':
        moodBgColor = const Color(0xFFFFF7E6);
        moodEmoji = '😊';
        break;
      case 'Calm':
        moodBgColor = const Color(0xFFF0F9EB);
        moodEmoji = '😌';
        break;
      case 'Neutral':
        moodBgColor = const Color(0xFFF4F4F5);
        moodEmoji = '😐';
        break;
      default:
        moodBgColor = const Color(0xFFF1F3EE);
        moodEmoji = '✨';
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF333333), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'DIARY ENTRY',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: const Color(0xFF5D6D66),
          ),
        ),
        centerTitle: true,
        actions: const [
          SizedBox(width: 48),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),

            // Title
            Text(
              title,
              style: GoogleFonts.playfairDisplay(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: textColorMain,
              ),
            ),

            const SizedBox(height: 12),

            // Date Row
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF7C9C84)),
                const SizedBox(width: 8),
                Text(
                  formattedDate,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: textColorSub,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Mood Badges
            Row(
              children: [
                _buildMoodBadge(displayMood, moodEmoji, moodBgColor, const Color(0xFF5D6D66)),
                const SizedBox(width: 12),
                if (mood == 'Happy' || displayMood.contains('Joy'))
                  _buildMoodBadge('Joyful', '😊', const Color(0xFFFFF3E0), const Color(0xFFFF9800)),
                if (mood == 'Calm' || displayMood.contains('Reflective'))
                  _buildMoodBadge('Peaceful', '🌿', const Color(0xFFE8F5E9), const Color(0xFF4CAF50)),
              ],
            ),

            const SizedBox(height: 32),

            // Content Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Text(
                content,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: const Color(0xFF4A4A4A),
                  height: 1.6,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // AI Insights Box
            if (summary != null && summary.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: aiInsightsBg,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE1E6DC),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.auto_awesome, size: 20, color: Color(0xFF7C9C84)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'AI Insights',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColorMain,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      summary,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: const Color(0xFF6B7280),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Image Card
            if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),

            const SizedBox(height: 32),

            // Buttons
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.share, color: Colors.white, size: 18),
                label: Text(
                  'Share with Trusted Contacts',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonGreen,
                  elevation: 2,
                  shadowColor: Colors.black26,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddDiaryScreen(
                        entryId: widget.docId,
                        initialData: data,
                        isDraft: false,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.edit, color: Color(0xFF5D6D66), size: 18),
                label: Text(
                  'Edit Entry',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF5D6D66),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Delete Link
            Center(
              child: TextButton.icon(
                onPressed: () => _showDeleteDialog(context),
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                label: Text(
                  'Delete Entry',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodBadge(String label, String emoji, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F1EC),
            borderRadius: BorderRadius.circular(28),
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFE57373),
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Delete Entry?',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This diary entry will be permanently removed from your collection. Are you sure?',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: const Color(0xFF666666),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Keep it',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF888888),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .collection('diary_entries')
                              .doc(widget.docId)
                              .delete();
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            Navigator.pop(context);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE57373),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Delete',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
