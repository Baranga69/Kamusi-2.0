import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../domain/models/expression_detail.dart';
import '../../domain/models/favorite_item.dart';
import '../../providers/detail_providers.dart';
import '../../providers/favorites_provider.dart';
import '../widgets/error_state.dart';
import '../widgets/lexeme_header.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/section_header.dart';
import '../theme/kamusi_typography.dart';

class ExpressionDetailScreen extends ConsumerWidget {
  const ExpressionDetailScreen({super.key, required this.expressionId});

  final String expressionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final detail = ref.watch(expressionDetailProvider(expressionId));
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.expressionTitle),
        actions: [
          favorites.when(
            data: (_) {
              final isFavorite = ref
                  .read(favoritesProvider.notifier)
                  .isFavorite(expressionId, FavoriteKind.expression);
              return IconButton(
                onPressed: () {
                  final item = _favoriteFromDetail(context, detail.value);
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
              LexemeHeader(lemma: expression.text),
              const SizedBox(height: 24),
              SectionHeader(title: l10n.expressionMeanings),
              const SizedBox(height: 12),
              ..._prioritizeSwahili(expression.meanings).map(
                (meaning) => _MeaningCard(meaning: meaning),
              ),
              if (expression.examples.isNotEmpty) ...[
                const SizedBox(height: 24),
                SectionHeader(title: l10n.examples),
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
        loading: () => const LoadingSkeleton(lines: 6),
        error: (error, _) => ErrorState(
          title: l10n.expressionUnableLoad,
          message: error.toString(),
          onRetry: () => ref.refresh(expressionDetailProvider(expressionId)),
        ),
      ),
    );
  }

  FavoriteItem? _favoriteFromDetail(
    BuildContext context,
    ExpressionDetail? detail,
  ) {
    if (detail == null || detail.id.isEmpty) {
      return null;
    }
    return FavoriteItem(
      id: detail.id,
      kind: FavoriteKind.expression,
      title: detail.text,
      subtitle: AppLocalizations.of(context)!.expressionTitle,
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
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final language = meaning.language.isNotEmpty
        ? meaning.language.toUpperCase()
        : l10n.meaningLabel;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              language,
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            meaning.text,
            style: KamusiTypography.serif(
              textTheme.bodyLarge,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
