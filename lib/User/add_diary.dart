import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:fyp/app_localizations.dart';
import 'entry_summary.dart';
import '../services/gamification_service.dart';
import '../widgets/level_up_dialog.dart';
import '../widgets/quest_completed_dialog.dart';
import '../widgets/badge_unlocked_dialog.dart';
import '../services/crisis_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/fcm_service.dart';


class AddDiaryScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final String? entryId;
  final bool isDraft;

  const AddDiaryScreen({
    super.key,
    this.initialData,
    this.entryId,
    this.isDraft = false,
  });

  @override
  State<AddDiaryScreen> createState() => _AddDiaryScreenState();
}

class _AddDiaryScreenState extends State<AddDiaryScreen> {
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFF2F1EC);
  final Color textColorMain = const Color(0xFF333333);
  final Color textColorSub = const Color(0xFF888888);

  String? _selectedEmotion;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  File? _selectedImage;
  bool _isUploading = false;
  bool _isSavingDraft = false;
  String? _currentDraftId;

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
    if (widget.isDraft) {
      _currentDraftId = widget.entryId;
    }

    if (widget.initialData != null) {
      _titleController.text = widget.initialData!['title'] ?? '';
      _contentController.text = widget.initialData!['content'] ?? '';
      _selectedEmotion = widget.initialData!['userMood'] ?? widget.initialData!['emotion'];
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  // Format the current date securely like the design 'October 24, 2023 • 10:30 AM'
  String _getFormattedDate() {
    final DateTime dt = DateTime.now();
    const List<String> months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final String month = months[dt.month - 1];
    final String day = dt.day.toString();
    final String year = dt.year.toString();
    final String hour = (dt.hour % 12 == 0 ? 12 : dt.hour % 12).toString().padLeft(2, '0');
    final String minute = dt.minute.toString().padLeft(2, '0');
    final String ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$month $day, $year • $hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleExit();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, size: 24),
            color: textColorMain,
            onPressed: () async {
              final shouldPop = await _handleExit();
              if (shouldPop && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(
            widget.entryId != null && !widget.isDraft
                ? AppLocalizations.of(context)!.translate('edit_entry').toUpperCase()
                : AppLocalizations.of(context)!.translate('new_entry').toUpperCase(),
            style: GoogleFonts.outfit(
              color: textColorMain,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          centerTitle: true,
          actions: const [
            SizedBox(width: 48),
          ],
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(), // Dismiss keyboard safely
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.entryId != null && !widget.isDraft
                      ? AppLocalizations.of(context)!.translate('edit_entry')
                      : AppLocalizations.of(context)!.translate('how_are_you_feeling'),
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: textColorMain,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getFormattedDate(),
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: textColorSub,
                  ),
                ),
                const SizedBox(height: 24),

                // Title Area
                Container(
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
                  child: TextField(
                    controller: _titleController,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textColorMain,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Entry Title',
                      hintStyle: GoogleFonts.outfit(
                        color: const Color(0xFFC0C0C0),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Content Area
                Container(
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
                  child: TextField(
                    controller: _contentController,
                    maxLines: 8,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: textColorMain,
                      height: 1.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Start writing your reflections here...',
                      hintStyle: GoogleFonts.outfit(
                        color: const Color(0xFFC0C0C0),
                        fontSize: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(24),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Custom Enhancement: Add Image Button
                if (_selectedImage != null)
                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          image: DecorationImage(
                            image: FileImage(_selectedImage!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.white, size: 28),
                        onPressed: () {
                          setState(() {
                            _selectedImage = null;
                          });
                        },
                      ),
                    ],
                  )
                else
                  GestureDetector(
                    onTap: _showImageSourceActionSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFEBEBE6)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.01),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )
                          ]
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.image_outlined, color: primaryGreen, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Attach Image',
                            style: GoogleFonts.outfit(
                              color: primaryGreen,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 32),

                Center(
                  child: Text(
                    'JOURNAL ENTRY',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: const Color(0xFF888888),
                    ),
                  ),
                ),
                const SizedBox(height: 16),



                // Save Button (Replaces Share config)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (_contentController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please write something in your diary before saving.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent),
                        );
                        return;
                      }
                      // Navigate to Full Screen AI Analysis instead of Modal
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EntrySummaryScreen(
                            entryTitle: _titleController.text.trim().isEmpty 
                                ? "Untitled Entry" 
                                : _titleController.text.trim(),
                            content: _contentController.text.trim(),
                            onConfirm: (moodTitle, category, summary, isCrisis, sharingTeams, secondaryCategory, emotionPercentages, keywords) async {
                              await _saveToFirebase(moodTitle, category, summary, isCrisis, sharingTeams, secondaryCategory, emotionPercentages, keywords);
                            },
                          ),
                        ),
                      );
                    },
                    icon: _isUploading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save_outlined, color: Colors.white, size: 20),
                    label: Text(
                      _isUploading
                          ? AppLocalizations.of(context)!.translate('saving')
                          : AppLocalizations.of(context)!.translate('save_entry'),
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _handleExit() async {
    final String content = _contentController.text.trim();
    if (content.isEmpty) {
      return true;
    }

    // If editing an existing entry, just pop without draft dialog
    if (widget.entryId != null && !widget.isDraft) {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (context) => Dialog(
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
                    color: const Color(0xFFFFF3E0),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFFFB74D),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Discard Changes?',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your edits have not been saved. Are you sure you want to leave and lose these changes?',
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
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Keep Editing',
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
                        onPressed: () => Navigator.pop(context, true),
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
                          'Discard',
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
      return result ?? false;
    }

    // New entry / draft — show save draft dialog
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
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
                  color: const Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.drive_file_rename_outline_rounded,
                  color: primaryGreen,
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Save Draft?',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You have unsaved reflections. Would you like to save this as a draft before leaving?',
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
                      onPressed: () => Navigator.pop(context, 'discard'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Discard',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFE57373),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, 'cancel'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF888888),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, 'save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Save Draft',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == 'save') {
      await _saveDraft();
      return true;
    } else if (result == 'discard') {
      return true;
    }
    return false;
  }

  Future<void> _saveDraft() async {
    final String content = _contentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSavingDraft = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final collection = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('diary_drafts');

        final data = {
          'content': content,
          'emotion': _selectedEmotion,
          'lastModified': FieldValue.serverTimestamp(),
        };

        if (_currentDraftId != null) {
          await collection.doc(_currentDraftId).update(data);
        } else {
          final docRef = await collection.add(data);
          _currentDraftId = docRef.id;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.translate('draft_saved')),
              backgroundColor: const Color(0xFF7C9C84),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving draft: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingDraft = false);
    }
  }

  Future<void> _saveToFirebase(String aiMoodTitle, String aiCategory, String summary, bool isCrisis, Map<String, bool> sharingTeams, [String? secondaryCategory, List<dynamic>? emotionPercentages, List<String>? keywords]) async {
    setState(() {
      _isUploading = true;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String contentText = _contentController.text.trim();
        String userTitle = _titleController.text.trim();
        
        if (userTitle.isEmpty) {
          List<String> words = contentText.split(' ');
          userTitle = words.take(5).join(' ') + (words.length > 5 ? '...' : '');
          if (userTitle.isEmpty) userTitle = "Untitled Entry";
        }

        String? imageUrl;
        if (_selectedImage != null) {
          // Upload image to Firebase Storage
          final ref = FirebaseStorage.instance
              .ref()
              .child('diary_images')
              .child(user.uid)
              .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
          await ref.putFile(_selectedImage!);
          imageUrl = await ref.getDownloadURL();
        }

        final diaryData = {
          'title': userTitle,
          'content': contentText,
          'mood': aiCategory,
          'secondaryMood': secondaryCategory,
          'aiMoodTitle': aiMoodTitle,
          'summary': summary,
          'isCrisis': isCrisis,
          'emotionPercentages': emotionPercentages,
          'keywords': keywords,
          'sharingAccess': sharingTeams,
          'userMood': null,
          'imageUrl': imageUrl ?? widget.initialData?['imageUrl'],
          'timestamp': (widget.entryId != null && !widget.isDraft)
              ? (widget.initialData?['timestamp'] ?? Timestamp.now())
              : Timestamp.now(),
          'lastEdited': Timestamp.now(),
        };

        if (widget.entryId != null && !widget.isDraft) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('diary_entries')
              .doc(widget.entryId)
              .update(diaryData);
        } else {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('diary_entries')
              .add(diaryData);
        }
        
        // Update check-in date to skip today's evening reflection reminder
        try {
          final prefs = await SharedPreferences.getInstance();
          final now = DateTime.now();
          final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
          await prefs.setString('last_checkin_date', todayStr);
          
          final dailyEnabled = prefs.getBool('daily_reminder') ?? true;
          if (dailyEnabled) {
            await FCMService.scheduleDailyReminder();
          }
        } catch (e) {
          debugPrint("Failed to update check-in date for notifications: $e");
        }
        
        // Notify recipients that there is a new shared item
        if (sharingTeams.isNotEmpty) {
          final initialSharingAccess = widget.initialData?['sharingAccess'] ?? {};
          final uidsToNotify = sharingTeams.entries
              .where((e) => e.value == true && initialSharingAccess[e.key] != true)
              .map((e) => e.key)
              .toList();
          
          if (uidsToNotify.isNotEmpty) {
            final senderDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
            final senderName = senderDoc.data()?['fullName'] ?? 'A friend';

            for (var uid in uidsToNotify) {
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .update({'hasNewSharedItems': true});

                await FirebaseFirestore.instance.collection('notifications').add({
                  'to': uid,
                  'from': user.uid,
                  'title': 'New Shared Diary',
                  'message': '$senderName shared a diary entry with you.',
                  'type': 'shared_item',
                  'isRead': false,
                  'sendPush': false,
                  'timestamp': FieldValue.serverTimestamp(),
                });
              } catch (e) {
                debugPrint("Error updating hasNewSharedItems for $uid: $e");
              }
            }
          }
        }
        
        if (isCrisis) {
          await CrisisService.triggerCrisisAlert(user.uid, 'diary');
          await CrisisService.sendLocalCrisisNotification();
        }

        // Cleanup: Remove draft if it was saved
        if (_currentDraftId != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('diary_drafts')
              .doc(_currentDraftId)
              .delete();
        }

        // Auto-complete journal tasks if it's a new entry
        bool showLevelUp = false;
        int totalXp = 0;
        int totalCoins = 0;
        bool hasSuccessfulCompletion = false;

        if (widget.entryId == null || widget.isDraft) {
          try {
            final results = await GamificationService.completeTasksByType(user.uid, 'journal');
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
            debugPrint("Error completing journal tasks: $e");
          }
          // Always re-check badges (e.g. diary_count) even if tasks were
          // already completed today
          List<Map<String, dynamic>> newlyUnlockedBadges = [];
          try {
            newlyUnlockedBadges = await GamificationService.checkAndUnlockBadges(user.uid);
          } catch (e) {
            debugPrint("Error checking badges after diary save: $e");
          }

          if (mounted && newlyUnlockedBadges.isNotEmpty) {
            for (final badge in newlyUnlockedBadges) {
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
        }

        setState(() {
          _isUploading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Diary entry saved successfully.'), backgroundColor: Color(0xFF7C9C84)),
          );

          if (showLevelUp) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const LevelUpDialog(),
            ).then((_) {
              if (mounted) {
                Navigator.pop(context); // Pop EntrySummaryScreen
                Navigator.pop(context); // Pop AddDiaryScreen
              }
            });
          } else if (hasSuccessfulCompletion) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => QuestCompletedDialog(
                xpEarned: totalXp,
                coinsEarned: totalCoins,
                title: 'Reflection Logged',
                subtitle: 'Great job reflecting on your day!',
              ),
            ).then((_) {
              if (mounted) {
                Navigator.pop(context); // Pop EntrySummaryScreen
                Navigator.pop(context); // Pop AddDiaryScreen
              }
            });
          } else {
            Navigator.pop(context); // Pop EntrySummaryScreen
            Navigator.pop(context); // Pop AddDiaryScreen
          }
        }
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving to diary: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _showImageSourceActionSheet() async {
    final picker = ImagePicker();
    
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFFF2F1EC),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFFD9D9D9),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Add Photo',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSourceOption(
                    context,
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                  _buildSourceOption(
                    context,
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );

    if (source != null) {
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    }
  }

  Widget _buildSourceOption(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: primaryGreen, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }
}
