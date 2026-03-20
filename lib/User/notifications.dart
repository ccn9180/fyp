import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFEAE9E4);
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

          final notifications = snapshot.data!.docs;

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 80, color: Colors.grey[200]),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final data = doc.data() as Map<String, dynamic>;
              bool isRead = data['isRead'] ?? true;
              final String type = data['type'] ?? '';

              if (type == 'friend_request') {
                return _buildFriendRequestCard(doc.id, data, isRead);
              } else {
                return _buildGenericCard(data, isRead);
              }
            },
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

  Widget _buildGenericCard(Map<String, dynamic> data, bool isRead) {
    String message = data['message'] ?? 'New notification';
    Timestamp? ts = data['timestamp'] as Timestamp?;
    String timeStr = ts != null ? timeago.format(ts.toDate()).toUpperCase() : 'NOW';

    return _buildBaseCard(
      isRead: isRead,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFF4F7F5),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.info_outline_rounded, color: primaryGreen, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: const Color(0xFF4A4A4A),
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
    );
  }
}
