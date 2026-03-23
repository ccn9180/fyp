import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'notifications.dart';
import 'search_friend.dart';
import 'public_profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'post_feeds.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> with AutomaticKeepAliveClientMixin {
  late Stream<QuerySnapshot> _postsStream;

  // Common colors
  final Color backgroundColor = const Color(0xFFF2F1EC);
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color textColorMain = const Color(0xFF333333);
  final Color textColorSub = const Color(0xFF888888);

  final TextEditingController _postController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool _isAnonymous = false;
  String _activeFilter = 'All'; // Replaces _selectedTopic for main filter
  String _selectedTopic = 'General';
  String _selectedMood = 'Calm';
  String _searchQuery = '';
  final User? currentUser = FirebaseAuth.instance.currentUser;
  File? _selectedImage;
  late ScrollController _scrollController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _postsStream = FirebaseFirestore.instance
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  void scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutBack,
      );
    }
  }

  void dispose() {
    _scrollController.dispose();
    _postController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handlePost() async {
    if (_postController.text.trim().isEmpty) return;
    if (currentUser == null) return;

    String authorName = 'User';
    String? profileImageUrl;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>;
      authorName = userData['fullName'] ?? currentUser!.displayName ?? 'User';
      profileImageUrl = userData['profileImageUrl'];
    }

    String? imageUrl;
    if (_selectedImage != null) {
      final bytes = await _selectedImage!.readAsBytes();
      imageUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    }

    final post = Post(
      id: '',
      authorId: currentUser!.uid,
      authorName: authorName,
      authorProfileImage: profileImageUrl,
      content: _postController.text.trim(),
      timestamp: DateTime.now(),
      isAnonymous: _isAnonymous,
      topic: _selectedTopic == 'All' ? 'General' : _selectedTopic,
      moodText: _selectedMood,
      moodColorValue: _getMoodColor(_selectedMood).value,
      likes: [],
      commentCount: 0,
      imageUrl: imageUrl,
    );

    await FirebaseFirestore.instance.collection('posts').add(post.toMap());
    _postController.clear();
    setState(() {
      _isAnonymous = false;
      _selectedMood = 'Calm';
      _selectedImage = null;
    });
  }

  Future<void> _pickPostImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 50,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Color _getMoodColor(String mood) {
    switch (mood) {
      case 'Calm': return const Color(0xFF7C9C84);
      case 'Grateful': return const Color(0xFF6B8E78);
      case 'Overwhelmed': return const Color(0xFFD97706);
      case 'Anxious': return const Color(0xFFEF4444);
      case 'Hopeful': return const Color(0xFF3B82F6);
      default: return const Color(0xFF7C9C84);
    }
  }

  IconData _getMoodIcon(String mood) {
    switch (mood) {
      case 'Calm': return Icons.spa;
      case 'Grateful': return Icons.wb_sunny;
      case 'Overwhelmed': return Icons.back_hand;
      case 'Anxious': return Icons.water_drop;
      case 'Hopeful': return Icons.auto_awesome;
      default: return Icons.mood;
    }
  }

  void _showTopicPicker() {
    final List<String> topics = ['Self-Love', 'Anxiety', 'Hope', 'Relationship', 'General'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select a Topic', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...topics.map((t) => ListTile(
              title: Text(t, style: GoogleFonts.outfit()),
              onTap: () {
                setState(() => _selectedTopic = t);
                Navigator.pop(context);
              },
              trailing: t == _selectedTopic ? Icon(Icons.check, color: primaryGreen) : null,
            )),
          ],
        ),
      ),
    );
  }

  void _showMoodPicker() {
    final List<String> moods = ['Calm', 'Grateful', 'Overwhelmed', 'Anxious', 'Hopeful'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('How are you feeling?', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...moods.map((m) => ListTile(
              leading: Icon(Icons.circle, color: _getMoodColor(m), size: 12),
              title: Text(m, style: GoogleFonts.outfit()),
              onTap: () {
                setState(() => _selectedMood = m);
                Navigator.pop(context);
              },
              trailing: m == _selectedMood ? Icon(Icons.check, color: primaryGreen) : null,
            )),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleLike(String postId, List<String> currentLikes) async {
    if (currentUser == null) return;
    final List<String> updatedLikes = List<String>.from(currentLikes);
    if (updatedLikes.contains(currentUser!.uid)) {
      updatedLikes.remove(currentUser!.uid);
    } else {
      updatedLikes.add(currentUser!.uid);
    }
    await FirebaseFirestore.instance.collection('posts').doc(postId).update({'likes': updatedLikes});
  }

  Future<void> _deletePost(String postId) async {
    bool confirm = await showDialog(
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
                'Delete Post?',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to delete this post? This action cannot be undone.',
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
                        'Keep Post',
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
    ) ?? false;

    if (confirm) {
      await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
    }
  }

  Future<void> _toggleArchive(String postId, bool isArchived) async {
    final newStatus = !isArchived;
    await FirebaseFirestore.instance.collection('posts').doc(postId).update({'isArchived': newStatus});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus ? 'Post archived from public feed' : 'Post restored to public feed', style: GoogleFonts.outfit()),
          backgroundColor: primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _editPost(Post post) async {
    final TextEditingController editController = TextEditingController(text: post.content);
    bool isAnon = post.isAnonymous;
    File? newImage;
    String? currentImageUrl = post.imageUrl;

    bool updated = await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: const Color(0xFFFBFBFA),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: primaryGreen.withOpacity(0.05),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Update Reflection',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: textColorMain,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Input Area
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.withOpacity(0.1)),
                          ),
                          child: TextField(
                            controller: editController,
                            maxLines: 5,
                            style: GoogleFonts.outfit(color: textColorMain, height: 1.5),
                            decoration: InputDecoration(
                              hintText: 'Share your thoughts...',
                              hintStyle: GoogleFonts.outfit(color: Colors.grey[400]),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Image Section
                        Text(
                          'VISUALS',
                          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: textColorSub, letterSpacing: 1.2),
                        ),
                        const SizedBox(height: 12),
                        
                        if (newImage != null || currentImageUrl != null)
                          Stack(
                            children: [
                              Container(
                                height: 160,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.grey.withOpacity(0.1)),
                                  image: DecorationImage(
                                    image: newImage != null
                                        ? FileImage(newImage!)
                                        : (currentImageUrl!.startsWith('data:')
                                            ? MemoryImage(base64Decode(currentImageUrl!.split(',').last))
                                            : NetworkImage(currentImageUrl!) as ImageProvider),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 10,
                                top: 10,
                                child: GestureDetector(
                                  onTap: () {
                                    setDialogState(() {
                                      newImage = null;
                                      currentImageUrl = null;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          GestureDetector(
                            onTap: () async {
                              final picker = ImagePicker();
                              final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 70);
                              if (picked != null) {
                                setDialogState(() => newImage = File(picked.path));
                              }
                            },
                            child: Container(
                              height: 100,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey[300]!, width: 1.5, style: BorderStyle.solid),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate_outlined, color: Colors.grey[400], size: 28),
                                    const SizedBox(height: 8),
                                    Text('Add a photo', style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        
                        const SizedBox(height: 24),
                        
                        // Settings Section
                        Text(
                          'PRIVACY',
                          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: textColorSub, letterSpacing: 1.2),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.withOpacity(0.05)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.visibility_off_outlined, size: 20, color: isAnon ? primaryGreen : Colors.grey[400]),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Anonymity',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      color: isAnon ? textColorMain : textColorSub,
                                      fontWeight: isAnon ? FontWeight.w600 : FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                              Switch.adaptive(
                                value: isAnon,
                                activeColor: primaryGreen,
                                onChanged: (val) => setDialogState(() => isAnon = val),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Actions
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: Text('Discard', style: GoogleFonts.outfit(color: textColorSub, fontWeight: FontWeight.w500)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryGreen,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: Text('Save Changes', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ) ?? false;

    if (updated) {
      Map<String, dynamic> updates = {
        'content': editController.text.trim(),
        'isAnonymous': isAnon,
      };

      if (newImage != null) {
        final bytes = await newImage!.readAsBytes();
        updates['imageUrl'] = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      } else if (currentImageUrl == null) {
        updates['imageUrl'] = null;
      }

      await FirebaseFirestore.instance.collection('posts').doc(post.id).update(updates);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (currentUser == null) return const Scaffold(body: Center(child: Text('Please login')));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots(),
      builder: (context, userSnapshot) {
        final List<String> following = List<String>.from(userSnapshot.data?['following'] ?? []);

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('notifications')
              .where('from', isEqualTo: currentUser!.uid)
              .where('type', isEqualTo: 'friend_request')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, requestSnapshot) {
            final List<String> requestedUids = requestSnapshot.hasData
                ? requestSnapshot.data!.docs.map((doc) => doc['to'] as String).toList()
                : [];

            return Scaffold(
              backgroundColor: backgroundColor,
              floatingActionButton: FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PostFeedsPage()),
                  );
                },
                backgroundColor: primaryGreen,
                elevation: 4,
                shape: const CircleBorder(),
                child: const Icon(Icons.add, color: Colors.white, size: 28),
              ),
              body: SafeArea(
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    // Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Community',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                color: textColorMain,
                              ),
                            ),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const SearchFriendScreen()),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.person_add_alt_1_rounded, color: primaryGreen, size: 22),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Stack(
                                      children: [
                                        Icon(Icons.notifications_none_outlined, color: primaryGreen, size: 24),
                                        StreamBuilder<QuerySnapshot>(
                                          stream: FirebaseFirestore.instance
                                              .collection('notifications')
                                              .where('to', isEqualTo: currentUser?.uid)
                                              .where('isRead', isEqualTo: false)
                                              .snapshots(),
                                          builder: (context, snapshot) {
                                            if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                                              return Positioned(
                                                right: 0,
                                                top: 0,
                                                child: Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: const BoxDecoration(
                                                    color: Colors.red,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Search Bar
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value.toLowerCase();
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Search posts, moods, or topics...',
                              hintStyle: GoogleFonts.outfit(color: const Color(0xFFB3B3B3), fontSize: 14),
                              prefixIcon: const Icon(Icons.search, color: Color(0xFFB3B3B3), size: 20),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),

                    // Create Post Input Card
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: const Color(0xFFEAEAEA),
                                    child: Icon(Icons.person, color: Colors.grey.shade400, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _postController,
                                      maxLines: 2,
                                      decoration: InputDecoration(
                                        hintText: 'Share your thoughts or\nfeelings...',
                                        hintStyle: GoogleFonts.outfit(
                                          color: const Color(0xFFBDBDBD),
                                          fontSize: 15,
                                          height: 1.4,
                                        ),
                                        border: InputBorder.none,
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(color: Color(0xFFF0F0F0), thickness: 1),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.sentiment_satisfied_alt, color: primaryGreen, size: 22),
                                        onPressed: _showMoodPicker,
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.image_outlined, color: primaryGreen, size: 22),
                                        onPressed: _pickPostImage,
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                      ),

                                      IconButton(
                                        icon: Icon(
                                            _isAnonymous ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                            color: _isAnonymous ? Colors.orange : primaryGreen,
                                            size: 22
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _isAnonymous = !_isAnonymous;
                                          });
                                        },
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                      ),
                                    ],
                                  ),
                                  GestureDetector(
                                    onTap: _handlePost,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: primaryGreen,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        'Post',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),

                    // Horizontal Filter Chips
                    SliverToBoxAdapter(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Row(
                          children: [
                            _buildFilterChip('All', _activeFilter == 'All'),
                            const SizedBox(width: 12),
                            _buildMyPostsChip(_activeFilter == 'MyPosts'),
                            const SizedBox(width: 12),
                            _buildFilterChip('Self-Love', _activeFilter == 'Self-Love'),
                            const SizedBox(width: 12),
                            _buildFilterChip('Anxiety', _activeFilter == 'Anxiety'),
                            const SizedBox(width: 12),
                            _buildFilterChip('Hope', _activeFilter == 'Hope'),
                          ],
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),

                    // Post Cards
                    StreamBuilder<QuerySnapshot>(
                      stream: _postsStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Center(child: Text('Error loading posts: ${snapshot.error}')),
                            ),
                          );
                        }

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Center(child: CircularProgressIndicator(color: Color(0xFF7C9C84))),
                            ),
                          );
                        }

                        final posts = snapshot.data!.docs.map((doc) => Post.fromFirestore(doc)).toList();

                        // Filter by selected topic and search query
                        final filteredPosts = posts.where((post) {
                          if (_activeFilter != 'MyPosts' && post.isArchived) return false;

                          final matchesAuthor = _activeFilter == 'MyPosts'
                              ? (currentUser != null && post.authorId == currentUser!.uid)
                              : true;
                          final matchesTopic = (_activeFilter == 'All' || _activeFilter == 'MyPosts')
                              ? true
                              : post.topic == _activeFilter;

                          final query = _searchQuery.toLowerCase();
                          final matchesSearch = query.isEmpty ||
                              post.content.toLowerCase().contains(query) ||
                              post.authorName.toLowerCase().contains(query) ||
                              post.topic.toLowerCase().contains(query);
                          return matchesAuthor && matchesTopic && matchesSearch;
                        }).toList();

                        if (filteredPosts.isEmpty) {
                          String emptyMessage = _searchQuery.isEmpty
                              ? (_activeFilter == 'All' || _activeFilter == 'MyPosts' ? 'No posts found.' : 'No posts in $_activeFilter category yet.')
                              : 'No posts found matching "$_searchQuery"';
                          return SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                children: [
                                  Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.withOpacity(0.5)),
                                  const SizedBox(height: 16),
                                  Text(
                                    emptyMessage,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(color: textColorSub, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return SliverList(
                          delegate: SliverChildBuilderDelegate(
                                (context, index) {
                              final post = filteredPosts[index];
                              return Padding(
                                padding: EdgeInsets.only(bottom: index == filteredPosts.length - 1 ? 100 : 0),
                                child: _buildPostCard(
                                  post,
                                  isFollowing: following.contains(post.authorId),
                                  isRequested: requestedUids.contains(post.authorId),
                                ),
                              );
                            },
                            childCount: filteredPosts.length,
                          ),
                        );
                      },
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: isSelected ? Colors.white : const Color(0xFF888888),
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildMyPostsChip(bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeFilter = 'MyPosts';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person, size: 16, color: isSelected ? Colors.white : const Color(0xFF888888)),
            const SizedBox(width: 6),
            Text(
              'MyPosts',
              style: GoogleFonts.outfit(
                color: isSelected ? Colors.white : const Color(0xFF888888),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(Post post, {bool isFollowing = false, bool isRequested = false}) {
    bool isLiked = currentUser != null && post.likes.contains(currentUser!.uid);
    bool isOwner = currentUser != null && post.authorId == currentUser!.uid;
    String displayAuthor = isOwner ? 'You' : (post.isAnonymous ? 'Anonymous' : post.authorName);
    String timeAgo = timeago.format(post.timestamp);

    return Container(
      margin: const EdgeInsets.only(left: 24, right: 24, bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: post.isArchived ? const Color(0xFFF1F1F1) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: post.isArchived ? Border.all(color: Colors.grey.withOpacity(0.1)) : null,
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
          // Header: Avatar, Name, Topics, Options
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: isOwner || post.isAnonymous
                    ? null
                    : () => _showUserProfile(
                  post.authorId,
                  name: post.authorName,
                  imageUrl: post.authorProfileImage,
                  isFollowing: isFollowing,
                  isRequested: isRequested,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFFEAF0ED),
                      backgroundImage: ( (isOwner || !post.isAnonymous) && post.authorProfileImage != null)
                          ? (post.authorProfileImage!.startsWith('data:image')
                          ? MemoryImage(base64Decode(post.authorProfileImage!.split(',').last))
                          : NetworkImage(post.authorProfileImage!) as ImageProvider)
                          : null,
                      child: ( (!isOwner && post.isAnonymous) || post.authorProfileImage == null)
                          ? Icon(Icons.person, color: primaryGreen, size: 22)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              displayAuthor,
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: textColorMain,
                              ),
                            ),
                            if (isOwner && post.isAnonymous) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'ANONYMOUS',
                                  style: GoogleFonts.outfit(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber[800],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${post.topic.toUpperCase()} • ${timeAgo.toUpperCase()}',
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: textColorSub,
                          ),
                        ),
                        if (post.isArchived)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'ARCHIVED',
                              style: GoogleFonts.outfit(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (_activeFilter == 'MyPosts')
                PopupMenuButton<String>(
                  position: PopupMenuPosition.under,
                  elevation: 4,
                  shadowColor: Colors.black.withOpacity(0.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  color: Colors.white,
                  padding: EdgeInsets.zero,
                  onSelected: (value) {
                    if (value == 'edit') _editPost(post);
                    if (value == 'archive') _toggleArchive(post.id, post.isArchived);
                    if (value == 'delete') _deletePost(post.id);
                  },
                  itemBuilder: (context) => [
                    if (!post.isArchived)
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, color: primaryGreen, size: 18),
                            const SizedBox(width: 12),
                            Text('Edit Reflection', style: GoogleFonts.outfit(fontSize: 14)),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'archive',
                      child: Row(
                        children: [
                          Icon(
                            post.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                            color: Colors.blueGrey,
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            post.isArchived ? 'Unarchive Post' : 'Archive Post',
                            style: GoogleFonts.outfit(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(height: 1),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 12),
                          Text('Delete Forever', style: GoogleFonts.outfit(fontSize: 14, color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.more_horiz, color: Color(0xFFB3B3B3), size: 20),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Mood Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Color(post.moodColorValue).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getMoodIcon(post.moodText), color: Color(post.moodColorValue), size: 12),
                const SizedBox(width: 4),
                Text(
                  post.moodText.toUpperCase(),
                  style: GoogleFonts.outfit(
                    color: Color(post.moodColorValue),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Content Text
          Text(
            post.content,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: const Color(0xFF4A4A4A),
              height: 1.5,
            ),
          ),

          // Optional Image
          if (post.imageUrl != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
            child: post.imageUrl!.startsWith('data:')
                ? Image.memory(
                    base64Decode(post.imageUrl!.split(',').last),
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Image.network(
                    post.imageUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
            ),
          ],

          const SizedBox(height: 20),

          // Footer: Actions (Like, Comment, Bookmark)
          Row(
            children: [
              GestureDetector(
                onTap: () => _toggleLike(post.id, post.likes),
                child: Row(
                  children: [
                    Icon(
                      isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, // Changed from diff
                      color: isLiked ? Colors.red : const Color(0xFF9CA3AF),
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      post.likes.length.toString(),
                      style: GoogleFonts.outfit(
                        color: isLiked ? Colors.red : const Color(0xFF9CA3AF),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Row(
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF9CA3AF), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    post.commentCount.toString(),
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF9CA3AF),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const Icon(Icons.bookmark_border, color: Color(0xFF9CA3AF), size: 20),
            ],
          ),
        ],
      ),
    );
  }

  void _showUserProfile(String authorId, {String? name, String? imageUrl, bool? isFollowing, bool? isRequested}) {
    if (currentUser == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PublicProfileScreen(
          uid: authorId,
          initialData: {
            'name': name,
            'profileImageUrl': imageUrl,
            'isFollowing': isFollowing, // Added from diff
            'isRequested': isRequested, // Added from diff
          },
        ),
      ),
    );
  }
}
