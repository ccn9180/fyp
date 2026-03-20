import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp/app_localizations.dart';
import 'add_diary.dart';

class DiaryDraftsScreen extends StatefulWidget {
  const DiaryDraftsScreen({super.key});

  @override
  State<DiaryDraftsScreen> createState() => _DiaryDraftsScreenState();
}

class _DiaryDraftsScreenState extends State<DiaryDraftsScreen> {
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFF2F1EC);
  final Color textColorMain = const Color(0xFF333333);
  final Color textColorSub = const Color(0xFF888888);

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: textColorMain,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.translate('drafts'),
          style: GoogleFonts.playfairDisplay(
            color: textColorMain,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: user == null
          ? _buildEmptyState()
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('diary_drafts')
            .orderBy('lastModified', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF7C9C84)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final drafts = snapshot.data!.docs;
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            itemCount: drafts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final doc = drafts[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildDraftCard(doc.id, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildDraftCard(String draftId, Map<String, dynamic> data) {
    final String content = data['content'] ?? '';
    final String emotion = data['emotion'] ?? 'Neutral';
    final Timestamp? lastModified = data['lastModified'];

    String dateStr = 'Unknown';
    if (lastModified != null) {
      final DateTime dt = lastModified.toDate();
      dateStr = '${_getMonth(dt.month)} ${dt.day}, ${dt.year}';
    }

    return Dismissible(
      key: Key(draftId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.redAccent),
      ),
      onDismissed: (direction) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .collection('diary_drafts')
            .doc(draftId)
            .delete();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draft deleted'), backgroundColor: Colors.redAccent),
        );
      },
      child: GestureDetector(
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => AddDiaryScreen(
                initialData: data,
                entryId: draftId,
                isDraft: true,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateStr,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: textColorSub,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      emotion,
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                content.isEmpty ? 'Empty Draft' : content,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  color: textColorMain,
                  height: 1.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.edit_note_rounded, size: 16, color: primaryGreen),
                  const SizedBox(width: 4),
                  Text(
                    'Tap to continue writing',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: primaryGreen,
                      fontWeight: FontWeight.w500,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_stories_outlined, size: 64, color: const Color(0xFFBBCBC2)),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.translate('no_drafts'),
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: textColorMain,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.translate('no_drafts_sub'),
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: textColorSub,
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  String _getMonth(int month) {
    const List<String> months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return months[month - 1];
  }
}
