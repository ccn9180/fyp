import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'session_feedback.dart';

class SessionHistoryScreen extends StatefulWidget {
  const SessionHistoryScreen({super.key});

  @override
  State<SessionHistoryScreen> createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends State<SessionHistoryScreen> {
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFFBFBF6);
  final Color textColorMain = const Color(0xFF333333);
  final Color textColorSub = const Color(0xFF888888);

  final List<Map<String, dynamic>> _allCompletedSessions = [];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF333333), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'SESSION HISTORY',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: textColorMain,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('counsellor_bookings')
            .where('patientId', isEqualTo: user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF7C9C84)));
          }
          
          if (snapshot.hasError) {
            debugPrint('Session History Stream Error: ${snapshot.error}');
            return Center(
              child: Text(
                'Something went wrong loading your history.',
                style: GoogleFonts.outfit(color: textColorSub, fontSize: 16),
              ),
            );
          }

          final List<Map<String, dynamic>> completedSessions = [];
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            for (var doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final startTime = (data['startTime'] as Timestamp?)?.toDate();
              final status = (data['status'] ?? '').toString().toUpperCase();

              // Include if explicitly completed or the start time has already passed
              if (status == 'COMPLETED' || (startTime != null && startTime.isBefore(DateTime.now()))) {
                completedSessions.add({
                  ...data,
                  'id': doc.id,
                  'summary': data['summary'] ?? data['notes'] ?? 'General counseling session to check in and monitor wellness goals.',
                  'sessionDuration': data['sessionDuration'] ?? '60 mins',
                  'type': data['type'] ?? 'Video Call',
                });
              }
            }
          }

          completedSessions.sort((a, b) {
            final aTime = (a['startTime'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = (b['startTime'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime); // descending
          });

          final listToShow = completedSessions;

          if (listToShow.isEmpty) {
            return Center(
              child: Text(
                'No past sessions yet.',
                style: GoogleFonts.outfit(color: textColorSub, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            itemCount: listToShow.length,
            itemBuilder: (context, index) {
              return _buildSessionCard(context, listToShow[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildSessionCard(BuildContext context, Map<String, dynamic> session) {
    final startTime = (session['startTime'] as Timestamp).toDate();
    final String imageUrl = session['counsellorImageUrl'] ?? '';
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SessionFeedbackScreen(session: session),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(24),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFEEF3F0),
                backgroundImage: imageUrl.isNotEmpty 
                  ? (imageUrl.startsWith('data:image')
                      ? MemoryImage(base64Decode(imageUrl.split(',').last)) as ImageProvider
                      : NetworkImage(imageUrl))
                  : null,
                child: imageUrl.isEmpty ? const Icon(Icons.person, color: Color(0xFF98B3A1)) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session['counsellorName'],
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColorMain,
                      ),
                    ),
                    Text(
                      DateFormat('MMMM dd, yyyy').format(startTime),
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: textColorSub,
                      ),
                    ),
                  ],
                ),
              ),
              if (session['rating'] != null && (session['rating'] is int ? session['rating'] : int.tryParse(session['rating'].toString()) ?? 0) > 0)
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFFFB74D), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      session['rating'].toString(),
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: textColorMain,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Session Focus:',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: primaryGreen,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            session['summary'],
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: textColorMain.withOpacity(0.8),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildMetricChip(Icons.access_time_rounded, session['sessionDuration']),
              const SizedBox(width: 12),
              _buildMetricChip(Icons.videocam_outlined, session['type']),
              const Spacer(),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: primaryGreen),
            ],
          ),
        ],
      ),
    ));
  }

  Widget _buildMetricChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: textColorSub),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 11, color: textColorSub),
          ),
        ],
      ),
    );
  }
}
