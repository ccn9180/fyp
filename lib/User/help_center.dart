import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'change_password.dart';
import 'language_settings.dart';
import 'xp_journey.dart';
import 'counsellor.dart';
import 'chatbot_screen.dart';

class HelpCenterScreen extends StatefulWidget {
  final bool isCounsellor;
  const HelpCenterScreen({super.key, this.isCounsellor = false});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int? _expandedIndex;

  static const Color _primary = Color(0xFF7C9C84);
  static const Color _bg = Color(0xFFF2F1EC);
  static const Color _textMain = Color(0xFF333333);
  static const Color _textSub = Color(0xFF7A8C85);

  final List<Map<String, String>> _userFaqs = [
    {
      'q': 'How do I book a counselling session?',
      'a':
          'Navigate to the Counsellors tab, browse available professionals, and tap on one to view their profile. From there, select an available time slot and confirm your booking. You\'ll receive a notification once confirmed.',
    },
    {
      'q': 'Is my personal data kept private?',
      'a':
          'Yes. All your diary entries, session notes, and personal information are encrypted and stored securely. We never share or sell your data to third parties. Only you can access your private content.',
    },
    {
      'q': 'How do I change my password?',
      'a':
          'Go to Settings → Account & Security → Change Password. Enter your current password and then your new password twice to confirm the change.',
    },
    {
      'q': 'What is Zen Progress / XP?',
      'a':
          'Zen Progress is our gamified mindfulness tracker. You earn XP (experience points) by completing meditations, reading wellness articles, writing diary entries, and attending counselling sessions. XP can be redeemed in the Reward Store.',
    },
    {
      'q': 'Can I cancel or reschedule a session?',
      'a':
          'Yes. Go to your upcoming session detail from the Home screen and tap "Reschedule" or "Cancel". Cancellations made at least 24 hours before the session are fully refunded.',
    },
    {
      'q': 'How do I delete my account?',
      'a':
          'Go to Settings → Account & Security → Delete Account. You will be asked to confirm your password. This action is irreversible and will permanently remove all your data.',
    },
    {
      'q': 'What languages does the app support?',
      'a':
          'Eunoia currently supports English, Bahasa Melayu, and Simplified Chinese. You can change your language in Settings → Language.',
    },
    {
      'q': 'How do I enable biometric login?',
      'a':
          'Go to Settings → Account & Security and toggle on Face Unlock or Fingerprint Unlock. You will be asked to verify your account password once to activate this feature.',
    },
  ];

  final List<Map<String, String>> _counsellorFaqs = [
    {
      'q': 'How do I manage my schedule?',
      'a':
          'Go to Profile → Practice Tools → Schedule Management. You can set your working hours, add specific breaks, and manage upcoming availability slots. Patients will only see times you have explicitly marked as available.',
    },
    {
      'q': 'How do I get paid for my sessions?',
      'a':
          'Earnings from completed sessions are accumulated in your Wallet. Payouts are processed bi-weekly to your registered bank account. You can view your earning history under the Payment Dashboard.',
    },
    {
      'q': 'Can I decline a booking request?',
      'a':
          'Yes, if you have a schedule conflict, you can decline or suggest a reschedule from the Session Management tab. Please try to give clients at least 24 hours notice to maintain a high professional rating.',
    },
    {
      'q': 'Is patient information secure?',
      'a':
          'Yes. Patient notes and shared files are fully encrypted. You must not download or share patient information outside the platform in accordance with the HIPAA and our Data Privacy Addendum.',
    },
    {
      'q': 'How do I deactivate my professional profile?',
      'a':
          'If you need to take an extended leave or retire, go to Profile → Account & Status → Retire / Deactivate Profile. Your current patients will be notified and your profile will be hidden from the directory.',
    },
  ];

  List<Map<String, String>> get _activeFaqs => widget.isCounsellor ? _counsellorFaqs : _userFaqs;

