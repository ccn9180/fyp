import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'notifications.dart';
import 'counsellor_detail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

class CounsellorScreen extends StatefulWidget {
  const CounsellorScreen({super.key});

  @override
  State<CounsellorScreen> createState() => _CounsellorScreenState();
}

class _CounsellorScreenState extends State<CounsellorScreen> {
  String _selectedSpecialty = 'All';
  bool _showOnlyFavorites = false;
  String _selectedGender = 'Any';
  String _selectedLanguage = 'Any';
  List<dynamic> _userFavorites = [];
  String _searchQuery = '';
  
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFF2F1EC);
  final Color textColorMain = const Color(0xFF333333);
  final Color textColorSub = const Color(0xFF888888);

  late Stream<QuerySnapshot> _counsellorsStream;
  late Stream<DocumentSnapshot> _userFavsStream;
  late Stream<QuerySnapshot> _bookingsStream;

  @override
  void initState() {
    super.initState();
    _counsellorsStream = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'counsellor')
        .snapshots();

    _userFavsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser?.uid)
        .snapshots();

    _bookingsStream = FirebaseFirestore.instance
        .collection('counsellor_bookings')
        .where('patientId', isEqualTo: _currentUser?.uid)
        .orderBy('startTime', descending: false)
        .where('startTime', isGreaterThan: Timestamp.now())
        .limit(1)
        .snapshots();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
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

  void _scrollToSearch() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        380, // Offset to push up Journey and Title
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: StreamBuilder<QuerySnapshot>(
        stream: _counsellorsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF7C9C84)));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading counselors', style: GoogleFonts.outfit()));
          }

          return StreamBuilder<DocumentSnapshot>(
            stream: _userFavsStream,
            builder: (context, userSnapshot) {
              if (userSnapshot.hasData && userSnapshot.data != null) {
                final data = userSnapshot.data!.data() as Map<String, dynamic>?;
                _userFavorites = data?['favoriteCounsellors'] ?? [];
              }

              final allCounsellors = snapshot.data!.docs;

              // Apply All Frontend Filters Simultaneously
              final filteredCounsellors = allCounsellors.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                
                // 1. Specialty Filter
                if (_selectedSpecialty != 'All') {
                  final List<dynamic> specs = data['specializations'] ?? [];
                  if (!specs.any((spec) => spec.toString().toLowerCase().contains(_selectedSpecialty.toLowerCase()))) return false;
                }

                // 2. Favorites Filter
                if (_showOnlyFavorites) {
                  if (!_userFavorites.contains(doc.id)) return false;
                }

                // 3. Gender Filter
                if (_selectedGender != 'Any') {
                  final gender = (data['gender'] ?? '').toString().toLowerCase();
                  if (gender != _selectedGender.toLowerCase()) return false;
                }

                // 4. Language Filter
                if (_selectedLanguage != 'Any') {
                  final List<dynamic> languages = data['languages'] ?? [];
                  if (!languages.any((lang) => lang.toString().toLowerCase() == _selectedLanguage.toLowerCase())) return false;
                }

                // 5. Search Filter
                if (_searchQuery.isNotEmpty) {
                  final name = (data['fullName'] ?? '').toString().toLowerCase();
                  final List<dynamic> specs = data['specializations'] ?? [];
                  final matchesName = name.contains(_searchQuery);
                  final matchesSpecs = specs.any((spec) => spec.toString().toLowerCase().contains(_searchQuery));
                  if (!matchesName && !matchesSpecs) return false;
                }

                return true;
              }).toList();

              return CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // 1. Title Header (Floating)
                  SliverAppBar(
                    floating: true,
                    pinned: false,
                    backgroundColor: backgroundColor,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    surfaceTintColor: Colors.transparent,
                    automaticallyImplyLeading: false,
                    titleSpacing: 24,
                    title: Text(
                      'Counselors',
                      style: GoogleFonts.playfairDisplay(
                        color: textColorMain,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: 24.0),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(Icons.notifications_none_outlined, color: primaryGreen, size: 24),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 2. Upcoming Sessions (Scrolls away)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _bookingsStream,
                        builder: (context, bookingSnapshot) {
                          if (bookingSnapshot.hasData && bookingSnapshot.data!.docs.isNotEmpty) {
                            final bookingData = bookingSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader('UPCOMING SESSIONS', 'SEE ALL'),
                                const SizedBox(height: 16),
                                _buildMainUpcomingCard(context, bookingData: bookingData),
                                const SizedBox(height: 32),
                              ],
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader('YOUR JOURNEY'),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Color(0xFF86A590), Color(0xFF7C9C84)]),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Ready to start healing?',
                                        style: GoogleFonts.playfairDisplay(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Text('Book your first session with an authorized counselor today.',
                                        style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.9), fontSize: 13)),
                                    const SizedBox(height: 20),
                                    ElevatedButton(
                                      onPressed: () {
                                        _scrollController.animateTo(350, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: primaryGreen,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        elevation: 0,
                                      ),
                                      child: Text('Find Support', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                  // 3. STICKY Search & Filters (Pushed up and stays there)
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: SearchHeaderDelegate(
                      height: 240, // Height for title + search + chips + headers
                      backgroundColor: backgroundColor,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Find a Counselor',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: textColorMain,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildSearchBar(),
                            const SizedBox(height: 16),
                            _buildFilterChips(),
                            const SizedBox(height: 32),
                            _buildSectionHeader('RECOMMENDED FOR YOU'),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 4. Results List
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: filteredCounsellors.isEmpty
                        ? SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.person_search_rounded, size: 64, color: primaryGreen.withOpacity(0.2)),
                                    const SizedBox(height: 16),
                                    Text('No counselors found in this category',
                                        style: GoogleFonts.outfit(color: Colors.grey[500])),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final doc = filteredCounsellors[index];
                                final data = doc.data() as Map<String, dynamic>;
                                final name = data['fullName'] ?? 'Expert Counselor';
                                final specs = data['specializations'] as List<dynamic>? ?? ['Mental Health Specialist'];
                                final specialty = specs.isNotEmpty ? specs[0].toString() : 'Expert Therapist';
                                final rating = data['rating']?.toString() ?? '5.0';
                                final reviews = data['reviews']?.toString() ?? '0';
                                final price = data['price']?.toString() ?? 'Free';
                                final imageUrl = data['counsellorImageUrl'] ?? data['profileImageUrl'];
                                final isOnline = data['isOnline'] ?? true;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _buildRecommendedCard(
                                    context,
                                    name: name,
                                    specialty: specialty,
                                    rating: rating,
                                    reviews: reviews,
                                    price: price.startsWith('\$') ? price : '\$${price}/hr',
                                    imageUrl: imageUrl ?? 'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?auto=format&fit=crop&q=80&w=2000',
                                    isOnline: isOnline,
                                    isFavorite: _userFavorites.contains(doc.id),
                                    bgColor: const Color(0xFFF3E7C9),
                                    data: {...data, 'id': doc.id}, 
                                  ),
                                );
                              },
                              childCount: filteredCounsellors.length,
                            ),
                          ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, [String? actionLabel]) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: const Color(0xFF888888),
          ),
        ),
        if (actionLabel != null)
          Text(
            actionLabel,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: primaryGreen,
            ),
          ),
      ],
    );
  }

  Widget _buildMainUpcomingCard(BuildContext context, {Map<String, dynamic>? bookingData}) {
    final name = bookingData?['counsellorName'] ?? 'Dr. Sarah Eunoia';
    final specialty = bookingData?['counsellorSpecialty'] ?? 'Mental Wellness Counselor';
    final startTime = (bookingData?['startTime'] as Timestamp?)?.toDate() ?? DateTime.now();
    final imageUrl = bookingData?['counsellorImageUrl'] ?? 'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?auto=format&fit=crop&q=80&w=2000';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CounsellorDetailScreen(
              counsellorId: bookingData?['counsellorId'] ?? '',
              name: name,
              specialty: specialty,
              imageUrl: imageUrl,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: imageUrl.startsWith('data:image')
                      ? Image.memory(base64Decode(imageUrl.split(',').last), height: 180, width: double.infinity, fit: BoxFit.cover, alignment: Alignment.topCenter)
                      : Image.network(
                    imageUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      startTime.difference(DateTime.now()).inMinutes < 60 ? 'LIVE SOON' : 'UPCOMING',
                      style: GoogleFonts.outfit(
                        color: primaryGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${DateFormat('MMM dd').format(startTime)} • ${DateFormat('hh:mm a').format(startTime)}',
                    style: GoogleFonts.outfit(
                      color: primaryGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    style: GoogleFonts.playfairDisplay(
                      color: textColorMain,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    specialty,
                    style: GoogleFonts.outfit(
                      color: textColorSub,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            'Join Session',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8EFEA),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Icon(Icons.more_horiz, color: primaryGreen),
                        ),
                      )
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextField(
        controller: _searchController,
        onTap: _scrollToSearch,
        style: GoogleFonts.outfit(
          color: textColorMain,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: 'Search by name, specialty, or concern...',
          hintStyle: GoogleFonts.outfit(
            color: const Color(0xFFC0C0C0),
            fontSize: 14,
          ),
          prefixIcon: const Icon(Icons.search, color: Color(0xFFC0C0C0)),
          suffixIcon: _searchQuery.isNotEmpty 
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    FocusScope.of(context).unfocus();
                  },
                  icon: const Icon(Icons.close_rounded, color: Color(0xFFC0C0C0), size: 18),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      key: const PageStorageKey('counsellor_filter_scroller'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildPillFilter('All', isSelected: _selectedSpecialty == 'All' && _selectedGender == 'Any' && _selectedLanguage == 'Any' && !_showOnlyFavorites, onTap: () {
            _scrollToSearch();
            setState(() {
              _selectedSpecialty = 'All';
              _selectedGender = 'Any';
              _selectedLanguage = 'Any';
              _showOnlyFavorites = false;
            });
          }),
          const SizedBox(width: 8),
          _buildPillFilter('Favourite', isSelected: _showOnlyFavorites, onTap: () {
            _scrollToSearch();
            setState(() => _showOnlyFavorites = !_showOnlyFavorites);
          }),
          const SizedBox(width: 8),
          _buildPillFilter(_selectedGender == 'Any' ? 'Gender' : _selectedGender, hasDropdown: true, isSelected: _selectedGender != 'Any', onTap: () {
            _scrollToSearch();
            _showGenderPicker();
          }),
          const SizedBox(width: 8),
          _buildPillFilter(_selectedLanguage == 'Any' ? 'Language' : _selectedLanguage, hasDropdown: true, isSelected: _selectedLanguage != 'Any', onTap: () {
            _scrollToSearch();
            _showLanguagePicker();
          }),
          const SizedBox(width: 8),
          ...['Anxiety', 'Grief', 'Growth', 'Stress'].map((filter) {
            final bool isSelected = filter == _selectedSpecialty;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildPillFilter(filter, isSelected: isSelected, onTap: () {
                _scrollToSearch();
                setState(() => _selectedSpecialty = filter);
              }),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildPillFilter(String label, {bool isSelected = false, bool hasDropdown = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: hasDropdown ? 16 : 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: isSelected ? [] : [
            BoxShadow(
              color: Colors.black.withAlpha(5),
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
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            if (hasDropdown) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: isSelected ? Colors.white : const Color(0xFF666666),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showGenderPicker() {
    _showPickerBottomSheet(
      title: 'Select Gender',
      options: ['Any', 'Male', 'Female'],
      currentValue: _selectedGender,
      onSelected: (val) => setState(() => _selectedGender = val),
    );
  }

  void _showLanguagePicker() {
    _showPickerBottomSheet(
      title: 'Select Language',
      options: ['Any', 'English', 'Malay', 'Chinese'],
      currentValue: _selectedLanguage,
      onSelected: (val) => setState(() => _selectedLanguage = val),
    );
  }

  void _showPickerBottomSheet({
    required String title,
    required List<String> options,
    required String currentValue,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColorMain,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...options.map((option) {
              final isSelected = option == currentValue;
              return InkWell(
                onTap: () {
                  onSelected(option);
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        option,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? primaryGreen : textColorMain,
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle_rounded, color: primaryGreen, size: 20),
                    ],
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }


  Widget _buildRecommendedCard(
      BuildContext context, {
        required String name,
        required String specialty,
        required String rating,
        required String reviews,
        required String price,
        required String imageUrl,
        required bool isOnline,
        Color bgColor = const Color(0xFFEBCDAA),
        Map<String, dynamic>? data,
        bool isFavorite = false,
      }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CounsellorDetailScreen(
              counsellorId: data?['id'] ?? '',
              name: name,
              specialty: specialty,
              rating: rating,
              imageUrl: imageUrl,
              experience: data?['experience'] ?? '5 yrs',
              about: data?['counsellorBio'] ?? 'Dedicated mental health professional.',
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(20),
                    image: DecorationImage(
                      image: imageUrl.startsWith('data:image')
                          ? MemoryImage(base64Decode(imageUrl.split(',').last)) as ImageProvider
                          : NetworkImage(imageUrl),
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                  ),
                ),
                if (isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5AB46E), // online green
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.outfit(
                            color: textColorMain,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    specialty,
                    style: GoogleFonts.outfit(
                      color: primaryGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Color(0xFFFFB800), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        rating,
                        style: GoogleFonts.outfit(
                          color: textColorMain,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () async {
                          final docRef = FirebaseFirestore.instance.collection('users').doc(_currentUser?.uid);
                          if (_userFavorites.contains(data?['id'])) {
                            await docRef.update({'favoriteCounsellors': FieldValue.arrayRemove([data?['id']])});
                          } else {
                            await docRef.update({'favoriteCounsellors': FieldValue.arrayUnion([data?['id']])});
                          }
                        },
                        child: Icon(
                          _userFavorites.contains(data?['id']) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: _userFavorites.contains(data?['id']) ? primaryGreen : const Color(0xFFDADADA),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '($reviews)',
                        style: GoogleFonts.outfit(
                          color: textColorSub,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F5F1), // Very light green bg
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          price,
                          style: GoogleFonts.outfit(
                            color: primaryGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;
  final Color backgroundColor;

  SearchHeaderDelegate({
    required this.child,
    required this.height,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      alignment: Alignment.center,
      child: child,
    );
  }

  @override
  double get maxExtent => height;
  @override
  double get minExtent => height;
  @override
  bool shouldRebuild(SliverPersistentHeaderDelegate oldDelegate) => true;
}
