import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/favorite_item.dart';
import '../../providers/favorites_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import 'expression_detail_screen.dart';
import 'lexeme_detail_screen.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Favorites'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Lexemes'),
              Tab(text: 'Expressions'),
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
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorState(
            title: 'Unable to load favorites',
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
    if (items.isEmpty) {
      return const EmptyState(
        title: 'No favorites yet',
        message: 'Save a lexeme or expression to revisit it quickly.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(item.title),
          subtitle: item.subtitle.isEmpty ? null : Text(item.subtitle),
          trailing: IconButton(
            icon: const Icon(Icons.star),
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
