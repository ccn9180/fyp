import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../User/main_screen.dart';
import 'login.dart';

class UserDetailsPage extends StatefulWidget {
  final String email;
  final String password;

  const UserDetailsPage({
    super.key,
    required this.email,
    required this.password,
  });

  @override
  State<UserDetailsPage> createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends State<UserDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  
  final _fullNameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  
  String _selectedGender = 'Female'; // Default selection
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _dobCtrl.dispose();
    _phoneCtrl.dispose();
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

  Future<void> _completeRegistration() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dobCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select your Date of Birth')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Get current user (already created in VerificationPage)
      User? user = FirebaseAuth.instance.currentUser;
      
      if (user == null) throw Exception("User session lost. Please try again.");

      // 2. Refresh user to check if they verified their email in the meantime
      await user.reload();
      user = FirebaseAuth.instance.currentUser;

      // 3. Save ALL User Data to Firestore
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'uid': user.uid,
        'email': widget.email,
        'fullName': _fullNameCtrl.text.trim(),
        'dateOfBirth': _dobCtrl.text.trim(),
        'phoneNumber': _phoneCtrl.text.trim(),
        'gender': _selectedGender,
        'createdAt': FieldValue.serverTimestamp(),
        'isVerified': user.emailVerified, 
      });

      // Update Display Name
      await user.updateDisplayName(_fullNameCtrl.text.trim());

      if (mounted) {
        if (!user.emailVerified) {
          // If not verified yet, remind them and go back to login instead of Home
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Details saved! Please check your email to verify before logging in."),
              backgroundColor: Colors.orangeAccent,
              duration: Duration(seconds: 5),
            ),
          );
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Registration Complete! Welcome."),
              backgroundColor: Color(0xFF7B9E89),
            ),
          );

          // Navigate to Home
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MainScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                                      // Cleanup: Delete the account if they cancel mid-flow
                                      // This ensures no "ghost" auth records exist without Firestore profiles.
                                      await FirebaseAuth.instance.currentUser?.delete();
                                    } catch (e) {
                                      await FirebaseAuth.instance.signOut();
                                    }
                                    if (mounted) Navigator.pop(context);
                                  },
                                ),
                              ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildProgressStep(true),
                        const SizedBox(width: 8),
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
                      onTap: () {
                        // AI Scan Mockup
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("AI Scan feature coming soon!")));
                      },
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
                  validator: (val) => val!.isEmpty ? 'Name is required' : null,
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

                // Phone Number
                _buildLabel('PHONE NUMBER'),
                _buildTextField(
                  controller: _phoneCtrl,
                  hintText: '+1 (555) 000-0000',
                  keyboardType: TextInputType.phone,
                  validator: (val) => val!.isEmpty ? 'Phone is required' : null,
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
                    onPressed: _isLoading ? null : _completeRegistration,
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
