import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'user_details_page.dart';
import 'email_verification_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _isLoading = false;
  bool _passwordVisible = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _processRegistrationStep1() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match"), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check if email already exists in Firestore
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: _emailCtrl.text.trim())
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        if (mounted) _showAccountExistsDialog();
        return;
      }

      // Proceed to Step 2 (Email Verification)
      if (mounted) {
        // 1. Create the Firebase user
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text.trim(),
        );

        // 2. Send verification email
        await userCredential.user?.sendEmailVerification();

        // 3. Navigate to EmailVerificationPage
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EmailVerificationPage(
                email: _emailCtrl.text.trim(),
                password: _passwordCtrl.text.trim(),
              ),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        if (mounted) _showAccountExistsDialog();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Registration Error: ${e.message}"), backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Check if user already exists in Firestore
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: googleUser.email)
          .limit(1)
          .get();

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign into Firebase
      await FirebaseAuth.instance.signInWithCredential(credential);

      if (mounted) {
        if (userQuery.docs.isNotEmpty) {
          // Account exists in Firestore, prevent registration sign-in
          await FirebaseAuth.instance.signOut();
          await GoogleSignIn().signOut();
          
          if (mounted) _showAccountExistsDialog();
          return;
        } else {
          // New user, go to UserDetailsPage first to complete "scan"
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => UserDetailsPage(
                email: googleUser.email,
                password: "", // No password needed for Google users
                isGoogle: true,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Google Sign-In failed: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAccountExistsDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Circle
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4F1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline, 
                  color: Color(0xFF7B9E89), 
                  size: 42
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              Text(
                'Account Already Exists',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF324F43),
                ),
              ),
              const SizedBox(height: 16),
              
              // Description
              Text(
                'It looks like you already have an account with us. Please sign in to continue your journey.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  color: const Color(0xFF7A8C85),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              
              // Sign In Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Go back to LoginPage
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B9E89),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Sign In',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // Try another email
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Try another email',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: const Color(0xFF7A8C85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
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
                const SizedBox(height: 27),
                // Top Progress Bar (Back Button removed for Step 1)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildProgressStep(true),
                        const SizedBox(width: 8),
                        _buildProgressStep(false),
                        const SizedBox(width: 8),
                        _buildProgressStep(false),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // Header
                Text(
                  'Begin your journey',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF324F43),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Start with create your account',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    color: const Color(0xFF7A8C85),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),


                // Email Address
                _buildLabel('EMAIL ADDRESS'),
                _buildTextField(
                  controller: _emailCtrl,
                  hintText: 'name@example.com',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Email is required';
                    if (!val.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Password
                _buildLabel('PASSWORD'),
                _buildTextField(
                  controller: _passwordCtrl,
                  hintText: '••••••••',
                  icon: Icons.lock_outline,
                  obscureText: !_passwordVisible,
                  suffixIcon: IconButton(
                    icon: Icon(_passwordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                    onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Password is required';
                    if (val.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                
                const SizedBox(height: 20),

                _buildLabel('CONFIRM PASSWORD'),
                _buildTextField(
                  controller: _confirmPasswordCtrl,
                  hintText: '••••••••',
                  icon: Icons.lock_outline,
                  obscureText: !_passwordVisible,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Confirm your password';
                    return null;
                  },
                ),

                const SizedBox(height: 40),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _processRegistrationStep1,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7B9E89),
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
                                'Register',
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

                // OR Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[200])),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'or',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey[200])),
                  ],
                ),

                const SizedBox(height: 24),

                // Google Sign In
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.grey[100]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                      shadowColor: Colors.black.withOpacity(0.05),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          'assets/Group.svg',
                          width: 24,
                          height: 24,
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            'Sign up with Google',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF324F43),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Footer
                Text(
                  'By continuing, you acknowledge our Privacy Policy\nand Terms.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.grey[400],
                    height: 1.5,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Back to Login
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                     "Already have an account? Log In",
                     style: GoogleFonts.outfit(color: const Color(0xFF7B9E89), fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressStep(bool isActive) {
    return Container(
      width: 60,
      height: 2,
      color: isActive ? const Color(0xFF7B9E89) : Colors.grey[300],
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
    required String hintText,
    IconData? icon,
    bool obscureText = false,
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
        obscureText: obscureText,
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
          prefixIcon: icon != null ? Icon(icon, color: Colors.grey[400], size: 20) : null,
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
