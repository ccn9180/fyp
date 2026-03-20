
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class EditCounsellorProfileScreen extends StatefulWidget {
  const EditCounsellorProfileScreen({super.key});

  @override
  State<EditCounsellorProfileScreen> createState() => _EditCounsellorProfileScreenState();
}

class _EditCounsellorProfileScreenState extends State<EditCounsellorProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final List<String> _selectedSpecializations = [];

  String? _counsellorImageUrl;
  File? _imageFile;

  final List<String> _allSpecializations = [
    'Cognitive Behavioral Therapy (CBT)',
    'Mindfulness & Meditation',
    'Grief & Trauma Counseling',
    'Stress & Anxiety Management',
    'Relationship & Family Therapy',
    'Life Coaching',
  ];

  bool _isLoading = true;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _fetchCounsellorData();
  }

  Future<void> _fetchCounsellorData() async {
    if (_currentUser == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _nameController.text = data['fullName'] ?? _currentUser?.displayName ?? '';
          _emailController.text = data['email'] ?? _currentUser?.email ?? '';
          _bioController.text = data['counsellorBio'] ?? '';
          _experienceController.text = data['experience'] ?? '';
          _counsellorImageUrl = data['counsellorImageUrl'];
          if (data['specializations'] != null) {
            _selectedSpecializations.clear();
            _selectedSpecializations.addAll(List<String>.from(data['specializations']));
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching counsellor data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 256,
      maxHeight: 256,
      imageQuality: 40,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _processImageToBase64(File image) async {
    try {
      final bytes = await image.readAsBytes();
      String base64Image = base64Encode(bytes);
      return 'data:image/jpeg;base64,$base64Image';
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveChanges() async {
    if (_currentUser == null) return;
    if (_nameController.text.isEmpty || _experienceController.text.isEmpty || _selectedSpecializations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all mandatory fields')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      String? imageUrl = _counsellorImageUrl;
      if (_imageFile != null) {
        imageUrl = await _processImageToBase64(_imageFile!);
      }

      await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).update({
        'fullName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'counsellorBio': _bioController.text.trim(),
        'experience': _experienceController.text.trim(),
        'specializations': _selectedSpecializations,
        'counsellorImageUrl': imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _currentUser!.updateDisplayName(_nameController.text.trim());
      // We don't update Firebase Auth photoURL with counsellor image to keep personal photo as primary identity
      // but we could if we wanted. For now let's keep it separate.
      if (imageUrl != null && !imageUrl.startsWith('data:image')) {
        await _currentUser!.updatePhotoURL(imageUrl);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Color(0xFF7C9C84)));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = const Color(0xFF7C9C84);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: const Color(0xFF333333),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Professional Profile',
          style: GoogleFonts.playfairDisplay(color: const Color(0xFF333333), fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C9C84)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Image Section
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
                      ],
                      image: _imageFile != null
                          ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                          : (_counsellorImageUrl != null && _counsellorImageUrl!.startsWith('data:image'))
                          ? DecorationImage(image: MemoryImage(base64Decode(_counsellorImageUrl!.split(',').last)), fit: BoxFit.cover)
                          : _counsellorImageUrl != null
                          ? DecorationImage(image: NetworkImage(_counsellorImageUrl!), fit: BoxFit.cover)
                          : null,
                    ),
                    child: (_imageFile == null && _counsellorImageUrl == null)
                        ? const Icon(Icons.person, size: 60, color: Color(0xFFBBCBC2))
                        : null,
                  ),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: primaryGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            _buildLabel('FULL NAME'),
            _buildTextField(_nameController, "Your professional name"),

            const SizedBox(height: 24),
            _buildLabel('EMAIL ADDRESS'),
            _buildTextField(_emailController, "Enter your email", keyboardType: TextInputType.emailAddress),

            const SizedBox(height: 24),
            _buildLabel('PROFESSIONAL BIO'),
            _buildTextField(_bioController, "Describe your therapeutic approach...", maxLines: 4),

            const SizedBox(height: 24),
            _buildLabel('YEARS OF EXPERIENCE'),
            _buildTextField(_experienceController, "e.g. 8", keyboardType: TextInputType.number),

            const SizedBox(height: 32),
            _buildLabel('SPECIALIZATIONS'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _allSpecializations.map((spec) {
                final isSelected = _selectedSpecializations.contains(spec);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) _selectedSpecializations.remove(spec);
                      else _selectedSpecializations.add(spec);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryGreen : Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: isSelected ? primaryGreen : Colors.grey[300]!),
                    ),
                    child: Text(
                      spec,
                      style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: isSelected ? Colors.white : const Color(0xFF555555),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('Save Professional Profile', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey[500]),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {TextInputType? keyboardType, int maxLines = 1}) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: GoogleFonts.outfit(),
        decoration: InputDecoration(
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}
