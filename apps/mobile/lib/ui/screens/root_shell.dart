import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'dictionary_home_screen.dart';
import 'favorites_screen.dart';
import 'learn_home_screen.dart';
import 'search_screen_new.dart';

/// Holds the app's surfaces side by side.
///
/// The split is the point: the dictionary stays calm and reading-first, and
/// Jifunze is a separate place you step into, where the app is allowed to be
/// playful. A bottom bar rather than a drawer so the learn surface is visible
/// rather than hidden behind a menu — a game nobody can find teaches nobody.
///
/// `IndexedStack` keeps each surface alive, so switching tabs does not discard
/// a half-finished scroll position or re-fetch the day's round.
class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  int _index = 0;

  void _openSearch(BuildContext context, {String initialQuery = ''}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SearchScreen(initialQuery: initialQuery)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          DictionaryHomeScreen(
            onOpenSearch: () => _openSearch(context),
            onSearchSubmitted: (query) => _openSearch(context, initialQuery: query),
          ),
          const LearnHomeScreen(),
          FavoritesScreen(onOpenSearch: () => _openSearch(context)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book),
            label: l10n.navDictionary,
          ),
          NavigationDestination(
            icon: const Icon(Icons.school_outlined),
            selectedIcon: const Icon(Icons.school),
            label: l10n.navLearn,
          ),
          NavigationDestination(
            icon: const Icon(Icons.star_outline),
            selectedIcon: const Icon(Icons.star),
            label: l10n.navFavorites,
          ),
        ],
      ),
    );
  }
}
