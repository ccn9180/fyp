import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'add_diary.dart';
import 'package:fyp/services/friends_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DiaryDetailScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic>? mockData;
  final bool isInnerCircle;
  final String? authorUid;

  const DiaryDetailScreen({
    super.key,
    required this.docId,
    this.mockData,
    this.isInnerCircle = false,
    this.authorUid,
  });

  @override
  State<DiaryDetailScreen> createState() => _DiaryDetailScreenState();
}

class _DiaryDetailScreenState extends State<DiaryDetailScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey _exportKey = GlobalKey(); // for image capture
  bool _isExporting = false;
  Map<String, bool> _sharingStates = {};
  List<FriendProfile> _friendsList = [];
  bool _isLoadingFriends = true;
  bool _friendsLoaded = false;

  Future<void> _loadFriendsAndSharing(Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final Map<String, dynamic> access = data['sharingAccess'] ?? {};
      final List<FriendProfile> contacts = [];
      final Map<String, bool> updatedSharingStates = {};

      if (doc.exists && doc.data()?['trustedContacts'] != null) {
        final list = List<Map<String, dynamic>>.from(doc.data()?['trustedContacts']);
        for (var contact in list) {
          final String name = contact['name'] ?? contact['label'] ?? 'Unknown';
          final String relation = contact['relationship'] ?? 'OTHER';
          final String shareKey = contact['uid'] ?? contact['email'] ?? contact['name'] ?? '';
          if (shareKey.isNotEmpty) {
            contacts.add(FriendProfile(
              uid: shareKey,
              fullName: '$name|$relation',
              profileImageUrl: null,
            ));
            updatedSharingStates[shareKey] = access[shareKey] == true;
          }
        }
      }

      if (mounted) {
        setState(() {
          _friendsList = contacts;
          _sharingStates = updatedSharingStates;
          _isLoadingFriends = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading trusted contacts: $e');
      if (mounted) {
        setState(() {
          _isLoadingFriends = false;
        });
      }
    }
  }


  @override
  void initState() {
    super.initState();
  }

  // Helper methods to get emotion details
  String _getEmotionEmoji(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'joy': return '😊';
      case 'calm': return '😌';
      case 'sadness': case 'sad': return '😢';
      case 'anxiety': case 'anxious': return '😰';
      case 'anger': case 'angry': return '😠';
      default: return '😐';
    }
  }

  String _getEmotionDisplayName(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'joy': return 'Happy';
      case 'calm': return 'Calm';
      case 'sadness': case 'sad': return 'Sad';
      case 'anxiety': case 'anxious': return 'Anxious';
      case 'anger': case 'angry': return 'Angry';
      default: return 'Neutral';
    }
  }

  Color _getEmotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'joy': return const Color(0xFF4CAF50);
      case 'calm': return const Color(0xFF2196F3);
      case 'sadness': case 'sad': return const Color(0xFF9C27B0);
      case 'anxiety': case 'anxious': return const Color(0xFFFF9800);
      case 'anger': case 'angry': return const Color(0xFFF44336);
      default: return const Color(0xFF9E9E9E);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mockData != null) {
      return _buildContent(context, widget.mockData!);
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    final String targetUserUid = (widget.isInnerCircle && widget.authorUid != null)
        ? widget.authorUid!
        : user.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserUid)
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

    final user = FirebaseAuth.instance.currentUser;
    if (widget.isInnerCircle && widget.mockData == null) {
      final Map<String, dynamic> access = data['sharingAccess'] ?? {};
      if (user == null || access[user.uid] != true) {
        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF333333)),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 64, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  Text(
                    'Access Denied',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textColorMain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You do not have permission to view this shared reflection.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 14, color: textColorSub),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    final String title = data['title'] ?? 'Untitled Entry';
    final String content = data['content'] ?? '';
    final String mood = data['mood'] ?? 'Neutral';
    final String displayMood = data['aiMoodTitle'] ?? mood;
    final String? imageUrl = data['imageUrl'];
    final String? summary = data['summary'];
    final Timestamp? timestamp = data['timestamp'];
    final List<dynamic>? emotionPercentages = data['emotionPercentages'];
    final List<dynamic>? keywords = data['keywords'];

    String formattedDate = '';
    if (timestamp != null) {
      final DateTime dt = timestamp.toDate();
      formattedDate = DateFormat('EEEE, MMM d • hh:mm a').format(dt);
    }

    // Initialize sharing states from Firestore if not already set or whenever data changes
    if (!_friendsLoaded && !widget.isInnerCircle) {
      _friendsLoaded = true;
      _loadFriendsAndSharing(data);
    }

    if (data['sharingAccess'] != null && _sharingStates.isEmpty) {
      final Map<String, dynamic> access = data['sharingAccess'];
      access.forEach((key, value) {
        _sharingStates[key] = value as bool;
      });
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

    final List<FriendProfile> activeSharedFriends = [];
    _sharingStates.forEach((uid, val) {
      if (val) {
        final friend = _friendsList.firstWhere(
          (f) => f.uid == uid,
          orElse: () => FriendProfile(uid: uid, fullName: uid),
        );
        activeSharedFriends.add(friend);
      }
    });


    return Scaffold(
      key: _scaffoldKey,
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
        actions: [
          _isExporting
              ? const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C9C84)),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.ios_share_rounded, color: Color(0xFF7C9C84), size: 22),
                  onPressed: () => _showExportSheet(context, data),
                ),
          if (!widget.isInnerCircle)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE57373), size: 24),
              onPressed: () => _showDeleteDialog(context),
            ),
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

            const SizedBox(height: 16),

            if (keywords != null && keywords.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: keywords.map((k) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3EE),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE1E6DC)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.label_outline_rounded, size: 14, color: Color(0xFF7C9C84)),
                      const SizedBox(width: 6),
                      Text(
                        k.toString(),
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: textColorMain,
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ],

            const SizedBox(height: 24),            // Content Box
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

            if (emotionPercentages != null && emotionPercentages.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 10)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emotion Breakdown',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColorMain,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...emotionPercentages.map((ep) {
                      final eName = ep['emotion'] ?? 'neutral';
                      final conf = (ep['confidence'] as num?)?.toDouble() ?? 0.0;
                      final cLabel = _getEmotionDisplayName(eName);
                      final cColor = _getEmotionColor(eName);
                      final emoji = _getEmotionEmoji(eName);
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            SizedBox(width: 24, child: Text(emoji, style: const TextStyle(fontSize: 14))),
                            SizedBox(
                              width: 60, 
                              child: Text(
                                cLabel, 
                                style: GoogleFonts.outfit(fontSize: 13, color: textColorMain, fontWeight: FontWeight.w500)
                              )
                            ),
                            Expanded(
                              child: Stack(
                                children: [
                                  Container(
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: cColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: (conf / 100).clamp(0.0, 1.0),
                                    child: Container(
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: cColor,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 44,
                              child: Text(
                                '${conf.toStringAsFixed(1)}%',
                                style: GoogleFonts.outfit(fontSize: 12, color: textColorSub, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.right,
                              )
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],

            // AI Insights Box
            if (summary != null && summary.isNotEmpty) ...[
              const SizedBox(height: 24),
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
            ],

            // Image Card
            if (imageUrl != null) ...[
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: widget.mockData != null && !imageUrl.startsWith('http')
                    ? const Icon(Icons.image, size: 100) // Fallback for local/mock
                    : Image.network(
                  imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],



            // Shared With Section (Only for owner)
            if (activeSharedFriends.isNotEmpty && !widget.isInnerCircle) ...[
              const SizedBox(height: 32),
              Text(
                'SHARED WITH',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: textColorSub,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: -8,
                        children: activeSharedFriends.map((friend) => Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: CircleAvatar(
                            backgroundColor: buttonGreen.withOpacity(0.2),
                            backgroundImage: friend.profileImageUrl != null && friend.profileImageUrl!.isNotEmpty
                                ? (friend.profileImageUrl!.startsWith('data:image')
                                    ? MemoryImage(base64Decode(friend.profileImageUrl!.split(',').last)) as ImageProvider
                                    : NetworkImage(friend.profileImageUrl!))
                                : null,
                            child: friend.profileImageUrl == null || friend.profileImageUrl!.isEmpty
                                ? Text(
                                    friend.fullName.isNotEmpty ? friend.fullName.split('|')[0][0].toUpperCase() : 'U',
                                    style: TextStyle(fontSize: 12, color: buttonGreen, fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                        )).toList(),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showManageAccessSheet(context),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F3EE), // Soft Sage Green
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'MANAGE',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: buttonGreen, // Use the existing buttonGreen constant
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],

            const SizedBox(height: 32),

            // Buttons
            if (!widget.isInnerCircle) ...[
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => _showShareSheet(context, widget.docId),
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
            ],

            const SizedBox(height: 32),
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

  void _showShareSheet(BuildContext context, String docId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final Color textColorSub = const Color(0xFF888888);
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 32),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C9C84).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.group_add_outlined, color: Color(0xFF7C9C84), size: 24),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Share Reflection',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF333333),
                          ),
                        ),
                        Text(
                          'Choose who can view this entry',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: const Color(0xFF888888),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Contact List
                if (_isLoadingFriends)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF7C9C84))),
                  )
                else if (_friendsList.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'No trusted contacts found to share with.',
                      style: GoogleFonts.outfit(color: textColorSub),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _friendsList.length,
                      itemBuilder: (context, index) {
                        final friend = _friendsList[index];
                        final parts = friend.fullName.split('|');
                        final name = parts[0];
                        final relation = parts.length > 1 ? parts[1] : 'OTHER';
                        final icon = relation == 'FAMILY'
                            ? Icons.person_outline
                            : (relation == 'COUNSELOR' || relation == 'DOCTOR'
                                ? Icons.medical_services_outlined
                                : Icons.sentiment_satisfied_outlined);
                        return _buildShareContactTile(
                          name,
                          relation,
                          icon,
                          _sharingStates[friend.uid] ?? false,
                          friend.profileImageUrl,
                          (val) {
                            setSheetState(() => _sharingStates[friend.uid] = val);
                          },
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 32),

                // Share Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _sharingStates.values.any((v) => v) ? () async {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .collection('diary_entries')
                            .doc(docId)
                            .update({
                          'sharingAccess': _sharingStates,
                          'lastEdited': FieldValue.serverTimestamp(),
                        });
                      }
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sharing preferences updated'),
                            backgroundColor: Color(0xFF7C9C84),
                          ),
                        );
                      }
                      setState(() {});
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C9C84),
                      disabledBackgroundColor: Colors.grey[300],
                      disabledForegroundColor: Colors.grey[500],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(
                      'Share with Selected',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showManageAccessSheet(BuildContext context) {
    final Color textColorMain = const Color(0xFF333333);
    final Color textColorSub = const Color(0xFF888888);
    final Color primaryGreen = const Color(0xFF7C9C84);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final List<FriendProfile> currentSharedFriends = [];
          _sharingStates.forEach((uid, val) {
            if (val) {
              final friend = _friendsList.firstWhere(
                (f) => f.uid == uid,
                orElse: () => FriendProfile(uid: uid, fullName: uid),
              );
              currentSharedFriends.add(friend);
            }
          });

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F3EE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_user_outlined, color: Color(0xFF7C9C84), size: 40),
                ),
                const SizedBox(height: 24),
                Text(
                  'MANAGE ACCESS',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textColorMain,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Revoke viewing rights for this reflection.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: textColorSub,
                  ),
                ),
                const SizedBox(height: 32),
                if (currentSharedFriends.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text('No active shares', style: GoogleFonts.outfit(color: textColorSub)),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: currentSharedFriends.length,
                      itemBuilder: (context, index) {
                        final friend = currentSharedFriends[index];
                        return Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9F9F7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                               CircleAvatar(
                                 backgroundColor: primaryGreen.withOpacity(0.1),
                                 backgroundImage: friend.profileImageUrl != null && friend.profileImageUrl!.isNotEmpty
                                     ? (friend.profileImageUrl!.startsWith('data:image')
                                         ? MemoryImage(base64Decode(friend.profileImageUrl!.split(',').last)) as ImageProvider
                                         : NetworkImage(friend.profileImageUrl!))
                                     : null,
                                 child: friend.profileImageUrl == null || friend.profileImageUrl!.isEmpty
                                     ? Text(
                                         friend.fullName.isNotEmpty ? friend.fullName.split('|')[0][0].toUpperCase() : 'U',
                                         style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold),
                                       )
                                     : null,
                               ),
                               const SizedBox(width: 16),
                               Expanded(
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     Text(
                                       friend.fullName.split('|')[0],
                                       style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: textColorMain),
                                     ),
                                     if (friend.fullName.contains('|'))
                                       Text(
                                         friend.fullName.split('|')[1],
                                         style: GoogleFonts.outfit(fontSize: 12, color: textColorSub),
                                       ),
                                   ],
                                 ),
                               ),
                               TextButton(
                                 onPressed: () {
                                   setSheetState(() {
                                     _sharingStates[friend.uid] = false;
                                   });
                                   setState(() {}); // Update main UI too
                                   
                                   final user = FirebaseAuth.instance.currentUser;
                                   if (user != null) {
                                     FirebaseFirestore.instance
                                         .collection('users')
                                         .doc(user.uid)
                                         .collection('diary_entries')
                                         .doc(widget.docId)
                                         .update({'sharingAccess': _sharingStates});
                                   }
                                   ScaffoldMessenger.of(context).showSnackBar(
                                     SnackBar(content: Text('Access revoked for ${friend.fullName.split('|')[0]}'), backgroundColor: Colors.redAccent),
                                   );
                                 },
                                style: TextButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFEBEE),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text('REVOKE', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFE57373))),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: primaryGreen)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildShareContactTile(
    String name,
    String relation,
    IconData icon,
    bool isSelected,
    String? imageUrl,
    Function(bool) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isSelected ? const Color(0xFF7C9C84) : Colors.transparent, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: imageUrl == null || imageUrl.isEmpty ? const EdgeInsets.all(10) : EdgeInsets.zero,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? CircleAvatar(
                    radius: 20,
                    backgroundImage: imageUrl.startsWith('data:image')
                        ? MemoryImage(base64Decode(imageUrl.split(',').last)) as ImageProvider
                        : NetworkImage(imageUrl),
                  )
                : Icon(icon, color: isSelected ? const Color(0xFF7C9C84) : Colors.grey[400], size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF333333),
                  ),
                ),
                Text(
                  relation,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[400],
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Checkbox(
            value: isSelected,
            onChanged: (val) => onChanged(val ?? false),
            activeColor: const Color(0xFF7C9C84),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ],
      ),
    );
  }


  void _showExportSheet(BuildContext context, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 32),
            Text(
              'EXPORT REFLECTION',
              style: GoogleFonts.outfit(
                fontSize: 12, fontWeight: FontWeight.bold,
                letterSpacing: 2.0, color: const Color(0xFFB0B0B0),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Save or share this diary entry',
              style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: _buildExportOption(
                    ctx,
                    Icons.picture_as_pdf_rounded,
                    'Export PDF',
                    'Styled document with full entry',
                    const Color(0xFF7C9C84),
                    () async {
                      Navigator.pop(ctx);
                      await _exportAsPdf(data);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildExportOption(
                    ctx,
                    Icons.image_rounded,
                    'Save Photo',
                    'Share as a beautiful image',
                    const Color(0xFF94A9B0),
                    () async {
                      Navigator.pop(ctx);
                      await _exportAsImage(data);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildExportOption(BuildContext context, IconData icon, String title,
      String subtitle, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(title, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 10, color: color.withOpacity(0.6))),
          ],
        ),
      ),
    );
  }

  // ── PDF Export ────────────────────────────────────────────────
  Future<void> _exportAsPdf(Map<String, dynamic> data) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final String title    = data['title'] ?? 'My Reflection';
      final String body     = data['content'] ?? '';
      final String emotion  = data['mood'] ?? '';
      final String summary  = data['summary'] ?? '';
      final List<dynamic> keywords = data['keywords'] ?? [];
      final Timestamp? ts  = data['timestamp'] as Timestamp?;
      final String dateStr = ts != null
          ? DateFormat('MMMM d, yyyy  •  h:mm a').format(ts.toDate())
          : '';

      final doc = pw.Document();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 56),
          build: (pw.Context ctx) => [
            // ── Header ──
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 20),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFF7C9C84), width: 1.5)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Eunoia · Personal Reflection',
                    style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF7C9C84), letterSpacing: 1.5),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    title,
                    style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF222222)),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    dateStr,
                    style: pw.TextStyle(fontSize: 10, color: PdfColor.fromInt(0xFF888888)),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // ── Emotion chip ──
            if (emotion.isNotEmpty) ...[
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFEAF0EC),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(20)),
                ),
                child: pw.Text(
                  '${_emotionEmoji(emotion)}  ${emotion[0].toUpperCase()}${emotion.substring(1)}',
                  style: pw.TextStyle(fontSize: 11, color: PdfColor.fromInt(0xFF4A7A5A), fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 20),
            ],

            // ── Body ──
            pw.Text(
              body,
              style: pw.TextStyle(fontSize: 13, color: PdfColor.fromInt(0xFF333333), lineSpacing: 6),
            ),

            pw.SizedBox(height: 28),

            // ── AI Summary ──
            if (summary.isNotEmpty) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF5F7F5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                  border: pw.Border.all(color: PdfColor.fromInt(0xFFD4E0D6)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('AI Insight',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromInt(0xFF7C9C84), letterSpacing: 1.2)),
                    pw.SizedBox(height: 8),
                    pw.Text(summary,
                        style: pw.TextStyle(fontSize: 12, color: PdfColor.fromInt(0xFF555555), lineSpacing: 4)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
            ],

            // ── Keywords ──
            if (keywords.isNotEmpty) ...[
              pw.Wrap(
                spacing: 8,
                runSpacing: 6,
                children: keywords.map((k) => pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColor.fromInt(0xFF7C9C84)),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(14)),
                  ),
                  child: pw.Text('#$k',
                      style: pw.TextStyle(fontSize: 10, color: PdfColor.fromInt(0xFF7C9C84))),
                )).toList(),
              ),
              pw.SizedBox(height: 20),
            ],

            // ── Footer ──
            pw.Divider(color: PdfColor.fromInt(0xFFEEEEEE)),
            pw.SizedBox(height: 8),
            pw.Text(
              'Exported from Eunoia · Your personal wellness journal',
              style: pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFFAAAAAA)),
            ),
          ],
        ),
      );

      final Uint8List bytes = await doc.save();
      await Printing.sharePdf(bytes: bytes, filename: '${title.replaceAll(' ', '_')}_diary.pdf');
    } catch (e) {
      debugPrint('PDF export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _emotionEmoji(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'joy':       return '😊';
      case 'calm':      return '😌';
      case 'sadness':   return '😢';
      case 'anxiety':   return '😰';
      case 'anger':     return '😠';
      case 'hopeful':   return '🌟';
      case 'overwhelmed': return '😵';
      default:          return '📖';
    }
  }

  // ── Image Export ──────────────────────────────────────────────
  Future<void> _exportAsImage(Map<String, dynamic> data) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final String title   = data['title'] ?? 'My Reflection';
      final String body    = data['content'] ?? '';
      final String emotion = data['mood'] ?? '';
      final String summary = data['summary'] ?? '';
      final Timestamp? ts  = data['timestamp'] as Timestamp?;
      final String dateStr = ts != null
          ? DateFormat('MMMM d, yyyy').format(ts.toDate())
          : '';

      // Build an offscreen widget, then capture it
      final imageWidget = RepaintBoundary(
        key: _exportKey,
        child: _buildExportCard(title, body, emotion, summary, dateStr),
      );

      // Insert into a temporary overlay to render it
      late OverlayEntry entry;
      entry = OverlayEntry(
        builder: (_) => Positioned(
          left: -9999, top: -9999,
          child: Material(color: Colors.transparent, child: imageWidget),
        ),
      );
      Overlay.of(context).insert(entry);

      // Wait for rendering
      await Future.delayed(const Duration(milliseconds: 300));

      final RenderRepaintBoundary boundary =
          _exportKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image img = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      entry.remove();

      if (byteData == null) throw Exception('Failed to render image');

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Save to temp file and share
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${title.replaceAll(' ', '_')}_diary.png');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: 'My diary reflection: $title',
      );
    } catch (e) {
      debugPrint('Image export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Widget _buildExportCard(String title, String body, String emotion,
      String summary, String dateStr) {
    final Color primary = const Color(0xFF7C9C84);
    final Color bg      = const Color(0xFFF2F1EC);

    return Container(
      width: 400,
      color: bg,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand header
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.eco_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text('Eunoia', style: GoogleFonts.playfairDisplay(
                fontSize: 16, fontWeight: FontWeight.bold, color: primary)),
              const Spacer(),
              Text(dateStr, style: GoogleFonts.outfit(
                fontSize: 10, color: Colors.grey[500])),
            ],
          ),
          const SizedBox(height: 24),
          // Emotion
          if (emotion.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_emotionEmoji(emotion)}  ${emotion[0].toUpperCase()}${emotion.substring(1)}',
                style: GoogleFonts.outfit(
                  fontSize: 11, fontWeight: FontWeight.bold, color: primary),
              ),
            ),
          const SizedBox(height: 16),
          // Title
          Text(title, style: GoogleFonts.playfairDisplay(
            fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF222222))),
          const SizedBox(height: 16),
          // Divider
          Container(height: 1, color: primary.withOpacity(0.2)),
          const SizedBox(height: 16),
          // Body (max 300 chars to fit card)
          Text(
            body.length > 320 ? '${body.substring(0, 317)}...' : body,
            style: GoogleFonts.outfit(
              fontSize: 13, color: const Color(0xFF444444), height: 1.6),
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primary.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Insight', style: GoogleFonts.outfit(
                    fontSize: 9, fontWeight: FontWeight.bold,
                    color: primary, letterSpacing: 1.2)),
                  const SizedBox(height: 6),
                  Text(
                    summary.length > 180 ? '${summary.substring(0, 177)}...' : summary,
                    style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[600], height: 1.5),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          // Footer
          Center(
            child: Text(
              '✨ Exported from Eunoia Wellness Journal',
              style: GoogleFonts.outfit(fontSize: 9, color: Colors.grey[400]),
            ),
          ),
        ],
      ),
    );
  }
}
