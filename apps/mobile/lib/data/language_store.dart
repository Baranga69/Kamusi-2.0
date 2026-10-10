import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which language the interface is in.
///
/// Separate from the device setting on purpose. Phones across East Africa are
/// routinely set to English for compatibility by people who would rather read
/// Swahili, so following the system alone would quietly make a Swahili-first
/// dictionary an English one (KAMUSI_STATE.md §1: "Not English-first").
enum AppLanguage {
  /// Kiswahili. The default, and what the app is for.
  swahili,

  /// English, for readers who prefer it.
  english,

  /// Whatever the phone is set to, falling back to Swahili.
  system;

  Locale? get locale => switch (this) {
        AppLanguage.swahili => const Locale('sw'),
        AppLanguage.english => const Locale('en'),
        AppLanguage.system => null,
      };

  static AppLanguage fromName(String? name) {
    return AppLanguage.values.firstWhere(
      (value) => value.name == name,
      orElse: () => AppLanguage.swahili,
    );
  }
}

class LanguageStore {
  static const _key = 'kamusi_app_language';

  Future<AppLanguage> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppLanguage.fromName(prefs.getString(_key));
  }

  Future<void> save(AppLanguage language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, language.name);
  }
}
