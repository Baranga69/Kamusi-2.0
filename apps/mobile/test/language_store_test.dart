import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamusi_mobile/data/language_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to Swahili, not the device language', () async {
    // KAMUSI_STATE.md §1 lists "Not English-first" as a non-goal, so an
    // unconfigured install reads Swahili.
    expect(await LanguageStore().load(), AppLanguage.swahili);
  });

  test('remembers a choice', () async {
    final store = LanguageStore();
    await store.save(AppLanguage.english);
    expect(await store.load(), AppLanguage.english);

    await store.save(AppLanguage.system);
    expect(await store.load(), AppLanguage.system);
  });

  test('survives a restart', () async {
    await LanguageStore().save(AppLanguage.english);
    expect(await LanguageStore().load(), AppLanguage.english);
  });

  test('falls back to Swahili on an unreadable value', () async {
    SharedPreferences.setMockInitialValues({'kamusi_app_language': 'klingon'});
    expect(await LanguageStore().load(), AppLanguage.swahili);
  });

  test('maps to the right locale', () {
    expect(AppLanguage.swahili.locale, const Locale('sw'));
    expect(AppLanguage.english.locale, const Locale('en'));
    // Null hands resolution to the device, which the app then falls back to
    // Swahili for rather than to English.
    expect(AppLanguage.system.locale, isNull);
  });
}
