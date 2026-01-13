import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/search_entry.dart';
import '../../providers/word_of_day_provider.dart';
import '../widgets/kamusi_header.dart';
import '../widgets/result_list_tile.dart';
import '../widgets/search_bar.dart';
import '../widgets/word_of_day_card.dart';
import 'lexeme_detail_screen.dart';

class DictionaryHomeScreen extends ConsumerStatefulWidget {
  final List<SearchEntry> recent;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback? onOpenSearch;

  const DictionaryHomeScreen({
    super.key,
    required this.recent,
    required this.onSearchSubmitted,
    this.onOpenSearch,
  });

  @override
  ConsumerState<DictionaryHomeScreen> createState() =>
      _DictionaryHomeScreenState();
}

class _DictionaryHomeScreenState
    extends ConsumerState<DictionaryHomeScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final wordOfDaySection = ref.watch(wordOfDayProvider).when(
          data: (word) => WordOfDayCard(
            title: l10n.homeWordOfDayTitle,
            lemma: word.lemma,
            definition: word.definition,
            onTap: () => _openLexeme(word.lexemeId),
          ),
          loading: () => WordOfDayCard(
            title: l10n.homeWordOfDayTitle,
            isLoading: true,
            message: l10n.homeWordOfDayLoading,
          ),
          error: (_, __) => WordOfDayCard(
            title: l10n.homeWordOfDayTitle,
            message: l10n.homeWordOfDayError,
          ),
        );
    final bodyCard = Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(Icons.history,
                    size: 18, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  l10n.homeRecentHeader,
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          if (widget.recent.isEmpty)
            Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                l10n.homeRecentEmpty,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...widget.recent.map(
              (r) => Column(
                children: [
                  SearchResultTile(
                    item: r,
                    onTap: () => widget.onSearchSubmitted(r.text),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
        ],
      ),
    );

    return Scaffold(
      body: Column(
        children: [
          KamusiHeader(
            title: l10n.headerTitle,
            leading: IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {},
              splashRadius: 22,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.mic_none),
                onPressed: () {},
                splashRadius: 22,
              ),
            ],
            child: KamusiSearchBar(
              hint: l10n.homeSearchHint,
              controller: _controller,
              readOnly: true,
              onTap: widget.onOpenSearch,
              onClear: () {
                _controller.clear();
                setState(() {});
              },
              onSubmitted: (q) {
                if (q.trim().isNotEmpty) widget.onSearchSubmitted(q.trim());
              },
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                wordOfDaySection,
                bodyCard,
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _KamusiBottomNav(
        currentIndex: 1,
        onTap: (_) {},
      ),
    );
  }

  void _openLexeme(String lexemeId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LexemeDetailScreen(lexemeId: lexemeId),
      ),
    );
  }
}

class _KamusiBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _KamusiBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      destinations: [
        NavigationDestination(
            icon: const Icon(Icons.home_outlined), label: l10n.bottomNavHome),
        NavigationDestination(
            icon: const Icon(Icons.search), label: l10n.bottomNavSearch),
        NavigationDestination(
            icon: const Icon(Icons.star_border),
            label: l10n.bottomNavFavorites),
        NavigationDestination(
            icon: const Icon(Icons.history), label: l10n.bottomNavProfile),
      ],
    );
  }
}
