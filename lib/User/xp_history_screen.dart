import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class XPHistoryScreen extends StatefulWidget {
  const XPHistoryScreen({super.key});

  @override
  State<XPHistoryScreen> createState() => _XPHistoryScreenState();
}

class _XPHistoryScreenState extends State<XPHistoryScreen> {
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFF2F1EC);
  final String? uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Please log in.')));
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF333333), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'GROWTH MOMENTS',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: const Color(0xFF333333),
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('xp_logs')
            .doc(uid)
            .collection('entries')
            .orderBy('earned_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'No XP history logged yet.',
                style: GoogleFonts.outfit(color: Colors.grey),
              ),
            );
          }

          final logs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index].data() as Map<String, dynamic>;
              final String source = log['source'] ?? 'Activity';
              final int xp = (log['xp'] ?? 0) as int;
              final int coins = (log['coins'] ?? 0) as int;
              final Timestamp? timestamp = log['earned_at'] as Timestamp?;
              
              final String dateStr = timestamp != null
                  ? DateFormat('d MMM yyyy').format(timestamp.toDate())
                  : 'Recent';

              bool showHeader = false;
              if (index == 0) {
                showHeader = true;
              } else {
                final prevLog = logs[index - 1].data() as Map<String, dynamic>;
                final Timestamp? prevTimestamp = prevLog['earned_at'] as Timestamp?;
                final String prevDateStr = prevTimestamp != null
                    ? DateFormat('d MMM yyyy').format(prevTimestamp.toDate())
                    : 'Recent';
                if (dateStr != prevDateStr) {
                  showHeader = true;
                }
              }

              // Distinct formatting for reward redemption vs XP earnings
              final bool isRedemption = source == 'reward_redeemed' || coins < 0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showHeader) ...[
                    if (index > 0) const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 12),
                      child: Text(
                        dateStr.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: Colors.grey[500],
                        ),
                      ),
                    ),
                  ],
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.withOpacity(0.05)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isRedemption 
                                ? Colors.orange.withOpacity(0.08)
                                : Colors.blue.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isRedemption ? Icons.shopping_bag_rounded : Icons.bolt_rounded,
                            color: isRedemption ? Colors.orange : Colors.blue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isRedemption ? 'Redeemed Reward' : source, 
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 14, 
                                  color: const Color(0xFF333333),
                                ),
                              ),
                              Text(
                                isRedemption ? 'Spent Coins' : 'XP & Coins Earned', 
                                style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              isRedemption ? '$coins C' : '+$xp XP',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold, 
                                fontSize: 14, 
                                color: isRedemption ? Colors.orange : primaryGreen,
                              ),
                            ),
                            if (!isRedemption && coins > 0)
                              Text(
                                '+$coins C',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFB59300),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
