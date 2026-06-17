import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  String? _selectedExperience;
  final List<String> _experienceOptions = ['1-2 Years', '3-5 Years', '5-10 Years', '10+ Years', '15+ Years'];

  final List<String> _specializationOptions = [
    'Anxiety & Stress', 'Depression', 'Relationship Issues', 
    'Trauma & PTSD', 'Career Counseling', 'Addiction Recovery',
    'OCD', 'Grief & Loss', 'Eating Disorders'
  ];
  List<String> _selectedSpecializations = [];

  final List<String> _languageOptions = ['English', 'Malay', 'Mandarin', 'Cantonese', 'Tamil', 'Hokkien'];
  List<String> _selectedLanguages = [];

  bool _isLoading = false;
  bool _isFreeSession = false;
  
  String? _profileImageUrl;
  File? _imageFile;
  
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFF2F1EC);
  final Color textColorMain = const Color(0xFF333333);

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _priceController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _nameController.text = data['fullName'] ?? user.displayName ?? 'Expert';
        _phoneController.text = data['phone'] ?? '';
        final appDoc = await FirebaseFirestore.instance.collection('counsellor_applications').doc(user.uid).get();
        final appData = appDoc.exists ? appDoc.data() as Map<String, dynamic> : null;
        _bioController.text = data['counsellorBio'] ?? '';

        if (appData != null) {
          final appBio = appData['bio'] ?? appData['motivation'];
          if (_bioController.text.isEmpty && appBio != null && appBio.toString().trim().isNotEmpty) {
             _bioController.text = appBio.toString();
          }
          if (_selectedExperience == null || _selectedExperience!.isEmpty) {
             _selectedExperience = appData['experience'];
          }
          if (_selectedSpecializations.isEmpty) {
             final dynamic specs = appData['specializations'];
             if (specs is List) {
               _selectedSpecializations = List<String>.from(specs);
             }
          }
          if (_selectedLanguages.isEmpty) {
             final dynamic langData = appData['languages'];
             if (langData is List) {
               _selectedLanguages = List<String>.from(langData);
             } else if (langData is String && langData.isNotEmpty) {
               _selectedLanguages = langData.split(', ').map((e) => e.trim()).toList();
             }
          }
        }
          if (_bioController.text.isEmpty && data['bio'] != null) {
            _bioController.text = data['bio'] ?? '';
          }
          if (_selectedExperience == null && data['experience'] != null) {
            _selectedExperience = data['experience']?.toString();
          }

          if (_selectedSpecializations.isEmpty) {
            final dynamic specs = data['specializations'];
            if (specs is List) {
              _selectedSpecializations = List<String>.from(specs);
            }
          }

          if (_selectedLanguages.isEmpty) {
            final dynamic langData = data['languages'];
            if (langData is List) {
              _selectedLanguages = List<String>.from(langData);
            } else if (langData is String && langData.isNotEmpty) {
              _selectedLanguages = langData.split(', ').map((e) => e.trim()).toList();
            }
          }
        
        _priceController.text = data['price']?.toString() ?? 'Free';
        _isFreeSession = _priceController.text.toLowerCase() == 'free' || _priceController.text == '0' || _priceController.text.trim().isEmpty;
        _profileImageUrl = data['counsellorImageUrl'] ?? (appData != null ? appData['profilePhotoUrl'] : null);
        
        if (_selectedExperience != null && !_experienceOptions.contains(_selectedExperience)) {
          _selectedExperience = null;
        }
      }
    }
    setState(() => _isLoading = false);
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
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 32),
            Text('Update Profile Photo', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.w600, color: const Color(0xFF333333))),
            const SizedBox(height: 8),
            Text('Choose a way to capture your essence', style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF7A8C85))),
            const SizedBox(height: 32),
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
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF7A8C85))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap, Color iconColor = const Color(0xFF7C9C84)}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5)),
        child: Row(
          children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: iconColor, size: 24)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF333333))),
              const SizedBox(height: 2),
              Text(subtitle, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF7A8C85))),
            ])),
            Icon(Icons.chevron_right, color: Colors.grey[300], size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: source, maxWidth: 256, maxHeight: 256, imageQuality: 40);
      if (pickedFile != null) setState(() => _imageFile = File(pickedFile.path));
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
      final bytes = await image.readAsBytes();
      String base64Image = base64Encode(bytes);
      return 'data:image/jpeg;base64,$base64Image';
    } catch (e) {
      debugPrint('Error processing image: $e');
      return null;
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    
    try {
      String? imageUrl = _profileImageUrl;
      if (_imageFile != null) {
        imageUrl = await _processImageToBase64(_imageFile!);
      }

      await FirebaseFirestore.instance.collection('users').doc(user?.uid).update({
        'counsellorBio': _bioController.text.trim(),
        'price': _isFreeSession ? 'Free' : _priceController.text.trim(),
        'experience': _selectedExperience,
        'specializations': _selectedSpecializations,
        'languages': _selectedLanguages,
        'counsellorImageUrl': imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('counsellor_applications').doc(user?.uid).set({
        'bio': _bioController.text.trim(),
        'price': _isFreeSession ? 'Free' : _priceController.text.trim(),
        'experience': _selectedExperience,
        'specializations': _selectedSpecializations,
        'languages': _selectedLanguages,
        'profilePhotoUrl': imageUrl,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Professional profile updated successfully'), backgroundColor: Color(0xFF7C9C84)));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
        title: Text('Edit Profile', style: GoogleFonts.playfairDisplay(color: textColorMain, fontWeight: FontWeight.bold, fontSize: 24)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF333333), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C9C84))))
        : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PHOTO SECTION (Enlarged Avatar)
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
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
                            image: _imageFile != null
                                ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                                : (_profileImageUrl != null && _profileImageUrl!.startsWith('data:image'))
                                ? DecorationImage(image: MemoryImage(base64Decode(_profileImageUrl!.split(',').last)), fit: BoxFit.cover)
                                : _profileImageUrl != null
                                ? DecorationImage(image: NetworkImage(_profileImageUrl!), fit: BoxFit.cover)
                                : null,
                          ),
                          child: (_imageFile == null && _profileImageUrl == null)
                              ? const Icon(Icons.person, size: 60, color: Color(0xFFBBCBC2))
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
                              color: primaryGreen,
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
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: primaryGreen),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            _buildSectionTitle('CLINICAL IDENTITY'),
            
            // Full Name Field
            _buildLabel('FULL NAME (READ-ONLY)'),
            _buildTextField(_nameController, hintText: "Enter your full name", readOnly: true),

            const SizedBox(height: 24),

            // Email Field
            _buildLabel('PROFESSIONAL EMAIL (READ-ONLY)'),
            _buildTextField(_emailController, hintText: "Enter your professional email", readOnly: true),

            const SizedBox(height: 24),

            // Phone Field
            _buildLabel('PHONE CONTACT (READ-ONLY)'),
            _buildTextField(_phoneController, hintText: "Enter your phone contact", readOnly: true),

            const SizedBox(height: 24),

            // Bio Field
            _buildLabel('THERAPEUTIC BIO'),
            _buildTextField(_bioController, maxLines: 4, hintText: "Describe your clinical background and approach..."),

            const SizedBox(height: 32),

            // EXPERIENCE RANK (Selection Grid)
            _buildSectionTitle('EXPERIENCE RANK'),
            _buildExperienceGrid(),

            const SizedBox(height: 32),

            // SESSION PRICE
            _buildSectionTitle('SESSION PRICE'),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text('Offer Free Sessions', style: GoogleFonts.outfit(fontSize: 16, color: textColorMain)),
                    value: _isFreeSession,
                    activeColor: primaryGreen,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    onChanged: (bool value) {
                      setState(() {
                        _isFreeSession = value;
                        if (value) {
                          _priceController.text = 'Free';
                        } else {
                          _priceController.text = '100'; // Default to 100 when toggled off
                        }
                      });
                    },
                  ),
                  if (!_isFreeSession)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Row(
                        children: [
                          Text('RM ', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: primaryGreen)),
                          Expanded(
                            child: TextField(
                              controller: _priceController,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.outfit(fontSize: 16, color: textColorMain),
                              decoration: InputDecoration(
                                hintText: 'Enter session price',
                                hintStyle: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 14),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          Text('/ hour', style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // CLINICAL SPECIALIZATIONS
            _buildSectionTitle('CLINICAL SPECIALIZATIONS'),
            _buildSelectionChipGrid(_specializationOptions, _selectedSpecializations, (option, selected) {
              setState(() {
                if (selected) {
                  _selectedSpecializations.add(option);
                } else {
                  _selectedSpecializations.remove(option);
                }
              });
            }),

            const SizedBox(height: 32),

            // LANGUAGES SPOKEN
            _buildSectionTitle('PROFICIENCY IN LANGUAGES'),
            _buildSelectionChipGrid(_languageOptions, _selectedLanguages, (option, selected) {
              setState(() {
                if (selected) {
                  _selectedLanguages.add(option);
                } else {
                  _selectedLanguages.remove(option);
                }
              });
            }),

            const SizedBox(height: 48),

            // SUBMIT ACTION
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('Save Changes', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF333333)),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: const Color(0xFFA3A3A3)),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, {int maxLines = 1, String? hintText, bool readOnly = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        readOnly: readOnly,
        style: GoogleFonts.outfit(fontSize: 16, color: readOnly ? const Color(0xFF9E9E9E) : const Color(0xFF333333)),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 14),
          suffixIcon: readOnly ? const Icon(Icons.lock_outline_rounded, color: Color(0xFFD1D5DB), size: 20) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildExperienceGrid() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _experienceOptions.map((opt) {
        final isSel = _selectedExperience == opt;
        return GestureDetector(
          onTap: () => setState(() => _selectedExperience = opt),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSel ? primaryGreen : Colors.transparent,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: isSel ? primaryGreen : Colors.grey[400]!, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  opt,
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w500, color: isSel ? Colors.white : const Color(0xFF555555)),
                ),
                if (isSel) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.check, size: 16, color: Colors.white),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSelectionChipGrid(List<String> options, List<String> selected, Function(String, bool) onToggle) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((opt) {
        final isSel = selected.contains(opt);
        return GestureDetector(
          onTap: () => onToggle(opt, !isSel),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSel ? primaryGreen : Colors.transparent,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: isSel ? primaryGreen : Colors.grey[400]!, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  opt,
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w500, color: isSel ? Colors.white : const Color(0xFF555555)),
                ),
                if (isSel) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.check, size: 16, color: Colors.white),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
