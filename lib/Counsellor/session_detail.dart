
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SessionDetailScreen extends StatelessWidget {
  final Map<String, dynamic> bookingData;
  final String bookingId;

  const SessionDetailScreen({super.key, required this.bookingData, required this.bookingId});

  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = const Color(0xFF7C9C84);
    final Color backgroundColor = const Color(0xFFF2F1EC);
    final Color textColorMain = const Color(0xFF333333);
    final startTime = (bookingData['startTime'] as Timestamp).toDate();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Session Details', style: GoogleFonts.playfairDisplay(color: textColorMain, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Client Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: primaryGreen.withOpacity(0.1),
                    child: Text(
                      bookingData['patientName']?[0].toUpperCase() ?? 'P',
                      style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: primaryGreen),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(bookingData['patientName'] ?? 'Anonymous Patient', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('Patient ID: ${bookingData['patientId']?.substring(0, 8)}', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[400])),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: primaryGreen.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.chat_bubble_outline_rounded, color: primaryGreen, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Time Info
            _buildInfoCard(
              Icons.calendar_today_rounded,
              'Appointment Time',
              '${DateFormat('EEEE, MMM dd').format(startTime)}\n${DateFormat('hh:mm a').format(startTime)} - ${DateFormat('hh:mm a').format(startTime.add(const Duration(hours: 1)))}',
              Colors.blue,
            ),
            const SizedBox(height: 16),

            // Clinical Notes Placeholder
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PRIVATE CLINICAL NOTES', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey[400])),
                  const SizedBox(height: 16),
                  Text(
                    bookingData['notes'] ?? 'No clinical notes recorded for this session yet. Tap to add notes after the session is completed.',
                    style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600], height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            Text('POST-SESSION SUPPORT', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey[400])),
            const SizedBox(height: 16),

            // Action Button: Recommend Resources
            GestureDetector(
              onTap: () => _showResourceSelector(context),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primaryGreen, const Color(0xFF6A8671)]),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: primaryGreen.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Recommend Resources', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('Send articles or meditations to this patient', style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[400])),
              const SizedBox(height: 4),
              Text(value, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF333333))),
            ],
          ),
        ],
      ),
    );
  }

  void _showResourceSelector(BuildContext context) {
    final Color primaryGreen = const Color(0xFF7C9C84);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Color(0xFFF2F1EC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Recommend Support', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('articles').limit(10).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                    final docs = snapshot.data!.docs;
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final art = docs[index].data() as Map<String, dynamic>;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(art['imageUrl'] ?? '', width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey[200])),
                            ),
                            title: Text(art['title'] ?? 'Untitled', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text('Article · Self-Help', style: GoogleFonts.outfit(fontSize: 12)),
                            trailing: IconButton(
                              icon: Icon(Icons.send_rounded, color: primaryGreen),
                              onPressed: () async {
                                // Recommend logic
                                await FirebaseFirestore.instance.collection('recommendations').add({
                                  'patientId': bookingData['patientId'],
                                  'counsellorId': bookingData['counsellorId'],
                                  'resourceId': docs[index].id,
                                  'resourceTitle': art['title'],
                                  'resourceType': 'article',
                                  'recommendedAt': FieldValue.serverTimestamp(),
                                });
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Successfully recommended to ${bookingData['patientName']}')),
                                  );
                                }
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
