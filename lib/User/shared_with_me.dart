import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'diary_detail.dart';
import 'chat_detail.dart';

class _FriendData {
  final String uid;
  final String fullName;
  final String? profileImageUrl;
  final List<Map<String, dynamic>> reflections;
  final List<Map<String, dynamic>> chats;

  _FriendData({
    required this.uid,
    required this.fullName,
    this.profileImageUrl,
    List<Map<String, dynamic>>? reflections,
    List<Map<String, dynamic>>? chats,
  })  : reflections = reflections ?? [],
        chats = chats ?? [];

  int get totalShared => reflections.length + chats.length;
  
  DateTime? get lastSharedDate {
    DateTime? lastRef;
    DateTime? lastChat;
    if (reflections.isNotEmpty) {
      final ref = reflections.first;
      lastRef = ref['timestamp'] is Timestamp ? (ref['timestamp'] as Timestamp).toDate() : null;
    }
    if (chats.isNotEmpty) {
      final ch = chats.first;
      lastChat = ch['createdAt'] is Timestamp ? (ch['createdAt'] as Timestamp).toDate() : null;
    }
    if (lastRef == null) return lastChat;
    if (lastChat == null) return lastRef;
    return lastRef.isAfter(lastChat) ? lastRef : lastChat;
  }
}

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

  List<_FriendData> _friends = [];
  bool _isLoading = true;
  String _searchQuery = '';
  _FriendData? _selectedFriend;

  String _diaryFilter = 'all';
  String _chatFilter = 'all';

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
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    
    // Clear new shared items badge
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'hasNewSharedItems': false});
    } catch (e) {
      debugPrint("Error clearing hasNewSharedItems: $e");
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('trustedContactUids', arrayContains: user.uid)
          .get();

      List<_FriendData> loadedFriends = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final String uid = doc.id;
        final String fullName = data['fullName'] ?? 'Friend';
        final String? profileImageUrl = data['profileImageUrl'];

        final friendData = _FriendData(
          uid: uid,
          fullName: fullName,
          profileImageUrl: profileImageUrl,
        );

        // Fetch reflections
        final refQuery = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('diary_entries')
            .get();
        for (var rDoc in refQuery.docs) {
          final rData = rDoc.data();
          final Map<String, dynamic> access = rData['sharingAccess'] ?? {};
          if (access[user.uid] == true) {
            friendData.reflections.add({
              'id': rDoc.id,
              'sharedByUid': uid,
              'title': rData['title'] ?? 'Untitled Entry',
              'content': rData['content'] ?? '',
              'mood': rData['mood'] ?? 'Neutral',
              'timestamp': rData['timestamp'] ?? Timestamp.now(),
              'aiMoodTitle': rData['aiMoodTitle'] ?? rData['mood'] ?? 'Neutral',
              'summary': rData['summary'] ?? '',
              'sharedBy': fullName,
              'profileImageUrl': profileImageUrl,
            });
          }
        }
        friendData.reflections.sort((a, b) {
          final Timestamp aTime = a['timestamp'];
          final Timestamp bTime = b['timestamp'];
          return bTime.compareTo(aTime);
        });

        loadedFriends.add(friendData);
      }

      if (loadedFriends.isNotEmpty) {
        final List<String> allUids = loadedFriends.map((f) => f.uid).toList();
        for (var i = 0; i < allUids.length; i += 30) {
          final chunk = allUids.sublist(i, i + 30 > allUids.length ? allUids.length : i + 30);
          final chatQuery = await FirebaseFirestore.instance
              .collection('chat_sessions')
              .where('userId', whereIn: chunk)
              .get();

          for (var cDoc in chatQuery.docs) {
            final cData = cDoc.data();
            final Map<String, dynamic> access = cData['sharingAccess'] ?? {};
            if (access[user.uid] == true) {
              final authorUid = cData['userId'];
              final friend = loadedFriends.firstWhere((f) => f.uid == authorUid);
              friend.chats.add({
                'id': cDoc.id,
                'sharedByUid': authorUid,
                'title': cData['title'] ?? 'Mindful Chat',
                'preview': cData['preview'] ?? '',
                'tag': cData['tag'] ?? 'GUIDE',
                'createdAt': cData['createdAt'] ?? Timestamp.now(),
                'messages': cData['messages'] ?? [],
                'sharedBy': friend.fullName,
                'profileImageUrl': friend.profileImageUrl,
              });
            }
          }
        }
      }

      for (var f in loadedFriends) {
        f.chats.sort((a, b) {
          final Timestamp aTime = a['createdAt'];
          final Timestamp bTime = b['createdAt'];
          return bTime.compareTo(aTime);
        });
      }

      // Sort friends by most recent shared item
      loadedFriends.sort((a, b) {
        final aDate = a.lastSharedDate ?? DateTime(0);
        final bDate = b.lastSharedDate ?? DateTime(0);
        return bDate.compareTo(aDate);
      });

      if (mounted) {
        setState(() {
          _friends = loadedFriends;
          if (_selectedFriend != null) {
            // Update selected friend with fresh data if they still exist
            final matching = loadedFriends.where((f) => f.uid == _selectedFriend!.uid).toList();
            if (matching.isNotEmpty) {
              _selectedFriend = matching.first;
            } else {
              _selectedFriend = null;
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading shared items: $e');
      if (mounted) setState(() => _isLoading = false);
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: textColorMain,
          onPressed: () {
            if (_selectedFriend != null) {
              setState(() => _selectedFriend = null);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _selectedFriend == null ? 'SHARED JOURNEYS' : 'FRIEND PROFILE',
          style: GoogleFonts.outfit(
            color: textColorMain,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: _selectedFriend == null ? _buildFriendList() : _buildDetailView(),
    );
  }

  Widget _buildFriendList() {
    final filteredFriends = _friends.where((f) {
      if (_searchQuery.isEmpty) return true;
      return f.fullName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
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
              const SizedBox(height: 8),
              Text(
                'Explore the moments and conversations shared with you by your inner circle.',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: textColorSub,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              // Search Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
                ),
                child: Center(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search friends...',
                      hintStyle: GoogleFonts.outfit(fontSize: 14, color: Colors.grey),
                      border: InputBorder.none,
                      icon: const Icon(Icons.search_rounded, size: 20, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: primaryGreen))
              : filteredFriends.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadAllData,
                      color: primaryGreen,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        itemCount: filteredFriends.length,
                        itemBuilder: (context, index) {
                          return _buildFriendCard(filteredFriends[index]);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final bool isSearching = _searchQuery.isNotEmpty;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: primaryGreen.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSearching ? Icons.search_off_rounded : Icons.people_outline_rounded,
                        color: primaryGreen,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isSearching ? "No results found" : 'No friends sharing yet',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColorMain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isSearching ? 'Try adjusting your search terms.' : 'When your inner circle shares with you, they will appear here.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: textColorSub,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFriendCard(_FriendData friend) {
    String formattedDate = 'No activity';
    if (friend.lastSharedDate != null) {
      formattedDate = DateFormat('d MMM yyyy').format(friend.lastSharedDate!);
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFriend = friend;
          _tabController.index = 0; // Default to Diary
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1F3EE), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: primaryGreen.withOpacity(0.12),
                backgroundImage: _getAvatarProvider(friend.profileImageUrl),
                child: friend.profileImageUrl == null || friend.profileImageUrl!.isEmpty
                    ? Text(
                        friend.fullName.isNotEmpty ? friend.fullName[0].toUpperCase() : 'F',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
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
                      friend.fullName,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: textColorMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${friend.totalShared} Shared',
                          style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[500]),
                        ),
                        if (friend.totalShared > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(color: Colors.grey[400], shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formattedDate,
                            style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[500]),
                          ),
                        ]
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailView() {
    final friend = _selectedFriend!;
    return Column(
      children: [
        // Profile Header Card
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: primaryGreen.withOpacity(0.1),
                  backgroundImage: _getAvatarProvider(friend.profileImageUrl),
                  child: friend.profileImageUrl == null || friend.profileImageUrl!.isEmpty
                      ? Text(
                          friend.fullName.isNotEmpty ? friend.fullName[0].toUpperCase() : 'F',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                            color: primaryGreen,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friend.fullName,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: textColorMain,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${friend.reflections.length} Diaries · ${friend.chats.length} Chats',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: textColorSub,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Tabs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _buildNavItem('DIARY', 0)),
                      Expanded(child: _buildNavItem('CONVERSATION', 1)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _showTabFilterSheet(context),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.tune_rounded, color: Color(0xFF333333), size: 22),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildReflectionList(friend.reflections),
              _buildChatList(friend.chats),
            ],
          ),
        ),
      ],
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
        decoration: BoxDecoration(
          color: isSelected ? primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
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
      ),
    );
  }

  void _showTabFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: backgroundColor, // Match background color
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text('Filter ${_tabController.index == 0 ? 'Diaries' : 'Conversations'}', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: textColorMain)),
              const SizedBox(height: 24),
              if (_tabController.index == 0) ...[
                _buildFilterOption(Icons.all_inclusive_rounded, 'All Diaries', () {
                  setState(() => _diaryFilter = 'all');
                  Navigator.pop(context);
                }),
                _buildFilterOption(Icons.sentiment_satisfied_rounded, 'Positive Moods', () {
                  setState(() => _diaryFilter = 'positive');
                  Navigator.pop(context);
                }),
                _buildFilterOption(Icons.sentiment_dissatisfied_rounded, 'Negative Moods', () {
                  setState(() => _diaryFilter = 'negative');
                  Navigator.pop(context);
                }),
                _buildFilterOption(Icons.sentiment_neutral_rounded, 'Neutral Moods', () {
                  setState(() => _diaryFilter = 'neutral');
                  Navigator.pop(context);
                }, isLast: true),
              ] else ...[
                _buildFilterOption(Icons.all_inclusive_rounded, 'All Conversations', () {
                  setState(() => _chatFilter = 'all');
                  Navigator.pop(context);
                }),
                _buildFilterOption(Icons.explore_rounded, 'GUIDE Chat', () {
                  setState(() => _chatFilter = 'GUIDE');
                  Navigator.pop(context);
                }),
                _buildFilterOption(Icons.people_rounded, 'FRIEND Chat', () {
                  setState(() => _chatFilter = 'FRIEND');
                  Navigator.pop(context);
                }),
                _buildFilterOption(Icons.psychology_rounded, 'EXPERT Chat', () {
                  setState(() => _chatFilter = 'EXPERT');
                  Navigator.pop(context);
                }, isLast: true),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterOption(IconData icon, String label, VoidCallback onTap, {bool isLast = false}) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          leading: Icon(icon, color: primaryGreen, size: 20),
          title: Text(label, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500, color: textColorMain)),
          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 18),
          contentPadding: EdgeInsets.zero,
        ),
        if (!isLast) Divider(color: Colors.grey.withOpacity(0.1)),
      ],
    );
  }

  Widget _buildReflectionList(List<Map<String, dynamic>> reflections) {
    List<Map<String, dynamic>> filtered = reflections;
    if (_diaryFilter != 'all') {
      filtered = reflections.where((r) {
        String mood = (r['mood'] as String? ?? 'neutral').toLowerCase();
        if (_diaryFilter == 'positive') {
          return ['joy', 'surprise', 'love', 'happy', 'calm', 'excited', 'proud', 'positive', 'grateful', 'optimistic', 'relieved'].contains(mood);
        } else if (_diaryFilter == 'negative') {
          return ['sadness', 'fear', 'anger', 'anxiety', 'anxious', 'angry', 'sad', 'stressed', 'negative', 'frustrated', 'lonely', 'overwhelmed', 'disappointed', 'guilty'].contains(mood);
        } else if (_diaryFilter == 'neutral') {
          return ['neutral', 'tired', 'confused', 'bored'].contains(mood);
        }
        return true;
      }).toList();
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_rounded, size: 48, color: textColorSub.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'No shared diary entries',
              style: GoogleFonts.outfit(color: textColorSub),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final entry = filtered[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: _buildSharedCard(entry),
        );
      },
    );
  }

  Widget _buildChatList(List<Map<String, dynamic>> chats) {
    List<Map<String, dynamic>> filtered = chats;
    if (_chatFilter != 'all') {
      filtered = chats.where((c) {
        String tag = (c['tag'] as String? ?? '').toUpperCase();
        return tag == _chatFilter;
      }).toList();
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_rounded, size: 48, color: textColorSub.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'No shared conversations',
              style: GoogleFonts.outfit(color: textColorSub),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final chat = filtered[index];
        return _buildSharedChatCard(chat);
      },
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
