import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditCounsellorProfileScreen extends StatefulWidget {
  const EditCounsellorProfileScreen({super.key});

  @override
  State<EditCounsellorProfileScreen> createState() => _EditCounsellorProfileScreenState();
}

class _EditCounsellorProfileScreenState extends State<EditCounsellorProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _userName;
  String? _userEmail;
  String? _licenseNumber;
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  
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
    _bioController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userEmail = user.email;
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _userName = data['fullName'] ?? user.displayName ?? 'Expert';
        _licenseNumber = data['licenseNumber'] ?? 'E-SAGE-${user.uid.substring(0, 8).toUpperCase()}';
        _bioController.text = data['bio'] ?? '';
        _priceController.text = data['price']?.toString() ?? 'Free';
        _isFreeSession = _priceController.text.toLowerCase() == 'free' || _priceController.text == '0' || _priceController.text.trim().isEmpty;
        _selectedExperience = data['experience']?.toString();
        
        // Safety check for legacy data
        if (_selectedExperience != null && !_experienceOptions.contains(_selectedExperience)) {
          _selectedExperience = null;
        }

        final List<dynamic>? specs = data['specializations'];
        if (specs != null) _selectedSpecializations = List<String>.from(specs);

        final dynamic langData = data['languages'];
        if (langData is List) {
          _selectedLanguages = List<String>.from(langData);
        } else if (langData is String && langData.isNotEmpty) {
          _selectedLanguages = langData.split(', ').toList();
        }
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    
    try {
      await FirebaseFirestore.instance.collection('users').doc(user?.uid).update({
        'bio': _bioController.text.trim(),
        'price': _isFreeSession ? 'Free' : _priceController.text.trim(),
        'experience': _selectedExperience,
        'specializations': _selectedSpecializations,
        'languages': _selectedLanguages,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Professional profile updated successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(backgroundColor: backgroundColor, body: const Center(child: CircularProgressIndicator(color: Color(0xFF7C9C84))));

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text('Edit Profile', style: GoogleFonts.playfairDisplay(color: textColorMain, fontWeight: FontWeight.bold, fontSize: 22)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF333333), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Form(
          key: _formKey,
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
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 10))],
                          ),
                          child: Icon(Icons.person_rounded, color: Colors.grey[200], size: 60),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: primaryGreen, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // READ-ONLY IDENTITY
              _buildSectionTitle('CLINICAL IDENTITY (READ-ONLY)'),
              _buildReadOnlyBlock([
                _buildStaticInfo('Full Name', _userName ?? 'Expert', Icons.badge_outlined),
                const Divider(height: 1, indent: 60),
                _buildStaticInfo('Clinical License ID', _licenseNumber ?? 'N/A', Icons.verified_user_outlined),
                const Divider(height: 1, indent: 60),
                _buildStaticInfo('Professional Email', _userEmail ?? 'No email', Icons.email_outlined),
              ]),

              const SizedBox(height: 32),

              // EXPERIENCE RANK (Selection Grid)
              _buildSectionTitle('EXPERIENCE RANK'),
              _buildExperienceGrid(),

              const SizedBox(height: 32),

              // THERAPEUTIC BIO
              _buildSectionTitle('THERAPEUTIC BIO'),
              _buildFormSection([
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: TextFormField(
                    controller: _bioController,
                    maxLines: 4,
                    style: GoogleFonts.outfit(fontSize: 14, height: 1.5),
                    decoration: InputDecoration(
                      hintText: 'Describe your clinical background and approach...',
                      hintStyle: GoogleFonts.outfit(color: Colors.grey[400], height: 1.5),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ]),

              const SizedBox(height: 32),

              // SESSION PRICE
              _buildSectionTitle('SESSION PRICE'),
              _buildFormSection([
                SwitchListTile(
                  title: Text('Offer Free Sessions', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: textColorMain)),
                  value: _isFreeSession,
                  activeColor: primaryGreen,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        Text('RM ', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: primaryGreen)),
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.outfit(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Enter session price',
                              hintStyle: GoogleFonts.outfit(color: Colors.grey[400]),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        Text('/ hour', style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[500])),
                      ],
                    ),
                  ),
              ]),

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
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: _isLoading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Update Professional Records', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey[500]),
      ),
    );
  }

  Widget _buildReadOnlyBlock(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8ECE9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildFormSection(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildStaticInfo(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.bold)),
                Text(value, style: GoogleFonts.outfit(fontSize: 14, color: textColorMain, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Icon(Icons.lock_rounded, color: Colors.grey, size: 14),
        ],
      ),
    );
  }

  Widget _buildExperienceGrid() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _experienceOptions.map((opt) {
          final isSel = _selectedExperience == opt;
          return GestureDetector(
            onTap: () => setState(() => _selectedExperience = opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSel ? primaryGreen : const Color(0xFFF7F8F7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                opt,
                style: GoogleFonts.outfit(fontSize: 13, color: isSel ? Colors.white : Colors.grey[600], fontWeight: isSel ? FontWeight.bold : FontWeight.w500),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSelectionChipGrid(List<String> options, List<String> selected, Function(String, bool) onToggle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: options.map((opt) {
          final isSel = selected.contains(opt);
          return GestureDetector(
            onTap: () => onToggle(opt, !isSel),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSel ? primaryGreen : const Color(0xFFF7F8F7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                opt,
                style: GoogleFonts.outfit(fontSize: 13, color: isSel ? Colors.white : Colors.grey[600], fontWeight: isSel ? FontWeight.bold : FontWeight.w500),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
