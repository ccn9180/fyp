import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'verification_page.dart';

class EmailVerificationPage extends StatefulWidget {
  final String email;
  final String password;

  const EmailVerificationPage({
    super.key,
    required this.email,
    required this.password,
  });

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  bool _isVerified = false;
  bool _isResending = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Start checking for email verification status every 3 seconds
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkEmailVerified();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkEmailVerified() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();
      if (user.emailVerified) {
        _timer?.cancel();
        setState(() {
          _isVerified = true;
        });
      }
    }
  }

  Future<void> _resendEmail() async {
    setState(() => _isResending = true);
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email resent! Please check your inbox.'), 
            backgroundColor: Color(0xFF7B9E89)
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Failed to send email. Please try again later.';
      
      if (e.code == 'too-many-requests') {
        errorMessage = 'Too many requests. Please wait a moment before trying again.';
      } else if (e.message != null) {
        errorMessage = e.message!;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage), 
            backgroundColor: Colors.orangeAccent
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred. Please try again.'), 
            backgroundColor: Colors.redAccent
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _proceedToFaceScan() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => VerificationPage(
          email: widget.email,
          password: widget.password,
          isGoogle: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F1EB),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isVerified ? Icons.mark_email_read_outlined : Icons.mark_email_unread_outlined,
                  size: 64,
                  color: const Color(0xFF7B9E89),
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                _isVerified ? 'Email Verified' : 'Check Your Email',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF324F43),
                ),
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                _isVerified
                    ? 'Great! Your email has been verified. You can now proceed to the face scan verification.'
                    : 'We have sent a verification email to:\n${widget.email}\n\nPlease click the link in the email to verify your account.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: const Color(0xFF7A8C85),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),

              // Action Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isVerified ? _proceedToFaceScan : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B9E89),
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _isVerified ? 'Continue to Face Scan' : 'Waiting for verification...',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Resend Option
              if (!_isVerified)
                TextButton(
                  onPressed: _isResending ? null : _resendEmail,
                  child: Text(
                    _isResending ? 'Sending...' : 'Didn\'t receive an email? Resend',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF7B9E89),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              
              // Back Button
              TextButton(
                onPressed: () async {
                  try {
                    // Option B Cleanup: Delete the account if they cancel mid-flow
                    await FirebaseAuth.instance.currentUser?.delete();
                  } catch (e) {
                    // Fallback to sign out if delete fails
                    await FirebaseAuth.instance.signOut();
                  }
                  if (mounted) Navigator.pop(context);
                },
                child: Text(
                  'Cancel Registration',
                  style: GoogleFonts.outfit(
                    color: Colors.red[300],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
