import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp/services/friends_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ChatDetailScreen extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic> chatData;
  final bool isInnerCircle;

  const ChatDetailScreen({super.key, this.docId, required this.chatData, this.isInnerCircle = false});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFF9F9F7);
  final Color textColorMain = const Color(0xFF333333);
  final Color textColorSub = const Color(0xFF888888);
  final Color aiInsightsBg = const Color(0xFFF1F3EE);
  final Color buttonGreen = const Color(0xFF84A590);

  Map<String, bool> _sharingStates = {};
  Map<String, bool> _initialSharingStates = {};
  List<FriendProfile> _friendsList = [];
  bool _isLoadingFriends = true;
  bool _friendsLoaded = false;
  bool _isExporting = false;
  final GlobalKey _exportKey = GlobalKey();
  Stream<DocumentSnapshot>? _chatStream;

  @override
  void initState() {
    super.initState();
    if (widget.docId != null) {
      _chatStream = FirebaseFirestore.instance.collection('chat_sessions').doc(widget.docId).snapshots();
    }
  }

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
          final String? profileImageUrl = contact['profileImageUrl'];
          if (shareKey.isNotEmpty) {
            contacts.add(FriendProfile(
              uid: shareKey,
              fullName: '$name|$relation',
              profileImageUrl: profileImageUrl,
            ));
            updatedSharingStates[shareKey] = access[shareKey] == true;
          }
        }
      }

      if (mounted) {
        setState(() {
          _friendsList = contacts;
          _sharingStates = updatedSharingStates;
          _initialSharingStates = Map.from(updatedSharingStates);
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

  int _selectedRating = 0;
  bool _isFeedbackSubmitted = false;
  bool _ratingInitialized = false;


  void _showShareSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
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
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 32),
              Text(
                'SHARE CONVERSATION',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  color: const Color(0xFFB0B0B0),
                ),
              ),
              const SizedBox(height: 24),
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
                          ? Icons.family_restroom_rounded
                          : (relation == 'COUNSELOR' || relation == 'DOCTOR'
                              ? Icons.medical_services_rounded
                              : Icons.face_rounded);
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
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    if (widget.docId != null) {
                      await FirebaseFirestore.instance
                          .collection('chat_sessions')
                          .doc(widget.docId)
                          .update({
                        'sharingAccess': _sharingStates,
                      });
                      
                      // Notify recipients
                      final uidsToNotify = _sharingStates.entries
                          .where((e) => e.value == true && _initialSharingStates[e.key] != true)
                          .map((e) => e.key)
                          .toList();
                      
                      final currentUser = FirebaseAuth.instance.currentUser;
                      if (currentUser != null && uidsToNotify.isNotEmpty) {
                        final senderDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
                        final senderName = senderDoc.data()?['fullName'] ?? 'A friend';
                        
                        for (var uid in uidsToNotify) {
                          try {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .update({'hasNewSharedItems': true});
                                
                            await FirebaseFirestore.instance.collection('notifications').add({
                              'to': uid,
                              'from': currentUser.uid,
                              'title': 'New Shared Conversation',
                              'message': '$senderName shared a conversation transcript with you.',
                              'type': 'shared_item',
                              'isRead': false,
                              'sendPush': false,
                              'timestamp': FieldValue.serverTimestamp(),
                            });
                          } catch (e) {
                            debugPrint("Error updating hasNewSharedItems for $uid: $e");
                          }
                        }
                        _initialSharingStates = Map.from(_sharingStates);
                      }
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
                    backgroundColor: buttonGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    elevation: 0,
                  ),
                  child: Text('DONE', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showManageAccessSheet(BuildContext context) {
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
                  'Revoke viewing rights for this chat session.',
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
                          decoration: BoxDecoration(color: const Color(0xFFF9F9F7), borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: buttonGreen.withOpacity(0.1),
                                backgroundImage: friend.profileImageUrl != null && friend.profileImageUrl!.isNotEmpty
                                    ? (friend.profileImageUrl!.startsWith('data:image')
                                        ? MemoryImage(base64Decode(friend.profileImageUrl!.split(',').last)) as ImageProvider
                                        : NetworkImage(friend.profileImageUrl!))
                                    : null,
                                child: friend.profileImageUrl == null || friend.profileImageUrl!.isEmpty
                                    ? Text(
                                        friend.fullName.isNotEmpty ? friend.fullName.split('|')[0][0].toUpperCase() : 'U',
                                        style: TextStyle(color: buttonGreen, fontWeight: FontWeight.bold),
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
                                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
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
                                onPressed: () async {
                                  final bool? confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return Dialog(
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
                                                color: Colors.black.withOpacity(0.12),
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
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFFFEBEE),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.person_off_rounded,
                                                  color: Color(0xFFE57373),
                                                  size: 32,
                                                ),
                                              ),
                                              const SizedBox(height: 24),
                                              Text(
                                                'Revoke Access',
                                                style: GoogleFonts.playfairDisplay(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                  color: const Color(0xFF333333),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                'Are you sure you want to revoke access for ${friend.fullName.split('|')[0]}?',
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
                                                        'Cancel',
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
                                                        'Revoke',
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
                                      );
                                    },
                                  );

                                  if (confirm == true) {
                                    final nav = Navigator.of(context);
                                    final messenger = ScaffoldMessenger.of(context);

                                    setSheetState(() => _sharingStates[friend.uid] = false);
                                    setState(() {});
                                    if (widget.docId != null) {
                                      await FirebaseFirestore.instance
                                          .collection('chat_sessions')
                                          .doc(widget.docId)
                                          .update({
                                        'sharingAccess': _sharingStates,
                                      });
                                    }
                                    
                                    nav.pop(); // Close the manage access sheet directly
                                    messenger.showSnackBar(
                                      SnackBar(content: Text('Access revoked for ${friend.fullName.split('|')[0]}'), backgroundColor: const Color(0xFF7C9C84)),
                                    );
                                  }
                                },
                                style: TextButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFEBEE),
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
                  child: TextButton(
                    onPressed: () => Navigator.pop(context), 
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text('Close', style: GoogleFonts.outfit(color: buttonGreen, fontWeight: FontWeight.bold, fontSize: 16)),
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
        border: Border.all(color: isSelected ? buttonGreen : Colors.transparent, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: imageUrl == null || imageUrl.isEmpty ? const EdgeInsets.all(10) : EdgeInsets.zero,
            decoration: const BoxDecoration(
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
                : Icon(icon, color: isSelected ? buttonGreen : Colors.grey[400], size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
                Text(relation, style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[400])),
              ],
            ),
          ),
          Checkbox(
            value: isSelected,
            onChanged: (val) => onChanged(val ?? false),
            activeColor: buttonGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.docId == null) {
      return _buildContent(context, widget.chatData);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _chatStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: backgroundColor,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF86A590), size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: const Center(child: CircularProgressIndicator(color: Color(0xFF7C9C84))),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: backgroundColor,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF86A590), size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: Center(
              child: Text(
                'Conversation not found',
                style: GoogleFonts.outfit(color: textColorSub),
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
    final user = FirebaseAuth.instance.currentUser;
    if (widget.isInnerCircle && widget.docId != null) {
      final Map<String, dynamic> access = data['sharingAccess'] ?? {};
      if (user == null || access[user.uid] != true) {
        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF86A590), size: 20),
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
                    'You do not have permission to view this shared conversation.',
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

    if (data['sharingAccess'] != null && _sharingStates.isEmpty) {
      final Map<String, dynamic> access = data['sharingAccess'];
      access.forEach((key, value) {
        _sharingStates[key] = value as bool;
      });
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

    if (!_ratingInitialized) {
      if (data.containsKey('rating')) {
        _selectedRating = data['rating'] as int;
        _isFeedbackSubmitted = true;
      }
      _ratingInitialized = true;
    }

    final List<dynamic> messagesList = data['messages'] ?? [];
    String? aiSummary = data['aiSummary'];
    if (aiSummary == data['preview']) {
      aiSummary = null;
    }

    String displayDate = 'RECENT';
    if (data['createdAt'] != null) {
      if (data['createdAt'] is Timestamp) {
        final DateTime dt = (data['createdAt'] as Timestamp).toDate();
        displayDate = DateFormat('EEEE, MMM d • hh:mm a').format(dt);
      } else if (data['createdAt'] is String) {
        displayDate = data['createdAt'];
      }
    } else if (data['date'] != null) {
      displayDate = data['date'];
    }

    if (!_friendsLoaded && !widget.isInnerCircle) {
      _friendsLoaded = true;
      _loadFriendsAndSharing(data);
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF86A590), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              'Eunoia AI',
              style: GoogleFonts.outfit(
                color: textColorMain,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF86A590),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'MINDFUL GUIDE',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFB0BDB5),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          _isExporting
              ? const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF86A590)),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.ios_share_rounded, color: Color(0xFF86A590), size: 22),
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
            // Date Divider
            _buildDateDivider(displayDate.toUpperCase()),
            const SizedBox(height: 24),

            // Transcript Bubbles
            if (messagesList.isNotEmpty)
              ...messagesList.map((m) {
                final String role = m['role'] ?? '';
                final String text = m['text'] ?? '';
                if (role == 'assistant') {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _buildAiMessage(text),
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _buildUserMessage(text),
                  );
                }
              }).toList()
            else ...[
              _buildAiMessage("Hello. I'm here to support your mindfulness journey today. How are you feeling in this moment?"),
              const SizedBox(height: 24),
              _buildUserMessage("I've been feeling a bit overwhelmed with work lately. I need a moment to breathe."),
              const SizedBox(height: 24),
              _buildAiMessage("I understand. Let's take a mindful pause together. We discussed deep breathing techniques to manage workplace stress."),
            ],
            
            const SizedBox(height: 48),

            // AI SUMMARY SECTION
            if (aiSummary != null && aiSummary.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: aiInsightsBg,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: Color(0xFFE1E6DC), shape: BoxShape.circle),
                          child: const Icon(Icons.auto_awesome, size: 20, color: Color(0xFF7C9C84)),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'AI INSIGHTS',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: const Color(0xFF5D6D66),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      aiSummary,
                      style: GoogleFonts.outfit(fontSize: 15, color: const Color(0xFF4A4A4A), height: 1.6),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
            ],

            // Rating & Feedback
            if (!widget.isInnerCircle)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'How helpful was this chat?',
                      style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold, color: textColorMain),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < _selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: index < _selectedRating ? const Color(0xFFFFB74D) : Colors.grey[300],
                            size: 36,
                          ),
                          onPressed: _isFeedbackSubmitted ? null : () {
                            setState(() {
                              if (_selectedRating == index + 1) {
                                _selectedRating = 0;
                              } else {
                                _selectedRating = index + 1;
                              }
                            });
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isFeedbackSubmitted || _selectedRating == 0 ? null : () async {
                          if (widget.docId != null) {
                            try {
                              await FirebaseFirestore.instance
                                  .collection('chat_sessions')
                                  .doc(widget.docId)
                                  .update({'rating': _selectedRating});
                              setState(() {
                                _isFeedbackSubmitted = true;
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Feedback submitted successfully!'), backgroundColor: Color(0xFF7C9C84)),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to submit feedback: $e'), backgroundColor: Colors.redAccent),
                                );
                              }
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonGreen,
                          disabledBackgroundColor: Colors.grey[300],
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text('SUBMIT FEEDBACK', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 48),

            // Sharing Section
            if (!widget.isInnerCircle) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SHARING',
                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: textColorSub),
                  ),
                  const SizedBox(height: 16),
                  if (activeSharedFriends.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
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
                              backgroundColor: const Color(0xFFF1F3EE),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('MANAGE', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: buttonGreen)),
                          ),
                        ],
                      ),
                    ),
                  if (activeSharedFriends.isEmpty)
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () => _showShareSheet(context),
                        icon: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                        label: Text('Share with Trusted Contacts', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonGreen,
                          elevation: 2,
                          shadowColor: Colors.black26,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildDateDivider(String label) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFFEBEBE4), borderRadius: BorderRadius.circular(12)),
        child: Text(label, style: GoogleFonts.outfit(color: const Color(0xFF909088), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ),
    );
  }

  Widget _buildAiMessage(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(color: Color(0xFF86A590), shape: BoxShape.circle),
          child: const Icon(Icons.eco, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('EUNOIA AI', style: GoogleFonts.outfit(color: const Color(0xFFB0BDB5), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
                  border: Border.all(color: const Color(0xFFEBEBE4), width: 1),
                ),
                child: Text(text, style: GoogleFonts.outfit(color: textColorMain, fontSize: 15, height: 1.4)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 40),
      ],
    );
  }

  Widget _buildUserMessage(String text) {
    final String userDisplayName = widget.isInnerCircle
        ? (widget.chatData['userName']?.toUpperCase() ?? 'FRIEND')
        : '';
    final String initial = userDisplayName.isNotEmpty ? userDisplayName[0].toUpperCase() : 'U';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const SizedBox(width: 40),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (userDisplayName.isNotEmpty) ...[
                Text(userDisplayName, style: GoogleFonts.outfit(color: const Color(0xFFB0BDB5), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 4),
              ],
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF86A590),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomLeft: Radius.circular(16)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Text(text, style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, height: 1.4)),
              ),
            ],
          ),
        ),
        if (widget.isInnerCircle) ...[
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: buttonGreen.withOpacity(0.2),
            child: Text(
              initial,
              style: TextStyle(fontSize: 12, color: buttonGreen, fontWeight: FontWeight.bold),
            ),
          ),
        ]
      ],
    );
  }

  ImageProvider? _getAvatarProvider(String? profileImageUrl) {
    if (profileImageUrl == null || profileImageUrl.isEmpty) return null;
    if (profileImageUrl.startsWith('data:image')) {
      try {
        final bytes = base64Decode(profileImageUrl.split(',').last);
        return MemoryImage(bytes);
      } catch (_) {
        return null;
      }
    }
    return NetworkImage(profileImageUrl);
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
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
                  color: Colors.black.withOpacity(0.12),
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
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFEBEE),
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
                  'Delete Chat',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Are you sure you want to delete this conversation? This action cannot be undone.',
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
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Cancel',
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
                          if (widget.docId != null) {
                            await FirebaseFirestore.instance
                                .collection('chat_sessions')
                                .doc(widget.docId)
                                .delete();
                          }
                          if (context.mounted) {
                            Navigator.pop(context);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Chat deleted successfully'),
                                backgroundColor: Color(0xFFE57373),
                              ),
                            );
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
        );
      },
    );
  }

  void _showExportSheet(BuildContext context, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(32),
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
              'EXPORT CHAT',
              style: GoogleFonts.outfit(
                fontSize: 12, fontWeight: FontWeight.bold,
                letterSpacing: 2.0, color: const Color(0xFFB0B0B0),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Save or share this conversation',
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
                    'Styled document with full chat',
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

  Future<void> _exportAsPdf(Map<String, dynamic> data) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final String title    = data['title'] ?? 'Chat Session';
      String summary = '';
      if (data['aiSummary'] != null && data['aiSummary'] != data['preview']) {
        summary = data['aiSummary'];
      }
      final Timestamp? ts  = data['createdAt'] is Timestamp ? data['createdAt'] : null;
      final String dateStr = ts != null
          ? DateFormat('MMMM d, yyyy  •  h:mm a').format(ts.toDate())
          : (data['createdAt'] is String ? data['createdAt'] : 'Recent');
      final List<dynamic> messages = data['messages'] ?? [];

      final doc = pw.Document();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 56),
          build: (pw.Context ctx) => [
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 20),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFF86A590), width: 1.5)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Eunoia · Chat Transcript',
                    style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF86A590), letterSpacing: 1.5),
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
                            color: PdfColor.fromInt(0xFF86A590), letterSpacing: 1.2)),
                    pw.SizedBox(height: 8),
                    pw.Text(summary,
                        style: pw.TextStyle(fontSize: 12, color: PdfColor.fromInt(0xFF555555), lineSpacing: 4)),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
            ],

            ...messages.map((m) {
              final isAi = m['role'] == 'assistant';
              final text = m['text'] ?? '';
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 16),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: isAi ? PdfColor.fromInt(0xFFFFFFFF) : PdfColor.fromInt(0xFF86A590),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                  border: isAi ? pw.Border.all(color: PdfColor.fromInt(0xFFEEEEEE)) : null,
                ),
                child: pw.Column(
                  crossAxisAlignment: isAi ? pw.CrossAxisAlignment.start : pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      isAi ? 'EUNOIA AI' : 'USER',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: isAi ? PdfColor.fromInt(0xFF86A590) : PdfColor.fromInt(0xFFEBEBEB)),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(text, style: pw.TextStyle(fontSize: 12, color: isAi ? PdfColor.fromInt(0xFF333333) : PdfColor.fromInt(0xFFFFFFFF))),
                  ],
                ),
              );
            }).toList(),

            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColor.fromInt(0xFFEEEEEE)),
            pw.SizedBox(height: 8),
            pw.Text(
              'Exported from Eunoia · Your mindful guide',
              style: pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFFAAAAAA)),
            ),
          ],
        ),
      );

      final Uint8List bytes = await doc.save();
      await Printing.sharePdf(bytes: bytes, filename: '${title.replaceAll(' ', '_')}_chat.pdf');
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

  Future<void> _exportAsImage(Map<String, dynamic> data) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final String title    = data['title'] ?? 'Chat Session';
      String summary = '';
      if (data['aiSummary'] != null && data['aiSummary'] != data['preview']) {
        summary = data['aiSummary'];
      }
      final Timestamp? ts  = data['createdAt'] is Timestamp ? data['createdAt'] : null;
      final String dateStr = ts != null
          ? DateFormat('MMMM d, yyyy').format(ts.toDate())
          : (data['createdAt'] is String ? data['createdAt'] : 'Recent');

      final imageWidget = RepaintBoundary(
        key: _exportKey,
        child: _buildExportCard(title, summary, dateStr),
      );

      late OverlayEntry entry;
      entry = OverlayEntry(
        builder: (_) => Positioned(
          left: -9999, top: -9999,
          child: Material(color: Colors.transparent, child: imageWidget),
        ),
      );
      Overlay.of(context).insert(entry);

      await Future.delayed(const Duration(milliseconds: 300));

      final RenderRepaintBoundary boundary =
          _exportKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image img = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      entry.remove();

      if (byteData == null) throw Exception('Failed to render image');

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${title.replaceAll(' ', '_')}_chat.png');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: 'My chat transcript: $title',
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

  Widget _buildExportCard(String title, String summary, String dateStr) {
    final Color primary = const Color(0xFF86A590);
    final Color bg      = const Color(0xFFF9F9F7);

    return Container(
      width: 400,
      color: bg,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Text(title, style: GoogleFonts.playfairDisplay(
            fontSize: 28, fontWeight: FontWeight.w600, color: const Color(0xFF333333))),
          const SizedBox(height: 16),
          if (summary.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3EE),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE1E6DC)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 14, color: primary),
                      const SizedBox(width: 6),
                      Text('AI Insight', style: GoogleFonts.outfit(
                        fontSize: 10, fontWeight: FontWeight.bold, color: primary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(summary, style: GoogleFonts.outfit(
                    fontSize: 14, color: const Color(0xFF555555), height: 1.5)),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          Divider(color: Colors.grey[300]),
          const SizedBox(height: 16),
          Center(
            child: Text('eunoia.com/chat', style: GoogleFonts.outfit(
              fontSize: 10, color: Colors.grey[400])),
          ),
        ],
      ),
    );
  }
}
