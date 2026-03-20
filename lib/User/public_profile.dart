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

        // Show initial data if stream hasn't arrived yet
        final String name = userData?['fullName'] ?? widget.initialData?['name'] ?? 'User';
        final String email = userData?['email'] ?? widget.initialData?['email'] ?? '';
        final String bio = userData?['bio'] ?? '';
        final String? profileImageUrl = userData?['profileImageUrl'] ?? widget.initialData?['profileImageUrl'];
        final List<String> followers = List<String>.from(userData?['followers'] ?? []);
        final List<String> following = List<String>.from(userData?['following'] ?? []);
        final bool isDataLoaded = userSnapshot.hasData;

        return Scaffold(
          backgroundColor: backgroundColor,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 0,
                floating: true,
                backgroundColor: backgroundColor,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF333333), size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  name,
                  style: GoogleFonts.playfairDisplay(
                    color: textColorMain,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                centerTitle: true,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    children: [
                      // Profile Identity
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: primaryGreen.withOpacity(0.1),
                        backgroundImage: profileImageUrl != null
                            ? (profileImageUrl.startsWith('data:image')
                            ? MemoryImage(base64Decode(profileImageUrl.split(',').last))
                            : NetworkImage(profileImageUrl) as ImageProvider)
                            : null,
                        child: profileImageUrl == null ? Icon(Icons.person, size: 50, color: primaryGreen) : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        name,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: textColorMain,
                        ),
                      ),
                      Text(
                        email,
                        style: GoogleFonts.outfit(color: textColorSub, fontSize: 14),
                      ),
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          bio,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: const Color(0xFF666666),
                            height: 1.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Stats
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildStatColumn('Followers', followers.length),
                          const SizedBox(width: 48),
                          _buildStatColumn('Following', following.length),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Action Button
                      if (widget.uid != currentUser!.uid)
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots(),
                          builder: (context, currentSnapshot) {
                            final currentData = currentSnapshot.data?.data() as Map<String, dynamic>?;

                            // Use initialData as fallback to prevent button "jump"
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
                                // Use initialData as fallback to prevent button "jump"
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
                                      backgroundColor: isFollowing || isRequested ? const Color(0xFFF0F0F0) : primaryGreen,
                                      foregroundColor: isFollowing || isRequested ? textColorMain : Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    child: Text(
                                      isFollowing ? 'Friends' : (isRequested ? 'Requested' : 'Add Friend'),
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      const SizedBox(height: 32),
                      const Divider(thickness: 1, color: Color(0xFFEEEEEE)),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Posts',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textColorMain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // User's Posts
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .where('authorId', isEqualTo: widget.uid)
                    .where('isAnonymous', isEqualTo: false) // Only show non-anonymous posts for public profile
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
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            'No public posts yet.',
                            style: GoogleFonts.outfit(color: textColorSub),
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
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
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
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: textColorSub,
          ),
        ),
      ],
    );
  }

  Widget _buildPostCard(Post post) {
    bool isLiked = currentUser != null && post.likes.contains(currentUser!.uid);
    String displayAuthor = post.authorName;
    String timeAgo = timeago.format(post.timestamp);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFEAF0ED),
                backgroundImage: post.authorProfileImage != null
                    ? (post.authorProfileImage!.startsWith('data:image')
                    ? MemoryImage(base64Decode(post.authorProfileImage!.split(',').last))
                    : NetworkImage(post.authorProfileImage!) as ImageProvider)
                    : null,
                child: post.authorProfileImage == null ? Icon(Icons.person, color: primaryGreen, size: 20) : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayAuthor,
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: textColorMain),
                  ),
                  Text(
                    '${post.topic.toUpperCase()} • ${timeAgo.toUpperCase()}',
                    style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: textColorSub),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            post.content,
            style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF4A4A4A), height: 1.5),
          ),
          if (post.imageUrl != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(post.imageUrl!, height: 180, width: double.infinity, fit: BoxFit.cover),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : const Color(0xFF9CA3AF), size: 20),
              const SizedBox(width: 6),
              Text(post.likes.length.toString(), style: GoogleFonts.outfit(color: isLiked ? Colors.red : const Color(0xFF9CA3AF), fontSize: 13)),
              const SizedBox(width: 20),
              const Icon(Icons.chat_bubble_rounded, color: Color(0xFF9CA3AF), size: 18),
              const SizedBox(width: 6),
              Text(post.commentCount.toString(), style: GoogleFonts.outfit(color: const Color(0xFF9CA3AF), fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}
