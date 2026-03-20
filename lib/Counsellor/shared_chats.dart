
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class SharedChatsScreen extends StatelessWidget {
  const SharedChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = const Color(0xFF7C9C84);
    final Color backgroundColor = const Color(0xFFEAE9E4);
    final Color textColorMain = const Color(0xFF333333);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shared Insights',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E2742),
                      ),
                    ),
                    Text(
                      'Understand your clients through AI',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('shared_chats')
                      .where('counsellorId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                      .orderBy('sharedAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, size: 80, color: primaryGreen.withOpacity(0.1)),
                            const SizedBox(height: 24),
                            Text(
                              'No shared data',
                              style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold, color: textColorMain),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'When users share their AI chatbot\nsessions with you, they will appear here.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[500], height: 1.5),
                            ),
                          ],
                        ),
                      );
                    }

                    final sharedData = snapshot.data!.docs;

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      itemCount: sharedData.length,
                      itemBuilder: (context, index) {
                        final data = sharedData[index].data() as Map<String, dynamic>;
                        final userName = data['userName'] ?? 'User';
                        final sharedAt = (data['sharedAt'] as Timestamp).toDate();
                        final summary = data['aiSummary'] ?? 'No summary provided.';
                        final emotionTags = List<String>.from(data['emotionTags'] ?? []);

                        return GestureDetector(
                          onTap: () => _viewChatDetail(context, data),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
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
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: primaryGreen.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Center(
                                        child: Text(
                                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: primaryGreen),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            userName,
                                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: textColorMain),
                                          ),
                                          Text(
                                            'Shared ${DateFormat('MMM dd, hh:mm a').format(sharedAt)}',
                                            style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[400]),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'AI Summary',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12, color: primaryGreen, letterSpacing: 1.1),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  summary,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(fontSize: 14, color: textColorMain, height: 1.5),
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: emotionTags.map((tag) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5F7F6),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '#$tag',
                                      style: GoogleFonts.outfit(fontSize: 11, color: primaryGreen, fontWeight: FontWeight.w600),
                                    ),
                                  )).toList(),
                                ),
                              ],
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
        ),
      ),
    );
  }

  void _viewChatDetail(BuildContext context, Map<String, dynamic> data) {
    final Color primaryGreen = const Color(0xFF7C9C84);
    final Color textColorMain = const Color(0xFF333333);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          padding: const EdgeInsets.all(32),
          decoration: const BoxDecoration(
            color: Color(0xFFEAE9E4),
            borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 28),
                ),
              ),
              Text(
                'AI Conversation Insights',
                style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Confidential shared chatbot transcription from ${data['userName']}',
                style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 32),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailSection('Clinical Summary', data['aiSummary'], primaryGreen),
                      const SizedBox(height: 24),
                      _buildDetailSection('Emotion Profile', 'Key tones identified: ${List<String>.from(data['emotionTags'] ?? []).join(", ")}', Colors.blue),
                      const SizedBox(height: 24),

                      Text(
                        'FULL CONVERSATION LOG',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey[400]),
                      ),
                      const SizedBox(height: 16),

                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: (data['messages'] as List).length,
                        itemBuilder: (context, idx) {
                          final msg = data['messages'][idx];
                          final bool isBot = msg['role'] == 'assistant' || msg['role'] == 'bot';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isBot ? Colors.white : primaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isBot ? 'EUNOIA AI' : 'CLIENT',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 10, color: isBot ? primaryGreen : textColorMain),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  msg['text'] ?? '',
                                  style: GoogleFonts.outfit(fontSize: 14, height: 1.4),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailSection(String title, String content, Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: accent, size: 18),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: accent),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: GoogleFonts.outfit(fontSize: 15, color: const Color(0xFF333333), height: 1.6),
          ),
        ],
      ),
    );
  }
}
