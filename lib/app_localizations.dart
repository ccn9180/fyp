import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  late Map<String, String> _localizedStrings;

  Future<bool> load() async {
    Map<String, Map<String, String>> staticTranslations = {
      'en': {
        'language': 'Language',
        'app_language': 'App Language',
        'choose_language': 'Choose the language you want to interact with throughout the app.',
        'language_updated': 'Language updated to',
        'settings': 'Settings',
        'english': 'English (US)',
        'chinese': 'Chinese (Simplified)',
        'malay': 'Malay',
        'peaceful_morning': 'Peaceful morning',
        'ready_calm': 'Ready for a moment of calm?',
        'diary': 'Diary',
        'add_entry': 'Add Entry',
        'my_diary': 'My Diary',
        'no_entries': 'No diary entries yet.',
        'no_entries_sub': 'Start reflecting and release your thoughts.',
        'save': 'Save',
        'cancel': 'Cancel',
        'confirm_save': 'Confirm & Save',
        'edit_entry': 'Edit Entry',
        'ai_insights': 'AI Insights',
        'entry_summary': 'Entry Summary',
        'sharing_access': 'Sharing Access',
        'new_entry': 'New Entry',
        'drafts': 'DRAFTS',
        'save_entry': 'Save Entry',
        'how_are_you_feeling': 'How are you feeling?',
        'saving': 'Saving...',
        'done_save': 'Done & Save',
        'draft_saved': 'Draft saved successfully',
        'no_drafts': 'No drafts found',
        'no_drafts_sub': 'Your unfinished reflections will appear here.',
        'save_as_draft': 'Save as Draft',
      },
      'zh': {
        'language': '语言',
        'app_language': '应用语言',
        'choose_language': '选择您希望在整个应用中进行交互的语言。',
        'language_updated': '语言已更新至',
        'settings': '设置',
        'english': '英语 (US)',
        'chinese': '简体中文',
        'malay': '马来语',
        'peaceful_morning': '安详的早晨',
        'ready_calm': '准备好享受片刻宁静了吗？',
        'diary': '日记',
        'add_entry': '添加条目',
        'my_diary': '我的日记',
        'no_entries': '尚无日记条目。',
        'no_entries_sub': '开始反思，释放你的想法。',
        'save': '保存',
        'cancel': '取消',
        'confirm_save': '确认并保存',
        'edit_entry': '编辑条目',
        'ai_insights': 'AI 洞察',
        'entry_summary': '条目摘要',
        'sharing_access': '共享权限',
        'new_entry': '新条目',
        'drafts': '草稿',
        'save_entry': '保存条目',
        'how_are_you_feeling': '你感觉如何？',
        'saving': '正在保存...',
        'done_save': '完成并保存',
        'draft_saved': '草稿已成功保存',
        'no_drafts': '未发现草稿',
        'no_drafts_sub': '您未完成的反思将出现在这里。',
        'save_as_draft': '存为草稿',
      },
      'ms': {
        'language': 'Bahasa',
        'app_language': 'Bahasa Aplikasi',
        'choose_language': 'Pilih bahasa yang anda mahu berinteraksi di seluruh aplikasi.',
        'language_updated': 'Bahasa dikemas kini kepada',
        'settings': 'Tetapan',
        'english': 'Inggeris (US)',
        'chinese': 'Cina (Ringkas)',
        'malay': 'Melayu',
        'peaceful_morning': 'Pagi yang tenang',
        'ready_calm': 'Sedia untuk ketenangan seketika?',
        'diary': 'Diari',
        'add_entry': 'Tambah Entri',
        'my_diary': 'Diari Saya',
        'no_entries': 'Tiada entri diari lagi.',
        'no_entries_sub': 'Mula merenung dan lepaskan fikiran anda.',
        'save': 'Simpan',
        'cancel': 'Batal',
        'confirm_save': 'Sahkan & Simpan',
        'edit_entry': 'Edit Entri',
        'ai_insights': 'Wawasan AI',
        'entry_summary': 'Ringkasan Entri',
        'sharing_access': 'Akses Perkongsian',
        'new_entry': 'Entri Baru',
        'drafts': 'DRAF',
        'save_entry': 'Simpan Entri',
        'how_are_you_feeling': 'Bagaimana perasaan anda?',
        'saving': 'Menyimpan...',
        'done_save': 'Siap & Simpan',
        'draft_saved': 'Draf berjaya disimpan',
        'no_drafts': 'Tiada draf dijumpai',
        'no_drafts_sub': 'Renungan anda yang belum selesai akan muncul di sini.',
        'save_as_draft': 'Simpan sebagai Draf',
      }
    };

    _localizedStrings = staticTranslations[locale.languageCode] ?? staticTranslations['en']!;
    return true;
  }

  String translate(String key) {
    return _localizedStrings[key] ?? key;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'zh', 'ms'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
