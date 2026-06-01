import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp/app_localizations.dart';
import 'add_diary.dart';
import 'diary_drafts.dart';
import 'diary_detail.dart';

class DiaryListScreen extends StatefulWidget {
  const DiaryListScreen({super.key});

  @override
  State<DiaryListScreen> createState() => _DiaryListScreenState();
}

class _DiaryListScreenState extends State<DiaryListScreen> {
  String _selectedFilter = 'All';
  DateTime? _selectedDate;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFF2F1EC);
  final Color textColorMain = const Color(0xFF333333);
  final Color textColorSub = const Color(0xFF888888);

  final List<String> _filters = ['All', 'Happy', 'Calm', 'Neutral', 'Anxious', 'Angry', 'Sad'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: const Color(0xFF333333),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.translate('diary'),
          style: GoogleFonts.playfairDisplay(
            color: textColorMain,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DiaryDraftsScreen()),
              );
            },
            child: Text(
              AppLocalizations.of(context)!.translate('drafts'),
              style: GoogleFonts.outfit(
                color: primaryGreen,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: _buildSearchBar(),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 24, bottom: 20),
            child: _buildFilterChips(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildSectionHeader(
                _selectedDate == null
                    ? 'RECENT ENTRIES'
                    : 'ENTRIES FOR ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                _selectedDate == null ? 'View Calendar' : 'Clear Date'
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _buildDiaryList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddDiaryScreen()),
          );
        },
        backgroundColor: primaryGreen,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
        style: GoogleFonts.outfit(
          color: textColorMain,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: 'Search entries...',
          hintStyle: GoogleFonts.outfit(
            color: const Color(0xFFC0C0C0),
            fontSize: 14,
          ),
          prefixIcon: const Icon(Icons.search, color: Color(0xFFC0C0C0)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear, size: 18),
            onPressed: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
          )
              : null,
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filters.map((filter) {
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? primaryGreen : Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: isSelected ? primaryGreen : const Color(0xFFEBEBE6),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    if (filter == 'All') ...[
                      Icon(Icons.grid_view_rounded, size: 16, color: isSelected ? Colors.white : primaryGreen),
                      const SizedBox(width: 8),
                    ] else if (filter == 'Happy') ...[
                      Icon(Icons.sentiment_satisfied_rounded, size: 16, color: isSelected ? Colors.white : primaryGreen),
                      const SizedBox(width: 8),
                    ] else if (filter == 'Calm') ...[
                      Icon(Icons.cloud_outlined, size: 16, color: isSelected ? Colors.white : primaryGreen),
                      const SizedBox(width: 8),
                    ] else if (filter == 'Neutral') ...[
                      Icon(Icons.sentiment_neutral_rounded, size: 16, color: isSelected ? Colors.white : primaryGreen),
                      const SizedBox(width: 8),
                    ] else if (filter == 'Anxious') ...[
                      Icon(Icons.sentiment_dissatisfied_rounded, size: 16, color: isSelected ? Colors.white : primaryGreen),
                      const SizedBox(width: 8),
                    ] else if (filter == 'Angry') ...[
                      Icon(Icons.storm_outlined, size: 16, color: isSelected ? Colors.white : primaryGreen),
                      const SizedBox(width: 8),
                    ] else if (filter == 'Sad') ...[
                      Icon(Icons.sentiment_very_dissatisfied_rounded, size: 16, color: isSelected ? Colors.white : primaryGreen),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      filter,
                      style: GoogleFonts.outfit(
                        color: isSelected ? Colors.white : primaryGreen,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String actionLabel) {
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
        Row(
          children: [
            GestureDetector(
              onTap: () async {
                if (_selectedDate != null) {
                  setState(() => _selectedDate = null);
                  return;
                }
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(
                          primary: primaryGreen,
                          onPrimary: Colors.white,
                          onSurface: textColorMain,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                }
              },
              child: Row(
                children: [
                  Text(
                    actionLabel,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: actionLabel == 'Clear Date' ? Colors.redAccent : primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                      actionLabel == 'Clear Date' ? Icons.event_busy_outlined : Icons.calendar_today_outlined,
                      size: 14,
                      color: actionLabel == 'Clear Date' ? Colors.redAccent : primaryGreen
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDiaryList() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _buildEmptyState();
    }

    Query query = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('diary_entries')
        .orderBy('timestamp', descending: true);

    if (_selectedFilter != 'All') {
      query = query.where('mood', isEqualTo: _selectedFilter);
    }

    // Note: Firestore doesn't support inequality filters on different fields easily with orderBy.
    // For date filtering on the same day, we fetch and then filter locally OR use a range.
    if (_selectedDate != null) {
      final start = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
      final end = start.add(const Duration(days: 1));
      query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('timestamp', isLessThan: Timestamp.fromDate(end));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF7C9C84)));
        }

        final documents = snapshot.data?.docs ?? [];
        
        // Final Client-side Search Filtering
        final List<Map<String, dynamic>> entries = [];

        for (var doc in documents) {
          final data = doc.data() as Map<String, dynamic>;
          final title = (data['title'] ?? '').toString().toLowerCase();
          final entriesContent = (data['content'] ?? '').toString().toLowerCase();
          if (title.contains(_searchQuery) || entriesContent.contains(_searchQuery)) {
            data['id'] = doc.id;
            entries.add(data);
          }
        }

        if (entries.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          itemCount: entries.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final data = entries[index];
            return _buildDiaryCard(data['id'], data);
          },
        );
      },
    );
  }

  Widget _buildDiaryCard(String docId, Map<String, dynamic> data) {
    // Expecting fields: title, content, mood (e.g. 'Happy'), date (Timestamp)
    final String title = data['title'] ?? 'Untitled Entry';
    final String content = data['content'] ?? '';
    final String mood = data['mood'] ?? 'Calm';
    final String displayMood = data['aiMoodTitle'] ?? mood;
    final String? imageUrl = data['imageUrl'];

    // Formatting date safely. Defaults to a hardcoded format string for UI demo purposes if missing.
    final Timestamp? timestamp = data['timestamp'];
    String formattedDate = 'UNKNOWN DATE';
    if (timestamp != null) {
      final DateTime dt = timestamp.toDate();
      // Simple format matching UI: OCT 24, 2023 • 09:30 AM
      const List<String> months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
      final String month = months[dt.month - 1];
      final String day = dt.day.toString().padLeft(2, '0');
      final String year = dt.year.toString();
      final String hour = (dt.hour % 12 == 0 ? 12 : dt.hour % 12).toString().padLeft(2, '0');
      final String minute = dt.minute.toString().padLeft(2, '0');
      final String ampm = dt.hour < 12 ? 'AM' : 'PM';
      formattedDate = '$month $day, $year • $hour:$minute $ampm';
    }

    Color moodColor;
    Color moodBgColor;
    String moodEmoji;

    switch (mood) {
      case 'Happy':
        moodColor = const Color(0xFF4CAf50);
        moodBgColor = const Color(0xFFE8F5E9);
        moodEmoji = '😊';
        break;
      case 'Angry':
        moodColor = const Color(0xFFF44336);
        moodBgColor = const Color(0xFFFFEBEE);
        moodEmoji = '😠';
        break;
      case 'Anxious':
        moodColor = const Color(0xFFFF9800);
        moodBgColor = const Color(0xFFFFF3E0);
        moodEmoji = '😰';
        break;
      case 'Neutral':
        moodColor = const Color(0xFF9E9E9E);
        moodBgColor = const Color(0xFFF5F5F5);
        moodEmoji = '😐';
        break;
      case 'Sad':
        moodColor = const Color(0xFF9C27B0);
        moodBgColor = const Color(0xFFF3E5F5);
        moodEmoji = '😢';
        break;
      case 'Calm':
      default:
        moodColor = const Color(0xFF2196F3);
        moodBgColor = const Color(0xFFE3F2FD);
        moodEmoji = '😌';
        break;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DiaryDetailScreen(
              docId: docId,
              mockData: docId.startsWith('hc_') ? data : null,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formattedDate,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: const Color(0xFF888888),
                  ),
                ),
                GestureDetector(
                  onTap: () => _showActionSheet(context, docId, data),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.03),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.more_vert_rounded, color: Color(0xFF888888), size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: moodBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayMood,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: moodColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(moodEmoji, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (data['sharingAccess'] != null && (data['sharingAccess'] as Map).values.any((v) => v == true))
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                     decoration: BoxDecoration(
                       color: const Color(0xFFFFEBEE),
                       borderRadius: BorderRadius.circular(6),
                     ),
                     child: Row(
                       children: [
                         const Icon(Icons.share_outlined, size: 10, color: Color(0xFFE57373)),
                         const SizedBox(width: 4),
                         Text(
                           'SHARED',
                           style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: const Color(0xFFE57373)),
                         ),
                       ],
                     ),
                   )
                else
                  const Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFFB0B0B0)),
              ],
            ),
            const SizedBox(height: 16),
            if (imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 150,
                    width: double.infinity,
                    color: const Color(0xFFEBEBE6),
                    child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              title,
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: textColorMain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: const Color(0xFF7A8C85),
                height: 1.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_rounded, size: 64, color: const Color(0xFFBBCBC2)),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.translate('no_entries'),
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: textColorMain,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.translate('no_entries_sub'),
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: textColorSub,
            ),
          ),
          const SizedBox(height: 80), // offset for spacing
        ],
      ),
    );
  }

  void _showActionSheet(BuildContext context, String docId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: const BoxDecoration(
          color: Color(0xFFF2F1EC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Entry Options',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage your reflection',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: const Color(0xFF888888),
              ),
            ),
            const SizedBox(height: 32),
            _buildActionItem(
              title: "Edit Reflection",
              subtitle: "Update your thoughts or emotions",
              icon: Icons.edit_note_rounded,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddDiaryScreen(
                      entryId: docId,
                      initialData: data,
                      isDraft: false,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildActionItem(
              title: "View Full Entry",
              subtitle: "Read your complete reflection",
              icon: Icons.chrome_reader_mode_outlined,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DiaryDetailScreen(docId: docId),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildActionItem(
              title: "Delete Entry",
              subtitle: "Permanently remove from diary",
              icon: Icons.delete_outline_rounded,
              isDestructive: true,
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(context, docId);
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF888888),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDestructive ? const Color(0xFFFFEBEE) : const Color(0xFFF5F7F6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isDestructive ? const Color(0xFFE57373) : const Color(0xFF7C9C84),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDestructive ? const Color(0xFFE57373) : const Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[300], size: 24),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, String docId) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F1EC),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEBEE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFE57373),
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Delete Entry?',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This diary entry will be permanently removed from your collection. Are you sure?',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: const Color(0xFF666666),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Keep it',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF888888),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .collection('diary_entries')
                              .doc(docId)
                              .delete();
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE57373),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Delete',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
