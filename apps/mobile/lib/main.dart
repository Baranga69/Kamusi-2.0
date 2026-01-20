import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'providers/app_providers.dart';
import 'ui/screens/dictionary_home_screen.dart';
import 'ui/screens/search_screen_new.dart';
import 'ui/theme/kamusi_theme.dart';

void main() {
  runApp(const ProviderScope(child: KamusiApp()));
}

class KamusiApp extends ConsumerWidget {
  const KamusiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildKamusiTheme(brightness: Brightness.light),
      darkTheme: buildKamusiTheme(brightness: Brightness.dark),
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      home: Builder(
        builder: (context) => DictionaryHomeScreen(
          onOpenSearch: () => _openSearch(context),
          onSearchSubmitted: (q) => _openSearch(context, initialQuery: q),
        ),
      ),
    );
  }

  void _openSearch(BuildContext context, {String initialQuery = ''}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchScreen(initialQuery: initialQuery),
      ),
    );
  }
}
