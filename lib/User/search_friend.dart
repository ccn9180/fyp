import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'public_profile.dart';

class SearchFriendScreen extends StatefulWidget {
  const SearchFriendScreen({super.key});

  @override
  State<SearchFriendScreen> createState() => _SearchFriendScreenState();
}

class _SearchFriendScreenState extends State<SearchFriendScreen> {
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFEAE9E4);
  final Color textColorMain = const Color(0xFF333333);

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  User? currentUser = FirebaseAuth.instance.currentUser;
  List<String> _searchHistory = [];
  bool _historyLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
  }

  Future<void> _loadSearchHistory() async {
    if (currentUser == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _searchHistory = List<String>.from(doc.data()?['searchHistory'] ?? []).reversed.toList();
          _historyLoaded = true;
        });
      }
    } catch (e) {
      debugPrint("Error loading search history: $e");
      if (mounted) setState(() => _historyLoaded = true);
    }
  }

  Future<void> _addToSearchHistory(String query) async {
    if (currentUser == null || query.isEmpty) return;
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({
        'searchHistory': FieldValue.arrayUnion([normalizedQuery])
      });
      _loadSearchHistory();
    } catch (e) {
      debugPrint("Error saving search history: $e");
    }
  }

  Future<void> _removeFromSearchHistory(String query) async {
    if (currentUser == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({
        'searchHistory': FieldValue.arrayRemove([query])
      });
      _loadSearchHistory();
    } catch (e) {
      debugPrint("Error removing from search history: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Find Friends',
          style: GoogleFonts.playfairDisplay(
            color: textColorMain,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    _addToSearchHistory(value);
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Search by name or email...',
                  hintStyle: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: primaryGreen),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = "");
                    },
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),

          // Results List
          Expanded(
            child: _searchQuery.isEmpty
                ? _buildEmptyState()
                : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF7C9C84)));
                }

                final currentUserDoc = snapshot.data!.docs.where((doc) => doc.id == currentUser?.uid).firstOrNull;
                final currentUserData = currentUserDoc?.data() as Map<String, dynamic>?;
                final followingList = List<String>.from(currentUserData?['following'] ?? []);

                final users = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final fullName = (data['fullName'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  final uid = doc.id;

                  // Exclude current user and filter by search query
                  return uid != currentUser?.uid &&
                      (fullName.contains(_searchQuery) || email.contains(_searchQuery));
                }).toList();

                if (users.isEmpty) {
                  return Center(
                    child: Text(
                      'No users found',
                      style: GoogleFonts.outfit(color: Colors.grey[500]),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final userDoc = users[index];
                    final userData = userDoc.data() as Map<String, dynamic>;
                    final uid = userDoc.id;
                    final name = userData['fullName'] ?? 'User';
                    final email = userData['email'] ?? '';
                    final profileImageUrl = userData['profileImageUrl'];
                    final isFollowing = followingList.contains(uid);

                    return _buildUserTile(uid, name, email, profileImageUrl, isFollowing);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUser?.uid).snapshots(),
      builder: (context, userSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').limit(15).snapshots(),
          builder: (context, suggestSnapshot) {
            // Wait for history AND both streams to have data
            if (!_historyLoaded ||
                userSnapshot.connectionState == ConnectionState.waiting ||
                suggestSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF7C9C84)));
            }

            final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
            final following = List<String>.from(userData?['following'] ?? []);

            // Sync history from stream to avoid the "refresh" jump
            final currentHistory = List<String>.from(userData?['searchHistory'] ?? []).reversed.toList();

            final suggestions = (suggestSnapshot.data?.docs ?? []).where((doc) {
              final uid = doc.id;
              return uid != currentUser?.uid && !following.contains(uid);
            }).toList();

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (currentHistory.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Searches',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textColorMain,
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              if (currentUser == null) return;
                              await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({
                                'searchHistory': []
                              });
                            },
                            child: Text('Clear All', style: GoogleFonts.outfit(color: primaryGreen, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: currentHistory.length > 5 ? 5 : currentHistory.length,
                      itemBuilder: (context, index) {
                        final query = currentHistory[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.history, color: Colors.grey[400], size: 20),
                          title: Text(
                            query,
                            style: GoogleFonts.outfit(color: textColorMain, fontSize: 15),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => _removeFromSearchHistory(query),
                          ),
                          onTap: () {
                            _searchController.text = query;
                            setState(() {
                              _searchQuery = query.toLowerCase();
                            });
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Suggested Users Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Suggested for you',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColorMain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (suggestions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text('No new suggestions at the moment', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14)),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: suggestions.length > 5 ? 5 : suggestions.length,
                      itemBuilder: (context, index) {
                        final doc = suggestions[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return _buildUserTile(
                            doc.id,
                            data['fullName'] ?? 'User',
                            data['email'] ?? '',
                            data['profileImageUrl'],
                            false
                        );
                      },
                    ),

                  if (currentHistory.isEmpty) ...[
                    const SizedBox(height: 60),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.person_search_outlined, size: 80, color: Colors.grey[200]),
                          const SizedBox(height: 16),
                          Text(
                            'Search for your friends on Eunoia',
                            style: GoogleFonts.outfit(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUserTile(String uid, String name, String email, String? profileImageUrl, bool isFollowing) {
    ImageProvider? imageProvider;
    if (profileImageUrl != null) {
      if (profileImageUrl.startsWith('data:image')) {
        imageProvider = MemoryImage(base64Decode(profileImageUrl.split(',').last));
      } else {
        imageProvider = NetworkImage(profileImageUrl);
      }
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('from', isEqualTo: currentUser?.uid)
          .where('to', isEqualTo: uid)
          .where('type', isEqualTo: 'friend_request')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, requestSnapshot) {
        final isRequested = requestSnapshot.hasData && requestSnapshot.data!.docs.isNotEmpty;

        return GestureDetector(
          onTap: () => _showUserProfile(
            uid,
            name: name,
            imageUrl: profileImageUrl,
            isFollowing: isFollowing,
            isRequested: isRequested,
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: primaryGreen.withOpacity(0.1),
                  backgroundImage: imageProvider,
                  child: imageProvider == null ? Icon(Icons.person, color: primaryGreen) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: textColorMain,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        email,
                        style: GoogleFonts.outfit(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _handleRequestAction(uid, isFollowing, isRequested, name),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFollowing ? const Color(0xFFF0F0F0) : (isRequested ? const Color(0xFFF0F0F0) : primaryGreen),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    isFollowing ? 'Friends' : (isRequested ? 'Requested' : 'Add'),
                    style: GoogleFonts.outfit(
                      color: isFollowing || isRequested ? textColorMain : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleRequestAction(String targetUid, bool isFriends, bool isRequested, String targetName) async {
    await handleRequestActionGlobal(context, currentUser, targetUid, isFriends, isRequested, targetName);
  }

  Future<void> _showUserProfile(String uid, {String? name, String? imageUrl, bool? isFollowing, bool? isRequested}) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PublicProfileScreen(
          uid: uid,
          initialData: {
            'name': name,
            'profileImageUrl': imageUrl,
            'isFollowing': isFollowing,
            'isRequested': isRequested,
          },
        ),
      ),
    );
  }
}

Future<void> handleRequestActionGlobal(BuildContext context, User? currentUser, String targetUid, bool isFriends, bool isRequested, String targetName) async {
  if (currentUser == null) return;
  final String currentUserId = currentUser.uid;

  if (isFriends) {
    // Unfriend logic
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
            color: const Color(0xFFEAE9E4),
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
                  Icons.person_remove_rounded,
                  color: Color(0xFFE57373),
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Unfriend User?',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to remove this connection? You won\'t be able to see their private updates.',
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
                        'Keep Friend',
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
                        'Unfriend',
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

    if (!confirm) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUserId).update({
        'following': FieldValue.arrayRemove([targetUid]),
        'followers': FieldValue.arrayRemove([targetUid])
      });
      await FirebaseFirestore.instance.collection('users').doc(targetUid).update({
        'following': FieldValue.arrayRemove([currentUserId]),
        'followers': FieldValue.arrayRemove([currentUserId])
      });
    } catch (e) {
      debugPrint("Error unfriending: $e");
    }
    return;
  }

  if (isRequested) {
    // Cancel request
    try {
      final query = await FirebaseFirestore.instance
          .collection('notifications')
          .where('from', isEqualTo: currentUserId)
          .where('to', isEqualTo: targetUid)
          .where('type', isEqualTo: 'friend_request')
          .where('status', isEqualTo: 'pending')
          .get();
      for (var doc in query.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint("Error canceling request: $e");
    }
  } else {
    // Send new request
    try {
      final senderDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
      final senderData = senderDoc.data() as Map<String, dynamic>?;

      await FirebaseFirestore.instance.collection('notifications').add({
        'from': currentUserId,
        'to': targetUid,
        'type': 'friend_request',
        'status': 'pending',
        'isRead': false,
        'senderName': senderData?['fullName'] ?? 'Someone',
        'senderPhoto': senderData?['profileImageUrl'],
        'timestamp': FieldValue.serverTimestamp(),
        'message': '${senderData?['fullName'] ?? "Someone"} sent you a connection request.',
      });
    } catch (e) {
      debugPrint("Error sending request: $e");
    }
  }
}
