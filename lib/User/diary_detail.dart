import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'add_diary.dart';
import 'package:fyp/services/friends_service.dart';

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
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, color: Color(0xFF7C9C84), size: 22),
            onPressed: () => _showExportSheet(context),
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

            const SizedBox(height: 24),

            // Mood Badges
            Row(
              children: [
                _buildMoodBadge(displayMood, moodEmoji, moodBgColor, const Color(0xFF5D6D66)),
                const SizedBox(width: 12),
                if ((mood == 'Happy' || displayMood.contains('Joy')) && !displayMood.toLowerCase().contains('joy'))
                  _buildMoodBadge('Joyful', '😊', const Color(0xFFFFF3E0), const Color(0xFFFF9800)),
                if ((mood == 'Calm' || displayMood.contains('Reflective')) && !displayMood.toLowerCase().contains('peace') && !displayMood.toLowerCase().contains('reflect'))
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
                child: widget.mockData != null && !imageUrl.startsWith('http')
                    ? const Icon(Icons.image, size: 100) // Fallback for local/mock
                    : Image.network(
                  imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),

            const SizedBox(height: 32),

            // Shared With Section (Only for owner)
            if (activeSharedFriends.isNotEmpty && !widget.isInnerCircle) ...[
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
                                ? NetworkImage(friend.profileImageUrl!)
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
                    onPressed: () async {
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
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C9C84),
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
                                     ? NetworkImage(friend.profileImageUrl!)
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
                    backgroundImage: NetworkImage(imageUrl),
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


  void _showExportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
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
            Text(
              'EXPORT REFLECTION',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
                color: const Color(0xFFB0B0B0),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildExportOption(
                    context,
                    Icons.picture_as_pdf_rounded,
                    'Export PDF',
                    'Create a high-quality document',
                    const Color(0xFF7C9C84),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildExportOption(
                    context,
                    Icons.image_rounded,
                    'Save Photo',
                    'Save as a beautiful image',
                    const Color(0xFF94A9B0),
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

  Widget _buildExportOption(BuildContext context, IconData icon, String title, String subtitle, Color color) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Preparing $title...'),
            backgroundColor: color,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 10,
                color: color.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
