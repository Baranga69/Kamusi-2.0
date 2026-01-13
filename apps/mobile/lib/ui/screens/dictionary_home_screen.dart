import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../domain/models/search_entry.dart';
import '../widgets/kamusi_header.dart';
import '../widgets/result_list_tile.dart';
import '../widgets/search_bar.dart';

class DictionaryHomeScreen extends StatefulWidget {
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
  State<DictionaryHomeScreen> createState() => _DictionaryHomeScreenState();
}

class _DictionaryHomeScreenState extends State<DictionaryHomeScreen> {
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
            child: GestureDetector(
              onTap: widget.onOpenSearch,
              child: KamusiSearchBar(
                hint: l10n.homeSearchHint,
                controller: _controller,
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
          ),
          Expanded(child: ListView(children: [bodyCard])),
        ],
      ),
      bottomNavigationBar: _KamusiBottomNav(
        currentIndex: 1,
        onTap: (_) {},
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
