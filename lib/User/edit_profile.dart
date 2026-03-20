import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  final List<String> _selectedInterests = [];
  final List<String> _allInterests = [
    'Anxiety Relief',
    'Daily Gratitude',
    'Sleep Hygiene',
    'Peer Support',
    'Productivity',
  ];

  bool _isLoading = true;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  String? _profileImageUrl;
  File? _imageFile;
  final List<Map<String, dynamic>> _trustedContacts = [];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 32),

            // Title
            Text(
              'Update Profile Photo',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a way to capture your essence',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: const Color(0xFF7A8C85),
              ),
            ),
            const SizedBox(height: 32),

            // Options
            _buildSourceTile(
              icon: Icons.camera_alt_outlined,
              title: 'Take Photo',
              subtitle: 'Use your camera for a new shot',
              onTap: () {
                Navigator.pop(context);
                _getImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 16),
            _buildSourceTile(
              icon: Icons.photo_library_outlined,
              title: 'Choose from Gallery',
              subtitle: 'Pick from your existing library',
              onTap: () {
                Navigator.pop(context);
                _getImage(ImageSource.gallery);
              },
            ),

            if (_imageFile != null || _profileImageUrl != null) ...[
              const SizedBox(height: 16),
              _buildSourceTile(
                icon: Icons.delete_outline,
                iconColor: Colors.redAccent,
                title: 'Remove Current Photo',
                subtitle: 'Revert to default avatar',
                onTap: () {
                  Navigator.pop(context);
                  _markImageForRemoval();
                },
              ),
            ],

            const SizedBox(height: 32),

            // Cancel Button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF7A8C85),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFF7C9C84),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
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
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: const Color(0xFF7A8C85),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[300], size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 256, // Reduced from 512 for manageable Base64 size
        maxHeight: 256, // Reduced from 512
        imageQuality: 40, // Reduced quality to keep string length down
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _markImageForRemoval() {
    setState(() {
      _imageFile = null;
      _profileImageUrl = null;
    });
  }

  Future<String?> _processImageToBase64(File image) async {
    try {
      // 1. Read the image bytes
      final bytes = await image.readAsBytes();

      // 2. Compress the image if it's too large (Firestore limit is 1MB total for doc)
      // Since we can't easily compress bytes directly to a specific size without a package like flutter_image_compress,
      // we'll just encode it. To be safe, ensure the user picks a small image or use a package later.

      String base64Image = base64Encode(bytes);

      // 3. Return as a Data URI so Flutter can display it easily
      return 'data:image/jpeg;base64,$base64Image';
    } catch (e) {
      debugPrint('Error processing image: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    if (_currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _nameController.text = data['fullName'] ?? '';
          _emailController.text = data['email'] ?? '';
          _bioController.text = data['bio'] ?? '';
          _profileImageUrl = data['profileImageUrl'];

          if (data['interests'] != null) {
            _selectedInterests.clear();
            _selectedInterests.addAll(List<String>.from(data['interests']));
          }

          if (data['trustedContacts'] != null) {
            _trustedContacts.clear();
            _trustedContacts.addAll(List<Map<String, dynamic>>.from(data['trustedContacts']));
          }

          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleInterest(String interest) {
    setState(() {
      if (_selectedInterests.contains(interest)) {
        _selectedInterests.remove(interest);
      } else {
        _selectedInterests.add(interest);
      }
    });
  }

  Future<void> _saveChanges() async {
    if (_currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      String? imageUrl = _profileImageUrl;
      if (_imageFile != null) {
        imageUrl = await _processImageToBase64(_imageFile!);
      }

      final name = _nameController.text.trim();
      final docRef = FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid);

      await docRef.update({
        'fullName': name,
        'email': _emailController.text.trim(),
        'bio': _bioController.text.trim(),
        'interests': _selectedInterests,
        'profileImageUrl': imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Also update FirebaseAuth displayName
      await _currentUser!.updateDisplayName(name);
      await _currentUser!.reload(); // Refresh the user object

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profile updated successfully!"),
            backgroundColor: Color(0xFF7C9C84),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error updating profile: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EC),
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
          'Edit Profile',
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFF333333),
            fontWeight: FontWeight.w600,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        actions: const [
          SizedBox(width: 48), // Balancing the leading icon space
        ],
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C9C84)),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Picture Section
            Center(
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                            image: _imageFile != null
                                ? DecorationImage(
                              image: FileImage(_imageFile!),
                              fit: BoxFit.cover,
                            )
                                : (_profileImageUrl != null && _profileImageUrl!.startsWith('data:image'))
                                ? DecorationImage(
                              image: MemoryImage(base64Decode(_profileImageUrl!.split(',').last)),
                              fit: BoxFit.cover,
                            )
                                : _profileImageUrl != null
                                ? DecorationImage(
                              image: NetworkImage(_profileImageUrl!),
                              fit: BoxFit.cover,
                            )
                                : null,
                          ),
                          child: (_imageFile == null && _profileImageUrl == null)
                              ? const Icon(
                            Icons.person,
                            size: 60,
                            color: Color(0xFFBBCBC2),
                          )
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C9C84),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Text(
                      'CHANGE PROFILE PICTURE',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: const Color(0xFF7C9C84),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Full Name Field
            _buildLabel('FULL NAME'),
            _buildTextField(_nameController, hintText: "Enter your full name"),

            const SizedBox(height: 24),

            // Email Field
            _buildLabel('EMAIL ADDRESS'),
            _buildTextField(_emailController, hintText: "Enter your email address"),

            const SizedBox(height: 24),

            // Bio Field
            _buildLabel('MINDFUL BIO'),
            _buildTextField(_bioController, maxLines: 4, hintText: "Share your mindful journey or goals..."),

            const SizedBox(height: 32),

            // Trusted Contacts
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trusted Contacts',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Share your progress summaries',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3E8E4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add, size: 16, color: Color(0xFF7C9C84)),
                      const SizedBox(width: 4),
                      Text(
                        'Add',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF7C9C84),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_trustedContacts.isEmpty)
              GestureDetector(
                onTap: () {
                  // Action for adding contact
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Add Contact feature coming soon!")),
                  );
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3E8E4),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFBBCBC2), width: 1),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.add,
                      size: 30,
                      color: Color(0xFF7C9C84),
                    ),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: _trustedContacts.map((contact) {
                  return _buildContactAvatar(
                    contact['initials'] ?? '??',
                    contact['label'] ?? 'Unknown',
                  );
                }).toList(),
              ),

            const SizedBox(height: 32),

            // Mood Interests
            Text(
              'Mood Interests',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 8),
            if (_selectedInterests.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
                child: Text(
                  'No interests selected yet. Pick some below!',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.orange[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _allInterests.map((interest) {
                final isSelected = _selectedInterests.contains(interest);
                return GestureDetector(
                  onTap: () => _toggleInterest(interest),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF7C9C84) : Colors.transparent,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF7C9C84) : Colors.grey[400]!,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          interest,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.white : const Color(0xFF555555),
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.check, size: 16, color: Colors.white),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 40),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C9C84),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  'Save Changes',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
          color: const Color(0xFFA3A3A3),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, {int maxLines = 1, String? hintText}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: GoogleFonts.outfit(
          fontSize: 16,
          color: const Color(0xFF333333),
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.outfit(
            color: Colors.grey[400],
            fontSize: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildContactAvatar(String initials, String label) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFFE3E8E4),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFBBCBC2), width: 1),
          ),
          child: Center(
            child: Text(
              initials,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF7C9C84),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }
}
