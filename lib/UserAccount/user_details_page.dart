import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'login.dart';
import 'verification_page.dart';
import 'id_scanner_page.dart';

class UserDetailsPage extends StatefulWidget {
  final String email;
  final String password;
  final bool isGoogle;

  const UserDetailsPage({
    super.key,
    required this.email,
    required this.password,
    this.isGoogle = false,
  });

  @override
  State<UserDetailsPage> createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends State<UserDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  
  final _fullNameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _icNumberCtrl = TextEditingController();
  
  String _selectedGender = 'Female'; // Default selection
  bool _isLoading = false;
  String? _capturedIcImagePath; // Captured IC image for face verification

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _dobCtrl.dispose();
    _icNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)), // Default to 18 years ago
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: const Color(0xFF7B9E89),
            colorScheme: const ColorScheme.light(primary: Color(0xFF7B9E89)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dobCtrl.text = "${picked.month}/${picked.day}/${picked.year}";
      });
    }
  }

  Future<void> _scanIDWithAI() async {
    final ScannedIdResult? result = await Navigator.push<ScannedIdResult>(
      context,
      MaterialPageRoute(builder: (context) => const IDScannerPage()),
    );

    if (result == null) return;

    setState(() {
      if (result.fullName != null) _fullNameCtrl.text = result.fullName!;
      if (result.dob != null) _dobCtrl.text = result.dob!;
      if (result.gender != null) _selectedGender = result.gender!;
      if (result.icNumber != null) _icNumberCtrl.text = result.icNumber!;
      if (result.capturedImagePath != null) _capturedIcImagePath = result.capturedImagePath;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("ID scanned and details filled successfully!"),
        backgroundColor: Color(0xFF7B9E89),
      ),
    );
  }

  void _goToVerification() {
    if (!_formKey.currentState!.validate()) return;
    if (_dobCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select your Date of Birth')));
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VerificationPage(
          email: widget.email,
          password: widget.password,
          isGoogle: widget.isGoogle,
          fullName: _fullNameCtrl.text.trim(),
          dob: _dobCtrl.text.trim(),
          icNumber: _icNumberCtrl.text.trim(),
          gender: _selectedGender,
          icImagePath: _capturedIcImagePath,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF7),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 4),
                // Progress Bar (Step 3) with Back Button
                Stack(
                  alignment: Alignment.center,
                  children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: IconButton(
                                  icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF1E2742)),
                                  onPressed: () async {
                                    try {
                                      await FirebaseAuth.instance.currentUser?.delete();
                                      await GoogleSignIn().signOut();
                                    } catch (e) {
                                      await FirebaseAuth.instance.signOut();
                                      await GoogleSignIn().signOut();
                                    }
                                    if (mounted) {
                                      Navigator.of(context).pushAndRemoveUntil(
                                        MaterialPageRoute(builder: (context) => const LoginPage()),
                                        (route) => false,
                                      );
                                    }
                                  },
                                ),
                              ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildProgressStep(true),
                        const SizedBox(width: 8),
                        _buildProgressStep(true), // Active
                        const SizedBox(width: 8),
                        _buildProgressStep(false),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 17),

                Text(
                  'Personal Info',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF324F43),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Personalize your experience. Use AI to\nscan your details or enter them\nmanually.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                      fontSize: 15, color: const Color(0xFF7A8C85), height: 1.5),
                ),
                const SizedBox(height: 32),

                // Scan ID with AI Button
                Container(
                  width: double.infinity,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isLoading ? null : _scanIDWithAI,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F1EB),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.document_scanner, color: Color(0xFF7B9E89), size: 24),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Scan ID with AI',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1E2742),
                                  ),
                                ),
                                Text(
                                  'Extract info automatically',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // OR divider
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[300])),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR REVIEW DETAILS',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey[300])),
                  ],
                ),
                
                const SizedBox(height: 32),

                // Full Name
                _buildLabel('FULL NAME'),
                _buildTextField(
                  controller: _fullNameCtrl,
                  hintText: 'E.g. Julianne Smith',
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Name is required';
                    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(val)) return 'Name can only contain alphabets';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Date of Birth
                _buildLabel('DATE OF BIRTH'),
                GestureDetector(
                  onTap: _selectDate,
                  child: AbsorbPointer(
                    child: _buildTextField(
                      controller: _dobCtrl,
                      hintText: 'mm/dd/yyyy',
                      suffixIcon: const Icon(Icons.calendar_today_outlined, color: Color(0xFF7B9E89), size: 20),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ID Number
                _buildLabel('ID NUMBER'),
                _buildTextField(
                  controller: _icNumberCtrl,
                  hintText: 'E.g. 990123-14-5555',
                  keyboardType: TextInputType.text,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'ID number is required';
                    if (!RegExp(r'^\d{6}-\d{2}-\d{4}$').hasMatch(val)) return 'Format must be XXXXXX-XX-XXXX';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Gender
                _buildLabel('GENDER'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildGenderChip('Female'),
                    const SizedBox(width: 12),
                    _buildGenderChip('Male'),
                    const SizedBox(width: 12),
                    _buildGenderChip('Non-binary'),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _buildGenderChip('Other'),
                ),

                const SizedBox(height: 40),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _goToVerification,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7B9E89), // Sage Green
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Continue',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.white),
                            ],
                          ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                 Text(
                  'Your data is encrypted and handled with care.\nReview our Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.grey[400],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenderChip(String label) {
    bool isSelected = _selectedGender == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGender = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F1EB) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? const Color(0xFF7B9E89) : Colors.transparent,
            width: 1,
          ),
          boxShadow: [
            if (!isSelected)
            BoxShadow(
              color: Colors.black.withOpacity(0.01),
              blurRadius: 5,
              offset: const Offset(0, 2),
            )
          ]
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? const Color(0xFF4A6356) : const Color(0xFF777777),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressStep(bool isActive) {
    return Container(
      width: 60,
      height: 2,
      decoration: BoxDecoration(
         color: isActive ? const Color(0xFF7B9E89) : Colors.grey[200],
         borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          text,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: const Color(0xFF7A8C85),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    String? hintText,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: GoogleFonts.outfit(
          fontSize: 16,
          color: const Color(0xFF1E2742),
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.outfit(
            color: Colors.grey[300],
          ),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }
}
