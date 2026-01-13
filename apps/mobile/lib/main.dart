import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:kamusi_mobile/ui/screens/dictionary_home_screen.dart';
import 'package:kamusi_mobile/ui/screens/search_screen_new.dart';

import 'domain/models/search_entry.dart';
import 'ui/theme/kamusi_theme.dart';

void main() {
  runApp(const ProviderScope(child: KamusiApp()));
}

class KamusiApp extends StatelessWidget {
  const KamusiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildKamusiTheme(),
      home: Builder(
        builder: (context) => DictionaryHomeScreen(
          recent: const <SearchEntry>[],
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
