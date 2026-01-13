import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kamusi_mobile/ui/screens/dictionary_home_screen.dart';
import 'package:kamusi_mobile/ui/screens/search_screen_new.dart';

import 'domain/models/search_entry.dart';
import 'ui/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: KamusiApp()));
}

class KamusiApp extends StatelessWidget {
  const KamusiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kamusi',
      theme: buildAppTheme(),
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
