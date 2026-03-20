import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'change_password.dart';
import 'language_settings.dart';
import 'help_center.dart';
import 'terms_of_service.dart';
import 'privacy_policy.dart';
import '../app_localizations.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Mock settings state
  bool _pushNotifications = true;
  bool _emailAlerts = false;
  bool _offlineMode = false;
  bool _dailyReminder = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAE9E4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: const Color(0xFF333333),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)?.translate('settings') ?? 'Settings',
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFF333333),
            fontWeight: FontWeight.w600,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          _buildSectionHeader('Preferences'),
          _buildSettingsCard(
            children: [
              _buildSwitchTile(
                icon: Icons.notifications_active_outlined,
                title: 'Push Notifications',
                subtitle: 'Daily quotes and reminders',
                value: _pushNotifications,
                onChanged: (val) => setState(() => _pushNotifications = val),
              ),
              const Divider(height: 1, indent: 60),
              _buildSwitchTile(
                icon: Icons.email_outlined,
                title: 'Email Newsletter',
                subtitle: 'Weekly mindfulness tips',
                value: _emailAlerts,
                onChanged: (val) => setState(() => _emailAlerts = val),
              ),
              const Divider(height: 1, indent: 60),
              _buildSwitchTile(
                icon: Icons.cloud_off_outlined,
                title: 'Offline Mode',
                subtitle: 'Download sessions automatically',
                value: _offlineMode,
                onChanged: (val) => setState(() => _offlineMode = val),
              ),
              const Divider(height: 1, indent: 60),
              _buildSwitchTile(
                icon: Icons.access_time_outlined,
                title: 'Daily Reminder',
                subtitle: 'Evening reflection prompt',
                value: _dailyReminder,
                onChanged: (val) => setState(() => _dailyReminder = val),
              ),
            ],
          ),

          const SizedBox(height: 32),

          _buildSectionHeader('Account & Security'),
          _buildSettingsCard(
            children: [
              _buildNavigationTile(
                icon: Icons.lock_outline,
                title: 'Change Password',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
                  );
                },
              ),
              const Divider(height: 1, indent: 60),
              _buildNavigationTile(
                icon: Icons.language_outlined,
                title: AppLocalizations.of(context)?.translate('language') ?? 'Language',
                subtitle: MyApp.localeNotifier.value.languageCode == 'zh'
                    ? '简体中文'
                    : MyApp.localeNotifier.value.languageCode == 'ms'
                    ? 'Bahasa Melayu'
                    : 'English (US)',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LanguageSettingsScreen()),
                  );
                },
              ),
              const Divider(height: 1, indent: 60),
              _buildNavigationTile(
                icon: Icons.delete_outline,
                title: 'Delete Account',
                iconColor: Colors.redAccent,
                titleColor: Colors.redAccent,
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 32),

          _buildSectionHeader('Support & Legal'),
          _buildSettingsCard(
            children: [
              _buildNavigationTile(
                icon: Icons.help_outline,
                title: 'Help Center',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HelpCenterScreen()),
                  );
                },
              ),
              const Divider(height: 1, indent: 60),
              _buildNavigationTile(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TermsOfServiceScreen()),
                  );
                },
              ),
              const Divider(height: 1, indent: 60),
              _buildNavigationTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 48),

          Center(
            child: Text(
              'App Version 1.0.0',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: const Color(0xFFA3A3A3),
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: const Color(0xFFB0B0B0),
        ),
      ),
    );
  }

  Widget _buildSettingsCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF7C9C84), size: 22),
      ),
      title: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF333333),
        ),
      ),
      subtitle: subtitle != null ? Text(
        subtitle,
        style: GoogleFonts.outfit(
          fontSize: 12,
          color: Colors.grey[500],
        ),
      ) : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.white,
        activeTrackColor: const Color(0xFF7C9C84),
        inactiveThumbColor: Colors.white,
        inactiveTrackColor: const Color(0xFFEBEBE6),
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color iconColor = const Color(0xFF7C9C84),
    Color titleColor = const Color(0xFF333333),
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor == const Color(0xFF7C9C84) ? const Color(0xFFF5F7F6) : iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: titleColor,
        ),
      ),
      subtitle: subtitle != null ? Text(
        subtitle,
        style: GoogleFonts.outfit(
          fontSize: 12,
          color: Colors.grey[500],
        ),
      ) : null,
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
      onTap: onTap,
    );
  }
}
