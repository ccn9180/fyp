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
  String _selectedFilter = 'All';
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFEAE9E4);
  final Color textColorMain = const Color(0xFF333333);
  final Color textColorSub = const Color(0xFF888888);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'counsellor')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF7C9C84)));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading counselors', style: GoogleFonts.outfit()));
          }

          final allCounsellors = snapshot.data!.docs;

          // Apply Frontend Filtering based on _selectedFilter
          final filteredCounsellors = allCounsellors.where((doc) {
            if (_selectedFilter == 'All') return true;
            final data = doc.data() as Map<String, dynamic>;
            final List<dynamic> specs = data['specializations'] ?? [];
            return specs.any((spec) => spec.toString().toLowerCase().contains(_selectedFilter.toLowerCase()));
          }).toList();

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            children: [
              // Real Upcoming Sessions logic
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('counsellor_bookings')
                    .where('patientId', isEqualTo: _currentUser?.uid)
                    .orderBy('startTime', descending: false)
                    .where('startTime', isGreaterThan: Timestamp.now())
                    .limit(1)
                    .snapshots(),
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

                  // Empty state for upcoming sessions
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
                                // Maybe scroll to "Find a Counselor"
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

              if (filteredCounsellors.isEmpty)
                Padding(
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
                )
              else
                ...filteredCounsellors.map((doc) {
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
                      bgColor: const Color(0xFFF3E7C9),
                      data: {...data, 'id': doc.id}, // Pass the whole data with correct ID for detail screen
                    ),
                  );
                }).toList(),

              const SizedBox(height: 48),
            ],
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
      ),);
  }



  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextField(
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
    final filters = ['All', 'Anxiety', 'Grief', 'Growth', 'Stress'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = filter == _selectedFilter;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedFilter = filter;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? primaryGreen : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  filter,
                  style: GoogleFonts.outfit(
                    color: isSelected ? Colors.white : const Color(0xFF7A8B7F),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
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
                      const Icon(Icons.favorite_rounded, color: Color(0xFFDADADA), size: 24),
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
      ),);
  }
}
