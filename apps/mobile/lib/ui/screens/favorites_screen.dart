import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../domain/models/favorite_item.dart';
import '../../providers/favorites_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/loading_skeleton.dart';
import 'expression_detail_screen.dart';
import 'lexeme_detail_screen.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final favorites = ref.watch(favoritesProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.favoritesTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.favoritesTabLexemes),
              Tab(text: l10n.favoritesTabExpressions),
            ],
          ),
        ),
        body: favorites.when(
          data: (items) {
            final lexemes = items
                .where((item) => item.kind == FavoriteKind.lexeme)
                .toList();
            final expressions = items
                .where((item) => item.kind == FavoriteKind.expression)
                .toList();

            return TabBarView(
              children: [
                _FavoritesList(items: lexemes),
                _FavoritesList(items: expressions),
              ],
            );
          },
          loading: () => const LoadingSkeleton(lines: 6),
          error: (error, _) => ErrorState(
            title: l10n.favoritesUnableLoad,
            message: error.toString(),
            onRetry: () => ref.refresh(favoritesProvider),
          ),
        ),
      ),
    );
  }
}

class _FavoritesList extends ConsumerWidget {
  const _FavoritesList({required this.items});

  final List<FavoriteItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    if (items.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return EmptyState(
        title: l10n.favoritesEmptyTitle,
        message: l10n.favoritesEmptyMessage,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          tileColor: colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(item.title),
          subtitle: item.subtitle.isEmpty
              ? null
              : Text(
                  item.subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
          trailing: IconButton(
            icon: Icon(Icons.star, color: colorScheme.secondary),
            onPressed: () =>
                ref.read(favoritesProvider.notifier).toggleFavorite(item),
          ),
          onTap: () {
            if (item.kind == FavoriteKind.expression) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ExpressionDetailScreen(expressionId: item.id),
                ),
              );
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LexemeDetailScreen(lexemeId: item.id),
                ),
              );
            }
          },
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: items.length,
    );
  }
}
