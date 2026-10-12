import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/language_store.dart';
import 'data/game_feedback.dart';
import 'data/game_settings_store.dart';
import 'data/server_store.dart';
import 'l10n/app_localizations.dart';
import 'providers/app_providers.dart';
import 'ui/screens/root_shell.dart';
import 'ui/theme/kamusi_theme.dart';
import 'ui/widgets/offline_banner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Read the language preference before the first frame, so the app never
  // flashes English on its way to Swahili.
  final language = await LanguageStore().load();

  // And the server address, so the first request already goes to the right
  // place rather than failing once against a stale default.
  final storedServer = await ServerStore().load();

  // Sound and haptics, before anything can play. Loading these lazily meant
  // somebody who had turned sound off still heard the first word they found,
  // because nothing had read the setting yet.
  final gameSettings = GameSettingsStore();
  GameFeedback.configure(
    sound: await gameSettings.loadSound(),
    haptics: await gameSettings.loadHaptics(),
  );

  runApp(
    ProviderScope(
      overrides: [
        appLanguageProvider.overrideWith((ref) => language),
        if (storedServer != null)
          apiBaseUrlProvider.overrideWith((ref) => storedServer),
      ],
      child: const KamusiApp(),
    ),
  );
}

class KamusiApp extends ConsumerWidget {
  const KamusiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      // Only consulted when `locale` is null, i.e. "follow the device".
      // Flutter would otherwise fall back to the first supported locale, which
      // the generator orders alphabetically — making English the default for
      // every language we do not ship. On a Swahili-first dictionary the
      // fallback should be Swahili.
      localeResolutionCallback: (deviceLocale, supported) {
        if (deviceLocale != null) {
          for (final candidate in supported) {
            if (candidate.languageCode == deviceLocale.languageCode) {
              return candidate;
            }
          }
        }
        return const Locale('sw');
      },
      theme: buildKamusiTheme(brightness: Brightness.light),
      darkTheme: buildKamusiTheme(brightness: Brightness.dark),
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      // Wrapping here rather than per screen means pushed routes are covered
      // too, and there is one place that decides how offline is presented.
      builder: (context, child) =>
          OfflineBanner(child: child ?? const SizedBox.shrink()),
      home: const RootShell(),
    );
  }
}
