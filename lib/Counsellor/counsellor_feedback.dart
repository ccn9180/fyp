
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('counsellor_bookings')
            .where('counsellorId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
            .where('status', isEqualTo: 'completed')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF7C9C84)));
          }

          List<Map<String, dynamic>> reviews = [];
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            for (var doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              if (data['feedback'] != null) {
                reviews.add({
                  'name': data['patientName'] ?? data['userName'] ?? 'Anonymous',
                  'date': data['feedback']['date'] ?? DateFormat('MMM dd, yyyy').format((data['startTime'] as Timestamp).toDate()),
                  'comment': data['feedback']['comment'] ?? '',
                  'rating': (data['feedback']['rating'] ?? 0).toDouble(),
                });
              }
            }
          }

          if (reviews.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rate_review_outlined, size: 48, color: primaryGreen.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'No reviews yet',
                    style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold, color: textColorMain),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Client feedback will appear here.',
                    style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          double totalRating = 0;
          List<int> starCounts = [0, 0, 0, 0, 0]; // 1-star to 5-star

          for (var r in reviews) {
            double rating = r['rating'] as double;
            totalRating += rating;
            if (rating >= 1 && rating <= 5) {
              starCounts[(rating.round()) - 1]++;
            }
          }

          double avgRating = totalRating / reviews.length;

          return SingleChildScrollView(
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
                            avgRating.toStringAsFixed(1),
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
                                idx < avgRating.floor() ? Icons.star_rounded : (idx < avgRating ? Icons.star_half_rounded : Icons.star_outline_rounded),
                                color: Colors.amber,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Based on ${reviews.length} reviews',
                            style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        children: [
                          _buildRatingBar(5, starCounts[4] / reviews.length, primaryGreen),
                          _buildRatingBar(4, starCounts[3] / reviews.length, primaryGreen),
                          _buildRatingBar(3, starCounts[2] / reviews.length, primaryGreen),
                          _buildRatingBar(2, starCounts[1] / reviews.length, primaryGreen),
                          _buildRatingBar(1, starCounts[0] / reviews.length, primaryGreen),
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

                ...reviews.map((r) => _buildReviewItem(
                  r['name'] as String,
                  r['date'] as String,
                  r['comment'] as String,
                  r['rating'] as double,
                )).toList(),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
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
