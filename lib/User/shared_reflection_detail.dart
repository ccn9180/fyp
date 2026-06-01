import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SharedReflectionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> entry;

  const SharedReflectionDetailScreen({
    super.key,
    required this.entry,
  });

  @override
  State<SharedReflectionDetailScreen> createState() => _SharedReflectionDetailScreenState();
}

class _SharedReflectionDetailScreenState extends State<SharedReflectionDetailScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFF2F1EC);
  final Color textColorMain = const Color(0xFF333333);
  final Color textColorSub = const Color(0xFF888888);

  late List<String> currentSharedUsers;

  @override
  void initState() {
    super.initState();
    // Copy the list to manage local state for the demo
    currentSharedUsers = List<String>.from(widget.entry['sharedWith']);
  }

  void _revokeUser(String name) {
    setState(() {
      currentSharedUsers.remove(name);
    });
    // For demo, just show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Access revoked for $name'),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: backgroundColor,
      // The drawer on the right side
      endDrawer: _buildRevokeDrawer(),
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
          'REFLECTION DETAIL',
          style: GoogleFonts.outfit(
            color: textColorMain,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Date
            Text(
              widget.entry['title'],
              style: GoogleFonts.playfairDisplay(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: textColorMain,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF7C9C84)),
                const SizedBox(width: 8),
                Text(
                  '${widget.entry['date']} • ${widget.entry['time']}',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: textColorSub,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Mood Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('😌', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Text(
                    widget.entry['aiMoodTitle'],
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF5D6D66),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Content
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Text(
                widget.entry['content'],
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: const Color(0xFF4A4A4A),
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 48),

            // Shared View Section
            Text(
              'SHARED WITH',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: const Color(0xFF888888),
              ),
            ),
            const SizedBox(height: 16),

            if (currentSharedUsers.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    'No longer sharing this entry.',
                    style: GoogleFonts.outfit(color: textColorSub, fontSize: 14, fontStyle: FontStyle.italic),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: currentSharedUsers.map((name) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: primaryGreen.withOpacity(0.1),
                            radius: 18,
                            child: Text(
                              name[0],
                              style: TextStyle(fontSize: 12, color: primaryGreen, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            name,
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500, color: textColorMain),
                          ),
                          const Spacer(),
                          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: 48),

            // Revoke Access Button
            SizedBox(
              width: double.infinity,
              height: 64,
              child: ElevatedButton.icon(
                onPressed: () {
                  _scaffoldKey.currentState!.openEndDrawer();
                },
                icon: const Icon(Icons.lock_reset_rounded, color: Colors.white, size: 22),
                label: Text(
                  'Revoke Access',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE57373),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  elevation: 4,
                  shadowColor: const Color(0xFFE57373).withOpacity(0.3),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildRevokeDrawer() {
    return Drawer(
      backgroundColor: backgroundColor,
      width: MediaQuery.of(context).size.width * 0.85,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero), // Full height edge
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.security_update_warning_rounded, color: Color(0xFFE57373), size: 40),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'MANAGE ACCESS',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textColorMain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Revoke viewing rights for this reflection.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: textColorSub,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: Color(0xFFEBEBE6)),

            // User List Item
            Expanded(
              child: currentSharedUsers.isEmpty
                ? Center(child: Text('Everyone\'s access was revoked.', style: GoogleFonts.outfit(color: textColorSub)))
                : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                itemCount: currentSharedUsers.length,
                itemBuilder: (context, index) {
                  final name = currentSharedUsers[index];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: primaryGreen.withOpacity(0.1),
                          child: Text(name[0], style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textColorMain,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Revoke button for specific user
                        TextButton(
                          onPressed: () => _revokeUser(name),
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFFFEBEE),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'REVOKE',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFE57373),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Close Drawer
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Done',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
