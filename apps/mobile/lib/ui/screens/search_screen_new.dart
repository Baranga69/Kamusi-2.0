import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../domain/models/search_entry.dart';
import '../../providers/app_providers.dart';
import '../../providers/recent_searches_provider.dart';
import '../widgets/filter_chips_row.dart';
import '../widgets/kamusi_header.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/result_list_tile.dart';
import '../widgets/search_bar.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
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
  bool _hasLoggedInitialSearch = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuery.trim();
    _controller.text = initial;
    if (initial.isNotEmpty) {
      _recordRecent(initial);
      _doSearch(initial);
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
    if (!_hasLoggedInitialSearch) {
      _logInitialSearchEndpoint(q);
      _hasLoggedInitialSearch = true;
    }
    final l10n = AppLocalizations.of(context)!;
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
        _errorMessage = l10n.searchErrorFailed;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openEntry(SearchEntry entry) {
    final query = _controller.text.trim();
    if (query.isNotEmpty) {
      _recordRecent(query);
    }
    if (entry.targetType.toLowerCase() == 'lexeme') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LexemeDetailScreen(lexemeId: entry.targetId),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(AppLocalizations.of(context)!.searchUnsupportedResultType),
        ),
      );
    }
  }

  void _recordRecent(String query) {
    ref.read(recentSearchesProvider.notifier).add(query);
  }

  void _logInitialSearchEndpoint(String query) {
    final baseUrl = ref.read(apiBaseUrlProvider);
    final uri = Uri.parse(baseUrl).resolve('/search').replace(
          queryParameters: {
            'q': query,
            'lang': 'sw',
            'limit': '20',
          },
        );
    debugPrint('[Kamusi] GET $uri (initial home search)');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(
        children: [
          KamusiHeader(
            title: l10n.searchHeaderTitle,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
              splashRadius: 22,
            ),
            child: Column(
              children: [
                KamusiSearchBar(
                  hint: l10n.searchHint,
                  controller: _controller,
                  autofocus: true,
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
                    if (t.isNotEmpty) {
                      _recordRecent(t);
                      _doSearch(t);
                    }
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Material(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                child: _loading
                    ? const LoadingSkeleton(lines: 8)
                    : _results.isEmpty
                        ? _errorMessage != null
                            ? ErrorState(
                                title: l10n.searchErrorFailed,
                                message: _errorMessage!,
                                onRetry: () => _doSearch(_lastQuery),
                              )
                            : EmptyState(
                                title: _lastQuery.isEmpty
                                    ? l10n.searchStartPrompt
                                    : l10n.searchNoResults,
                                message: _lastQuery.isEmpty
                                    ? l10n.searchHint
                                    : l10n.searchHint,
                              )
                        : ListView.separated(
                            itemCount: _results.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 6),
                            itemBuilder: (_, i) => SearchResultTile(
                              item: _results[i],
                              onTap: () => _openEntry(_results[i]),
                            ),
                          ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
