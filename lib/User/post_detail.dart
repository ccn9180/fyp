import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post.dart';
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

class _PostDetailScreenState extends State<PostDetailScreen>
    with SingleTickerProviderStateMixin {
  // ── Palette ────────────────────────────────────────────────────
  static const Color _bg = Color(0xFFF2F1EC);
  static const Color _green = Color(0xFF7C9C84);
  static const Color _darkText = Color(0xFF2B2B2B);
  static const Color _subText = Color(0xFF9B9B9B);
  static const Color _cardBg = Colors.white;
  static const Color _inputBg = Color(0xFFF0EFE9);

  final User? _me = FirebaseAuth.instance.currentUser;
  final TextEditingController _commentCtrl = TextEditingController();
  final FocusNode _commentFocus = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();

  bool _isAnonymous = false;
  String? _replyingToId;
  String? _replyingToName;
  String? _replyingToAuthorId;

  late AnimationController _likeAnimCtrl;
  late Animation<double> _likeScaleAnim;

  @override
  void initState() {
    super.initState();
    _likeAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _likeScaleAnim = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _likeAnimCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _commentFocus.dispose();
    _scrollCtrl.dispose();
    _likeAnimCtrl.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────
  Future<void> _toggleLike() async {
    if (_me == null) return;
    HapticFeedback.lightImpact();
    _likeAnimCtrl.forward().then((_) => _likeAnimCtrl.reverse());

    final ref = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.post.id);
    final doc = await ref.get();
    if (!doc.exists) return;
    final likes = List<String>.from(doc.data()?['likes'] ?? []);
    likes.contains(_me!.uid) ? likes.remove(_me!.uid) : likes.add(_me!.uid);
    await ref.update({'likes': likes});
  }

  Future<void> _toggleSave(bool isSaved) async {
    if (_me == null) return;
    HapticFeedback.selectionClick();
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(_me!.uid)
        .collection('saved_posts')
        .doc(widget.post.id);
    isSaved ? await ref.delete() : await ref.set({'savedAt': FieldValue.serverTimestamp()});
  }

  Future<void> _toggleEmojiReaction(String emoji) async {
    if (_me == null) return;
    HapticFeedback.mediumImpact();
    final ref = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.post.id);
    final doc = await ref.get();
    if (!doc.exists) return;
    final data = doc.data()!;
    Map<String, List<String>> reactions = {};
    if (data['emojiReactions'] != null) {
      (data['emojiReactions'] as Map<String, dynamic>).forEach((k, v) {
        reactions[k] = List<String>.from(v);
      });
    }
    final alreadyThis = reactions[emoji]?.contains(_me!.uid) ?? false;
    if (alreadyThis) return;
    reactions.forEach((k, v) => v.remove(_me!.uid));
    reactions.removeWhere((k, v) => v.isEmpty);
    reactions.putIfAbsent(emoji, () => []).add(_me!.uid);
    await ref.update({'emojiReactions': reactions});
  }

  Future<void> _postComment() async {
    if (_commentCtrl.text.trim().isEmpty || _me == null) return;
    HapticFeedback.lightImpact();

    String authorName = 'User';
    String? profileImage;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_me!.uid)
        .get();
    if (userDoc.exists) {
      final d = userDoc.data()!;
      final nick = d['nickname'] as String?;
      authorName = (nick != null && nick.trim().isNotEmpty)
          ? nick
          : (d['fullName'] ?? _me!.displayName ?? 'User');
      profileImage = d['profileImageUrl'];
    }

    final batch = FirebaseFirestore.instance.batch();
    final postRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.post.id);
    final commentRef = postRef.collection('comments').doc();

    batch.set(commentRef, {
      'authorId': _me!.uid,
      'authorName': authorName,
      'authorProfileImage': profileImage,
      'content': _commentCtrl.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'isAnonymous': _isAnonymous,
      if (_replyingToId != null) 'parentId': _replyingToId,
    });
    batch.update(postRef, {'commentCount': FieldValue.increment(1)});

    // Notifications
    if (_replyingToId != null &&
        _replyingToAuthorId != null &&
        _replyingToAuthorId != _me!.uid) {
      batch.set(FirebaseFirestore.instance.collection('notifications').doc(), {
        'to': _replyingToAuthorId,
        'from': _me!.uid,
        'fromName': _isAnonymous ? 'Anonymous' : authorName,
        'type': 'comment_reply',
        'postId': widget.post.id,
        'title': 'New Reply',
        'message': '${_isAnonymous ? 'Anonymous' : authorName} replied to your comment.',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } else if (widget.post.authorId != _me!.uid && _replyingToId == null) {
      batch.set(FirebaseFirestore.instance.collection('notifications').doc(), {
        'to': widget.post.authorId,
        'from': _me!.uid,
        'fromName': _isAnonymous ? 'Anonymous' : authorName,
        'type': 'post_comment',
        'postId': widget.post.id,
        'title': 'New Comment',
        'message': '${_isAnonymous ? 'Anonymous' : authorName} commented on your post.',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    }

    await batch.commit();
    _commentCtrl.clear();
    _commentFocus.unfocus();
    setState(() {
      _isAnonymous = false;
      _replyingToId = null;
      _replyingToName = null;
      _replyingToAuthorId = null;
    });
  }

  // ── Build ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      extendBodyBehindAppBar: false,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.post.id)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData || !snap.data!.exists) {
                  return const Center(
                      child: CircularProgressIndicator(color: _green));
                }
                final post = Post.fromFirestore(snap.data!);
                return ListView(
                  controller: _scrollCtrl,
                  padding: EdgeInsets.zero,
                  children: [
                    _buildHeroCard(post),
                    const SizedBox(height: 8),
                    _buildCommentsSection(post),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ── App Bar ────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: Center(
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: Color(0xFF333333),
              ),
            ),
          ),
        ),
      ),
      leadingWidth: 64,
      title: Text(
        'REFLECTION',
        style: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: const Color(0xFF5D6D66),
        ),
      ),
      centerTitle: true,
      actions: [
        if (_me != null)
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(_me!.uid)
                .collection('saved_posts')
                .doc(widget.post.id)
                .snapshots(),
            builder: (_, snap) {
              final isSaved = snap.hasData && snap.data!.exists;
              return GestureDetector(
                onTap: () => _toggleSave(isSaved),
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSaved
                        ? _green.withOpacity(0.12)
                        : _cardBg,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Icon(
                    isSaved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: isSaved ? _green : _darkText,
                    size: 20,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // ── Hero Post Card ─────────────────────────────────────────────
  Widget _buildHeroCard(Post post) {
    final isOwner = _me?.uid == post.authorId;
    final displayName =
        isOwner ? 'You' : (post.isAnonymous ? 'Anonymous' : post.authorName);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                // Avatar
                GestureDetector(
                  onTap: isOwner || post.isAnonymous
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PublicProfileScreen(
                              uid: post.authorId,
                              initialData: {
                                'name': post.authorName,
                                'profileImageUrl': post.authorProfileImage,
                                'isFollowing': widget.isFollowing,
                                'isRequested': widget.isRequested,
                              },
                            ),
                          )),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFFDEECE3),
                        backgroundImage: ((isOwner || !post.isAnonymous) &&
                                post.authorProfileImage != null)
                            ? (post.authorProfileImage!.startsWith('data:image')
                                ? MemoryImage(base64Decode(
                                    post.authorProfileImage!.split(',').last))
                                : NetworkImage(post.authorProfileImage!)
                                    as ImageProvider)
                            : null,
                        child: ((!isOwner && post.isAnonymous) ||
                                post.authorProfileImage == null)
                            ? const Icon(Icons.person, color: _green, size: 24)
                            : null,
                      ),
                      if (!post.isAnonymous)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFF5AB87A),
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: _cardBg, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _darkText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeago.format(post.timestamp),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: _subText,
                        ),
                      ),
                    ],
                  ),
                ),
                // Topic chip
                _topicChip(post.topic),
              ],
            ),
          ),

          // Divider
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Divider(height: 1, color: Color(0xFFF0EFE9)),
          ),

          // Post content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Text(
              post.content,
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: const Color(0xFF444444),
                height: 1.7,
                letterSpacing: 0.1,
              ),
            ),
          ),

          // Post image
          if (post.imageUrl != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: post.imageUrl!.startsWith('data:')
                    ? Image.memory(
                        base64Decode(post.imageUrl!.split(',').last),
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        post.imageUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
              ),
            ),

          // Divider before reactions
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(height: 1, color: Color(0xFFF0EFE9)),
          ),

          // Integrated reactions row (Responsive Wrap, no overflow)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: _buildReactionsRow(post),
          ),
        ],
      ),
    );
  }

  Widget _topicChip(String topic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD3E8DB), Color(0xFFBFDDCA)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.eco_rounded, size: 12, color: _green),
          const SizedBox(width: 5),
          Text(
            topic,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF3D6B50),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ── Inline Reactions Row (Integrated in card, responsive wrap) ──
  Widget _buildReactionsRow(Post post) {
    final isLiked = _me != null && post.likes.contains(_me!.uid);
    bool userReactedEmoji = false;
    post.emojiReactions.forEach((emoji, users) {
      if (_me != null && users.contains(_me!.uid)) userReactedEmoji = true;
    });

    return Row(
      children: [
        // Heart like
        ScaleTransition(
          scale: _likeScaleAnim,
          child: GestureDetector(
            onTap: _toggleLike,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_outline_rounded,
                    key: ValueKey(isLiked),
                    color: isLiked ? const Color(0xFFE8526A) : _subText,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  post.likes.length.toString(),
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isLiked ? const Color(0xFFE8526A) : _subText,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Vertical divider
        Container(
          width: 1,
          height: 16,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          color: const Color(0xFFEDEDE8),
        ),

        // Emoji reactions (Wraps responsively, avoiding any sub-pixel overflow)
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...post.emojiReactions.entries.map((entry) {
                final userReacted = _me != null &&
                    entry.value.contains(_me!.uid);
                return GestureDetector(
                  onTap: () {
                    if (userReacted) {
                      _showEmojiPicker();
                    } else {
                      _toggleEmojiReaction(entry.key);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: userReacted
                          ? _green.withOpacity(0.12)
                          : const Color(0xFFF5F5F2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: userReacted
                            ? _green.withOpacity(0.4)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(entry.key,
                            style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(
                          entry.value.length.toString(),
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color:
                                userReacted ? _green : _subText,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              // Add reaction button
              if (!userReactedEmoji)
                GestureDetector(
                  onTap: _showEmojiPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE0E0DA),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_reaction_outlined,
                            size: 14, color: _subText),
                        const SizedBox(width: 4),
                        Text(
                          'React',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: _subText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _showEmojiPicker() {
    HapticFeedback.lightImpact();
    final emojis = ['🤗', '💖', '💪', '😢', '🙌', '✨'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'How does this make you feel?',
              style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _darkText),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: emojis.map((emoji) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _toggleEmojiReaction(emoji);
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(emoji,
                          style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Comments Section ───────────────────────────────────────────
  Widget _buildCommentsSection(Post post) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post.id)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];

        List<DocumentSnapshot> parents = [];
        Map<String, List<DocumentSnapshot>> replies = {};
        for (var doc in docs) {
          final d = doc.data() as Map<String, dynamic>;
          final pid = d['parentId'] as String?;
          if (pid != null) {
            replies.putIfAbsent(pid, () => []).add(doc);
          } else {
            parents.add(doc);
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header (increased vertical spacing below it to separate it from the content card)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Row(
                children: [
                  Text(
                    'Supportive Messages',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _darkText,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${post.commentCount}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _green,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (parents.isEmpty)
              _buildEmptyComments()
            else
              ...parents.map((doc) {
                final comment = doc.data() as Map<String, dynamic>;
                final cId = doc.id;
                final docReplies = replies[cId] ?? [];

                return Column(
                  children: [
                    _buildCommentTile(
                      id: cId,
                      name: (comment['isAnonymous'] ?? false)
                          ? 'Anonymous'
                          : (comment['authorName'] ?? 'User'),
                      content: comment['content'] ?? '',
                      time: timeago.format(
                        (comment['timestamp'] as Timestamp?)?.toDate() ??
                            DateTime.now(),
                        locale: 'en_short',
                      ),
                      photo: comment['authorProfileImage'],
                      isAnon: comment['isAnonymous'] ?? false,
                      authorId: comment['authorId'] ?? '',
                      isReply: false,
                    ),
                    ...docReplies.reversed.map((rDoc) {
                      final r = rDoc.data() as Map<String, dynamic>;
                      return _buildCommentTile(
                        id: rDoc.id,
                        name: (r['isAnonymous'] ?? false)
                            ? 'Anonymous'
                            : (r['authorName'] ?? 'User'),
                        content: r['content'] ?? '',
                        time: timeago.format(
                          (r['timestamp'] as Timestamp?)?.toDate() ??
                              DateTime.now(),
                          locale: 'en_short',
                        ),
                        photo: r['authorProfileImage'],
                        isAnon: r['isAnonymous'] ?? false,
                        authorId: r['authorId'] ?? '',
                        isReply: true,
                      );
                    }),
                  ],
                );
              }),
          ],
        );
      },
    );
  }

  Widget _buildEmptyComments() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _green.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  color: _green, size: 28),
            ),
            const SizedBox(height: 16),
            Text('Be the first to respond',
                style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _darkText)),
            const SizedBox(height: 8),
            Text(
              'Share a supportive message with this community member.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  fontSize: 14, color: _subText, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentTile({
    required String id,
    required String name,
    required String content,
    required String time,
    String? photo,
    required bool isAnon,
    required String authorId,
    required bool isReply,
  }) {
    final isMe = _me?.uid == authorId;

    return Padding(
      padding: EdgeInsets.only(
        left: isReply ? 56 : 16,
        right: 16,
        bottom: 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: isReply ? 16 : 20,
            backgroundColor: const Color(0xFFDEECE3),
            backgroundImage: (!isAnon && photo != null)
                ? (photo.startsWith('data:image')
                    ? MemoryImage(base64Decode(photo.split(',').last))
                    : NetworkImage(photo) as ImageProvider)
                : null,
            child: (isAnon || photo == null)
                ? Icon(Icons.person, color: _green, size: isReply ? 16 : 20)
                : null,
          ),
          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bubble upgraded to a clean white card with subtle shadows and border, matching counsellor page style
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                    border: Border.all(
                      color: isMe ? _green.withOpacity(0.3) : const Color(0xFFEAEAE4),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isMe ? 'You' : name,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isMe ? _green : _darkText,
                              ),
                            ),
                          ),
                          Text(
                            time,
                            style: GoogleFonts.outfit(
                                fontSize: 11, color: _subText),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        content,
                        softWrap: true,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: const Color(0xFF444444),
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),

                // Reply button
                if (!isReply)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _replyingToId = id;
                        _replyingToName = name;
                        _replyingToAuthorId = authorId;
                      });
                      _commentFocus.requestFocus();
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Text(
                        'Reply',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: _green,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Comment Input Bar ──────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: _cardBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Replying-to banner
          if (_replyingToId != null)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.reply_rounded,
                      size: 16, color: _green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Replying to $_replyingToName',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: _green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _replyingToId = null;
                      _replyingToName = null;
                      _replyingToAuthorId = null;
                    }),
                    child: const Icon(Icons.close_rounded,
                        size: 18, color: _green),
                  ),
                ],
              ),
            ),

          // Input row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Anonymous toggle
              GestureDetector(
                onTap: () =>
                    setState(() => _isAnonymous = !_isAnonymous),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _isAnonymous
                        ? _green.withOpacity(0.12)
                        : _inputBg,
                    shape: BoxShape.circle,
                    border: _isAnonymous
                        ? Border.all(
                            color: _green.withOpacity(0.3))
                        : null,
                  ),
                  child: Icon(
                    _isAnonymous
                        ? Icons.visibility_off_rounded
                        : Icons.person_outline_rounded,
                    color: _isAnonymous ? _green : _subText,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Text field
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: _inputBg,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _commentCtrl,
                    focusNode: _commentFocus,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    style: GoogleFonts.outfit(
                        fontSize: 14, color: _darkText),
                    decoration: InputDecoration(
                      hintText: _isAnonymous
                          ? 'Write anonymously…'
                          : 'Share a supportive message…',
                      hintStyle: GoogleFonts.outfit(
                          color: _subText, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Send button
              GestureDetector(
                onTap: _postComment,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF7C9C84), Color(0xFF5A7E62)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),

          // Anonymous label
          if (_isAnonymous)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 54),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 12, color: _green),
                  const SizedBox(width: 4),
                  Text(
                    'Posting anonymously — your name will be hidden',
                    style: GoogleFonts.outfit(
                        fontSize: 11, color: _green),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