  List<Map<String, String>> get _filteredFaqs {
    if (_searchQuery.isEmpty) return _activeFaqs;
    return _activeFaqs
        .where((f) =>
            f['q']!.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            f['a']!.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmAndLaunch({
    required String title,
    required String url,
    required String confirmMessage,
  }) async {
    final shouldLaunch = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Text(
          title,
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF324F43),
          ),
        ),
        content: Text(
          confirmMessage,
          style: GoogleFonts.outfit(color: const Color(0xFF7A8C85), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Proceed',
              style: GoogleFonts.outfit(color: _primary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (shouldLaunch == true) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch $url')),
          );
        }
      }
    }
  }

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
          'Help Center',
          style: GoogleFonts.playfairDisplay(
            color: _textMain,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatbotScreen(isCounsellor: widget.isCounsellor),
            ),
          );
        },
        backgroundColor: const Color(0xFF7C9C84),
        child: const Icon(Icons.support_agent_rounded, color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C9C84), Color(0xFF5A7A62)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C9C84).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.support_agent_rounded, color: Colors.white70, size: 36),
                  const SizedBox(height: 12),
                  Text(
                    'How can we help\nyou today?',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Browse our FAQ or get in touch with support.',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Search bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() {
                  _searchQuery = val;
                  _expandedIndex = null;
                }),
                style: GoogleFonts.outfit(color: _textMain, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search questions...',
                  hintStyle: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Quick links
            if (_searchQuery.isEmpty) ...[
              _sectionLabel('Quick Links'),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (!widget.isCounsellor) ...[
                    _quickLinkCard(
                      icon: Icons.calendar_today_outlined,
                      label: 'Book a\nSession',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CounsellorScreen()),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  _quickLinkCard(
                    icon: Icons.lock_reset_rounded,
                    label: 'Change\nPassword',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (!widget.isCounsellor) ...[
                    _quickLinkCard(
                      icon: Icons.star_outline_rounded,
                      label: 'Zen\nProgress',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const XPJourneyScreen()),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  _quickLinkCard(
                    icon: Icons.translate_rounded,
                    label: 'Language\nSettings',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LanguageSettingsScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],

            // FAQ
            _sectionLabel('Frequently Asked Questions'),
            const SizedBox(height: 14),
            if (_filteredFaqs.isEmpty)
              _emptyState()
            else
              ...List.generate(_filteredFaqs.length, (i) {
                final faq = _filteredFaqs[i];
                final isExpanded = _expandedIndex == i;
                return _faqCard(faq['q']!, faq['a']!, i, isExpanded);
              }),

            const SizedBox(height: 32),

            // Contact support
            _sectionLabel('Contact Support'),
            const SizedBox(height: 14),
            _contactCard(
              icon: Icons.email_outlined,
              title: 'Email Support',
              subtitle: 'Eunoia@gmail.com',
              onTap: () => _confirmAndLaunch(
                title: 'Email Support',
                url: 'mailto:Eunoia@gmail.com',
                confirmMessage: 'Do you want to compose an email to Eunoia@gmail.com?',
              ),
            ),
            const SizedBox(height: 12),
            _contactCard(
              icon: Icons.phone_outlined,
              title: 'Hotline',
              subtitle: '6012-5834355',
              onTap: () => _confirmAndLaunch(
                title: 'Call Hotline',
                url: 'tel:60125834355',
                confirmMessage: 'Do you want to call 6012-5834355?',
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: Colors.grey[500],
      ),
    );
  }

  Widget _quickLinkCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C9C84).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _primary, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _textMain,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _faqCard(String question, String answer, int index, bool isExpanded) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isExpanded
            ? Border.all(color: const Color(0xFF7C9C84).withValues(alpha: 0.3), width: 1.5)
            : Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _expandedIndex = isExpanded ? null : index),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isExpanded
                            ? const Color(0xFF7C9C84).withValues(alpha: 0.15)
                            : const Color(0xFFF5F7F6),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        'Q',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isExpanded ? _primary : Colors.grey[500],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        question,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _textMain,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: isExpanded ? _primary : Colors.grey[400],
                        size: 22,
                      ),
                    ),
                  ],
                ),
                if (isExpanded) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    height: 1,
                    color: const Color(0xFFEEEEEA),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    answer,
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      color: _textSub,
                      height: 1.6,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _contactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    String? badge,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: _textMain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'No results found',
              style: GoogleFonts.playfairDisplay(
                fontSize: 16,
                color: Colors.grey[500],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different keyword',
              style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}
