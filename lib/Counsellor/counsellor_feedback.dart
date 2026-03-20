
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CounsellorFeedbackScreen extends StatelessWidget {
  const CounsellorFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = const Color(0xFF7C9C84);
    final Color backgroundColor = const Color(0xFFF2F1EC);
    final Color textColorMain = const Color(0xFF333333);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Client Feedback',
          style: GoogleFonts.playfairDisplay(color: textColorMain, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rating Overview
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '4.92',
                        style: GoogleFonts.outfit(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: textColorMain,
                        ),
                      ),
                      Row(
                        children: List.generate(
                          5,
                              (idx) => Icon(
                            idx < 4 ? Icons.star_rounded : Icons.star_half_rounded,
                            color: Colors.amber,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Based on 124 reviews',
                        style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    children: [
                      _buildRatingBar(5, 0.9, primaryGreen),
                      _buildRatingBar(4, 0.08, primaryGreen),
                      _buildRatingBar(3, 0.02, primaryGreen),
                      _buildRatingBar(2, 0.0, primaryGreen),
                      _buildRatingBar(1, 0.0, primaryGreen),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            Text(
              'REVIEWS FEED',
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey[400]),
            ),
            const SizedBox(height: 20),

            _buildReviewItem('Sarah J.', 'March 14, 2026', 'Very empathetic and helped me find clarity.', 5.0),
            _buildReviewItem('Michael R.', 'March 10, 2026', 'Great sessions. I feel much more mindful now.', 5.0),
            _buildReviewItem('Wei Keat', 'March 05, 2026', 'Excellent approach to anxiety management.', 4.5),
            _buildReviewItem('Arjun K.', 'Feb 28, 2026', 'Professional and warm environment.', 5.0),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingBar(int stars, double progress, Color color) {
    return Row(
      children: [
        Text('$stars ★', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withOpacity(0.05),
            color: color,
            borderRadius: BorderRadius.circular(10),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewItem(String name, String date, String comment, double rating) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(date, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[400])),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(
              5,
                  (idx) => Icon(
                idx < rating.floor() ? Icons.star_rounded : (idx < rating ? Icons.star_half_rounded : Icons.star_outline_rounded),
                color: Colors.amber,
                size: 16,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(comment, style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF333333), height: 1.5)),
        ],
      ),
    );
  }
}
