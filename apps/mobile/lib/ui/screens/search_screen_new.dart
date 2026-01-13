import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/search_entry.dart';
import '../../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/filter_chips_row.dart';
import '../widgets/kamusi_header.dart';
import '../widgets/result_list_tile.dart';
import '../widgets/search_bar.dart';
import 'lexeme_detail_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final String initialQuery;

  const SearchScreen({
    super.key,
    this.initialQuery = "",
  });

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  SearchFilter _filter = SearchFilter.all;
  bool _loading = false;
  List<SearchEntry> _results = [];
  String _lastQuery = "";
  String? _errorMessage;
  Timer? _debounce;

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
    _debounce?.cancel();
    super.dispose();
  }

  void _scheduleSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _doSearch(q);
    });
  }

  Future<void> _doSearch(String q) async {
    setState(() {
      _loading = true;
      _lastQuery = q;
      _errorMessage = null;
    });
    try {
      final repository = ref.read(kamusiRepositoryProvider);
      final res = await repository.search(q);
      if (!mounted) return;
      setState(() => _results = res);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _errorMessage = 'Arama başarısız. Lütfen tekrar deneyin.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openEntry(SearchEntry entry) {
    if (entry.targetType.toLowerCase() == 'lexeme') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LexemeDetailScreen(lexemeId: entry.targetId),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unsupported result type')),
      );
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
                      _errorMessage = null;
                    });
                  },
                  onSubmitted: (q) {
                    final t = q.trim();
                    if (t.isNotEmpty) _doSearch(t);
                  },
                  onChanged: (q) {
                    setState(() {});
                    final t = q.trim();
                    if (t.isEmpty) {
                      _debounce?.cancel();
                      setState(() {
                        _results = [];
                        _lastQuery = "";
                        _errorMessage = null;
                      });
                    } else {
                      _scheduleSearch(t);
                    }
                  },
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
                                : _errorMessage ?? "Sonuç bulunamadı.",
                            style:
                                const TextStyle(color: KamusiColors.textMuted),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _results.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) => ResultListTile(
                            item: _results[i],
                            onTap: () => _openEntry(_results[i]),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
