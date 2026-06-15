import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notifications.dart';
import 'article_detail.dart';
import 'meditation_player.dart';
import 'resource_preview_screen.dart';
import 'detailed_history_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SelfHelpScreen extends StatefulWidget {
  const SelfHelpScreen({super.key});

  @override
  State<SelfHelpScreen> createState() => _SelfHelpScreenState();
}

class _SelfHelpScreenState extends State<SelfHelpScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedMeditationCategory = 'All';
  String _selectedMeditationDuration = 'All';
  String _selectedArticleCategory = 'All';
  String _selectedArticleDuration = 'All';
  bool _isPreloading = true;
  Set<String> _favoritedResources = {};
  Set<String> _recommendedResourceIds = {};
  late ScrollController _scrollController;
  final ScrollController _meditationFilterScrollController = ScrollController();
  final ScrollController _articleFilterScrollController = ScrollController();
  bool _showBackToTop = false;
  String? _todayMood;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        // Reset scroll position to top when tab changes
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });

    _scrollController = ScrollController();
    _scrollController.addListener(() {
      if (_scrollController.offset > 300 && !_showBackToTop) {
        setState(() => _showBackToTop = true);
      } else if (_scrollController.offset <= 300 && _showBackToTop) {
        setState(() => _showBackToTop = false);
      }
    });

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase().trim();
      });
    });
    _loadFavorites();
    _loadRecommendations();
    _checkTodayMood();
    _preloadAssets();
  }

  Future<void> _checkTodayMood() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('mood_checkins')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
          
      if (snap.docs.isNotEmpty) {
        if (mounted) {
          setState(() {
            _todayMood = snap.docs.first['emotion'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking today mood: $e');
    }
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

  Future<void> _loadFavorites() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .get();

    setState(() {
      _favoritedResources = snapshot.docs.map((doc) => doc.id).toSet();
    });
  }

  Future<void> _loadRecommendations() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('recommendations')
          .where('patientId', isEqualTo: uid)
          .get();

      setState(() {
        _recommendedResourceIds = snapshot.docs.map((doc) => doc.data()['resourceId'] as String).toSet();
      });
    } catch (e) {
      debugPrint('Error loading recommendations: $e');
    }
  }

  Future<void> _recordView(String resourceId, String type) async {
    final collection = type == 'meditation' ? 'meditation_guides' : 'articles';
    await FirebaseFirestore.instance.collection(collection).doc(resourceId).update({
      'views': FieldValue.increment(1),
    });
  }

  Future<void> _toggleFavorite(String resourceId, String resourceTitle) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(resourceId);

    if (_favoritedResources.contains(resourceId)) {
      await docRef.delete();
      setState(() => _favoritedResources.remove(resourceId));
    } else {
      await docRef.set({
        'title': resourceTitle,
        'timestamp': FieldValue.serverTimestamp(),
      });
      setState(() => _favoritedResources.add(resourceId));
    }
  }

  Future<void> _preloadAssets() async {
    try {
      // 1. Fetch data for precaching
      final suggestedQuery = await FirebaseFirestore.instance
          .collection('meditation_guides')
          .where('status', isEqualTo: 'published')
          .limit(1)
          .get();

      final articlesQuery = await FirebaseFirestore.instance
          .collection('articles')
          .where('status', isEqualTo: 'published')
          .limit(3)
          .get();

      List<String> imageUrls = [];
      if (suggestedQuery.docs.isNotEmpty) {
        imageUrls.add(suggestedQuery.docs.first.get('imageUrl') ?? '');
      }
      for (var doc in articlesQuery.docs) {
        imageUrls.add(doc.get('imageUrl') ?? '');
      }

      // 2. Precache images
      List<Future<void>> precacheFutures = [];
      for (var url in imageUrls) {
        if (url.isNotEmpty) {
          precacheFutures.add(precacheImage(NetworkImage(url), context));
        }
      }

      // 3. Wait for precaching to complete, but don't hang too long (timeout after 3s)
      await Future.wait(precacheFutures).timeout(const Duration(seconds: 3), onTimeout: () => []);
    } catch (e) {
      debugPrint("Preload error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isPreloading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _meditationFilterScrollController.dispose();
    _articleFilterScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isPreloading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF2F1EC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFF7C9C84),
                strokeWidth: 3,
              ),
              const SizedBox(height: 24),
              Text(
                'Breath in, breath out...',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: const Color(0xFF7C9C84).withOpacity(0.8),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EC), // Using consistent light beige/cream background
      floatingActionButton: _showBackToTop ? FloatingActionButton(
        onPressed: () {
          _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
        },
        backgroundColor: const Color(0xFF7C9C84),
        child: const Icon(Icons.arrow_upward, color: Colors.white),
      ) : null,
      body: SafeArea(
        child: NestedScrollView(
          controller: _scrollController,
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (Navigator.canPop(context))
                            Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF333333), size: 18),
                                ),
                              ),
                            ),
                          Text(
                            'Resource Hub',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF333333),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
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
                                  const Icon(Icons.notifications_none_outlined, color: Color(0xFF7C9C84), size: 24),
                                  StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('notifications')
                                        .where('to', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
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

              // Search Bar perfectly matching the Community screen layout
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
                      onTap: () {
                        // Auto-scroll so search bar is at top when keyboard opens
                        if (_scrollController.hasClients) {
                          _scrollController.animateTo(
                            72,
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Search resources...',
                        hintStyle: GoogleFonts.outfit(color: const Color(0xFFB3B3B3), fontSize: 14),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFFB3B3B3), size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.close, color: Color(0xFFB3B3B3), size: 20),
                          onPressed: () {
                            _searchController.clear();
                            FocusScope.of(context).unfocus();
                            setState(() {
                              _selectedMeditationCategory = 'All';
                              _selectedMeditationDuration = 'All';
                              _selectedArticleCategory = 'All';
                              _selectedArticleDuration = 'All';
                            });

                            if (_meditationFilterScrollController.hasClients) {
                              _meditationFilterScrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
                            }
                            if (_articleFilterScrollController.hasClients) {
                              _articleFilterScrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
                            }
                          },
                        )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ),
              ),
              if (_searchQuery.isEmpty) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Your Journey',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF333333),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const DetailedHistoryScreen()),
                            );
                          },
                          child: Text(
                            'VIEW DETAILED HISTORY',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: const Color(0xFF7C9C84),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 12),
                ),
                SliverToBoxAdapter(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('user_activity')
                        .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      int totalMins = 0;
                      int articlesCount = 0;

                      if (snapshot.hasData) {
                        for (var doc in snapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          if (data['type'] == 'meditation') {
                            final durStr = (data['duration'] ?? '0:00').toString();
                            final parts = durStr.split(':');
                            if (parts.length == 3) {
                              // HH:MM:SS
                              totalMins += (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
                            } else if (parts.length == 2) {
                              // MM:SS
                              totalMins += int.tryParse(parts[0]) ?? 0;
                            } else {
                              totalMins += int.tryParse(durStr) ?? 0;
                            }
                          } else if (data['type'] == 'article') {
                            final progress = data['progress'] ?? 0;
                            if (progress > 80) articlesCount++;
                          }
                        }
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildJourneyCard(
                                totalMins.toString(),
                                'MINS',
                                'MEDITATED',
                                Icons.timer,
                                (totalMins / 300).clamp(0.0, 1.0), // Goal of 300 mins
                                () { 
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const DetailedHistoryScreen(filterType: 'meditation')),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _buildJourneyCard(
                                articlesCount.toString(),
                                'ITEMS',
                                'ARTICLES READ',
                                Icons.menu_book,
                                (articlesCount / 50).clamp(0.0, 1.0), // Goal of 50 articles
                                () { 
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const DetailedHistoryScreen(filterType: 'article')),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 16),
                ),
              ],
              SliverAppBar(
                pinned: true,
                backgroundColor: const Color(0xFFF2F1EC),
                surfaceTintColor: Colors.transparent,
                automaticallyImplyLeading: false,
                toolbarHeight: 0,
                elevation: 0,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(50),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFEBEBE6), width: 1.5),
                        ),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: const Color(0xFF7C9C84), // Sage green accent
                        indicatorWeight: 2,
                        labelColor: const Color(0xFF7C9C84),
                        unselectedLabelColor: const Color(0xFFA3A3A3),
                        labelStyle: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        tabs: const [
                          Tab(text: 'Meditations'),
                          Tab(text: 'Articles'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              // --- MEDITATIONS TAB CONTENT ---
              CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      controller: _meditationFilterScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        children: [
                          _buildFilterChip('All', false, isSelected: _selectedMeditationCategory == 'All' && _selectedMeditationDuration == 'All', onTap: () {
                            setState(() { _selectedMeditationCategory = 'All'; _selectedMeditationDuration = 'All'; });
                            if (_meditationFilterScrollController.hasClients) {
                              _meditationFilterScrollController.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
                            }
                          }),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => _showMeditationDurationPicker(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedMeditationDuration != 'All' ? const Color(0xFF7C9C84) : Colors.white,
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: _selectedMeditationDuration != 'All' ? const Color(0xFF7C9C84) : const Color(0xFFEBEBE6),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  if (_selectedMeditationDuration != 'All')
                                    BoxShadow(
                                      color: const Color(0xFF7C9C84).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 16,
                                    color: _selectedMeditationDuration != 'All' ? Colors.white : const Color(0xFF666666),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _selectedMeditationDuration == 'All' ? 'Duration' : (_selectedMeditationDuration == 'UNDER_3' ? '< 3 min' : (_selectedMeditationDuration == '3_TO_5' ? '3 - 5 min' : (_selectedMeditationDuration == '5_TO_10' ? '5 - 10 min' : '10+ min'))),
                                    style: GoogleFonts.outfit(
                                      color: _selectedMeditationDuration != 'All' ? Colors.white : const Color(0xFF666666),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 16,
                                    color: _selectedMeditationDuration != 'All' ? Colors.white : const Color(0xFF666666),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildFilterChip('Favourite', false, isSelected: _selectedMeditationCategory == 'Favourite', onTap: () => _onMeditationFilterTap('Favourite')),
                          const SizedBox(width: 12),
                          _buildFilterChip('Recommend', false, isSelected: _selectedMeditationCategory == 'Recommend', onTap: () => _onMeditationFilterTap('Recommend')),
                          const SizedBox(width: 12),
                          _buildFilterChip('Stress', false, isSelected: _selectedMeditationCategory == 'Stress', onTap: () => _onMeditationFilterTap('Stress')),
                          const SizedBox(width: 12),
                          _buildFilterChip('Sleep', false, isSelected: _selectedMeditationCategory == 'Sleep', onTap: () => _onMeditationFilterTap('Sleep')),
                          const SizedBox(width: 12),
                          _buildFilterChip('Focus', false, isSelected: _selectedMeditationCategory == 'Focus', onTap: () => _onMeditationFilterTap('Focus')),
                          const SizedBox(width: 12),
                          _buildFilterChip('Breathing', false, isSelected: _selectedMeditationCategory == 'Breathing', onTap: () => _onMeditationFilterTap('Breathing')),
                          const SizedBox(width: 12),
                          _buildFilterChip('Mindfulness', false, isSelected: _selectedMeditationCategory == 'Mindfulness', onTap: () => _onMeditationFilterTap('Mindfulness')),
                          const SizedBox(width: 12),
                          _buildFilterChip('Guided', false, isSelected: _selectedMeditationCategory == 'Guided', onTap: () => _onMeditationFilterTap('Guided')),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  if (_selectedMeditationCategory == 'Recommend')
                    SliverToBoxAdapter(
                      child: _buildCounsellorAnnouncement(),
                    ),
                   if (_searchQuery.isEmpty && _selectedMeditationCategory == 'All')
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('meditation_guides').where('status', isEqualTo: 'published').snapshots(),
                      builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                        String? moodCategory;
                        if (_todayMood != null) {
                          switch (_todayMood!.toLowerCase()) {
                            case 'anxious': moodCategory = 'Stress'; break;
                            case 'angry': moodCategory = 'Breathing'; break;
                            case 'happy': moodCategory = 'Focus'; break;
                            case 'calm': moodCategory = 'Guided'; break;
                            case 'neutral': moodCategory = 'Mindfulness'; break;
                          }
                        }

                        final filteredDocs = snapshot.data!.docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;

                          bool matchesCategory = false;
                          if (_recommendedResourceIds.isNotEmpty && _recommendedResourceIds.contains(doc.id)) {
                            matchesCategory = true;
                          } else if (moodCategory != null && (data['category'] ?? '').toString() == moodCategory) {
                            matchesCategory = true;
                          }

                          return matchesCategory;
                        }).take(8).toList();

                        if (filteredDocs.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

                        return SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Suggested for You',
                                      style: GoogleFonts.playfairDisplay(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF333333),
                                      ),
                                    ),
                                    Text(
                                      'SEE ALL',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                        color: const Color(0xFFA3A3A3),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 320,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                  itemCount: filteredDocs.length,
                                  itemBuilder: (context, index) {
                                    final data = filteredDocs[index].data() as Map<String, dynamic>;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 16.0),
                                      child: _buildSuggestedCard(
                                        context,
                                        data['title'] ?? 'Untitled',
                                        '${data['duration']} • ${data['category']}',
                                        data['imageUrl'] ?? 'https://images.unsplash.com/photo-1505118380757-91f5f5632de0?q=80&w=2526&auto=format&fit=crop',
                                        audioUrl: data['audioUrl']?.toString(),
                                        rating: (data['rating'] as num?)?.toDouble(),
                                        isFavorite: _favoritedResources.contains(filteredDocs[index].id),
                                        onFavoriteToggle: () => _toggleFavorite(filteredDocs[index].id, data['title'] ?? 'Untitled'),
                                        resourceId: filteredDocs[index].id,
                                        isRecommended: _recommendedResourceIds.contains(filteredDocs[index].id),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        );
                      }
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    },
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        _selectedMeditationCategory == 'All' ? 'Daily Practice' : 
                        _selectedMeditationCategory == 'Favourite' ? 'Your Favourites' : 
                        _selectedMeditationCategory == 'Recommend' ? 'Recommended for You' : 
                        '${_selectedMeditationCategory} Meditations',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF333333),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: const SizedBox(height: 16)),
                  StreamBuilder<QuerySnapshot>(
                    stream: (_selectedMeditationCategory == 'All' || _selectedMeditationCategory == 'Favourite' || _selectedMeditationCategory == 'Recommend')
                        ? FirebaseFirestore.instance.collection('meditation_guides').where('status', isEqualTo: 'published').snapshots()
                        : FirebaseFirestore.instance.collection('meditation_guides').where('status', isEqualTo: 'published').where('category', isEqualTo: _selectedMeditationCategory).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                        // Filter client-side for search + duration + category
                        var filteredDocs = snapshot.data!.docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final title = (data['title'] ?? '').toString().toLowerCase();
                          final category = (data['category'] ?? '').toString().toLowerCase();
                          final durationStr = (data['duration'] ?? '').toString();

                          final matchesSearch = _searchQuery.isEmpty || title.contains(_searchQuery) || category.contains(_searchQuery);
                          bool matchesDuration = _selectedMeditationDuration == 'All';

                          final parts = durationStr.split(':');
                          int mins = 99;
                          if (durationStr.contains('min')) {
                            mins = int.tryParse(durationStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 99;
                          } else if (parts.length >= 2) {
                            mins = int.tryParse(parts[0]) ?? 99;
                          } else {
                            mins = int.tryParse(durationStr) ?? 99;
                          }

                          if (_selectedMeditationDuration == 'UNDER_3') matchesDuration = mins < 3;
                          else if (_selectedMeditationDuration == '3_TO_5') matchesDuration = mins >= 3 && mins <= 5;
                          else if (_selectedMeditationDuration == '5_TO_10') matchesDuration = mins > 5 && mins <= 10;
                          else if (_selectedMeditationDuration == 'OVER_10') matchesDuration = mins > 10;

                          bool matchesCategory = true;
                          if (_selectedMeditationCategory == 'Favourite') {
                            matchesCategory = _favoritedResources.contains(doc.id);
                          } else if (_selectedMeditationCategory == 'Recommend') {
                            matchesCategory = _recommendedResourceIds.contains(doc.id);
                          }

                          return matchesSearch && matchesDuration && matchesCategory;
                        }).toList();

                        // Relevance sort — best matches float to top when searching
                        if (_searchQuery.isNotEmpty) {
                          final q = _searchQuery;
                          filteredDocs.sort((a, b) {
                            final aData = a.data() as Map<String, dynamic>;
                            final bData = b.data() as Map<String, dynamic>;
                            int score(Map<String, dynamic> d) {
                              final title = (d['title'] ?? '').toString().toLowerCase();
                              final cat = (d['category'] ?? '').toString().toLowerCase();
                              if (title == q) return 0;
                              if (title.startsWith(q)) return 1;
                              if (title.contains(q)) return 2;
                              if (cat.startsWith(q)) return 3;
                              if (cat.contains(q)) return 4;
                              return 5;
                            }
                            return score(aData).compareTo(score(bData));
                          });
                        }

                        if (filteredDocs.isEmpty) {
                          return _buildEmptyState("No meditation guides match your search or filter.");
                        }

                        return SliverList(
                          delegate: SliverChildBuilderDelegate(
                                (context, index) {
                              final data = filteredDocs[index].data() as Map<String, dynamic>;
                              return _buildDailyPracticeCard(
                                context,
                                (data['category'] ?? 'RELAX').toString().toUpperCase(),
                                data['title'] ?? 'Untitled',
                                '${data['duration']} • Guided Session',
                                data['imageUrl'] ?? 'https://images.unsplash.com/photo-1505118380757-91f5f5632de0?q=80&w=2526&auto=format&fit=crop',
                                audioUrl: data['audioUrl'],
                                isFavorite: _favoritedResources.contains(filteredDocs[index].id),
                                onFavoriteToggle: () => _toggleFavorite(filteredDocs[index].id, data['title'] ?? 'Untitled'),
                                resourceId: filteredDocs[index].id,
                                isRecommended: _recommendedResourceIds.contains(filteredDocs[index].id),
                              );
                            },
                            childCount: filteredDocs.length,
                          ),
                        );
                      } else if (snapshot.hasData && snapshot.data!.docs.isEmpty) {
                        return _buildEmptyState("No meditation guides found in this category.");
                      } else if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SliverToBoxAdapter(child: Center(child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(color: Color(0xFF7C9C84)),
                        )));
                      } else {
                        return _buildEmptyState("No meditation guides found.");
                      }
                    },
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),

              // --- ARTICLES TAB CONTENT ---
              CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      controller: _articleFilterScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        children: [
                          _buildFilterChip('All', false, isSelected: _selectedArticleCategory == 'All' && _selectedArticleDuration == 'All', onTap: () {
                            setState(() { _selectedArticleCategory = 'All'; _selectedArticleDuration = 'All'; });
                            if (_articleFilterScrollController.hasClients) {
                              _articleFilterScrollController.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
                            }
                          }),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => _showArticleDurationPicker(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedArticleDuration != 'All' ? const Color(0xFF86A588) : Colors.white,
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: _selectedArticleDuration != 'All' ? const Color(0xFF86A588) : const Color(0xFFEBEBE6),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.auto_stories_outlined,
                                    size: 16,
                                    color: _selectedArticleDuration != 'All' ? Colors.white : const Color(0xFF666666),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _selectedArticleDuration == 'All' ? 'Reading Time' : (_selectedArticleDuration == 'UNDER_3' ? '< 3 min' : (_selectedArticleDuration == '3_TO_5' ? '3 - 5 min' : (_selectedArticleDuration == '5_TO_10' ? '5 - 10 min' : '10+ min'))),
                                    style: GoogleFonts.outfit(
                                      color: _selectedArticleDuration != 'All' ? Colors.white : const Color(0xFF666666),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 16,
                                    color: _selectedArticleDuration != 'All' ? Colors.white : const Color(0xFF666666),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildFilterChip('Favourite', false, isSelected: _selectedArticleCategory == 'Favourite', onTap: () => _onArticleFilterTap('Favourite')),
                          const SizedBox(width: 12),
                          _buildFilterChip('Recommend', false, isSelected: _selectedArticleCategory == 'Recommend', onTap: () => _onArticleFilterTap('Recommend')),
                          const SizedBox(width: 12),
                          _buildFilterChip('Mental Health', false, isSelected: _selectedArticleCategory == 'Mental Health', onTap: () => _onArticleFilterTap('Mental Health')),
                          const SizedBox(width: 12),
                          _buildFilterChip('Self-Care', false, isSelected: _selectedArticleCategory == 'Self-Care', onTap: () => _onArticleFilterTap('Self-Care')),
                          const SizedBox(width: 12),
                          _buildFilterChip('Anxiety', false, isSelected: _selectedArticleCategory == 'Anxiety', onTap: () => _onArticleFilterTap('Anxiety')),
                          const SizedBox(width: 12),
                          _buildFilterChip('Science-Backed', false, isSelected: _selectedArticleCategory == 'Science-Backed', onTap: () => _onArticleFilterTap('Science-Backed')),
                          const SizedBox(width: 12),
                          _buildFilterChip('Productivity', false, isSelected: _selectedArticleCategory == 'Productivity', onTap: () => _onArticleFilterTap('Productivity')),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  if (_selectedArticleCategory == 'Recommend')
                    SliverToBoxAdapter(
                      child: _buildCounsellorAnnouncement(),
                    ),
                  if (_searchQuery.isEmpty && _selectedArticleCategory == 'All')
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('articles').where('status', isEqualTo: 'published').snapshots(),
                      builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                        String? moodTag;
                        if (_todayMood != null) {
                          switch (_todayMood!.toLowerCase()) {
                            case 'anxious': moodTag = 'Anxiety'; break;
                            case 'angry': moodTag = 'Self-Care'; break;
                            case 'happy': moodTag = 'Mental Health'; break;
                            case 'calm': moodTag = 'Science-Backed'; break;
                            case 'neutral': moodTag = 'Self-Care'; break;
                          }
                        }

                        final filteredDocs = snapshot.data!.docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final title = (data['title'] ?? '').toString().toLowerCase();
                          final tag = (data['tag'] ?? '').toString().toLowerCase();
                          final readTime = (data['readingTime'] ?? '').toString().toLowerCase();

                          bool matchesDuration = _selectedArticleDuration == 'All';
                          if (_selectedArticleDuration == 'SHORT') {
                            if (readTime.contains('min')) {
                              final mins = int.tryParse(readTime.split(' ')[0]) ?? 99;
                              matchesDuration = mins < 3;
                            }
                          } else if (readTime.contains(_selectedArticleDuration.toLowerCase())) {
                            matchesDuration = true;
                          }

                          bool matchesCategory = false;
                          if (_recommendedResourceIds.isNotEmpty && _recommendedResourceIds.contains(doc.id)) {
                            matchesCategory = true;
                          } else if (moodTag != null && (data['tag'] ?? '').toString() == moodTag) {
                            matchesCategory = true;
                          }

                          return matchesCategory && matchesDuration;
                        }).take(8).toList();

                        if (filteredDocs.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

                        return SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Suggested for You',
                                      style: GoogleFonts.playfairDisplay(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF333333),
                                      ),
                                    ),
                                    Text(
                                      'SEE ALL',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                        color: const Color(0xFFA3A3A3),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 320,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                  itemCount: filteredDocs.length,
                                  itemBuilder: (context, index) {
                                    final data = filteredDocs[index].data() as Map<String, dynamic>;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 16.0),
                                      child: _buildGradientArticleCard(
                                        context,
                                        (data['tag'] ?? 'Wellness').toString().toUpperCase() == 'IMPROVE' ? 'RECOMMEND' : (data['tag'] ?? 'Wellness').toString().toUpperCase(),
                                        data['title'] ?? 'Untitled',
                                        '${data['readingTime'] ?? '5 min read'} • ${data['authorName'] ?? 'Eunoia Team'}',
                                        const [Color(0xFF86A588), Color(0xFF4C6150)],
                                        imageUrl: data['imageUrl'],
                                        content: data['content'],
                                        dbSubtitle: data['subtitle'],
                                        authorName: data['authorName'],
                                        authorRole: data['authorRole'],
                                        authorImageUrl: data['authorImageUrl'],
                                        publishDate: 'Just Now',
                                        readingTime: data['readingTime'],
                                        rating: (data['rating'] as num?)?.toDouble(),
                                        isFavorite: _favoritedResources.contains(filteredDocs[index].id),
                                        onFavoriteToggle: () => _toggleFavorite(filteredDocs[index].id, data['title'] ?? 'Untitled'),
                                        resourceId: filteredDocs[index].id,
                                        isRecommended: _recommendedResourceIds.contains(filteredDocs[index].id),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 32),
                            ],
                          ),
                        );
                      }
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    },
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        _selectedArticleCategory == 'All' ? 'Latest Reads' : 
                        _selectedArticleCategory == 'Favourite' ? 'Your Favourites' : 
                        _selectedArticleCategory == 'Recommend' ? 'Recommended for You' : 
                        '${_selectedArticleCategory} Articles',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF333333),
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  StreamBuilder<QuerySnapshot>(
                    stream: (_selectedArticleCategory == 'All' || _selectedArticleCategory == 'Favourite' || _selectedArticleCategory == 'Recommend')
                        ? FirebaseFirestore.instance.collection('articles').where('status', isEqualTo: 'published').snapshots()
                        : FirebaseFirestore.instance.collection('articles').where('status', isEqualTo: 'published').where('tag', isEqualTo: _selectedArticleCategory).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                        // Filter client-side for search + duration + category
                        var filteredDocs = snapshot.data!.docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final title = (data['title'] ?? '').toString().toLowerCase();
                          final tag = (data['tag'] ?? '').toString().toLowerCase();
                          final readTime = (data['readingTime'] ?? '').toString().toLowerCase();

                          final matchesSearch = _searchQuery.isEmpty || title.contains(_searchQuery) || tag.contains(_searchQuery);
                          bool matchesDuration = _selectedArticleDuration == 'All';
                          if (readTime.contains('min')) {
                            final mins = int.tryParse(readTime.split(' ')[0]) ?? 99;
                            if (_selectedArticleDuration == 'UNDER_3') matchesDuration = mins < 3;
                            else if (_selectedArticleDuration == '3_TO_5') matchesDuration = mins >= 3 && mins <= 5;
                            else if (_selectedArticleDuration == '5_TO_10') matchesDuration = mins > 5 && mins <= 10;
                            else if (_selectedArticleDuration == 'OVER_10') matchesDuration = mins > 10;
                          }

                          bool matchesArticleCategory = true;
                          if (_selectedArticleCategory == 'Favourite') {
                            matchesArticleCategory = _favoritedResources.contains(doc.id);
                          } else if (_selectedArticleCategory == 'Recommend') {
                            matchesArticleCategory = _recommendedResourceIds.contains(doc.id);
                          }

                          return matchesSearch && matchesDuration && matchesArticleCategory;
                        }).toList();

                        // Relevance sort — best matches float to top when searching
                        if (_searchQuery.isNotEmpty) {
                          final q = _searchQuery;
                          filteredDocs.sort((a, b) {
                            final aData = a.data() as Map<String, dynamic>;
                            final bData = b.data() as Map<String, dynamic>;
                            int score(Map<String, dynamic> d) {
                              final title = (d['title'] ?? '').toString().toLowerCase();
                              final tag = (d['tag'] ?? '').toString().toLowerCase();
                              if (title == q) return 0;
                              if (title.startsWith(q)) return 1;
                              if (title.contains(q)) return 2;
                              if (tag.startsWith(q)) return 3;
                              if (tag.contains(q)) return 4;
                              return 5;
                            }
                            return score(aData).compareTo(score(bData));
                          });
                        }

                        if (filteredDocs.isEmpty) {
                          return _buildEmptyState("No articles match your search or filter.");
                        }

                        return SliverList(
                          delegate: SliverChildBuilderDelegate(
                                (context, index) {
                              final data = filteredDocs[index].data() as Map<String, dynamic>;
                              return _buildDailyReadCard(
                                context,
                                (data['tag'] ?? 'READ').toString().toUpperCase(),
                                data['title'] ?? 'Untitled',
                                '${data['readingTime'] ?? '5 min read'} • ${data['authorName'] ?? 'Eunoia Team'}',
                                const [Color(0xFFCBD6AB), Color(0xFF7E8457)],
                                imageUrl: data['imageUrl'],
                                content: data['content'],
                                dbSubtitle: data['subtitle'],
                                authorName: data['authorName'],
                                authorRole: data['authorRole'],
                                authorImageUrl: data['authorImageUrl'],
                                publishDate: 'Just Now',
                                readingTime: data['readingTime'],
                                rating: (data['rating'] as num?)?.toDouble(),
                                isFavorite: _favoritedResources.contains(filteredDocs[index].id),
                                onFavoriteToggle: () => _toggleFavorite(filteredDocs[index].id, data['title'] ?? 'Untitled'),
                                resourceId: filteredDocs[index].id,
                                isRecommended: _recommendedResourceIds.contains(filteredDocs[index].id),
                              );
                            },
                            childCount: filteredDocs.length,
                          ),
                        );
                      } else if (snapshot.hasData && snapshot.data!.docs.isEmpty) {
                        return _buildEmptyState("No articles found in this category.");
                      } else if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SliverToBoxAdapter(child: Center(child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(color: Color(0xFF7C9C84)),
                        )));
                      } else {
                        return _buildEmptyState("No articles found.");
                      }
                    },
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestedCard(BuildContext context, String title, String subtitle, String imageUrl, {
    String? audioUrl,
    double? rating,
    required bool isFavorite,
    required VoidCallback onFavoriteToggle,
    required String resourceId,
    bool isRecommended = false,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResourcePreviewScreen(
              type: 'meditation',
              title: title.replaceAll('\n', ' '),
              subtitle: subtitle,
              tag: isRecommended ? 'COUNSELLOR' : 'RECOMMEND',
              imageUrl: imageUrl,
              duration: subtitle.contains(' • ') ? subtitle.split(' • ')[0] : '10:00',
              rating: rating,
              isFavorite: _favoritedResources.contains(resourceId),
              onFavoriteToggle: onFavoriteToggle,
              onStart: () {
                _recordView(resourceId, 'meditation');
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MeditationPlayerScreen(
                      title: title.replaceAll('\n', ' '),
                      subtitle: subtitle,
                      imageUrl: imageUrl,
                      duration: subtitle.contains(' • ') ? subtitle.split(' • ')[0] : '10:00',
                      audioUrl: audioUrl,
                      isFavorite: _favoritedResources.contains(resourceId),
                      onFavoriteToggle: onFavoriteToggle,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          image: DecorationImage(
            image: NetworkImage(imageUrl),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.1),
                Colors.black.withOpacity(0.7),
              ],
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              // Top-left: counsellor badge
              if (isRecommended)
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC5A880),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.white, size: 9),
                        const SizedBox(width: 3),
                        Text(
                          'COUNSELLOR',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Top-right: heart
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onFavoriteToggle,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isFavorite ? Colors.redAccent : Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
              // Bottom content
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (rating != null && rating > 0)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, color: Color(0xFFEAB308), size: 13),
                              const SizedBox(width: 3),
                              Text(
                                rating.toStringAsFixed(1),
                                style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Text(
                      title,
                      style: GoogleFonts.playfairDisplay(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onMeditationFilterTap(String category) {
    if (_selectedMeditationCategory == category) {
      setState(() => _selectedMeditationCategory = 'All');
      if (_meditationFilterScrollController.hasClients) {
        _meditationFilterScrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
      }
    } else {
      setState(() => _selectedMeditationCategory = category);
    }
  }

  void _onArticleFilterTap(String category) {
    if (_selectedArticleCategory == category) {
      setState(() => _selectedArticleCategory = 'All');
      if (_articleFilterScrollController.hasClients) {
        _articleFilterScrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
      }
    } else {
      setState(() => _selectedArticleCategory = category);
    }
  }

  Widget _buildFilterChip(String label, bool hasDropdown, {bool isSelected = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: hasDropdown ? 16 : 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7C9C84) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                color: isSelected ? Colors.white : const Color(0xFF666666),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (hasDropdown) ...[
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down, color: isSelected ? Colors.white : const Color(0xFF666666), size: 16),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildCounsellorAnnouncement() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8ECE9), Color(0xFFD2DDD6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF7C9C84).withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF7C9C84),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.spa_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Counsellor Recommendations',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C3E30),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'These resources were handpicked by your counsellor to support you on your mental wellness journey.',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: const Color(0xFF556B5B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyCard(String value, String unit, String subtitle, IconData icon, double progress, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 5,
                  backgroundColor: const Color(0xFFEBEBE6),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C9C84)), // Darker sage green
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Icon(
                    icon,
                    color: const Color(0xFF7C9C84),
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF333333),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: const Color(0xFF888888),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: const Color(0xFFA3A3A3),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildDailyPracticeCard(BuildContext context, String tag, String title, String subtitle, String imageUrl, {
    String? audioUrl,
    double? rating,
    required bool isFavorite,
    required VoidCallback onFavoriteToggle,
    required String resourceId,
    bool isRecommended = false,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResourcePreviewScreen(
              type: 'meditation',
              title: title,
              subtitle: subtitle,
              tag: tag == 'IMPROVE' ? 'RECOMMEND' : (isRecommended ? 'COUNSELLOR' : tag),
              imageUrl: imageUrl,
              duration: subtitle.split(' • ')[0],
              rating: rating,
              isFavorite: _favoritedResources.contains(resourceId),
              onFavoriteToggle: onFavoriteToggle,
              onStart: () {
                _recordView(resourceId, 'meditation');
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MeditationPlayerScreen(
                      title: title,
                      subtitle: 'Mindfulness Practice',
                      imageUrl: imageUrl,
                      duration: subtitle.split(' • ')[0],
                      audioUrl: audioUrl,
                      isFavorite: _favoritedResources.contains(resourceId),
                      onFavoriteToggle: onFavoriteToggle,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(left: 24, right: 24, bottom: 16),
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                width: 70,
                height: 70,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TAG row: tag text on left, star rating on right
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        tag,
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: const Color(0xFFA3A3A3),
                        ),
                      ),
                      if (rating != null && rating > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, color: Color(0xFFEAB308), size: 12),
                            const SizedBox(width: 2),
                            Text(
                              rating.toStringAsFixed(1),
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFA3A3A3),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  // RECOMMENDED badge on its own line (no overflow possible)
                  if (isRecommended) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC5A880).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFC5A880).withOpacity(0.4), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.spa_rounded, color: Color(0xFFC5A880), size: 9),
                          const SizedBox(width: 3),
                          Text(
                            'Recommended by Counsellor',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFFC5A880),
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: const Color(0xFFA3A3A3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onFavoriteToggle,
              child: Icon(
                isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isFavorite ? Colors.redAccent : const Color(0xFF333333).withOpacity(0.5),
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- NEW WIDGETS FOR ARTICLES TAB ---

  Widget _buildGradientArticleCard(BuildContext context, String tag, String title, String subtitle, List<Color> gradientColors, {
    String? imageUrl,
    String? content,
    String? dbSubtitle,
    String? authorName,
    String? authorRole,
    String? authorImageUrl,
    String? publishDate,
    String? readingTime,
    double? rating,
    required bool isFavorite,
    required VoidCallback onFavoriteToggle,
    required String resourceId,
    bool isRecommended = false,
  }) {
    return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResourcePreviewScreen(
                type: 'article',
                title: title,
                subtitle: dbSubtitle ?? subtitle,
                tag: isRecommended ? 'COUNSELLOR' : tag,
                imageUrl: imageUrl ?? 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b',
                duration: readingTime ?? '5 min read',
                rating: rating,
                authorName: authorName,
                content: content,
                isFavorite: _favoritedResources.contains(resourceId),
                onFavoriteToggle: onFavoriteToggle,
                onStart: () {
                  _recordView(resourceId, 'article');
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ArticleDetailScreen(
                        title: title,
                        subtitle: dbSubtitle ?? '',
                        tag: isRecommended ? 'COUNSELLOR' : tag,
                        authorName: authorName ?? 'Eunoia Team',
                        authorRole: authorRole ?? 'Contributor',
                        authorImageUrl: authorImageUrl ?? 'https://ui-avatars.com/api/?name=${authorName ?? 'Eunoia'}&background=7C9C84&color=fff',
                        publishDate: publishDate ?? 'Just Now',
                        content: content ?? '',
                        imageUrl: imageUrl ?? 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b',
                        readingTime: readingTime ?? '5 min read',
                        isFavorite: _favoritedResources.contains(resourceId),
                        onFavoriteToggle: onFavoriteToggle,
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
        child: Container(
          width: 240,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: imageUrl == null
                ? LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradientColors,
            )
                : null,
            image: imageUrl != null
                ? DecorationImage(
              image: NetworkImage(imageUrl),
              fit: BoxFit.cover,
            )
                : null,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.1),
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Stack(
              children: [
                // Top-left: counsellor badge
                if (isRecommended)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC5A880),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.white, size: 9),
                          const SizedBox(width: 3),
                          Text(
                            'COUNSELLOR',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Top-right: heart
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: onFavoriteToggle,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isFavorite ? Colors.redAccent : Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                // Bottom content
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              tag,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          if (rating != null && rating > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded, color: Color(0xFFEAB308), size: 12),
                                  const SizedBox(width: 3),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        style: GoogleFonts.playfairDisplay(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: GoogleFonts.outfit(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ));
  }

  Widget _buildDailyReadCard(BuildContext context, String tag, String title, String subtitle, List<Color> gradientColors, {
    String? imageUrl,
    String? content,
    String? dbSubtitle,
    String? authorName,
    String? authorRole,
    String? authorImageUrl,
    String? publishDate,
    String? readingTime,
    double? rating,
    required bool isFavorite,
    required VoidCallback onFavoriteToggle,
    required String resourceId,
    bool isRecommended = false,
  }) {
    return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResourcePreviewScreen(
                type: 'article',
                title: title,
                subtitle: dbSubtitle ?? subtitle,
                tag: isRecommended ? 'COUNSELLOR' : tag,
                imageUrl: imageUrl ?? 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b',
                duration: readingTime ?? '5 min read',
                rating: rating,
                authorName: authorName,
                content: content,
                isFavorite: _favoritedResources.contains(resourceId),
                onFavoriteToggle: onFavoriteToggle,
                onStart: () {
                  _recordView(resourceId, 'article');
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ArticleDetailScreen(
                        title: title,
                        subtitle: dbSubtitle ?? '',
                        tag: isRecommended ? 'COUNSELLOR' : tag,
                        authorName: authorName ?? 'Eunoia Team',
                        authorRole: authorRole ?? 'Contributor',
                        authorImageUrl: authorImageUrl ?? 'https://ui-avatars.com/api/?name=${authorName ?? 'Eunoia'}&background=7C9C84&color=fff',
                        publishDate: publishDate ?? 'Just Now',
                        content: content ?? '',
                        imageUrl: imageUrl ?? 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b',
                        readingTime: readingTime ?? '5 min read',
                        isFavorite: _favoritedResources.contains(resourceId),
                        onFavoriteToggle: onFavoriteToggle,
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(left: 24, right: 24, bottom: 16),
          padding: const EdgeInsets.all(16),
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
          child: Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: gradientColors,
                  ),
                ),
                child: imageUrl != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.article_outlined, color: Colors.white, size: 30),
                  ),
                )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TAG row: tag text left, rating right
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tag,
                          style: GoogleFonts.outfit(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: const Color(0xFFA3A3A3),
                          ),
                        ),
                        if (rating != null && rating > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, color: Color(0xFFEAB308), size: 10),
                              const SizedBox(width: 2),
                              Text(
                                rating.toStringAsFixed(1),
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFA3A3A3),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    // RECOMMENDED badge on its own line
                    if (isRecommended) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC5A880).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFC5A880).withOpacity(0.4), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.spa_rounded, color: Color(0xFFC5A880), size: 9),
                            const SizedBox(width: 3),
                            Text(
                              'Recommended by Counsellor',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFFC5A880),
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: const Color(0xFFA3A3A3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.share, color: Color(0xFFD6D6D6), size: 20),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: onFavoriteToggle,
                    child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.redAccent : const Color(0xFFD6D6D6),
                        size: 20
                    ),
                  ),
                ],
              )
            ],
          ),
        ));
  }
  Widget _buildEmptyState(String message) {
    return SliverToBoxAdapter(
      child: _buildEmptyWidget(message),
    );
  }

  Widget _buildEmptyWidget(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF7C9C84).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              color: Color(0xFF7C9C84),
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "No results found",
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: const Color(0xFF888888),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _selectedMeditationCategory = 'All';
                _selectedMeditationDuration = 'All';
                _selectedArticleCategory = 'All';
                _selectedArticleDuration = 'All';
                _searchQuery = '';
                _searchController.clear();
              });
              if (_meditationFilterScrollController.hasClients) {
                _meditationFilterScrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
              }
              if (_articleFilterScrollController.hasClients) {
                _articleFilterScrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C9C84),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              "Clear Filters",
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showMeditationDurationPicker(BuildContext context) {
    _showPicker(
      context,
      'Meditation Duration',
      [
        _PickerOption('All', 'All Durations', Icons.all_inclusive, Colors.grey),
        _PickerOption('UNDER_3', '< 3 min', Icons.flash_on_outlined, Colors.amber),
        _PickerOption('3_TO_5', '3 - 5 min', Icons.timer_outlined, Colors.blue),
        _PickerOption('5_TO_10', '5 - 10 min', Icons.timer_outlined, Colors.indigo),
        _PickerOption('OVER_10', '10+ min', Icons.hourglass_bottom_outlined, Colors.purple),
      ],
      _selectedMeditationDuration,
          (val) => setState(() => _selectedMeditationDuration = val),
      const Color(0xFF7C9C84),
    );
  }

  void _showArticleDurationPicker(BuildContext context) {
    _showPicker(
      context,
      'Reading Time',
      [
        _PickerOption('All', 'All Reads', Icons.all_inclusive, Colors.grey),
        _PickerOption('UNDER_3', '< 3 min', Icons.bolt, Colors.amber),
        _PickerOption('3_TO_5', '3 - 5 min', Icons.auto_stories_outlined, Colors.blue),
        _PickerOption('5_TO_10', '5 - 10 min', Icons.auto_stories_outlined, Colors.indigo),
        _PickerOption('OVER_10', '10+ min', Icons.auto_stories_outlined, Colors.purple),
      ],
      _selectedArticleDuration,
          (val) => setState(() => _selectedArticleDuration = val),
      const Color(0xFF86A588),
    );
  }

  void _showPicker(BuildContext context, String title, List<_PickerOption> options, String currentValue, Function(String) onSelected, Color themeColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFEBEBE6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 20),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final opt = options[index];
                  final isSelected = opt.value == currentValue;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        onSelected(opt.value);
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: isSelected ? themeColor.withOpacity(0.08) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? themeColor : const Color(0xFFEBEBE6),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(opt.icon, color: isSelected ? themeColor : opt.color, size: 24),
                            const SizedBox(width: 16),
                            Text(
                              opt.label,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? themeColor : const Color(0xFF666666),
                              ),
                            ),
                            const Spacer(),
                            if (isSelected)
                              Icon(Icons.check_circle, color: themeColor, size: 24),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _PickerOption {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  _PickerOption(this.value, this.label, this.icon, this.color);
}
