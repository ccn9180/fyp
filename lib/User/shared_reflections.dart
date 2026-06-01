import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'shared_reflection_detail.dart';

class SharedReflectionsScreen extends StatefulWidget {
  const SharedReflectionsScreen({super.key});

  @override
  State<SharedReflectionsScreen> createState() => _SharedReflectionsScreenState();
}

class _SharedReflectionsScreenState extends State<SharedReflectionsScreen> {
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFF2F1EC);
  final Color textColorMain = const Color(0xFF333333);
  final Color textColorSub = const Color(0xFF888888);

  // Hardcoded Shared Entries
  final List<Map<String, dynamic>> _sharedEntries = [
    {
      'id': 'shared_1',
      'title': 'Mindful Morning Walk',
      'content': 'The crisp air today really helped me clear my head. I felt a sense of peace I haven\'t felt in weeks. Nature has a way of grounding us that nothing else can match.',
      'date': 'OCT 12, 2023',
      'time': '08:30 AM',
      'mood': 'Calm',
      'aiMoodTitle': 'Reflective & Peace',
      'sharedWith': ['Mom', 'Dr. Sarah'],
    },
    {
      'id': 'shared_2',
      'title': 'Dealing with Work Stress',
      'content': 'Today was tough. The deadlines are piling up and I feel like I\'m drowning. I need to remember to breathe and take things one step at a time.',
      'date': 'OCT 15, 2023',
      'time': '06:45 PM',
      'mood': 'Anxious',
      'aiMoodTitle': 'Tense & Overwhelmed',
      'sharedWith': ['Leo', 'Dr. Sarah'],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: textColorMain,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'SHARED REFLECTIONS',
          style: GoogleFonts.outfit(
            color: textColorMain,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connected Journey',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: textColorMain,
                  ),
                ),
                Text(
                  'Manage entries you\'ve shared with your circle',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: textColorSub,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              itemCount: _sharedEntries.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final entry = _sharedEntries[index];
                return _buildSharedCard(entry);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedCard(Map<String, dynamic> entry) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SharedReflectionDetailScreen(entry: entry),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 15,
              offset: const Offset(0, 5),
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
                  '${entry['date']} • ${entry['time']}',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: textColorSub,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.share_outlined, size: 12, color: primaryGreen),
                      const SizedBox(width: 4),
                      Text(
                        'SHARED',
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              entry['title'],
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: textColorMain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              entry['content'],
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: const Color(0xFF666666),
                height: 1.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            const Divider(color: Color(0xFFF1F1F1)),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Shared with:',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textColorSub,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: -8,
                    children: [
                      ...entry['sharedWith'].map<Widget>((name) {
                        return Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: CircleAvatar(
                            backgroundColor: primaryGreen.withOpacity(0.2),
                            child: Text(
                              name[0],
                              style: TextStyle(fontSize: 10, color: primaryGreen, fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      }).toList(),
                      if (entry['sharedWith'].length > 3)
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: CircleAvatar(
                            backgroundColor: const Color(0xFFF0F0F0),
                            child: Text(
                              '+${entry['sharedWith'].length - 3}',
                              style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.grey[300]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
