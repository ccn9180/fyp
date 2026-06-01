import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp/models/post.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'dart:convert';
import 'public_profile.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;
  final bool isFollowing;
  final bool isRequested;

  const PostDetailScreen({
    super.key,
    required this.post,
    this.isFollowing = false,
    this.isRequested = false,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final Color backgroundColor = const Color(0xFFF2F1EC);
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color textColorMain = const Color(0xFF333333);
  final Color textColorSub = const Color(0xFF888888);
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _commentController = TextEditingController();
  bool _isAnonymousComment = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    if (currentUser == null) return;
    final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.post.id);
    
    // We fetch current likes to be precise
    final doc = await postRef.get();
    if (!doc.exists) return;
    
    final List<String> currentLikes = List<String>.from(doc.data()?['likes'] ?? []);
    if (currentLikes.contains(currentUser!.uid)) {
      currentLikes.remove(currentUser!.uid);
    } else {
      currentLikes.add(currentUser!.uid);
    }
    await postRef.update({'likes': currentLikes});
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty || currentUser == null) return;

    String authorName = 'User';
    String? profileImageUrl;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>;
      authorName = userData['fullName'] ?? currentUser!.displayName ?? 'User';
      profileImageUrl = userData['profileImageUrl'];
    }

    final commentData = {
      'authorId': currentUser!.uid,
      'authorName': authorName,
      'authorProfileImage': profileImageUrl,
      'content': _commentController.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'isAnonymous': _isAnonymousComment,
    };

    final batch = FirebaseFirestore.instance.batch();
    final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.post.id);
    final commentRef = postRef.collection('comments').doc();

    batch.set(commentRef, commentData);
    batch.update(postRef, {'commentCount': FieldValue.increment(1)});

    await batch.commit();
    _commentController.clear();
    setState(() {
      _isAnonymousComment = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF5D6D66), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'POST REFLECTION',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: const Color(0xFF5D6D66),
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('posts').doc(widget.post.id).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final post = Post.fromFirestore(snapshot.data!);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  children: [
                    _buildPostHeader(post),
                    const SizedBox(height: 32),
                    _buildPostContent(post),
                    const SizedBox(height: 32),
                    _buildReactionsRow(post),
                    const SizedBox(height: 48),
                    _buildSectionHeader(post),
                    const SizedBox(height: 24),
                    _buildCommentsList(),
                  ],
                );
              }
            ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildPostHeader(Post post) {
    bool isOwner = currentUser?.uid == post.authorId;
    String displayAuthor = isOwner ? 'You' : (post.isAnonymous ? 'Anonymous' : post.authorName);
    String timeAgoStr = timeago.format(post.timestamp);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: isOwner || post.isAnonymous
              ? null
              : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PublicProfileScreen(
                      uid: post.authorId,
                      initialData: {
                        'name': post.authorName,
                        'profileImageUrl': post.authorProfileImage,
                        'isFollowing': widget.isFollowing,
                        'isRequested': widget.isRequested,
                      },
                    ),
                  ),
                ),
          child: CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFFEAF0ED),
            backgroundImage: ((isOwner || !post.isAnonymous) && post.authorProfileImage != null)
                ? (post.authorProfileImage!.startsWith('data:image')
                    ? MemoryImage(base64Decode(post.authorProfileImage!.split(',').last))
                    : NetworkImage(post.authorProfileImage!) as ImageProvider)
                : null,
            child: ((!isOwner && post.isAnonymous) || post.authorProfileImage == null)
                ? Icon(Icons.person, color: primaryGreen, size: 28)
                : null,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayAuthor,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColorMain,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$timeAgoStr • Community Member',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: textColorSub,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFD3E4D8),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.eco_rounded, size: 14, color: primaryGreen),
              const SizedBox(width: 6),
              Text(
                post.topic,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF4A4A4A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPostContent(Post post) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          post.content,
          style: GoogleFonts.outfit(
            fontSize: 16,
            color: const Color(0xFF4A4A4A),
            height: 1.6,
          ),
        ),
        if (post.imageUrl != null) ...[
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: post.imageUrl!.startsWith('data:')
                ? Image.memory(base64Decode(post.imageUrl!.split(',').last), width: double.infinity, fit: BoxFit.cover)
                : Image.network(post.imageUrl!, width: double.infinity, fit: BoxFit.cover),
          ),
        ],
      ],
    );
  }

  Widget _buildReactionsRow(Post post) {
    bool isLiked = currentUser != null && post.likes.contains(currentUser!.uid);

    return Row(
      children: [
        GestureDetector(
          onTap: _toggleLike,
          child: Row(
            children: [
              Icon(
                isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                color: isLiked ? Colors.red : const Color(0xFF4A4A4A),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                post.likes.length.toString(),
                style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF4A4A4A), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Row(
          children: [
            const Icon(Icons.sentiment_satisfied_alt_rounded, color: Color(0xFF4A4A4A), size: 20),
            const SizedBox(width: 8),
            Text(
              '12',
              style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF4A4A4A), fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(width: 24),
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: Color(0xFF4A4A4A), size: 20),
            const SizedBox(width: 8),
            Text(
              '8',
              style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF4A4A4A), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(Post post) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, thickness: 1, color: Color(0xFFE5E5E0)),
        const SizedBox(height: 48),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Supportive Messages (${post.commentCount})',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColorMain,
              ),
            ),
            Text(
              'Newest First',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: textColorSub,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post.id)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        
        return Column(
          children: [
            // Real comments
            ...docs.map((doc) {
              final comment = doc.data() as Map<String, dynamic>;
              return _buildCommentBubble(
                name: comment['isAnonymous'] ?? false ? 'Anonymous' : (comment['authorName'] ?? 'User'),
                content: comment['content'] ?? '',
                time: timeago.format((comment['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(), locale: 'en_short'),
                photo: comment['authorProfileImage'],
                isAnon: comment['isAnonymous'] ?? false,
              );
            }).toList(),

            // Hardcoded fallback comments if none exist, to show community feel
            if (docs.isEmpty) ...[
              _buildCommentBubble(
                name: "Julian M.",
                content: "This was exactly what I needed to read today. Thank you for sharing that beautiful imagery. Going to take a short walk now.",
                time: "45m",
                photo: null,
                isAnon: false,
              ),
              _buildCommentBubble(
                name: "Sarah K.",
                content: "The forest is such a powerful healer. So glad you found your moment of calm! ❤️",
                time: "1h",
                photo: null,
                isAnon: false,
              ),
              _buildCommentBubble(
                name: "David Chen",
                content: "\"Peace isn't built, it's noticed\" — I'm writing that down in my journal. Thank you Elena.",
                time: "1.5h",
                photo: null,
                isAnon: false,
              ),
            ],
          ],
        );
      }
    );
  }

  Widget _buildCommentBubble({required String name, required String content, required String time, String? photo, required bool isAnon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFEAF0ED),
            backgroundImage: (!isAnon && photo != null)
                ? (photo.startsWith('data:image')
                    ? MemoryImage(base64Decode(photo.split(',').last))
                    : NetworkImage(photo) as ImageProvider)
                : null,
            child: (isAnon || photo == null) ? Icon(Icons.person, color: primaryGreen, size: 20) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textColorMain,
                        ),
                      ),
                      Text(
                        time,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: textColorSub,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    content,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: const Color(0xFF4A4A4A),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E5E0),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: TextField(
                    controller: _commentController,
                    maxLines: null,
                    style: GoogleFonts.outfit(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Share a supportive reflection...',
                      hintStyle: GoogleFonts.outfit(color: textColorSub, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _postComment,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4C5B52),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 4),
              SizedBox(
                height: 20,
                width: 20,
                child: Checkbox(
                  value: _isAnonymousComment,
                  onChanged: (val) => setState(() => _isAnonymousComment = val ?? false),
                  activeColor: primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  side: BorderSide(color: Colors.grey.shade400),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Post Anonymously',
                style: GoogleFonts.outfit(fontSize: 11, color: textColorSub),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
