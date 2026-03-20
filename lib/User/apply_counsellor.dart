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
  final Color backgroundColor = const Color(0xFFEAE9E4);
  final Color textColorMain = const Color(0xFF333333);

  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _isLoadingStatus = true;
  String? _statusError;

  final List<String> _selectedSpecializations = [];
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

  @override
  void initState() {
    super.initState();
    _checkEligibility();
  }

  Future<void> _checkEligibility() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _statusError = "Please log in to apply.";
        _isLoadingStatus = false;
      });
      return;
    }

    try {
      // 1. Check if already a counsellor
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists && (userDoc.data()?['role'] == 'counsellor')) {
        setState(() {
          _statusError = "You are already registered as an active counsellor.";
          _isLoadingStatus = false;
        });
        return;
      }

      // 2. Check if has pending application
      final appDoc = await FirebaseFirestore.instance.collection('counsellor_applications').doc(user.uid).get();
      if (appDoc.exists) {
        final status = appDoc.data()?['status'];
        if (status == 'pending') {
          setState(() {
            _statusError = "You already have a pending application. Please wait for our review.";
            _isLoadingStatus = false;
          });
          return;
        } else if (status == 'approved') {
          // Synchronize role if app was approved but user role wasn't updated (fail-safe)
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'role': 'counsellor'});
          setState(() {
            _statusError = "You are already registered as a counsellor.";
            _isLoadingStatus = false;
          });
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
      setState(() {
        _certificateFile = File(image.path);
      });
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Become a Counselor',
          style: GoogleFonts.playfairDisplay(
            color: textColorMain,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoadingStatus
          ? Center(child: CircularProgressIndicator(color: primaryGreen))
          : _statusError != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline_rounded, size: 64, color: primaryGreen.withOpacity(0.5)),
              const SizedBox(height: 20),
              Text(
                _statusError!,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: textColorMain,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: primaryGreen),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text('Back Home', style: GoogleFonts.outfit(color: primaryGreen)),
                ),
              ),
            ],
          ),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Join our community of professionals and help others find their peace.',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              _buildSectionTitle('Professional Details'),
              const SizedBox(height: 16),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _specializations.map((spec) {
                  final isSelected = _selectedSpecializations.contains(spec);
                  return FilterChip(
                    label: Text(spec),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedSpecializations.add(spec);
                        } else {
                          _selectedSpecializations.remove(spec);
                        }
                      });
                    },
                    selectedColor: primaryGreen.withOpacity(0.2),
                    checkmarkColor: primaryGreen,
                    labelStyle: GoogleFonts.outfit(
                      fontSize: 13,
                      color: isSelected ? primaryGreen : textColorMain,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? primaryGreen : Colors.transparent,
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (_selectedSpecializations.isEmpty && _isSubmitting)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 12),
                  child: Text(
                    'Please select at least one specialization',
                    style: GoogleFonts.outfit(color: Colors.red[700], fontSize: 12),
                  ),
                ),

              const SizedBox(height: 16),
              _buildTextField(
                'Years of Experience',
                Icons.history_edu_outlined,
                _experienceController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Experience is required';
                  final yrs = int.tryParse(value);
                  if (yrs == null) return 'Enter a valid number';
                  if (yrs < 1) return 'Min 1 year required';
                  if (yrs > 50) return 'Please enter a realistic number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                'License Number',
                Icons.badge_outlined,
                _licenseController,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'License number is required';
                  if (value.length < 5) return 'Should be at least 5 characters';
                  return null;
                },
              ),

              const SizedBox(height: 32),

              _buildSectionTitle('Certification'),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _pickCertificate,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: (_certificateFile == null && _isSubmitting)
                              ? Colors.red[300]!
                              : (_certificateFile == null ? Colors.grey[300]! : primaryGreen),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _certificateFile == null ? Icons.upload_file_outlined : Icons.check_circle_outline_rounded,
                            color: (_certificateFile == null && _isSubmitting)
                                ? Colors.red[400]
                                : (_certificateFile == null ? Colors.grey[400] : primaryGreen),
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _certificateFile == null
                                ? 'Upload your professional certificate'
                                : 'Certificate Uploaded: ${_certificateFile!.path.split('/').last}',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: (_certificateFile == null && _isSubmitting)
                                  ? Colors.red[400]
                                  : (_certificateFile == null ? Colors.grey[500] : primaryGreen),
                              fontWeight: _certificateFile == null ? FontWeight.normal : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_certificateFile == null && _isSubmitting)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 12),
                      child: Text(
                        'Certification is required',
                        style: GoogleFonts.outfit(color: Colors.red[700], fontSize: 12),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 32),

              _buildSectionTitle('Why do you want to join us?'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _motivationController,
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please share your motivation';
                  if (value.length < 50) return 'Please be more detailed (min 50 chars)';
                  return null;
                },
                decoration: InputDecoration(
                  hintText: 'Tell us about your approach and motivation...',
                  hintStyle: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 14),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.red, width: 1),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.red, width: 1),
                  ),
                  contentPadding: const EdgeInsets.all(20),
                ),
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : () async {
                    if (_formKey.currentState!.validate() &&
                        _selectedSpecializations.isNotEmpty &&
                        _certificateFile != null) {

                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please login to apply.')),
                        );
                        return;
                      }

                      setState(() => _isSubmitting = true);

                      try {
                        // 1. Upload Certificate to Storage
                        final storageRef = FirebaseStorage.instance
                            .ref()
                            .child('counsellor_applications/certificates/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');

                        final uploadTask = await storageRef.putFile(_certificateFile!);
                        final certificateUrl = await uploadTask.ref.getDownloadURL();

                        // 2. Save Application to Firestore
                        await FirebaseFirestore.instance.collection('counsellor_applications').doc(user.uid).set({
                          'uid': user.uid,
                          'name': user.displayName ?? 'Anonymous User',
                          'email': user.email,
                          'specializations': _selectedSpecializations,
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
                              content: Text('Application submitted successfully! Our team will review it.'),
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
                    } else {
                      // Trigger rebuild to show manual validation errors for Chips and File upload
                      setState(() {});
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                    'Submit Application',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: primaryGreen,
      ),
    );
  }

  Widget _buildTextField(
      String label,
      IconData icon,
      TextEditingController controller, {
        TextInputType? keyboardType,
        String? Function(String?)? validator,
      }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 14),
        prefixIcon: Icon(icon, color: primaryGreen, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }
}

