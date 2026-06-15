import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/post.dart';
import 'post_detail.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFF2F1EC);
  final Color textColorMain = const Color(0xFF333333);
  final Color textColorSub = const Color(0xFF888888);
  bool _markedAsRead = false;

  @override
  void initState() {
    super.initState();
    _markAllAsRead();
  }

  Future<void> _markAllAsRead() async {
    if (currentUser == null || _markedAsRead) return;

    try {
      final query = await FirebaseFirestore.instance
          .collection('notifications')
          .where('to', isEqualTo: currentUser!.uid)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in query.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();

      if (mounted) {
        setState(() => _markedAsRead = true);
      }
    } catch (e) {
      debugPrint("Error marking notifications as read: $e");
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    bool isDanger = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (isDanger ? const Color(0xFFE57373) : primaryGreen).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDanger ? Icons.delete_outline_rounded : Icons.check_circle_outline_rounded,
                  color: isDanger ? const Color(0xFFE57373) : primaryGreen,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(title,
                  style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold, color: textColorMain),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(message,
                  style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF888888), height: 1.5),
                  textAlign: TextAlign.center),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Text('Cancel', style: GoogleFonts.outfit(color: const Color(0xFF888888), fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDanger ? const Color(0xFFE57373) : primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      child: Text(confirmLabel, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
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

  Future<void> _clearAllNotifications() async {
    if (currentUser == null) return;
    final confirm = await _showConfirmDialog(
      title: 'Clear All Notifications',
      message: 'All notifications will be permanently removed. This cannot be undone.',
      confirmLabel: 'Clear All',
      isDanger: true,
    );
    if (confirm != true) return;
    final query = await FirebaseFirestore.instance
        .collection('notifications')
        .where('to', isEqualTo: currentUser!.uid)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in query.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Map<String, List<QueryDocumentSnapshot>> _groupByDate(
      List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final Map<String, List<QueryDocumentSnapshot>> groups = {
      'Today': [],
      'Yesterday': [],
      'Earlier': [],
    };
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final ts = data['timestamp'] as Timestamp?;
      if (ts == null) { groups['Earlier']!.add(doc); continue; }
      final dt = ts.toDate();
      final day = DateTime(dt.year, dt.month, dt.day);
      if (day == today) groups['Today']!.add(doc);
      else if (day == yesterday) groups['Yesterday']!.add(doc);
      else groups['Earlier']!.add(doc);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(body: Center(child: Text('Please login to view notifications.', style: GoogleFonts.outfit())));
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF333333), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFF333333),
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF666666), size: 22),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            color: Colors.white,
            elevation: 8,
            onSelected: (value) async {
              if (value == 'read_all') {
                setState(() => _markedAsRead = false);
                await _markAllAsRead();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('All marked as read', style: GoogleFonts.outfit()),
                      backgroundColor: primaryGreen,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  );
                }
              } else if (value == 'clear_all') {
                await _clearAllNotifications();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'read_all',
                child: Row(
                  children: [
                    Icon(Icons.done_all_rounded, color: primaryGreen, size: 20),
                    const SizedBox(width: 12),
                    Text('Mark All as Read', style: GoogleFonts.outfit(fontSize: 14)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline_rounded, color: Color(0xFFE57373), size: 20),
                    const SizedBox(width: 12),
                    Text('Clear All', style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFFE57373))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('to', isEqualTo: currentUser!.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: GoogleFonts.outfit()));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF7C9C84)));
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: primaryGreen.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.notifications_none_rounded,
                        size: 52, color: primaryGreen.withOpacity(0.4)),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'All caught up!',
                    style: GoogleFonts.playfairDisplay(
                        color: textColorMain, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No new notifications right now.',
                    style: GoogleFonts.outfit(color: const Color(0xFF888888), fontSize: 14),
                  ),
                ],
              ),
            );
          }

          final grouped = _groupByDate(docs);
          final sections = ['Today', 'Yesterday', 'Earlier'];

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            children: sections.map((section) {
              final items = grouped[section]!;
              if (items.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 12),
                    child: Text(
                      section.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: const Color(0xFF888888),
                      ),
                    ),
                  ),
                  ...items.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    bool isRead = data['isRead'] ?? true;
                    final String type = data['type'] ?? '';

                    Widget card;
                    if (type == 'friend_request') {
                      card = _buildFriendRequestCard(doc.id, data, isRead);
                    } else {
                      card = _buildGenericCard(doc.id, data, isRead);
                    }

                    return Dismissible(
                      key: Key(doc.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE57373),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
                      ),
                      onDismissed: (_) async {
                        await FirebaseFirestore.instance
                            .collection('notifications')
                            .doc(doc.id)
                            .delete();
                      },
                      child: card,
                    );
                  }),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildBaseCard({required Widget child, bool isRead = true}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : const Color(0xFFF0F7F2), // Subtle green for unread
        borderRadius: BorderRadius.circular(24),
        border: isRead ? null : Border.all(color: primaryGreen.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildFriendRequestCard(String notificationId, Map<String, dynamic> data, bool isRead) {
    bool isPending = data['status'] == 'pending';
    String senderName = data['senderName'] ?? 'Someone';
    String? senderPhoto = data['senderPhoto'];
    Timestamp? ts = data['timestamp'] as Timestamp?;
    String timeStr = ts != null ? timeago.format(ts.toDate()).toUpperCase() : 'NOW';

    ImageProvider? imageProvider;
    if (senderPhoto != null) {
      if (senderPhoto.startsWith('data:image')) {
        imageProvider = MemoryImage(base64Decode(senderPhoto.split(',').last));
      } else {
        imageProvider = NetworkImage(senderPhoto);
      }
    }

    return _buildBaseCard(
        isRead: isRead,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: primaryGreen.withOpacity(0.1),
                  backgroundImage: imageProvider,
                  child: imageProvider == null ? Icon(Icons.person, color: primaryGreen, size: 20) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPending ? 'New Friend Request' : 'Friend Request Accepted',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textColorMain,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data['message'] ?? '$senderName sent you a friend request.',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: const Color(0xFF888888),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        timeStr,
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: const Color(0xFFB3B3B3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isPending) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _handleFriendRequest(notificationId, data, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: primaryGreen,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Accept',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _handleFriendRequest(notificationId, data, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Decline',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF4A4A4A),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            ]
          ],
        )
    );
  }

  Future<void> _handleFriendRequest(String notificationId, Map<String, dynamic> data, bool accept) async {
    final senderId = data['from'];
    final receiverId = data['to'];

    try {
      if (accept) {
        // Update both users following/followers lists to make them "Friends"
        await FirebaseFirestore.instance.collection('users').doc(receiverId).update({
          'following': FieldValue.arrayUnion([senderId]),
          'followers': FieldValue.arrayUnion([senderId]),
        });
        await FirebaseFirestore.instance.collection('users').doc(senderId).update({
          'following': FieldValue.arrayUnion([receiverId]),
          'followers': FieldValue.arrayUnion([receiverId]),
        });

        // Update notification
        await FirebaseFirestore.instance.collection('notifications').doc(notificationId).update({
          'status': 'accepted',
          'message': 'You are now connected with ${data['senderName'] ?? "a new friend"}.',
        });

        // Optionally send a notification back to the sender
        await FirebaseFirestore.instance.collection('notifications').add({
          'from': receiverId,
          'to': senderId,
          'type': 'friend_accepted',
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
          'message': '${currentUser!.displayName ?? "Someone"} accepted your friend request.',
        });

      } else {
        // For decline, we just delete the notification or update status
        await FirebaseFirestore.instance.collection('notifications').doc(notificationId).delete();
      }
    } catch (e) {
      debugPrint("Error handling friend request: $e");
    }
  }

  Widget _buildGenericCard(String notificationId, Map<String, dynamic> data, bool isRead) {
    String message = data['message'] ?? 'New notification';
    String title = data['title'] ?? 'Notification';
    String type = data['type'] ?? '';
    
    if (type == 'post_comment') {
      message = '${data['fromName'] ?? 'Someone'} commented on your post.';
      title = 'New Comment';
    } else if (type == 'comment_reply') {
      message = '${data['fromName'] ?? 'Someone'} replied to your comment.';
      title = 'New Reply';
    }

    Timestamp? ts = data['timestamp'] as Timestamp?;
    String timeStr = ts != null ? timeago.format(ts.toDate()).toUpperCase() : 'NOW';

    // UI configurations based on type
    Color iconColor;
    Color bgColor;
    IconData iconData;

    switch (type) {
      case 'recommendation':
        iconColor = const Color(0xFFC5A880);
        bgColor = const Color(0xFFC5A880).withOpacity(0.1);
        iconData = Icons.spa_rounded;
        break;
      case 'post_comment':
      case 'comment_reply':
        iconColor = primaryGreen;
        bgColor = primaryGreen.withOpacity(0.1);
        iconData = Icons.chat_bubble_outline_rounded;
        break;
      case 'reminder':
      case 'booking':
        iconColor = const Color(0xFF5C8CB9);
        bgColor = const Color(0xFF5C8CB9).withOpacity(0.1);
        iconData = Icons.calendar_today_rounded;
        if (title == 'Notification') title = 'Upcoming Session';
        break;
      case 'daily':
        iconColor = const Color(0xFFE5A83E);
        bgColor = const Color(0xFFE5A83E).withOpacity(0.1);
        iconData = Icons.wb_sunny_outlined;
        break;
      default:
        iconColor = const Color(0xFF888888);
        bgColor = const Color(0xFF888888).withOpacity(0.1);
        iconData = Icons.notifications_none_rounded;
    }

    return GestureDetector(
      onTap: () async {
        if ((type == 'post_comment' || type == 'comment_reply') && data['postId'] != null) {
          final postDoc = await FirebaseFirestore.instance.collection('posts').doc(data['postId']).get();
          if (postDoc.exists && mounted) {
            final post = Post.fromFirestore(postDoc);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PostDetailScreen(post: post)),
            );
          }
        }
      },
      child: _buildBaseCard(
        isRead: isRead,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColorMain,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: const Color(0xFF666666),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    timeStr,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: const Color(0xFFB3B3B3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
