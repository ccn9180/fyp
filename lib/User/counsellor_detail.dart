import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'book_session.dart';

class CounsellorDetailScreen extends StatelessWidget {
  final String counsellorId;
  final String name;
  final String specialty;
  final String rating;
  final String experience;
  final String patients;
  final String imageUrl;
  final String about;

  const CounsellorDetailScreen({
    super.key,
    required this.counsellorId,
    this.name = 'Dr. Sarah Eunoia',
    this.specialty = 'Licensed Clinical Psychologist',
    this.rating = '4.9',
    this.experience = '12 yrs',
    this.patients = '500+',
    this.imageUrl = 'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?auto=format&fit=crop&q=80&w=2000',
    this.about = 'Dr. Sarah specializes in mindful-based cognitive therapy and trauma recovery...',
  });

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
                    'Counselor Profile',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: textColorMain,
                    ),
                  ),
                  _buildRoundButton(
                    icon: Icons.favorite_border_rounded,
                    isFavorite: true, // Should probably be dynamic, but following existing logic
                    isHeart: true,
                    onTap: () {},
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
                              image: imageUrl.startsWith('data:image')
                                  ? MemoryImage(base64Decode(imageUrl.split(',').last)) as ImageProvider
                                  : NetworkImage(imageUrl),
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
                      name,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: textColorMain,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      specialty,
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
                          'PhD, PsyD • $experience experience',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: textColorSub,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Stats Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatCard('PATIENTS', patients),
                        _buildStatCard('EXPERIENCE', experience),
                        _buildStatCard('RATING', rating, isRating: true),
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
                          about,
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
                          children: [
                            _buildSpecialtyChip('Anxiety Recovery'),
                            _buildSpecialtyChip('Mindfulness'),
                            _buildSpecialtyChip('LGTBQ+ Affirming'),
                            _buildSpecialtyChip('PTSD'),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Reviews Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Patient Reviews',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: textColorMain,
                          ),
                        ),
                        Text(
                          'View All',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF98B3A1),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Review Card (Single Example)
                    Container(
                      padding: const EdgeInsets.all(20),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: const Color(0xFFEEF3F0),
                                child: Text(
                                  'M',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF98B3A1),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Michael R.',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w600,
                                      color: textColorMain,
                                    ),
                                  ),
                                  Row(
                                    children: List.generate(5, (index) => const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 16)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '"Dr. Sarah has a unique way of making you feel heard and understood from the very first session."',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: textColorSub,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 100), // Space for button
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
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
                    counsellorId: counsellorId,
                    name: name,
                    specialty: specialty,
                    rating: rating,
                    profileImage: imageUrl,
                    sessionsCount: 120,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.calendar_month_outlined, color: Colors.white),
            label: Text(
              'Book a Session',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
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
          color: isHeart && isFavorite ? Colors.redAccent : const Color(0xFF333333),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, {bool isRating = false}) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 20),
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
                const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 18),
                const SizedBox(width: 4),
              ],
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF333333),
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
