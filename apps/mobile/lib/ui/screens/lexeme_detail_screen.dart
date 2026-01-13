import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../domain/models/favorite_item.dart';
import '../../domain/models/lexeme_public.dart';
import '../../providers/detail_providers.dart';
import '../../providers/favorites_provider.dart';
import '../widgets/error_state.dart';
import '../widgets/lexeme_header.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/section_header.dart';
import '../widgets/sense_card.dart';

class LexemeDetailScreen extends ConsumerWidget {
  const LexemeDetailScreen({super.key, required this.lexemeId});

  final String lexemeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final detail = ref.watch(lexemeDetailProvider(lexemeId));
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.lexemeTitle),
        actions: [
          favorites.when(
            data: (items) {
              final isFavorite = ref
                  .read(favoritesProvider.notifier)
                  .isFavorite(lexemeId, FavoriteKind.lexeme);
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
        data: (lexeme) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              LexemeHeader(
                lemma: lexeme.lemma ?? '',
                partOfSpeech: lexeme.posId,
              ),
              const SizedBox(height: 24),
              SectionHeader(title: l10n.lexemeSenses),
              const SizedBox(height: 12),
              ...lexeme.senses.map((sense) => SenseCard(sense: sense)),
            ],
          );
        },
        loading: () => const LoadingSkeleton(lines: 8),
        error: (error, _) => ErrorState(
          title: l10n.lexemeUnableLoad,
          message: error.toString(),
          onRetry: () => ref.refresh(lexemeDetailProvider(lexemeId)),
        ),
      ),
    );
  }

  FavoriteItem? _favoriteFromDetail(LexemePublic? detail) {
    if (detail == null || detail.id.isEmpty) {
      return null;
    }
    return FavoriteItem(
      id: detail.id,
      kind: FavoriteKind.lexeme,
      title: detail.lemma ?? '',
      subtitle: detail.posId ?? '',
    );
  }
}
