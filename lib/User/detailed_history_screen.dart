import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'resource_preview_screen.dart';
import 'meditation_player.dart';
import 'article_detail.dart';

class DetailedHistoryScreen extends StatefulWidget {
  final String? filterType;
  const DetailedHistoryScreen({super.key, this.filterType});

  @override
  State<DetailedHistoryScreen> createState() => _DetailedHistoryScreenState();
}

class _DetailedHistoryScreenState extends State<DetailedHistoryScreen> {
  final Color primaryGreen = const Color(0xFF7C9C84);
  late String? _selectedFilter;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.filterType;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final difference = DateTime(now.year, now.month, now.day).difference(DateTime(date.year, date.month, date.day));

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${date.day} ${months[date.month - 1]}, ${date.year}';
    }
  }

  String _formatTime(DateTime date) {
    final hour = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final period = date.hour < 12 ? 'AM' : 'PM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EC),
      appBar: AppBar(
        title: Text(
          'YOUR JOURNEY HISTORY',
          style: GoogleFonts.outfit(
            color: const Color(0xFF333333),
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        backgroundColor: const Color(0xFFF2F1EC),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: currentUser == null
          ? Center(
        child: Text(
          'Please log in to view history',
          style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey),
        ),
      )
          : _buildHistoryList(currentUser),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          _buildFilterChip('All', null),
          const SizedBox(width: 10),
          _buildFilterChip('Meditations', 'meditation'),
          const SizedBox(width: 10),
          _buildFilterChip('Articles', 'article'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? value) {
    final bool isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: isSelected ? Colors.white : const Color(0xFF888888),
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryList(User currentUser) {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('user_activity')
            .where('userId', isEqualTo: currentUser.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: SelectableText(
                  'Database Index Error: Please click the link in your console to create the composite index for this query, or copy this: \n\n${snapshot.error}',
                  style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF7C9C84)),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C9C84).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.history_rounded, size: 48, color: Color(0xFF7C9C84)),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Your Journey Begins Here',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      color: const Color(0xFF333333),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Take a mindful moment.\nYour meditations and reading progress\nwill appear in this timeline.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            );
          }

          var docs = snapshot.data!.docs.toList();
          if (_selectedFilter != null) {
            docs = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['type'] == _selectedFilter;
            }).toList();
          }
          
          docs.sort((a, b) {
            final tA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            final tB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            if (tA == null && tB == null) return 0;
            if (tA == null) return -1; // pending writes to top
            if (tB == null) return 1;
            return tB.compareTo(tA); // descending
          });

          // Group by date string
          final Map<String, List<Map<String, dynamic>>> groupedData = {};
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            DateTime? date;
            if (data['timestamp'] != null) {
              date = (data['timestamp'] as Timestamp).toDate();
            } else {
              date = DateTime.now();
            }
            String dateKey = _formatDateHeader(date);
            if (!groupedData.containsKey(dateKey)) {
              groupedData[dateKey] = [];
            }
            groupedData[dateKey]!.add(data);
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            itemCount: groupedData.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildSummaryCard(docs.length, _selectedFilter);
              }
              if (index == 1) {
                return _buildFilterRow();
              }

              final dateKey = groupedData.keys.elementAt(index - 2);
              final items = groupedData[dateKey]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 12),
                    child: Text(
                      dateKey,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF333333),
                      ),
                    ),
                  ),
                  ...items.map((data) {
                    final type = data['type'] as String? ?? 'unknown';
                    final title = data['title'] as String? ?? 'Unknown Title';
                    final imageUrl = data['imageUrl'] as String?;
                    DateTime? date = (data['timestamp'] as Timestamp?)?.toDate();

                    final isMeditation = type == 'meditation';

                    String durationStr = '';
                    String progressStr = '';
                    if (isMeditation) {
                      durationStr = data['duration']?.toString() ?? '0:00';
                    } else if (type == 'article') {
                      progressStr = '${data['progress'] ?? 0}%';
                    }

                    return GestureDetector(
                      onTap: () => _openResource(context, title, type),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: isMeditation
                                    ? const Color(0xFF7C9C84).withOpacity(0.1)
                                    : const Color(0xFF7E8457).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                image: imageUrl != null && imageUrl.isNotEmpty
                                    ? DecorationImage(
                                  image: NetworkImage(imageUrl),
                                  fit: BoxFit.cover,
                                )
                                    : null,
                              ),
                              child: (imageUrl == null || imageUrl.isEmpty)
                                  ? Icon(
                                isMeditation ? Icons.headphones_rounded : Icons.article_rounded,
                                color: isMeditation ? const Color(0xFF7C9C84) : const Color(0xFF7E8457),
                                size: 24,
                              )
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF333333),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        isMeditation ? 'Meditation' : 'Article',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: isMeditation ? const Color(0xFF7C9C84) : const Color(0xFF7E8457),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 4,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[300],
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isMeditation ? 'Duration: $durationStr' : 'Progress: $progressStr',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (date != null) ...[
                              const SizedBox(width: 12),
                              Text(
                                _formatTime(date),
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ); // Closing GestureDetector
                  }).toList(),
                ],
              );
            },
          );
        },
    );
  }

  Future<void> _openResource(BuildContext context, String title, String type) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF7C9C84))),
    );

    try {
      final collection = type == 'meditation' ? 'meditation_guides' : 'articles';
      final query = await FirebaseFirestore.instance.collection(collection).where('title', isEqualTo: title).limit(1).get();

      if (!context.mounted) return;
      Navigator.pop(context); // close dialog

      if (query.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resource is no longer available.')));
        return;
      }

      final doc = query.docs.first;
      final data = doc.data();
      final docId = doc.id;

      // check if favorite
      final uid = FirebaseAuth.instance.currentUser?.uid;
      bool isFavorite = false;
      if (uid != null) {
        final favDoc = await FirebaseFirestore.instance.collection('users').doc(uid).collection('favorites').doc(docId).get();
        isFavorite = favDoc.exists;
      }

      if (!context.mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResourcePreviewScreen(
            type: type,
            title: title,
            subtitle: data['subtitle'] ?? '',
            tag: data['category'] ?? data['tag'] ?? (type == 'meditation' ? 'PRACTICE' : 'READ'),
            imageUrl: data['imageUrl'] ?? '',
            duration: type == 'meditation' ? (data['duration']?.toString() ?? '10 MINS') : (data['readingTime'] ?? '5 min read'),
            rating: (data['averageRating'] as num?)?.toDouble() ?? 0.0,
            content: data['content'],
            authorName: data['authorName'],
            authorRole: data['authorRole'],
            authorImageUrl: data['authorImageUrl'],
            isFavorite: isFavorite,
            onFavoriteToggle: () async {
              if (uid == null) return;
              final ref = FirebaseFirestore.instance.collection('users').doc(uid).collection('favorites').doc(docId);
              if (isFavorite) {
                await ref.delete();
              } else {
                await ref.set({'title': title, 'timestamp': FieldValue.serverTimestamp()});
              }
            },
            onStart: () {
              Navigator.pop(context);
              if (type == 'meditation') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => MeditationPlayerScreen(
                  title: title,
                  subtitle: data['category'] ?? 'PRACTICE',
                  duration: data['duration']?.toString() ?? '10 MINS',
                  imageUrl: data['imageUrl'] ?? '',
                  audioUrl: data['audioUrl'] ?? '',
                  isFavorite: isFavorite,
                  onFavoriteToggle: () {},
                )));
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => ArticleDetailScreen(
                  title: title,
                  subtitle: data['subtitle'] ?? '',
                  tag: data['category'] ?? data['tag'] ?? 'READ',
                  authorName: data['authorName'] ?? 'Eunoia',
                  authorRole: data['authorRole'] ?? 'Contributor',
                  authorImageUrl: data['authorImageUrl'] ?? '',
                  publishDate: data['publishDate'] ?? 'Recently',
                  content: data['content'] ?? '',
                  imageUrl: data['imageUrl'] ?? '',
                  readingTime: data['readingTime'] ?? '5 min read',
                  isFavorite: isFavorite,
                  onFavoriteToggle: () {},
                )));
              }
            },
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error opening resource')));
      }
    }
  }

  Widget _buildSummaryCard(int totalSessions, String? filterType) {
    String subtitle = 'Your Journey So Far';
    String unit = 'Sessions';
    IconData icon = Icons.analytics_rounded;
    if (filterType == 'meditation') {
      subtitle = 'Your Meditation Journey';
      unit = 'Meditations';
      icon = Icons.self_improvement_rounded;
    } else if (filterType == 'article') {
      subtitle = 'Your Reading Journey';
      unit = 'Articles Read';
      icon = Icons.menu_book_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C9C84), Color(0xFF5B7563)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C9C84).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalSessions $unit',
                  style: GoogleFonts.playfairDisplay(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Keep up the great work!',
                  style: GoogleFonts.outfit(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
