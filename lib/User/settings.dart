import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'change_password.dart';
import 'language_settings.dart';
import 'help_center.dart';
import 'terms_of_service.dart';
import 'privacy_policy.dart';
import '../app_localizations.dart';
import '../main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  bool _isFaceIdEnabled = false;
  bool _isFingerprintEnabled = false;
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isFaceIdEnabled = prefs.getBool('face_id_enabled') ?? false;
      _isFingerprintEnabled = prefs.getBool('fingerprint_enabled') ?? false;
    });
  }

  Future<void> _showPasswordConfirmationDialog(String type) async {
    final passwordCtrl = TextEditingController();
    bool isVerifying = false;
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: Colors.white,
              title: Text(
                'Confirm Password',
                style: GoogleFonts.playfairDisplay(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF324F43),
                ),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Please enter your account password to enable biometric login.',
                      style: GoogleFonts.outfit(color: const Color(0xFF7A8C85), fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passwordCtrl,
                      obscureText: true,
                      validator: (val) => val == null || val.isEmpty ? 'Password is required' : null,
                      style: GoogleFonts.outfit(color: const Color(0xFF333333)),
                      decoration: InputDecoration(
                        hintText: 'Enter password',
                        hintStyle: GoogleFonts.outfit(color: Colors.grey[400]),
                        filled: true,
                        fillColor: const Color(0xFFF5F7F6),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: isVerifying ? null : () async {
                    if (!formKey.currentState!.validate()) return;
                    setStateDialog(() => isVerifying = true);
                    
                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null && user.email != null) {
                        // Reauthenticate to verify password
                        final AuthCredential credential = EmailAuthProvider.credential(
                          email: user.email!,
                          password: passwordCtrl.text.trim(),
                        );
                        await user.reauthenticateWithCredential(credential);
                        
                        // If reauthentication succeeds, trigger biometric auth
                        final didAuth = await _localAuth.authenticate(
                          localizedReason: 'Verify your identity to enable ${type == 'face_id' ? 'Face ID' : 'Fingerprint'}',
                          options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
                        );

                        if (didAuth) {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('${type}_enabled', true);
                          await prefs.setString('biometric_email', user.email!);
                          await prefs.setString('biometric_password', passwordCtrl.text.trim());
                          
                          if (mounted) {
                            Navigator.pop(context);
                            _loadSettings();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${type == 'face_id' ? 'Face ID' : 'Fingerprint'} enabled successfully!'),
                                backgroundColor: const Color(0xFF7B9E89),
                              ),
                            );
                          }
                        } else {
                          setStateDialog(() => isVerifying = false);
                        }
                      } else {
                        throw Exception('User is not logged in.');
                      }
                    } catch (e) {
                      setStateDialog(() => isVerifying = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Verification failed. Please check your password.'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  },
                  child: isVerifying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7B9E89)),
                        )
                      : Text(
                          'Confirm',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF7B9E89),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _toggleBiometrics(bool value, String type) async {
    if (value) {
      try {
        final available = await _localAuth.getAvailableBiometrics();
        final bool isSupported = type == 'face_id' 
            ? available.contains(BiometricType.face) || available.contains(BiometricType.strong)
            : available.contains(BiometricType.fingerprint);

        if (!isSupported && type == 'face_id') {
           final canCheck = await _localAuth.canCheckBiometrics;
           if (!canCheck) {
             _showError('Your device does not support biometric authentication.');
             return;
           }
        }

        await _showPasswordConfirmationDialog(type);
      } catch (e) {
        _showError('Error enabling biometrics: $e');
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('${type}_enabled', false);
      final bool faceId = prefs.getBool('face_id_enabled') ?? false;
      final bool fingerprint = prefs.getBool('fingerprint_enabled') ?? false;
      if (!faceId && !fingerprint) {
        await prefs.remove('biometric_email');
        await prefs.remove('biometric_password');
      }
      _loadSettings();
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.orangeAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EC),
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
              _buildSwitchTile(
                icon: Icons.face_retouching_natural,
                title: 'Face Unlock',
                subtitle: 'Enable face recognition login',
                value: _isFaceIdEnabled,
                onChanged: (val) => _toggleBiometrics(val, 'face_id'),
              ),
              const Divider(height: 1, indent: 60),
              _buildSwitchTile(
                icon: Icons.fingerprint_rounded,
                title: 'Fingerprint Unlock',
                subtitle: 'Enable fingerprint sensor login',
                value: _isFingerprintEnabled,
                onChanged: (val) => _toggleBiometrics(val, 'fingerprint'),
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
