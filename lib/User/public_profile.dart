import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/post.dart';
import 'search_friend.dart';

class PublicProfileScreen extends StatefulWidget {
  final String uid;
  final Map<String, dynamic>? initialData;

  const PublicProfileScreen({super.key, required this.uid, this.initialData});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFF2F1EC);
  final Color textColorMain = const Color(0xFF333333);
  final Color textColorSub = const Color(0xFF888888);

  User? get currentUser => FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) return const Scaffold(body: Center(child: Text('Please login')));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).snapshots(),
      builder: (context, userSnapshot) {
        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;

        final String name = userData?['fullName'] ?? widget.initialData?['name'] ?? 'User';
        final String email = userData?['email'] ?? widget.initialData?['email'] ?? '';
        final String bio = userData?['bio'] ?? '';
        final String? profileImageUrl = userData?['profileImageUrl'] ?? widget.initialData?['profileImageUrl'];
        final List<String> followers = List<String>.from(userData?['followers'] ?? []);
        final List<String> following = List<String>.from(userData?['following'] ?? []);

        return Scaffold(
          backgroundColor: backgroundColor,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 0,
                floating: true,
                backgroundColor: backgroundColor,
                elevation: 0,
                scrolledUnderElevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF333333), size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  'PROFILE',
                  style: GoogleFonts.outfit(
                    color: textColorSub,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
                centerTitle: true,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Column(
                    children: [
                      // Profile Identity
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: primaryGreen.withOpacity(0.1), width: 2),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: CircleAvatar(
                          radius: 54,
                          backgroundColor: primaryGreen.withOpacity(0.05),
                          backgroundImage: profileImageUrl != null
                              ? (profileImageUrl.startsWith('data:image')
                              ? MemoryImage(base64Decode(profileImageUrl.split(',').last))
                              : NetworkImage(profileImageUrl) as ImageProvider)
                              : null,
                          child: profileImageUrl == null ? Icon(Icons.person, size: 54, color: primaryGreen.withOpacity(0.5)) : null,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        name,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: textColorMain,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email.toUpperCase(),
                        style: GoogleFonts.outfit(
                          color: textColorSub, 
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            bio,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: const Color(0xFF666666),
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),

                      // Stats Card
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
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
                            Expanded(child: _buildStatColumn('Followers', followers.length)),
                            Container(width: 1, height: 30, color: Colors.grey.withOpacity(0.1)),
                            Expanded(child: _buildStatColumn('Following', following.length)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Action Button
                      if (widget.uid != currentUser!.uid)
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots(),
                          builder: (context, currentSnapshot) {
                            final currentData = currentSnapshot.data?.data() as Map<String, dynamic>?;

                            final bool isFollowing = currentSnapshot.hasData
                                ? List<String>.from(currentData?['following'] ?? []).contains(widget.uid)
                                : (widget.initialData?['isFollowing'] ?? false);

                            return StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('notifications')
                                  .where('from', isEqualTo: currentUser!.uid)
                                  .where('to', isEqualTo: widget.uid)
                                  .where('type', isEqualTo: 'friend_request')
                                  .where('status', isEqualTo: 'pending')
                                  .snapshots(),
                              builder: (context, requestSnapshot) {
                                final bool isRequested = requestSnapshot.hasData
                                    ? requestSnapshot.data!.docs.isNotEmpty
                                    : (widget.initialData?['isRequested'] ?? false);

                                return SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () => handleRequestActionGlobal(
                                      context,
                                      currentUser,
                                      widget.uid,
                                      isFollowing,
                                      isRequested,
                                      name,
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isFollowing ? const Color(0xFFF1F3EE) : (isRequested ? const Color(0xFFF1F3EE) : primaryGreen),
                                      foregroundColor: isFollowing || isRequested ? textColorMain : Colors.white,
                                      elevation: isFollowing || isRequested ? 0 : 4,
                                      shadowColor: primaryGreen.withOpacity(0.3),
                                      padding: const EdgeInsets.symmetric(vertical: 18),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    ),
                                    child: Text(
                                      isFollowing ? 'CONNECTED' : (isRequested ? 'REQUESTED' : 'ADD FRIEND'),
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold, 
                                        letterSpacing: 1.0,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      
                      const SizedBox(height: 48),
                      
                      // Section Title
                      Row(
                        children: [
                          Text(
                            'PUBLIC REFLECTIONS',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: textColorSub,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Divider(color: Colors.grey.withOpacity(0.1))),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // User's Posts
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .where('authorId', isEqualTo: widget.uid)
                    .where('isAnonymous', isEqualTo: false)
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, postsSnapshot) {
                  if (postsSnapshot.connectionState == ConnectionState.waiting) {
                    return const SliverToBoxAdapter(
                      child: Center(child: CircularProgressIndicator(color: Color(0xFF7C9C84))),
                    );
                  }

                  if (!postsSnapshot.hasData || postsSnapshot.data!.docs.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.notes_rounded, size: 48, color: Colors.grey.withOpacity(0.2)),
                              const SizedBox(height: 16),
                              Text(
                                'No shared words yet.',
                                style: GoogleFonts.outfit(color: textColorSub, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  final posts = postsSnapshot.data!.docs.map((doc) => Post.fromFirestore(doc)).toList();

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildPostCard(posts[index]),
                      childCount: posts.length,
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textColorMain,
          ),
        ),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: textColorSub,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildPostCard(Post post) {
    bool isLiked = currentUser != null && post.likes.contains(currentUser!.uid);
    String timeAgo = timeago.format(post.timestamp);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: primaryGreen.withOpacity(0.1), width: 1),
                ),
                padding: const EdgeInsets.all(2),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFF1F3EE),
                  backgroundImage: post.authorProfileImage != null
                      ? (post.authorProfileImage!.startsWith('data:image')
                      ? MemoryImage(base64Decode(post.authorProfileImage!.split(',').last))
                      : NetworkImage(post.authorProfileImage!) as ImageProvider)
                      : null,
                  child: post.authorProfileImage == null ? Icon(Icons.person, color: primaryGreen, size: 18) : null,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.authorName,
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: textColorMain),
                  ),
                  Text(
                    timeAgo.toUpperCase(),
                    style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: textColorSub),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(post.moodColorValue).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  post.topic.toUpperCase(),
                  style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: Color(post.moodColorValue)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            post.content,
            style: GoogleFonts.outfit(fontSize: 15, color: const Color(0xFF555555), height: 1.6),
          ),
          if (post.imageUrl != null) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: post.imageUrl!.startsWith('data:')
                ? Image.memory(base64Decode(post.imageUrl!.split(',').last), width: double.infinity, fit: BoxFit.cover)
                : Image.network(post.imageUrl!, width: double.infinity, fit: BoxFit.cover),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(
                isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, 
                color: isLiked ? Colors.red : const Color(0xFF9CA3AF), 
                size: 20
              ),
              const SizedBox(width: 8),
              Text(
                post.likes.length.toString(), 
                style: GoogleFonts.outfit(color: isLiked ? Colors.red : textColorSub, fontSize: 13, fontWeight: FontWeight.w600)
              ),
              const SizedBox(width: 24),
              const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF9CA3AF), size: 18),
              const SizedBox(width: 8),
              Text(
                post.commentCount.toString(), 
                style: GoogleFonts.outfit(color: textColorSub, fontSize: 13, fontWeight: FontWeight.w600)
              ),
            ],
          ),
        ],
      ),
    );
  }
}
