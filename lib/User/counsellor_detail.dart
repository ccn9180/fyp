import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'book_session.dart';

class CounsellorDetailScreen extends StatefulWidget {
  final String counsellorId;
  final String name;
  final String specialty;
  final String rating;
  final String experience;
  final String patients;
  final String imageUrl;
  final String about;
  final String price;

  const CounsellorDetailScreen({
    super.key,
    required this.counsellorId,
    this.name = 'Counsellor',
    this.specialty = 'Professional Counsellor',
    this.rating = '-',
    this.experience = '-',
    this.patients = '-',
    this.imageUrl = 'https://ui-avatars.com/api/?name=Counsellor&background=random',
    this.about = 'Professional counsellor dedicated to providing a safe and supportive space.',
    this.price = 'Free',
  });

  @override
  State<CounsellorDetailScreen> createState() => _CounsellorDetailScreenState();
}

class _CounsellorDetailScreenState extends State<CounsellorDetailScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  bool isFavorited = false;
  bool isLoading = true;
  bool _isLoadingDetails = true;
  Map<String, dynamic>? _counsellorData;

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus();
    _fetchCounsellorDetails();
  }

  Future<void> _fetchCounsellorDetails() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.counsellorId)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _counsellorData = doc.data();
          _isLoadingDetails = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingDetails = false);
      }
    } catch (e) {
      print("Error fetching counsellor details: $e");
      if (mounted) setState(() => _isLoadingDetails = false);
    }
  }

  List<String> _getCounsellorSpecializations() {
    if (_counsellorData != null) {
      final List<dynamic>? specs = _counsellorData!['specializations'];
      if (specs != null && specs.isNotEmpty) {
        return List<String>.from(specs);
      }
    }
    return [widget.specialty];
  }

  List<String> _getCounsellorLanguages() {
    if (_counsellorData != null) {
      final dynamic langData = _counsellorData!['languages'];
      if (langData is List && langData.isNotEmpty) {
        return List<String>.from(langData);
      } else if (langData is String && langData.isNotEmpty) {
        return langData.split(', ').toList();
      }
    }
    return ['English'];
  }

  Widget _buildLanguageChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF3F0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 14,
          color: const Color(0xFF4C5E51),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _checkFavoriteStatus() async {
    if (currentUser == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      
      if (doc.exists) {
        final List<dynamic> favorites = doc.data()?['favoriteCounsellors'] ?? [];
        setState(() {
          isFavorited = favorites.contains(widget.counsellorId);
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error checking favorite: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (currentUser == null) return;

    final docRef = FirebaseFirestore.instance.collection('users').doc(currentUser!.uid);
    
    try {
      if (isFavorited) {
        await docRef.update({
          'favoriteCounsellors': FieldValue.arrayRemove([widget.counsellorId])
        });
      } else {
        await docRef.update({
          'favoriteCounsellors': FieldValue.arrayUnion([widget.counsellorId])
        });
      }
      setState(() => isFavorited = !isFavorited);
    } catch (e) {
      print("Error toggling favorite: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = const Color(0xFF7C9C84);
    final Color backgroundColor = const Color(0xFFFBFBF6);
    final Color textColorMain = const Color(0xFF333333);
    final Color textColorSub = const Color(0xFF888888);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildRoundButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  Text(
                    'COUNSELOR PROFILE',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: const Color(0xFF5D6D66),
                    ),
                  ),
                  _buildRoundButton(
                    icon: isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    isFavorite: isFavorited,
                    isHeart: true,
                    onTap: _toggleFavorite,
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                    // Profile Image with Verification Badge
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(40),
                            image: DecorationImage(
                              image: widget.imageUrl.startsWith('data:image')
                                  ? MemoryImage(base64Decode(widget.imageUrl.split(',').last)) as ImageProvider
                                  : NetworkImage(widget.imageUrl),
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF98B3A1), // Soft green badge
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Name and Title
                    Text(
                      widget.name,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        color: textColorMain,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.specialty,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        color: const Color(0xFF98B3A1),
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 12),
                    
                    // Credentials
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.school_outlined, size: 16, color: Color(0xFF888888)),
                        const SizedBox(width: 6),
                        Text(
                          'License: ${_counsellorData?['licenseNumber'] ?? 'Verifying...'} • ${widget.experience} exp',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: textColorSub,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.monetization_on_outlined, size: 16, color: Color(0xFF888888)),
                        const SizedBox(width: 6),
                        Text(
                          (widget.price.toLowerCase() == 'free' || widget.price == '0' || widget.price.trim().isEmpty)
                              ? 'Free Session'
                              : (widget.price.startsWith('RM') ? widget.price : 'RM${widget.price}/hr'),
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: primaryGreen,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Stats Row
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('PATIENTS', widget.patients)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard('EXPERIENCE', widget.experience)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard('RATING', widget.rating, isRating: true)),
                      ],
                    ),
                  ],
                ),
              ),

                    const SizedBox(height: 40),

                    // About Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: textColorMain,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _counsellorData?['bio'] ?? widget.about,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            color: const Color(0xFF7A8981),
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Specialties Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Specialties',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: textColorMain,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: _getCounsellorSpecializations().map((spec) => _buildSpecialtyChip(spec)).toList(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Languages Spoken Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Languages Spoken',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: textColorMain,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: _getCounsellorLanguages().map((lang) => _buildLanguageChip(lang)).toList(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 100), // Space for button
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: (currentUser?.uid == widget.counsellorId)
          ? Container(
              color: backgroundColor,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Center(
                  child: Text(
                    'This is your professional profile',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
            )
          : Container(
              color: backgroundColor,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BookSessionScreen(
                          counsellorId: widget.counsellorId,
                          name: widget.name,
                          specialty: widget.specialty,
                          rating: widget.rating,
                          profileImage: widget.imageUrl,
                          sessionsCount: 120,
                          price: widget.price,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.calendar_month_outlined, color: Colors.white),
                  label: Text(
                    'Book a Session',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF86A590),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildRoundButton({required IconData icon, required VoidCallback onTap, bool isFavorite = false, bool isHeart = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
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
        child: Icon(
          isHeart ? (isFavorite ? Icons.favorite_rounded : Icons.favorite_outline_rounded) : icon,
          size: 20,
          color: isHeart && isFavorite ? const Color(0xFF86A590) : const Color(0xFF333333),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, {bool isRating = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFC4C4C4),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isRating) ...[
                const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 16),
                const SizedBox(width: 2),
              ],
              Flexible(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF333333),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialtyChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 14,
          color: const Color(0xFF5A6B63),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
