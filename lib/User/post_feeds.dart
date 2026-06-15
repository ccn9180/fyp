import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post.dart';

class PostFeedsPage extends StatefulWidget {
  const PostFeedsPage({super.key});

  @override
  State<PostFeedsPage> createState() => _PostFeedsPageState();
}

class _PostFeedsPageState extends State<PostFeedsPage> {
  final TextEditingController _contentController = TextEditingController();
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color sageBg = const Color(0xFFF2F1EC);
  final Color textColorMain = const Color(0xFF333333);
  final Color textColorSub = const Color(0xFFA3A3A3);
  
  String _selectedTopic = 'General';
  String _selectedMood = 'Calm';
  bool _isAnonymous = false;
  File? _selectedImage;
  bool _isPosting = false;

  final List<String> _topics = ['Self-Love', 'Anxiety', 'Hope', 'Relationship', 'General'];
  final List<Map<String, dynamic>> _moods = [
    {'name': 'Calm', 'icon': Icons.spa, 'color': Color(0xFF7C9C84)},
    {'name': 'Grateful', 'icon': Icons.wb_sunny, 'color': Color(0xFF6B8E78)},
    {'name': 'Tired', 'icon': Icons.nightlight_round, 'color': Color(0xFF90A492)},
    {'name': 'Anxious', 'icon': Icons.water_drop, 'color': Color(0xFFEF4444)},
    {'name': 'Hopeful', 'icon': Icons.auto_awesome, 'color': Color(0xFF3B82F6)},
    {'name': 'Soft', 'icon': Icons.cloud, 'color': Color(0xFFBBCBC2)},
  ];

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  Future<void> _handlePost() async {
    if (_contentController.text.trim().isEmpty) return;
    setState(() => _isPosting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String authorName = 'User';
      String? profileImageUrl;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        String? nickname = userData['nickname'] as String?;
        if (nickname != null && nickname.trim().isNotEmpty) {
          authorName = nickname;
        } else {
          authorName = userData['fullName'] ?? user.displayName ?? 'User';
        }
        profileImageUrl = userData['profileImageUrl'];
      }

      String? imageUrl;
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        imageUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }

      final post = Post(
        id: '',
        authorId: user.uid,
        authorName: authorName,
        authorProfileImage: profileImageUrl,
        content: _contentController.text.trim(),
        timestamp: DateTime.now(),
        isAnonymous: _isAnonymous,
        topic: _selectedTopic,
        moodText: _selectedMood,
        moodColorValue: _getMoodColor(_selectedMood).value,
        likes: [],
        commentCount: 0,
        imageUrl: imageUrl,
      );

      await FirebaseFirestore.instance.collection('posts').add(post.toMap());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Error posting: $e");
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  Color _getMoodColor(String moodName) {
    return _moods.firstWhere((m) => m['name'] == moodName)['color'] as Color;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: sageBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: IconButton(
            icon: Icon(Icons.close_rounded, color: textColorMain, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        centerTitle: true,
        title: Text(
          'Add Feed',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: textColorMain,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TextButton(
              onPressed: _isPosting ? null : _handlePost,
              child: _isPosting 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C9C84)))
                : Text(
                    'Post',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: primaryGreen,
                    ),
                  ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  
                  // Content Area in a Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _contentController,
                          maxLines: 8,
                          style: GoogleFonts.outfit(fontSize: 17, height: 1.6, color: textColorMain),
                          decoration: InputDecoration(
                            hintText: 'Share your journey...',
                            hintStyle: GoogleFonts.outfit(color: textColorSub.withOpacity(0.5), fontSize: 17),
                            border: InputBorder.none,
                          ),
                        ),
                        
                        if (_selectedImage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.file(_selectedImage!, height: 200, width: double.infinity, fit: BoxFit.cover),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _selectedImage = null),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Mood Selection
                  Text(
                    'WHAT\'S YOUR RESONANCE?',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: textColorSub,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 90,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _moods.length,
                      itemBuilder: (context, index) {
                        final mood = _moods[index];
                        bool isSelected = _selectedMood == mood['name'];
                        return GestureDetector(
                          onTap: () => setState(() => _selectedMood = mood['name']),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 70,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? mood['color'] : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: (mood['color'] as Color).withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                )
                              ] : [],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  mood['icon'], 
                                  color: isSelected ? Colors.white : textColorSub,
                                  size: 24,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  mood['name'],
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : textColorSub,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Refinement Options
                  Text(
                    'REFINEMENTS',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: textColorSub,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildOptionTile(
                    label: 'Choose Topic',
                    value: _selectedTopic,
                    icon: Icons.auto_awesome_mosaic_outlined,
                    onTap: _showTopicPicker,
                  ),

                  _buildOptionTile(
                    label: 'Add Media',
                    value: _selectedImage != null ? 'Image Attached' : 'Gallery',
                    icon: Icons.image_outlined,
                    onTap: _pickImage,
                  ),

                  _buildOptionTile(
                    label: 'Anonymity',
                    value: _isAnonymous ? 'ON' : 'OFF',
                    icon: _isAnonymous ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    onTap: () => setState(() => _isAnonymous = !_isAnonymous),
                    isSwitchView: true,
                    switchValue: _isAnonymous,
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required String label, 
    required String value, 
    required IconData icon, 
    required VoidCallback onTap,
    bool isSwitchView = false,
    bool? switchValue,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: sageBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: primaryGreen, size: 20),
        ),
        title: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColorMain,
          ),
        ),
        trailing: isSwitchView 
          ? Switch.adaptive(
              value: switchValue!,
              activeColor: primaryGreen,
              onChanged: (v) => onTap(),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: primaryGreen,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: textColorSub, size: 20),
              ],
            ),
      ),
    );
  }

  void _showTopicPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Taxonomy',
              style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: textColorMain),
            ),
            const SizedBox(height: 20),
            ..._topics.map((t) => ListTile(
              title: Text(t, style: GoogleFonts.outfit(fontSize: 16, color: textColorMain)),
              trailing: t == _selectedTopic ? Icon(Icons.check_circle_rounded, color: primaryGreen) : null,
              onTap: () {
                setState(() => _selectedTopic = t);
                Navigator.pop(context);
              },
            )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
