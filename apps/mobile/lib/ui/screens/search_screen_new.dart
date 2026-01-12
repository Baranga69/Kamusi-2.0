import 'package:flutter/material.dart';

import '../../domain/models/search_suggestion.dart';
import '../theme/app_theme.dart';
import '../widgets/filter_chips_row.dart';
import '../widgets/kamusi_header.dart';
import '../widgets/result_list_tile.dart';
import '../widgets/search_bar.dart';

class SearchScreen extends StatefulWidget {
  final Future<List<SearchResultItem>> Function(
      String query, SearchFilter filter) onSearch;
  final void Function(SearchResultItem item) onOpenItem;
  final String initialQuery;

  const SearchScreen({
    super.key,
    required this.onSearch,
    required this.onOpenItem,
    this.initialQuery = "",
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  SearchFilter _filter = SearchFilter.all;
  bool _loading = false;
  List<SearchResultItem> _results = [];
  String _lastQuery = "";

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialQuery;
    if (widget.initialQuery.trim().isNotEmpty) {
      _doSearch(widget.initialQuery.trim());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _doSearch(String q) async {
    setState(() {
      _loading = true;
      _lastQuery = q;
    });
    try {
      final res = await widget.onSearch(q, _filter);
      if (!mounted) return;
      setState(() => _results = res);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          KamusiHeader(
            title: "Sözlük'te Ara",
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
              splashRadius: 22,
            ),
            child: Column(
              children: [
                RoundedSearchBar(
                  hint: "Ara...",
                  controller: _controller,
                  onClear: () {
                    _controller.clear();
                    setState(() {
                      _results = [];
                      _lastQuery = "";
                    });
                  },
                  onSubmitted: (q) {
                    final t = q.trim();
                    if (t.isNotEmpty) _doSearch(t);
                  },
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                FilterChipsRow(
                  selected: _filter,
                  onChanged: (f) {
                    setState(() => _filter = f);
                    final q = _controller.text.trim();
                    if (q.isNotEmpty) _doSearch(q);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Card(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: _loading
                  ? const Center(
                      child: Padding(
                      padding: EdgeInsets.all(18),
                      child: CircularProgressIndicator(),
                    ))
                  : _results.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            _lastQuery.isEmpty
                                ? "Aramaya başlayın."
                                : "Sonuç bulunamadı.",
                            style:
                                const TextStyle(color: KamusiColors.textMuted),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _results.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) => ResultListTile(
                            item: _results[i],
                            onTap: () => widget.onOpenItem(_results[i]),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
