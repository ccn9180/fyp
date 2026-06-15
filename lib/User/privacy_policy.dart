import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  final bool isCounsellor;
  const PrivacyPolicyScreen({super.key, this.isCounsellor = false});

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
          isCounsellor ? 'Counsellor Privacy' : 'Privacy Policy',
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
                  colors: [Color(0xFF5A7A62), Color(0xFF3D5C45)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5A7A62).withValues(alpha: 0.3),
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
                    child: const Icon(Icons.privacy_tip_outlined, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCounsellor ? 'Counsellor Privacy Policy' : 'Privacy Policy',
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

            // Commitment badge row
            Row(
              children: [
                _commitmentBadge(Icons.lock_outline_rounded, 'Encrypted'),
                const SizedBox(width: 10),
                _commitmentBadge(Icons.block_rounded, 'Never Sold'),
                const SizedBox(width: 10),
                _commitmentBadge(Icons.visibility_off_outlined, 'Private'),
              ],
            ),

            const SizedBox(height: 20),

            // Intro
            _introCard(
              'Your privacy is fundamental to everything we do at Eunoia. This policy explains what data we collect, how we use it, and the rights you have over your information.',
            ),

            const SizedBox(height: 20),
            
            if (isCounsellor) ...[
              _buildSection(
                number: '01',
                title: 'Professional Data & Visibility',
                icon: Icons.account_box_outlined,
                content: 'As a verified professional on Eunoia, certain elements of your profile—such as your name, profile picture, specializations, professional credentials, and scheduled availability—will be publicly visible to users of the app to facilitate bookings.\n\nHowever, your private banking details, personal contact information, and internal communication with our support team remain strictly confidential and are only accessed by authorized Eunoia personnel for administrative purposes.',
              ),
              _buildSection(
                number: '02',
                title: 'Client Confidentiality',
                icon: Icons.lock_person_outlined,
                content: 'You must maintain the absolute privacy of your clients. You are prohibited from sharing, exporting, or discussing patient data, session notes, or identifying information outside of the Eunoia platform, except where required by law (e.g., risk of self-harm or harm to others).',
              ),
            ] else ...[
              _buildSection(
                number: '01',
                title: 'Data We Collect',
                icon: Icons.data_usage_rounded,
                content: 'When you use Eunoia, we collect the following types of information:\n\n• Account Data: Name, email, and password.\n• Profile Data: Mood entries, journal logs, and self-help interactions.\n• Usage Data: Session durations, app interactions, and device information.',
              ),
              _buildSection(
                number: '02',
                title: 'How We Protect Your Data',
                icon: Icons.security_rounded,
                content: 'Your privacy and the security of your data are our highest priorities. We employ industry-standard security measures including:\n\n• End-to-end encryption for all diary entries and session chats.\n• Secure, cloud-based data storage on Firebase.\n• Strict access controls that ensure only you can access your personal journal data.',
              ),
            ],

            _buildSection(
              number: '01',
              title: 'Information We Collect',
              icon: Icons.storage_outlined,
              content:
                  'We collect only the minimum data necessary to provide you with a personalised wellness experience. This includes:\n\n'
                  '• Account information (name, email address)\n'
                  '• Profile details you choose to provide\n'
                  '• Diary entries and mood check-ins\n'
                  '• Session booking history and feedback\n'
                  '• Wellness progress and XP activity\n'
                  '• App usage analytics (anonymised)',
            ),
            _buildSection(
              number: '02',
              title: 'How We Use Your Data',
              icon: Icons.tune_rounded,
              content:
                  'The data we collect is used solely to improve your Eunoia experience:\n\n'
                  '• Personalising your wellness journey and content recommendations\n'
                  '• Tracking your meditation and mindfulness progress\n'
                  '• Matching you with suitable counsellors\n'
                  '• Sending reminders and motivational notifications\n'
                  '• Improving app performance and features\n\n'
                  'We do not use your data for advertising, and we never sell your information to third parties.',
            ),
            _buildSection(
              number: '03',
              title: 'Data Security',
              icon: Icons.shield_outlined,
              content:
                  'We take the security of your personal data seriously. All data is protected using industry-standard encryption both in transit (TLS) and at rest. Your diary entries and session notes are private and can only be accessed by you.\n\n'
                  'We conduct regular security audits and follow best practices to protect against unauthorised access, disclosure, alteration, or destruction of your data.',
            ),
            _buildSection(
              number: '04',
              title: 'Data Sharing',
              icon: Icons.share_outlined,
              content:
                  'We do not sell, trade, or rent your personal information to third parties. Data is only shared in the following limited circumstances:\n\n'
                  '• With counsellors you have booked a session with (session notes and context only)\n'
                  '• With trusted service providers who assist in operating the app (under strict confidentiality agreements)\n'
                  '• When required by law or to protect the safety of our users',
            ),
            _buildSection(
              number: '05',
              title: 'Cookies & Analytics',
              icon: Icons.bar_chart_rounded,
              content:
                  'We use anonymised analytics to understand how users interact with Eunoia so we can improve the experience. This data cannot be used to identify you personally. We use Firebase Analytics, which complies with international data protection regulations.',
            ),
            _buildSection(
              number: '06',
              title: 'Your Rights',
              icon: Icons.verified_user_outlined,
              content:
                  'You have full control over your personal data:\n\n'
                  '• Access: Request a copy of all personal data we hold about you\n'
                  '• Correction: Update or correct your information at any time in your profile\n'
                  '• Deletion: Delete your account and all associated data via Settings → Delete Account\n'
                  '• Portability: Request your data in a portable format\n'
                  '• Withdrawal: Withdraw consent for data processing at any time',
            ),
            _buildSection(
              number: '07',
              title: 'Children\'s Privacy',
              icon: Icons.child_care_outlined,
              content:
                  'Eunoia is not intended for use by individuals under the age of 13. We do not knowingly collect personal information from children. If we become aware that a child under 13 has provided us with personal data, we will delete it immediately.',
            ),
            _buildSection(
              number: '08',
              title: 'Changes to This Policy',
              icon: Icons.update_rounded,
              content:
                  'We may update this Privacy Policy periodically to reflect changes in our practices or legal requirements. We will notify you of any material changes through an in-app notification or email. Your continued use of Eunoia after such changes constitutes acceptance of the updated policy.',
            ),

            const SizedBox(height: 24),

            _contactNote(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _commitmentBadge(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: _primary, size: 20),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _textMain,
              ),
            ),
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
            'Questions about your Privacy?',
            style: GoogleFonts.playfairDisplay(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textMain,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'If you have any questions or wish to exercise your data rights, please contact our Privacy team at privacy@eunoia.com.',
            style: GoogleFonts.outfit(fontSize: 13, color: _textSub, height: 1.6),
          ),
        ],
      ),
    );
  }
}
