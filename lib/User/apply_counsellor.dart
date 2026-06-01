import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ApplyCounsellorScreen extends StatefulWidget {
  const ApplyCounsellorScreen({super.key});

  @override
  State<ApplyCounsellorScreen> createState() => _ApplyCounsellorScreenState();
}

class _ApplyCounsellorScreenState extends State<ApplyCounsellorScreen> {
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFF2F1EC);
  final Color textColorMain = const Color(0xFF333333);

  final _formKey = GlobalKey<FormState>();
  int _activeStep = 0;
  bool _isSubmitting = false;
  bool _isLoadingStatus = true;
  String? _statusError;

  final List<String> _selectedSpecializations = [];
  final List<String> _selectedLanguages = [];
  File? _certificateFile;
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _licenseController = TextEditingController();
  final TextEditingController _motivationController = TextEditingController();

  final List<String> _specializations = [
    'Cognitive Behavioral Therapy (CBT)',
    'Mindfulness & Meditation',
    'Grief & Trauma Counseling',
    'Stress & Anxiety Management',
    'Relationship & Family Therapy',
    'Life Coaching',
  ];

  final List<String> _languages = [
    'English',
    'Malay',
    'Mandarin',
    'Tamil',
    'Cantonese',
    'Hokkien',
  ];

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

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists && (userDoc.data()?['role'] == 'counsellor')) {
        if (mounted) {
          setState(() {
            _statusError = "You are already registered as an active counsellor.";
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
              _statusError = "You already have a pending application. Please wait for our review.";
              _isLoadingStatus = false;
            });
          }
          return;
        } else if (status == 'approved') {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'role': 'counsellor'});
          if (mounted) {
            setState(() {
              _statusError = "You are already registered as a counsellor.";
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
    _experienceController.dispose();
    _licenseController.dispose();
    _motivationController.dispose();
    super.dispose();
  }

  Future<void> _pickCertificate() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _certificateFile = File(image.path));
    }
  }

  bool _validateStep() {
    if (_activeStep == 0) {
      if (_selectedSpecializations.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one specialization')),
        );
        return false;
      }
      if (_selectedLanguages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one language preference')),
        );
        return false;
      }
      if (_experienceController.text.isEmpty || _licenseController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all professional details')),
        );
        return false;
      }
    } else if (_activeStep == 1) {
      if (_certificateFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload your professional certificate')),
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _submitFinalApplication() async {
    if (!_formKey.currentState!.validate()) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_motivationController.text.length < 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a more detailed motivation (min 50 chars)')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('counsellor_applications/certificates/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      final uploadTask = await storageRef.putFile(_certificateFile!);
      final certificateUrl = await uploadTask.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('counsellor_applications').doc(user.uid).set({
        'uid': user.uid,
        'name': user.displayName ?? 'Anonymous User',
        'email': user.email,
        'specializations': _selectedSpecializations,
        'languages': _selectedLanguages,
        'experience': _experienceController.text.trim(),
        'licenseNumber': _licenseController.text.trim(),
        'certificateUrl': certificateUrl,
        'motivation': _motivationController.text.trim(),
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application submitted successfully!'),
            backgroundColor: Color(0xFF7C9C84),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: _isLoadingStatus
          ? Center(child: CircularProgressIndicator(color: primaryGreen))
          : _statusError != null
          ? _buildErrorPlaceholder()
          : SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            _buildProgressIndicator(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
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
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: Color(0xFF333333)),
          ),
          Text(
            'Application Form',
            style: GoogleFonts.outfit(
              color: textColorMain,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          _buildStepDot(0, 'Credentials'),
          _buildStepLine(0),
          _buildStepDot(1, 'Verification'),
          _buildStepLine(1),
          _buildStepDot(2, 'Motivation'),
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
      width: 30,
      height: 2,
      margin: const EdgeInsets.only(bottom: 18),
      color: isActive ? primaryGreen : Colors.grey[300],
    );
  }

  Widget _buildCurrentStepView() {
    switch (_activeStep) {
      case 0:
        return _buildCredentialsStep();
      case 1:
        return _buildVerificationStep();
      case 2:
        return _buildMotivationStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildCredentialsStep() {
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader('Clinical Specializations', 'Select your main areas of expertise.'),
        const SizedBox(height: 16),
        _buildChipGroup(_specializations, _selectedSpecializations),
        const SizedBox(height: 32),
        _buildStepHeader('Language Preferences', 'What languages can you conduct sessions in?'),
        const SizedBox(height: 16),
        _buildChipGroup(_languages, _selectedLanguages),
        const SizedBox(height: 32),
        _buildStepHeader('Work Experience', 'Your professional background.'),
        const SizedBox(height: 16),
        _buildTextField('Years of Practice', Icons.history_edu, _experienceController, keyboardType: TextInputType.number),
        const SizedBox(height: 16),
        _buildTextField('Clinical License / ID', Icons.badge_outlined, _licenseController),
      ],
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
          selectedColor: primaryGreen.withOpacity(0.1),
          checkmarkColor: primaryGreen,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          labelStyle: GoogleFonts.outfit(
            fontSize: 13,
            color: isSelected ? primaryGreen : textColorMain,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isSelected ? primaryGreen : Colors.grey[200]!),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVerificationStep() {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader('Document Verification', 'Upload proof of your clinical qualifications.'),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _pickCertificate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _certificateFile == null ? Colors.grey[200]! : primaryGreen.withOpacity(0.5), width: 2),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: primaryGreen.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(_certificateFile == null ? Icons.cloud_upload_outlined : Icons.file_copy_rounded, color: primaryGreen, size: 32),
                ),
                const SizedBox(height: 16),
                Text(
                  _certificateFile == null ? 'Click to upload Certificate' : 'Certificate Selected',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: textColorMain),
                ),
                if (_certificateFile != null) ...[
                  const SizedBox(height: 8),
                  Text(_certificateFile!.path.split('/').last, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMotivationStep() {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader('Personal Statement', 'Tell our medical board about your vision and clinical approach.'),
        const SizedBox(height: 20),
        TextFormField(
          controller: _motivationController,
          maxLines: 8,
          style: GoogleFonts.outfit(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Share your journey as a therapist...',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(24),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: Colors.grey[400]),
            const SizedBox(width: 8),
            Text('Minimum 50 characters required for clinical review.', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
      ],
    );
  }

  Widget _buildStepHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: textColorMain)),
        const SizedBox(height: 4),
        Text(subtitle, style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          if (_activeStep > 0) ...[
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: () => setState(() => _activeStep--),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text('Previous', style: GoogleFonts.outfit(color: textColorMain, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            flex: 2,
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(_activeStep == 2 ? 'Submit Application' : 'Continue', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: primaryGreen.withOpacity(0.1), width: 10)),
              child: Icon(Icons.medical_services_outlined, size: 48, color: primaryGreen),
            ),
            const SizedBox(height: 32),
            Text(_statusError!, textAlign: TextAlign.center, style: GoogleFonts.playfairDisplay(fontSize: 20, color: textColorMain, fontWeight: FontWeight.bold)),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: primaryGreen),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text('Back to Home', style: GoogleFonts.outfit(color: primaryGreen, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon, TextEditingController controller, {TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.outfit(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 13),
        prefixIcon: Icon(icon, color: primaryGreen, size: 18),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[100]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[100]!)),
        contentPadding: const EdgeInsets.all(18),
      ),
    );
  }
}

