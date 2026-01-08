import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/expression_detail.dart';
import '../../domain/models/favorite_item.dart';
import '../../providers/detail_providers.dart';
import '../../providers/favorites_provider.dart';
import '../widgets/error_state.dart';
import '../widgets/section_header.dart';

class ExpressionDetailScreen extends ConsumerWidget {
  const ExpressionDetailScreen({super.key, required this.expressionId});

  final String expressionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(expressionDetailProvider(expressionId));
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expression'),
        actions: [
          favorites.when(
            data: (_) {
              final isFavorite = ref
                  .read(favoritesProvider.notifier)
                  .isFavorite(expressionId, FavoriteKind.expression);
              return IconButton(
                onPressed: () {
                  final item = _favoriteFromDetail(detail.value);
                  if (item != null) {
                    ref.read(favoritesProvider.notifier).toggleFavorite(item);
                  }
                },
                icon: Icon(isFavorite ? Icons.star : Icons.star_border),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: detail.when(
        data: (expression) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                expression.text,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Meanings'),
              const SizedBox(height: 12),
              ..._prioritizeSwahili(expression.meanings).map(
                (meaning) => _MeaningCard(meaning: meaning),
              ),
              if (expression.examples.isNotEmpty) ...[
                const SizedBox(height: 24),
                const SectionHeader(title: 'Examples'),
                const SizedBox(height: 12),
                ...expression.examples.map(
                  (example) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('“${example.text}”'),
                  ),
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorState(
          title: 'Unable to load expression',
          message: error.toString(),
          onRetry: () => ref.refresh(expressionDetailProvider(expressionId)),
        ),
      ),
    );
  }

  FavoriteItem? _favoriteFromDetail(ExpressionDetail? detail) {
    if (detail == null || detail.id.isEmpty) {
      return null;
    }
    return FavoriteItem(
      id: detail.id,
      kind: FavoriteKind.expression,
      title: detail.text,
      subtitle: 'Expression',
    );
  }

  List<Meaning> _prioritizeSwahili(List<Meaning> meanings) {
    final swahili = meanings
        .where((meaning) =>
            meaning.language.toLowerCase().startsWith('sw') ||
            meaning.language.toLowerCase().contains('swahili'))
        .toList();
    final others = meanings.where((meaning) => !swahili.contains(meaning)).toList();
    return [...swahili, ...others];
  }
}

class _MeaningCard extends StatelessWidget {
  const _MeaningCard({required this.meaning});

  final Meaning meaning;

  @override
  Widget build(BuildContext context) {
    final language = meaning.language.isNotEmpty
        ? meaning.language.toUpperCase()
        : 'Meaning';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          Text(
            language,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(meaning.text),
        ],
      ),
    );
  }
}
