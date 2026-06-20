import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/post.dart';
import '../services/backend_config.dart';

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
  
  List<String> _selectedTopics = ['General'];
  String _selectedMood = 'Neutral';
  bool _isAnonymous = false;
  File? _selectedImage;
  bool _isPosting = false;

  final List<String> _topics = ['Self-Love', 'Anxiety', 'Hope', 'Relationship', 'General'];
  final List<Map<String, dynamic>> _moods = [
    {'name': 'Happy', 'icon': Icons.sentiment_very_satisfied_rounded, 'color': Color(0xFF4CAF50), 'bgColor': Color(0xFFE8F5E9)},
    {'name': 'Calm', 'icon': Icons.sentiment_satisfied_rounded, 'color': Color(0xFF2196F3), 'bgColor': Color(0xFFE3F2FD)},
    {'name': 'Neutral', 'icon': Icons.sentiment_neutral_rounded, 'color': Color(0xFF9E9E9E), 'bgColor': Color(0xFFF5F5F5)},
    {'name': 'Sad', 'icon': Icons.sentiment_dissatisfied_rounded, 'color': Color(0xFF9C27B0), 'bgColor': Color(0xFFF3E5F5)},
    {'name': 'Anxious', 'icon': Icons.mood_bad_rounded, 'color': Color(0xFFFF9800), 'bgColor': Color(0xFFFFF3E0)},
    {'name': 'Angry', 'icon': Icons.sentiment_very_dissatisfied_rounded, 'color': Color(0xFFF44336), 'bgColor': Color(0xFFFFEBEE)},
  ];

  final ScrollController _moodScrollController = ScrollController();
  bool _isDetecting = false;

  @override
  void initState() {
    super.initState();
    _contentController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _contentController.removeListener(_onTextChanged);
    _contentController.dispose();
    _moodScrollController.dispose();
    super.dispose();
  }

  Future<void> _detectEmotionAndTopic(String text) async {
    setState(() => _isDetecting = true);
    try {
      final response = await BackendConfig.withRetry(
        (baseUrl) => http.post(
          Uri.parse('$baseUrl/predict_emotion'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'text': text}),
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final emotion = data['emotion'] as String?;
        final hashtags = data['hashtags'] as List<dynamic>?;

        if (emotion != null && mounted) {
          String newMood = 'Neutral';
          switch (emotion.toLowerCase()) {
            case 'joy':
            case 'hopeful':
              newMood = 'Happy';
              break;
            case 'calm':
              newMood = 'Calm';
              break;
            case 'sadness':
              newMood = 'Sad';
              break;
            case 'anxiety':
              newMood = 'Anxious';
              break;
            case 'anger':
              newMood = 'Angry';
              break;
            default:
              newMood = 'Neutral';
          }
          
          List<String> newTopics = List.from(_selectedTopics);
          if (hashtags != null && hashtags.isNotEmpty) {
            for (var tag in hashtags) {
              if (!newTopics.contains(tag.toString())) {
                newTopics.add(tag.toString());
              }
            }
            if (newTopics.length > 1 && newTopics.contains('General')) {
              newTopics.remove('General');
            }
          }

          setState(() {
            _selectedMood = newMood;
            if (newTopics.isNotEmpty) {
              _selectedTopics = newTopics;
            }
          });
          
          int moodIndex = _moods.indexWhere((m) => m['name'] == newMood);
          if (moodIndex != -1) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (_moodScrollController.hasClients) {
                // Approximate item width 75 + 12 margin = 87
                double offset = moodIndex * 87.0;
                double maxScroll = _moodScrollController.position.maxScrollExtent;
                _moodScrollController.animateTo(
                  offset > maxScroll ? maxScroll : offset,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                );
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error detecting emotion: $e");
    } finally {
      if (mounted) setState(() => _isDetecting = false);
    }
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
        topic: _selectedTopics.join(', '),
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

                  const SizedBox(height: 20),

                  // Magic Wand Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: _isDetecting || _contentController.text.trim().isEmpty
                          ? null
                          : () {
                              FocusScope.of(context).unfocus(); // hide keyboard
                              _detectEmotionAndTopic(_contentController.text.trim());
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: _contentController.text.trim().isEmpty ? Colors.grey[300] : primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _contentController.text.trim().isEmpty ? Colors.transparent : primaryGreen.withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isDetecting)
                              const SizedBox(
                                width: 14, height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C9C84)),
                              )
                            else
                              Icon(Icons.auto_awesome, color: _contentController.text.trim().isEmpty ? Colors.grey : primaryGreen, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              _isDetecting ? 'Analyzing...' : 'Suggest Mood & Topic',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _contentController.text.trim().isEmpty ? Colors.grey : primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Mood Selection
                  Row(
                    children: [
                      Text(
                        'EMOTION (MANUAL OR AUTO)',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: textColorSub,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 90,
                    child: ListView.builder(
                      controller: _moodScrollController,
                      scrollDirection: Axis.horizontal,
                      itemCount: _moods.length,
                      itemBuilder: (context, index) {
                        final mood = _moods[index];
                        bool isSelected = _selectedMood == mood['name'];
                        return GestureDetector(
                          onTap: () => setState(() => _selectedMood = mood['name']),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 75,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? mood['bgColor'] : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? mood['color'] : Colors.transparent,
                                width: 1.5,
                              ),
                              boxShadow: isSelected ? [] : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  mood['icon'], 
                                  color: isSelected ? mood['color'] : textColorSub.withOpacity(0.6),
                                  size: 26,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  mood['name'],
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? mood['color'] : textColorSub,
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
                    value: _selectedTopics.join(', ').length > 20 
                        ? '${_selectedTopics.join(', ').substring(0, 20)}...' 
                        : _selectedTopics.join(', '),
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
    List<String> displayTopics = List.from(_topics);
    for (String t in _selectedTopics) {
      if (!displayTopics.contains(t)) {
        displayTopics.insert(0, t);
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Topics',
                    style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: textColorMain),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: displayTopics.map((t) {
                      final isSelected = _selectedTopics.contains(t);
                      return FilterChip(
                        label: Text(t),
                        selected: isSelected,
                        showCheckmark: false,
                        selectedColor: primaryGreen,
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                          side: BorderSide(
                            color: isSelected ? Colors.transparent : Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        labelStyle: GoogleFonts.outfit(
                          color: isSelected ? Colors.white : textColorMain,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 14,
                        ),
                        onSelected: (bool selected) {
                          setModalState(() {
                            if (selected) {
                              _selectedTopics.add(t);
                              if (t != 'General' && _selectedTopics.contains('General')) {
                                _selectedTopics.remove('General');
                              }
                            } else {
                              _selectedTopics.remove(t);
                              if (_selectedTopics.isEmpty) {
                                _selectedTopics.add('General');
                              }
                            }
                          });
                          setState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text('Done', style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            );
          }
        );
      },
    );
  }
}
