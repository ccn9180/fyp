import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'active_chat.dart';

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Anxiety', 'Gratitude', 'Sleep', 'Focus'];

  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFFBFBF6);
  final Color textColorMain = const Color(0xFF333333);
  final Color textColorSub = const Color(0xFF888888);

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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Chat History',
          style: GoogleFonts.playfairDisplay(
            color: textColorMain,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: const [],
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
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
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search conversations...',
                  hintStyle: GoogleFonts.outfit(color: const Color(0xFFB0B0B0), fontSize: 15),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFFB0B0B0)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 24),
            child: Row(
              children: _filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedFilter = filter),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? primaryGreen : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          if (!isSelected)
                            BoxShadow(
                              color: Colors.black.withOpacity(0.01),
                              blurRadius: 5,
                            ),
                        ],
                      ),
                      child: Text(
                        filter,
                        style: GoogleFonts.outfit(
                          color: isSelected ? Colors.white : textColorSub,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          // List of chats
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                _buildChatCard(
                  title: 'Finding Peace Today',
                  date: 'Oct 24',
                  tag: 'CALM',
                  subTag: 'Anxiety',
                  preview: 'We discussed deep breathing techniques to manage workplace stress. You felt more grounde...',
                  icon: Icons.cloud_outlined,
                  iconColor: const Color(0xFF7C8D84),
                  tagColor: const Color(0xFFE8F5E9),
                  tagTextColor: const Color(0xFF43A047),
                ),
                const SizedBox(height: 16),
                _buildChatCard(
                  title: 'Gratitude Journaling',
                  date: 'Oct 22',
                  tag: 'GRATEFUL',
                  subTag: 'Gratitude',
                  preview: 'Listing three small things that brought you joy today. The coffee this morning was a highlight...',
                  icon: Icons.favorite_rounded,
                  iconColor: Colors.orange[400]!,
                  tagColor: Colors.orange[50]!,
                  tagTextColor: Colors.orange[700]!,
                ),
                const SizedBox(height: 16),
                _buildChatCard(
                  title: 'Night Wind-down',
                  date: 'Oct 21',
                  tag: 'SLEEPY',
                  subTag: 'Sleep',
                  preview: 'Preparation for a restful night. Guided visualization of a quiet forest to help quiet the mind...',
                  icon: Icons.nightlight_round,
                  iconColor: Colors.blue[400]!,
                  tagColor: Colors.blue[50]!,
                  tagTextColor: Colors.blue[700]!,
                ),
                const SizedBox(height: 16),
                _buildChatCard(
                  title: 'Morning Intentions',
                  date: 'Oct 19',
                  tag: 'FOCUSED',
                  subTag: 'Mindfulness',
                  preview: 'Setting a clear intention for the week ahead. Focusing on presence during conversations...',
                  icon: Icons.wb_sunny_outlined,
                  iconColor: Colors.yellow[700]!,
                  tagColor: Colors.yellow[50]!,
                  tagTextColor: Colors.yellow[800]!,
                ),
                const SizedBox(height: 100), // Bottom padding
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ActiveChatScreen()),
            );
          },
          backgroundColor: primaryGreen,
          elevation: 4,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text(
            'Start Conversation',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildChatCard({
    required String title,
    required String date,
    required String tag,
    required String subTag,
    required String preview,
    required IconData icon,
    required Color iconColor,
    required Color tagColor,
    required Color tagTextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: textColorMain,
                          ),
                        ),
                        Text(
                          date,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: const Color(0xFFA0A0A0),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: tagColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tag,
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: tagTextColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          subTag,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: const Color(0xFFB0B0B0),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            preview,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: const Color(0xFF666666),
              height: 1.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
