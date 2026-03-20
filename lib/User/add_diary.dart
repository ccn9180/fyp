import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:fyp/app_localizations.dart';
import 'entry_summary.dart';


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
                    onTap: () async {
                      final picker = ImagePicker();
                      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                      if (pickedFile != null) {
                        setState(() {
                          _selectedImage = File(pickedFile.path);
                        });
                      }
                    },
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

                // Quick Emotions Header
                Center(
                  child: Text(
                    'QUICK EMOTIONS',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: const Color(0xFF888888),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Quick Emotions Row
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(emotions.length, (index) {
                      final isSelected = _selectedEmotion == emotions[index];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedEmotion = emotions[index];
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? primaryGreen.withOpacity(0.15) : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            emotionIcons[index],
                            size: 36,
                            color: isSelected ? primaryGreen : const Color(0xFFB0B0B0),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 48),

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
                      if (_selectedEmotion == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select an emotion.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent),
                        );
                        return;
                      }

                      // Navigate to Full Screen AI Analysis instead of Modal
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EntrySummaryScreen(
                            content: _contentController.text.trim(),
                            onConfirm: (moodTitle, category, summary, isCrisis, sharingTeams) async {
                              // Pop the summary screen
                              Navigator.pop(context);

                              // Proceed with saving using AI insights
                              await _saveToFirebase(moodTitle, category, summary, isCrisis, sharingTeams);
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
    if (content.isEmpty && _selectedEmotion == null) {
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
    if (content.isEmpty && _selectedEmotion == null) return;

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

  Future<void> _saveToFirebase(String aiMoodTitle, String aiCategory, String summary, bool isCrisis, Map<String, bool> sharingTeams) async {
    setState(() {
      _isUploading = true;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String contentText = _contentController.text.trim();

        // Extract a graceful short title from the content
        List<String> words = contentText.split(' ');
        String title = words.take(5).join(' ') + (words.length > 5 ? '...' : '');

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
          'title': title,
          'content': contentText,
          'mood': aiCategory,
          'aiMoodTitle': aiMoodTitle,
          'summary': summary,
          'isCrisis': isCrisis,
          'sharingAccess': sharingTeams,
          'userMood': _selectedEmotion,
          'imageUrl': imageUrl ?? widget.initialData?['imageUrl'],
          'timestamp': (widget.entryId != null && !widget.isDraft)
              ? (widget.initialData?['timestamp'] ?? FieldValue.serverTimestamp())
              : FieldValue.serverTimestamp(),
          'lastEdited': FieldValue.serverTimestamp(),
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

        // Cleanup: Remove draft if it was saved
        if (_currentDraftId != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('diary_drafts')
              .doc(_currentDraftId)
              .delete();
        }

        setState(() {
          _isUploading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Diary entry saved successfully.'), backgroundColor: Color(0xFF7C9C84)),
          );
          Navigator.pop(context);
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
}
