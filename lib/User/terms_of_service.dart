import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TermsOfServiceScreen extends StatelessWidget {
  final bool isCounsellor;
  const TermsOfServiceScreen({super.key, this.isCounsellor = false});

  static const Color _primary = Color(0xFF7C9C84);
  static const Color _bg = Color(0xFFF2F1EC);
  static const Color _textMain = Color(0xFF333333);
  static const Color _textSub = Color(0xFF7A8C85);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: _textMain),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isCounsellor ? 'Counsellor Terms' : 'Terms of Service',
          style: GoogleFonts.playfairDisplay(
            color: _textMain,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C9C84), Color(0xFF5A7A62)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C9C84).withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.description_outlined, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCounsellor ? 'Counsellor Terms of Service' : 'Terms of Service',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Last updated: June 2025',
                          style: GoogleFonts.outfit(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Intro
            _introCard(
              'Please read these Terms of Service carefully before using Eunoia. By accessing or using our application, you agree to be bound by these terms.',
            ),

            const SizedBox(height: 20),

            _buildSection(
              number: '01',
              title: 'Acceptance of Terms',
              icon: Icons.handshake_outlined,
              content:
                  'By downloading, installing, or using Eunoia, you acknowledge that you have read, understood, and agree to be bound by these Terms of Service and our Privacy Policy. If you do not agree with any part of these terms, you must discontinue use of the application immediately.',
            ),
            _buildSection(
              number: '02',
              title: 'User Conduct',
              icon: Icons.person_outline_rounded,
              content:
                  'You are solely responsible for all content you create within Eunoia, including diary entries and community posts. You agree not to post content that is illegal, harmful, threatening, abusive, harassing, defamatory, or otherwise objectionable. We reserve the right to remove any content that violates these guidelines.',
            ),
            _buildSection(
              number: '03',
              title: 'Content Ownership',
              icon: Icons.copyright_rounded,
              content:
                  'You retain full ownership of all content you create within Eunoia. By using our service, you grant Eunoia a limited, non-exclusive, royalty-free license to store and process your content solely for the purpose of providing the service to you. We will never use your personal content for advertising or share it with third parties.',
            ),
            _buildSection(
              number: '04',
              title: 'Mental Health Disclaimer',
              icon: Icons.favorite_border_rounded,
              content:
                  'Eunoia is a mindfulness and wellness support tool, not a substitute for professional mental health diagnosis or treatment. The content, counsellors, and resources within the app are intended for general wellness purposes only. For urgent mental health concerns, please contact a qualified healthcare professional or emergency services.',
            ),
            _buildSection(
              number: '05',
              title: 'Account Responsibility',
              icon: Icons.shield_outlined,
              content:
                  'You are responsible for maintaining the confidentiality of your account credentials. You must notify us immediately of any unauthorized access or breach of security. Eunoia will not be liable for any loss or damage arising from your failure to comply with this responsibility.',
            ),
            _buildSection(
              number: '06',
              title: 'Termination',
              icon: Icons.block_outlined,
              content:
                  'We reserve the right to suspend or terminate your account at any time without notice if we believe you have violated these Terms of Service. You may also delete your account at any time through Settings → Account & Security → Delete Account.',
            ),
            _buildSection(
              number: '07',
              title: 'Changes to Terms',
              icon: Icons.update_rounded,
              content:
                  'We may update these Terms of Service from time to time. We will notify you of significant changes via in-app notification or email. Continued use of Eunoia after changes are posted constitutes your acceptance of the revised terms.',
            ),
            
            const SizedBox(height: 16),
            
            if (isCounsellor) ...[
              _buildSection(
                number: '01',
                title: 'Professional Obligations',
                icon: Icons.work_outline_rounded,
                content: 'As a counsellor on Eunoia, you agree to maintain appropriate professional licensure, act in the best interests of your clients, and adhere to the ethical standards of your respective professional associations. You must provide accurate representations of your qualifications, experience, and services.\n\nYou agree to promptly respond to appointment requests, honor confirmed bookings, and maintain professionalism during all consultations. Eunoia reserves the right to suspend or terminate your account if we receive multiple user complaints or if you violate our code of conduct.',
              ),
              _buildSection(
                number: '02',
                title: 'Payments & Fees',
                icon: Icons.payments_outlined,
                content: 'Eunoia charges a service fee for each completed consultation to cover platform maintenance, payment processing, and customer support. The remaining balance will be credited to your Eunoia Wallet. Payouts are processed on a bi-weekly basis to your designated bank account.',
              ),
            ] else ...[
              _buildSection(
                number: '01',
                title: 'Acceptable Use',
                icon: Icons.shield_outlined,
                content: 'You agree not to use the Service for any unlawful purpose or in any way that interrupts, damages, or impairs the service. You must not attempt to gain unauthorized access to our systems or other users\' accounts.\n\n• Do not post abusive, defamatory, or hateful content.\n• Do not impersonate any person or entity.\n• Do not use the service for commercial purposes without our consent.',
              ),
              _buildSection(
                number: '02',
                title: 'Medical Disclaimer',
                icon: Icons.local_hospital_outlined,
                content: 'Eunoia provides tools for mindfulness, mood tracking, and connections to professional counsellors. However, the app itself does not provide medical advice, diagnosis, or treatment.\n\nIf you are experiencing a medical emergency or severe mental health crisis, please call your local emergency services or a crisis hotline immediately. Reliance on any information provided by Eunoia is solely at your own risk.',
              ),
            ],

            _contactNote(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _introCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: _primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(fontSize: 13, color: _textSub, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String number,
    required String title,
    required IconData icon,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    number,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(icon, color: _primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _textMain,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              height: 1,
              color: const Color(0xFFF0F0EB),
            ),
            const SizedBox(height: 14),
            Text(
              content,
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                color: _textSub,
                height: 1.65,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Questions about our Terms?',
            style: GoogleFonts.playfairDisplay(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textMain,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'If you have any questions or concerns regarding these Terms of Service, please contact us at legal@eunoia.com.',
            style: GoogleFonts.outfit(fontSize: 13, color: _textSub, height: 1.6),
          ),
        ],
      ),
    );
  }
}
