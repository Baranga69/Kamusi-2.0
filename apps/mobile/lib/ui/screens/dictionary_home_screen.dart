import 'package:flutter/material.dart';

import '../../domain/models/search_entry.dart';
import '../theme/app_theme.dart';
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
    final bodyCard = Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: const [
                Icon(Icons.history, size: 18, color: KamusiColors.textMuted),
                SizedBox(width: 8),
                Text(
                  "Something Something",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: KamusiColors.textMuted,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          if (widget.recent.isEmpty)
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                "Swahili lexicon.",
                style: TextStyle(color: KamusiColors.textMuted),
              ),
            )
          else
            ...widget.recent.map(
              (r) => Column(
                children: [
                  ResultListTile(
                    item: r,
                    onTap: () => widget.onSearchSubmitted(r.text),
                  ),
                  const Divider(height: 1),
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
            title: "KAMUSI",
            leading: IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () {},
              splashRadius: 22,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.mic_none, color: Colors.white),
                onPressed: () {},
                splashRadius: 22,
              ),
            ],
            child: GestureDetector(
              onTap: widget.onOpenSearch,
              child: RoundedSearchBar(
                hint: "Tafuta neno...",
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
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), label: "Home"),
        NavigationDestination(icon: Icon(Icons.search), label: "Search"),
        NavigationDestination(
            icon: Icon(Icons.star_border), label: "Favorites"),
        NavigationDestination(icon: Icon(Icons.history), label: "Profile"),
      ],
    );
  }
}
