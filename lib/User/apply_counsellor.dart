import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:fyp/UserAccount/splash_screen.dart';

class ApplyCounsellorScreen extends StatefulWidget {
  const ApplyCounsellorScreen({super.key});

  @override
  State<ApplyCounsellorScreen> createState() => _ApplyCounsellorScreenState();
}

class _ApplyCounsellorScreenState extends State<ApplyCounsellorScreen> {
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFFBFBF6);
  final Color textColorMain = const Color(0xFF333333);

  final _formKey = GlobalKey<FormState>();
  int _activeStep = 0;
  bool _isSubmitting = false;
  bool _isLoadingStatus = true;
  String? _statusError;
  bool _isRejected = false;
  bool _isDeactivated = false;

  // Personal Information
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  File? _profilePhotoFile;

  // Professional Information
  final List<String> _selectedSpecializations = [];
  final List<String> _selectedLanguages = [];
  String? _selectedExperience;
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  bool _isFreeSession = false;

  // Verification Documents
  File? _certificateFile;

  final List<String> _specializations = [
    'Anxiety & Stress', 'Depression', 'Relationship Issues', 
    'Trauma & PTSD', 'Career Counseling', 'Addiction Recovery',
    'OCD', 'Grief & Loss', 'Eating Disorders'
  ];

  final List<String> _languageOptions = ['English', 'Malay', 'Mandarin', 'Cantonese', 'Tamil', 'Hokkien'];
  final List<String> _experienceOptions = ['1-2 Years', '3-5 Years', '5-10 Years', '10+ Years', '15+ Years'];

  @override
  void initState() {
    super.initState();
    _checkEligibility();
  }

  Future<void> _checkEligibility() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _statusError = "Please log in to apply.";
          _isLoadingStatus = false;
        });
      }
      return;
    }

    _nameController.text = user.displayName ?? '';
    _emailController.text = user.email ?? '';

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists && (userDoc.data()?['role'] == 'counsellor')) {
        if (mounted) {
          setState(() {
            _statusError = "Your application is ALREADY APPROVED! 🎉\n\nPlease long press the Profile tab at the bottom navigation bar to switch to the Counsellor portal.";
            _isLoadingStatus = false;
          });
        }
        return;
      }

      final appDoc = await FirebaseFirestore.instance.collection('counsellor_applications').doc(user.uid).get();
      if (appDoc.exists) {
        final status = appDoc.data()?['status'];
        if (status == 'pending') {
          if (mounted) {
            setState(() {
              _statusError = "Your application is currently PENDING. Our team is reviewing your details. Please check back later.";
              _isLoadingStatus = false;
            });
          }
          return;
        } else if (status == 'approved') {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'role': 'counsellor'});
          if (mounted) {
            setState(() {
              _statusError = "Your application is ALREADY APPROVED! 🎉\n\nPlease long press the Profile tab at the bottom navigation bar to switch to the Counsellor portal.";
              _isLoadingStatus = false;
            });
          }
          return;
        } else if (status == 'rejected') {
          final reason = appDoc.data()?['rejectionReason'] ?? 'Does not meet our requirements at this time.';
          if (mounted) {
            setState(() {
              _statusError = reason;
              _isRejected = true;
              _isLoadingStatus = false;
            });
          }
          return;
        } else if (status == 'deactivated') {
          if (mounted) {
            setState(() {
              _statusError = "Your account has been deactivated. You can apply again if you wish to return as a counsellor.";
              _isDeactivated = true;
              _isLoadingStatus = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint("Eligibility check error: $e");
    } finally {
      if (mounted) setState(() => _isLoadingStatus = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickFile(Function(File) onPicked) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => onPicked(File(image.path)));
    }
  }

  bool _validateStep() {
    if (_activeStep == 0) {
      if (!_formKey.currentState!.validate()) return false;
      if (_profilePhotoFile == null) {
        _showError('Please upload a profile photo');
        return false;
      }
    } else if (_activeStep == 1) {
      if (!_formKey.currentState!.validate()) return false;
      if (_selectedSpecializations.isEmpty) {
        _showError('Please select at least one specialization');
        return false;
      }
      if (_selectedLanguages.isEmpty) {
        _showError('Please select at least one language');
        return false;
      }
      if (_selectedExperience == null) {
        _showError('Please select your experience level');
        return false;
      }
      if (!_isFreeSession && _priceController.text.trim().isEmpty) {
        _showError('Please set your session price');
        return false;
      }
    } else if (_activeStep == 2) {
      if (_certificateFile == null) {
        _showError('Please upload your professional certificate');
        return false;
      }
    }
    return true;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(msg, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w500))),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
      )
    );
  }

  Future<String?> _uploadFile(File? file, String path) async {
    if (file == null) return null;
    final storageRef = FirebaseStorage.instance.ref().child(path);
    final uploadTask = await storageRef.putFile(file);
    return await uploadTask.ref.getDownloadURL();
  }

  Future<void> _submitFinalApplication() async {
    if (!_validateStep()) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      final phone = _phoneController.text.trim();
      
      // Check for duplicate phone number
      final existingApp = await FirebaseFirestore.instance
          .collection('counsellor_applications')
          .where('phone', isEqualTo: phone)
          .get();
          
      if (existingApp.docs.isNotEmpty) {
        bool isDuplicate = false;
        for (var doc in existingApp.docs) {
          if (doc.id != user.uid) {
            isDuplicate = true;
            break;
          }
        }
        if (isDuplicate) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This phone number is already registered by another counsellor. Please use a different number.')),
            );
            setState(() => _isSubmitting = false);
          }
          return;
        }
      }

      // Check users collection as well just in case
      final existingUser = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .get();
          
      if (existingUser.docs.isNotEmpty) {
        bool isDuplicate = false;
        for (var doc in existingUser.docs) {
          if (doc.id != user.uid && doc.data()['role'] == 'counsellor') {
            isDuplicate = true;
            break;
          }
        }
        if (isDuplicate) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This phone number is already registered by another counsellor. Please use a different number.')),
            );
            setState(() => _isSubmitting = false);
          }
          return;
        }
      }

      final String basePath = 'counsellor_applications/${user.uid}';
      
      final profileUrl = await _uploadFile(_profilePhotoFile, '$basePath/profile.jpg');
      final certUrl = await _uploadFile(_certificateFile, '$basePath/certificate.jpg');

      await FirebaseFirestore.instance.collection('counsellor_applications').doc(user.uid).set({
        'uid': user.uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': phone,
        'specializations': _selectedSpecializations,
        'languages': _selectedLanguages,
        'experience': _selectedExperience,
        'price': _isFreeSession ? 'Free' : _priceController.text.trim(),
        'bio': _bioController.text.trim(),
        'profilePhotoUrl': profileUrl,
        'certificateUrl': certUrl,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Application submitted successfully!'),
            backgroundColor: primaryGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submission failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _reactivateAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final appRef = FirebaseFirestore.instance.collection('counsellor_applications').doc(user.uid);

      final batch = FirebaseFirestore.instance.batch();
      batch.set(userRef, {'role': 'counsellor'}, SetOptions(merge: true));
      batch.set(appRef, {'status': 'approved'}, SetOptions(merge: true));

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Account successfully reactivated! Please log in again.'),
            backgroundColor: primaryGreen,
          ),
        );
        
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const SplashTransitionScreen(isLogout: true)),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reactivation failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: _isLoadingStatus
                  ? Center(child: CircularProgressIndicator(color: primaryGreen))
                  : _statusError != null
                      ? _buildErrorPlaceholder()
                      : Column(
                          children: [
                            _buildProgressIndicator(),
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                                child: Form(
                                  key: _formKey,
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: _buildCurrentStepView(),
                                  ),
                                ),
                              ),
                            ),
                            _buildBottomNav(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              if (_activeStep > 0) {
                setState(() => _activeStep--);
              } else {
                Navigator.pop(context);
              }
            },
            icon: Icon(Icons.arrow_back, color: textColorMain),
          ),
          Text(
            'PROFESSIONAL REGISTRATION',
            style: GoogleFonts.outfit(
              color: textColorMain,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          _buildStepDot(0, 'Personal'),
          _buildStepLine(0),
          _buildStepDot(1, 'Professional'),
          _buildStepLine(1),
          _buildStepDot(2, 'Verification'),
        ],
      ),
    );
  }

  Widget _buildStepDot(int step, String label) {
    bool isActive = _activeStep >= step;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isActive ? primaryGreen : Colors.grey[300],
              shape: BoxShape.circle,
              boxShadow: isActive
                  ? [BoxShadow(color: primaryGreen.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                  : null,
            ),
            child: Icon(
              isActive && _activeStep > step ? Icons.check : Icons.circle,
              size: 12,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: _activeStep == step ? FontWeight.bold : FontWeight.normal,
              color: _activeStep == step ? primaryGreen : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepLine(int step) {
    bool isActive = _activeStep > step;
    return Container(
      width: 15,
      height: 2,
      margin: const EdgeInsets.only(bottom: 18),
      color: isActive ? primaryGreen : Colors.grey[300],
    );
  }

  Widget _buildCurrentStepView() {
    switch (_activeStep) {
      case 0: return _buildPersonalStep();
      case 1: return _buildProfessionalStep();
      case 2: return _buildVerificationStep();
      default: return const SizedBox();
    }
  }

  Widget _buildPersonalStep() {
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard('Personal Information', Icons.person_outline, Column(
          children: [
            Center(
              child: GestureDetector(
                onTap: () => _pickFile((file) => _profilePhotoFile = file),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: primaryGreen.withOpacity(0.1),
                  backgroundImage: _profilePhotoFile != null ? FileImage(_profilePhotoFile!) : null,
                  child: _profilePhotoFile == null
                      ? Icon(Icons.camera_alt_outlined, color: primaryGreen, size: 30)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(child: Text('Profile Photo', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600]))),
            const SizedBox(height: 24),
            _buildTextField('Full Name', Icons.badge_outlined, _nameController),
            const SizedBox(height: 16),
            _buildTextField('Email Address', Icons.email_outlined, _emailController),
            const SizedBox(height: 16),
            _buildTextField('Phone Number', Icons.phone_outlined, _phoneController, keyboardType: TextInputType.phone, prefixText: '+60 '),
          ]
        )),
      ],
    );
  }

  Widget _buildProfessionalStep() {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard('Specializations', Icons.psychology_alt, _buildChipGroup(_specializations, _selectedSpecializations), subtext: 'Select all that apply to your professional practice.'),
        _buildSectionCard('Languages Spoken', Icons.language, _buildChipGroup(_languageOptions, _selectedLanguages), subtext: 'Select languages you are proficient in.'),
        _buildSectionCard('Years of Experience', Icons.calendar_today, _buildSingleChoiceChipGroup(_experienceOptions, _selectedExperience, (val) => setState(() => _selectedExperience = val))),
        _buildSectionCard('Session Price', Icons.payments_outlined, Column(
          children: [
            SwitchListTile(
              title: Text('Offer Free Sessions', style: GoogleFonts.outfit(fontSize: 14, color: textColorMain)),
              value: _isFreeSession,
              activeColor: primaryGreen,
              contentPadding: EdgeInsets.zero,
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
              Row(
                children: [
                  Text('RM ', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: primaryGreen)),
                  Expanded(
                    child: _buildTextField('Session price', null, _priceController, keyboardType: TextInputType.number),
                  ),
                  Text(' / hour', style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[500])),
                ],
              ),
          ],
        )),
        _buildSectionCard('Professional Biography', Icons.edit_note, _buildLargeTextField('Share your background and therapeutic approach...', _bioController)),
      ],
    );
  }

  Widget _buildVerificationStep() {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard('Professional Certificate', Icons.verified_user_outlined, _buildFileUploadUI(_certificateFile, (file) => _certificateFile = file, 'Upload Certificate')),
        const SizedBox(height: 8),
        _buildSecurityNotice(),
      ],
    );
  }



  Widget _buildFileUploadUI(File? file, Function(File) onUpdate, String placeholder) {
    return GestureDetector(
      onTap: () => _pickFile(onUpdate),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: file == null ? Colors.grey[300]! : primaryGreen, width: 2),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: primaryGreen.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(file == null ? Icons.upload_file_rounded : Icons.file_copy_rounded, color: primaryGreen, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              file == null ? placeholder : 'Document Selected',
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[700]),
            ),
            if (file != null) ...[
              const SizedBox(height: 8),
              Text(file.path.split('/').last, style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildChipGroup(List<String> options, List<String> selectedList) {
    return Wrap(
      spacing: 8,
      runSpacing: 10,
      children: options.map((item) {
        final isSelected = selectedList.contains(item);
        return FilterChip(
          label: Text(item),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) selectedList.add(item);
              else selectedList.remove(item);
            });
          },
          backgroundColor: Colors.white,
          selectedColor: Colors.white,
          checkmarkColor: primaryGreen,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          labelStyle: GoogleFonts.outfit(
            fontSize: 13,
            color: isSelected ? primaryGreen : Colors.grey[800],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: isSelected ? primaryGreen : Colors.grey[300]!, width: isSelected ? 1.5 : 1),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSingleChoiceChipGroup(List<String> options, String? selectedValue, Function(String) onSelected) {
    return Wrap(
      spacing: 8,
      runSpacing: 10,
      children: options.map((item) {
        final isSelected = item == selectedValue;
        return FilterChip(
          label: Text(item),
          selected: isSelected,
          onSelected: (_) => onSelected(item),
          backgroundColor: Colors.white,
          selectedColor: Colors.white,
          checkmarkColor: primaryGreen,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          labelStyle: GoogleFonts.outfit(
            fontSize: 13,
            color: isSelected ? primaryGreen : Colors.grey[800],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: isSelected ? primaryGreen : Colors.grey[300]!, width: isSelected ? 1.5 : 1),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, Widget child, {String? subtext}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryGreen, size: 20),
              const SizedBox(width: 10),
              Text(title, style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w600, color: primaryGreen)),
            ],
          ),
          const SizedBox(height: 20),
          child,
          if (subtext != null) ...[
            const SizedBox(height: 16),
            Text(subtext, style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[600])),
          ],
        ],
      ),
    );
  }

  Widget _buildSecurityNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryGreen.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: primaryGreen, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'YOUR CREDENTIALS ARE ENCRYPTED AND STRICTLY USED FOR VERIFICATION PURPOSES. WE ADHERE TO HIPAA-COMPLIANT DATA HANDLING STANDARDS.',
              style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: primaryGreen, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeTextField(String hint, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      maxLines: 5,
      style: GoogleFonts.outfit(fontSize: 14),
      validator: (value) => value == null || value.trim().length < 20 ? 'Minimum 20 characters required' : null,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        errorStyle: GoogleFonts.outfit(color: Colors.red[400], fontWeight: FontWeight.w500),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[200]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: primaryGreen, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.red[300]!, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.red[400]!, width: 2)),
        contentPadding: const EdgeInsets.all(20),
      ),
    );
  }

  Widget _buildTextField(String label, IconData? icon, TextEditingController controller, {TextInputType? keyboardType, bool isOptional = false, String? prefixText}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.outfit(fontSize: 14),
      validator: (value) {
        if (!isOptional && (value == null || value.trim().isEmpty)) return 'Required';
        
        if (value != null && value.trim().isNotEmpty) {
          if (keyboardType == TextInputType.number) {
            final number = int.tryParse(value.trim());
            if (number == null || number < 0 || number > 60) return 'Invalid (0-60)';
          }
          if (keyboardType == TextInputType.phone) {
            final phoneRegExp = RegExp(r'^[0-9]{9,10}$');
            if (!phoneRegExp.hasMatch(value.trim())) return 'Invalid format';
          }
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: icon != null ? (isOptional ? '$label (Optional)' : label) : null,
        hintText: icon == null ? (isOptional ? '$label (Optional)' : label) : null,
        labelStyle: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 13),
        hintStyle: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 13),
        prefixText: prefixText,
        prefixStyle: GoogleFonts.outfit(color: textColorMain, fontSize: 14, fontWeight: FontWeight.bold),
        prefixIcon: icon != null ? Icon(icon, color: primaryGreen, size: 18) : null,
        filled: true,
        fillColor: Colors.white,
        errorMaxLines: 2,
        errorStyle: GoogleFonts.outfit(color: Colors.red[400], fontWeight: FontWeight.w500, fontSize: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryGreen, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.red[300]!, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.red[400]!, width: 2)),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : () {
          if (_activeStep < 2) {
            if (_validateStep()) setState(() => _activeStep++);
          } else {
            _submitFinalApplication();
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_activeStep == 2 ? 'Submit Application' : 'Continue', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                  if (_activeStep < 2) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                  ]
                ],
              ),
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    final bool isErrorState = _isRejected || _isDeactivated;
    final bool isApproved = _statusError?.contains('ALREADY APPROVED') ?? false;
    final String title = _isDeactivated ? 'Account Deactivated' : (_isRejected ? 'Application Rejected' : (isApproved ? 'Application Approved' : 'Application Pending'));
    final String description = _isDeactivated 
        ? 'Your counselor profile has been deactivated.\n\n${_statusError ?? ''}'
        : (_isRejected 
            ? 'Your application was unfortunately not approved at this time.\n\nReason: ${_statusError ?? ''}'
            : (_statusError ?? ''));

    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isErrorState ? Colors.red[50] : primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(isErrorState ? Icons.error_outline_rounded : Icons.access_time_rounded, size: 48, color: isErrorState ? Colors.red[400] : primaryGreen),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: textColorMain,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: const Color(0xFF666666),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            if (isErrorState)
              ElevatedButton(
                onPressed: () {
                  if (_isDeactivated) {
                    _reactivateAccount();
                  } else {
                    setState(() {
                      _statusError = null;
                      _isRejected = false;
                      _isDeactivated = false;
                      _activeStep = 0;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  _isDeactivated ? 'Reactivate Again' : 'Reapply Now',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (isErrorState) const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: isErrorState ? Colors.white : primaryGreen,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: isErrorState ? BorderSide(color: Colors.grey[300]!) : BorderSide.none,
                ),
                elevation: 0,
              ),
              child: Text(
                'Return to Profile',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: isErrorState ? textColorMain : Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
