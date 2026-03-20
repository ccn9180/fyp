import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../app_localizations.dart';

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  late String _selectedLanguage;

  final List<Map<String, String>> _languages = [
    {'code': 'en', 'nameKey': 'english', 'native': 'English'},
    {'code': 'zh', 'nameKey': 'chinese', 'native': '简体中文'},
    {'code': 'ms', 'nameKey': 'malay', 'native': 'Bahasa Melayu'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedLanguage = MyApp.localeNotifier.value.languageCode;
  }

  Future<void> _updateLanguage(String languageCode) async {
    setState(() {
      _selectedLanguage = languageCode;
    });
    MyApp.localeNotifier.value = Locale(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', languageCode);
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
          AppLocalizations.of(context)?.translate('language') ?? 'Language',
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFF333333),
            fontWeight: FontWeight.w600,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)?.translate('app_language') ?? 'App Language',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)?.translate('choose_language') ?? 'Choose the language you want to interact with throughout the app.',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: const Color(0xFF7A8C85),
              ),
            ),
            const SizedBox(height: 32),
            Container(
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
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _languages.length,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 60),
                itemBuilder: (context, index) {
                  final lang = _languages[index];
                  final isSelected = _selectedLanguage == lang['code'];

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF7C9C84).withOpacity(0.1) : const Color(0xFFF5F7F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.language_rounded,
                        color: isSelected ? const Color(0xFF7C9C84) : const Color(0xFFB0B0B0),
                        size: 22,
                      ),
                    ),
                    title: Text(
                      AppLocalizations.of(context)?.translate(lang['nameKey']!) ?? lang['native']!,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    subtitle: Text(
                      lang['native']!,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: isSelected ? const Color(0xFF7C9C84) : Colors.grey[500],
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFF7C9C84), size: 24)
                        : const SizedBox(width: 24),
                    onTap: () async {
                      await _updateLanguage(lang['code']!);

                      if (!mounted) return;

                      final updatedMessage = AppLocalizations.of(context)?.translate('language_updated') ?? 'Language updated to';
                      final translatedLangName = AppLocalizations.of(context)?.translate(lang['nameKey']!) ?? lang['native']!;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("$updatedMessage $translatedLangName"),
                          backgroundColor: const Color(0xFF7C9C84),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
