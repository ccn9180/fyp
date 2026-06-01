import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp/services/friends_service.dart';
import 'package:intl/intl.dart';
import 'diary_detail.dart';
import 'chat_detail.dart';

class SharedWithMeScreen extends StatefulWidget {
  const SharedWithMeScreen({super.key});

  @override
  State<SharedWithMeScreen> createState() => _SharedWithMeScreenState();
}

class _SharedWithMeScreenState extends State<SharedWithMeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFFBFBF6);
  final Color textColorMain = const Color(0xFF333333);
  final Color textColorSub = const Color(0xFF888888);

  final Map<String, FriendProfile> _profileCache = {};
  List<Map<String, dynamic>> _reflections = [];
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;
  List<String> _friendUids = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    // 1. Fetch users who added us as a trusted contact
    final List<FriendProfile> trustedFriends = [];
    final List<String> trustedUids = [];
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('trustedContactUids', arrayContains: user.uid)
          .get();

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final String uid = doc.id;
        final String fullName = data['fullName'] ?? 'Friend';
        final String? profileImageUrl = data['profileImageUrl'];
        trustedFriends.add(FriendProfile(
          uid: uid,
          fullName: fullName,
          profileImageUrl: profileImageUrl,
        ));
        trustedUids.add(uid);
      }
    } catch (e) {
      print('Error querying trusted contact uids: $e');
    }

    _friendUids = trustedUids;

    // 2. Cache friend profiles locally
    if (mounted) {
      setState(() {
        for (var p in trustedFriends) {
          _profileCache[p.uid] = p;
        }
      });
    }

    // 3. Load dynamic reflections and chats in parallel
    final reflections = await _fetchSharedReflections(user.uid, _friendUids);
    final chats = await _fetchSharedChats(user.uid, _friendUids);

    if (mounted) {
      setState(() {
        _reflections = reflections;
        _chats = chats;
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchSharedReflections(String currentUserUid, List<String> friendUids) async {
    if (friendUids.isEmpty) return [];
    
    List<Map<String, dynamic>> results = [];
    
    // For each friend, query their diary_entries subcollection
    for (var friendUid in friendUids) {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(friendUid)
            .collection('diary_entries')
            .get();
            
        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          final Map<String, dynamic> access = data['sharingAccess'] ?? {};
          if (access[currentUserUid] == true) {
            results.add({
              'id': doc.id,
              'sharedByUid': friendUid,
              'title': data['title'] ?? 'Untitled Entry',
              'content': data['content'] ?? '',
              'mood': data['mood'] ?? 'Neutral',
              'timestamp': data['timestamp'] ?? Timestamp.now(),
              'aiMoodTitle': data['aiMoodTitle'] ?? data['mood'] ?? 'Neutral',
              'summary': data['summary'] ?? '',
            });
          }
        }
      } catch (e) {
        print('Error fetching reflections for $friendUid: $e');
      }
    }
    
    // Sort in memory by timestamp descending
    results.sort((a, b) {
      final Timestamp aTime = a['timestamp'];
      final Timestamp bTime = b['timestamp'];
      return bTime.compareTo(aTime);
    });
    
    return results;
  }

  Future<List<Map<String, dynamic>>> _fetchSharedChats(String currentUserUid, List<String> friendUids) async {
    if (friendUids.isEmpty) return [];
    
    List<Map<String, dynamic>> results = [];
    
    // Query chat_sessions where userId is in friendUids
    // Chunk friendUids into batches of 30 due to Firestore whereIn limits
    for (var i = 0; i < friendUids.length; i += 30) {
      final chunk = friendUids.sublist(i, i + 30 > friendUids.length ? friendUids.length : i + 30);
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('chat_sessions')
            .where('userId', whereIn: chunk)
            .get();
            
        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          final Map<String, dynamic> access = data['sharingAccess'] ?? {};
          if (access[currentUserUid] == true) {
            results.add({
              'id': doc.id,
              'sharedByUid': data['userId'],
              'title': data['title'] ?? 'Mindful Chat',
              'preview': data['preview'] ?? '',
              'tag': data['tag'] ?? 'GUIDE',
              'createdAt': data['createdAt'] ?? Timestamp.now(),
              'messages': data['messages'] ?? [],
            });
          }
        }
      } catch (e) {
        print('Error fetching chats: $e');
      }
    }
    
    // Sort in memory by createdAt descending
    results.sort((a, b) {
      final Timestamp aTime = a['createdAt'];
      final Timestamp bTime = b['createdAt'];
      return bTime.compareTo(aTime);
    });
    
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: textColorMain,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'SHARED JOURNEYS',
          style: GoogleFonts.outfit(
            color: textColorMain,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inner Circle',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: textColorMain,
                  ),
                ),
                Text(
                  'Explore the moments and conversations shared with you by your inner circle.',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: textColorSub,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          
          // Custom Premium Navigation
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _buildNavItem('DIARY', 0),
                const SizedBox(width: 12),
                _buildNavItem('CONVERSATION', 1),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildReflectionList(),
                _buildChatList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReflectionList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF7C9C84)));
    }

    if (_reflections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_rounded, size: 48, color: textColorSub.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'No shared diary entries yet',
              style: GoogleFonts.outfit(color: textColorSub),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllData,
      color: primaryGreen,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _reflections.length,
        itemBuilder: (context, index) {
          final entry = _reflections[index];
          final authorUid = entry['sharedByUid'];
          final profile = _profileCache[authorUid];

          final displayData = {
            ...entry,
            'sharedBy': profile?.fullName ?? 'Friend',
            'profileImageUrl': profile?.profileImageUrl,
          };

          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _buildSharedCard(displayData),
          );
        },
      ),
    );
  }

  Widget _buildChatList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF7C9C84)));
    }

    if (_chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_rounded, size: 48, color: textColorSub.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'No shared conversations yet',
              style: GoogleFonts.outfit(color: textColorSub),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllData,
      color: primaryGreen,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _chats.length,
        itemBuilder: (context, index) {
          final chat = _chats[index];
          final authorUid = chat['sharedByUid'];
          final profile = _profileCache[authorUid];

          final displayData = {
            ...chat,
            'sharedBy': profile?.fullName ?? 'Friend',
            'profileImageUrl': profile?.profileImageUrl,
          };

          return _buildSharedChatCard(displayData);
        },
      ),
    );
  }

  Widget _buildSharedCard(Map<String, dynamic> entry) {
    String formattedDate = '';
    if (entry['timestamp'] != null) {
      if (entry['timestamp'] is Timestamp) {
        final DateTime dt = (entry['timestamp'] as Timestamp).toDate();
        formattedDate = DateFormat('d MMM yyyy').format(dt);
      } else {
        formattedDate = entry['timestamp'].toString();
      }
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DiaryDetailScreen(
              docId: entry['id'],
              isInnerCircle: true,
              authorUid: entry['sharedByUid'],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFFF1F3EE), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C9C84).withOpacity(0.04),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFF1F3EE),
                  backgroundImage: _getAvatarProvider(entry['profileImageUrl']),
                  child: entry['profileImageUrl'] == null || entry['profileImageUrl'].isEmpty
                      ? Text(
                          entry['sharedBy'].isNotEmpty ? entry['sharedBy'][0].toUpperCase() : 'F',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryGreen,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry['sharedBy'],
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: textColorMain,
                        ),
                      ),
                      Text(
                        'Shared a diary entry',
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
                    color: primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    entry['mood'].toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              entry['title'],
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColorMain,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              entry['content'],
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: const Color(0xFF555555),
                height: 1.7,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formattedDate,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: textColorSub,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      'READ MORE',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.arrow_forward_ios_rounded, size: 10, color: primaryGreen),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSharedChatCard(Map<String, dynamic> chat) {
    String formattedDate = '';
    if (chat['createdAt'] != null) {
      if (chat['createdAt'] is Timestamp) {
        final DateTime dt = (chat['createdAt'] as Timestamp).toDate();
        formattedDate = DateFormat('d MMM yyyy').format(dt);
      } else {
        formattedDate = chat['createdAt'].toString();
      }
    } else if (chat['date'] != null) {
      formattedDate = chat['date'];
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              docId: chat['id'],
              chatData: chat,
              isInnerCircle: true,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFFF1F3EE), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C9C84).withOpacity(0.04),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF7C9C84).withOpacity(0.1),
                  backgroundImage: _getAvatarProvider(chat['profileImageUrl']),
                  child: chat['profileImageUrl'] == null || chat['profileImageUrl'].isEmpty
                      ? Text(
                          chat['sharedBy'].isNotEmpty ? chat['sharedBy'][0].toUpperCase() : 'F',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryGreen,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chat['sharedBy'],
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: textColorMain,
                        ),
                      ),
                      Text(
                        'Shared a conversation transcript',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: textColorSub,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildChatTag(chat['tag']),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFBFBF6),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF1F3EE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat['title'],
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColorMain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    chat['preview'],
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: textColorSub,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transcript shared $formattedDate',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: textColorSub,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      'OPEN CHAT',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.arrow_forward_ios_rounded, size: 10, color: primaryGreen),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(String label, int index) {
    bool isSelected = _tabController.index == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _tabController.animateTo(index);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? primaryGreen : const Color(0xFFF1F3EE),
            width: 1.5,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: primaryGreen.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ] : [],
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
            color: isSelected ? Colors.white : textColorSub,
          ),
        ),
      ),
    );
  }

  Widget _buildChatTag(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: primaryGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryGreen.withOpacity(0.15)),
      ),
      child: Text(
        tag,
        style: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: primaryGreen,
          letterSpacing: 1.1,
        ),
      ),
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
}
