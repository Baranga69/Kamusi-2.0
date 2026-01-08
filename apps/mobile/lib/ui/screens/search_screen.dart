import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/search_suggestion.dart';
import '../../providers/search_provider.dart';
import '../../ui/widgets/empty_state.dart';
import '../../ui/widgets/error_state.dart';
import 'expression_detail_screen.dart';
import 'lexeme_detail_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(searchSuggestionsProvider.notifier).search(value);
    });
  }

  void _openSuggestion(SearchSuggestion suggestion) {
    if (suggestion.entryType.toLowerCase() == 'expression') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ExpressionDetailScreen(expressionId: suggestion.targetId),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LexemeDetailScreen(lexemeId: suggestion.targetId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = ref.watch(searchSuggestionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Kamusi')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _controller,
              onChanged: _onQueryChanged,
              decoration: const InputDecoration(
                hintText: 'Search Swahili words or expressions',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: suggestions.when(
              data: (items) {
                if (_controller.text.trim().isEmpty) {
                  return const EmptyState(
                    title: 'Start searching',
                    message: 'Type a word or expression to see suggestions.',
                  );
                }
                if (items.isEmpty) {
                  return const EmptyState(
                    title: 'No results',
                    message: 'Try another spelling or search term.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final suggestion = items[index];
                    return _SuggestionCard(
                      suggestion: suggestion,
                      onTap: () => _openSuggestion(suggestion),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemCount: items.length,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, __) => ErrorState(
                title: 'Unable to load suggestions',
                message: error.toString(),
                onRetry: () => _onQueryChanged(_controller.text),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestion, required this.onTap});

  final SearchSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tags = suggestion.tags;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    suggestion.display,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  suggestion.entryType.toUpperCase(),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            if (suggestion.snippet.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                suggestion.snippet,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey.shade700),
              ),
            ],
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: -8,
                children: tags
                    .map((tag) => Chip(label: Text(tag)))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
