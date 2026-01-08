import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/favorite_item.dart';
import '../domain/repositories/favorites_repository.dart';
import 'app_providers.dart';

class FavoritesController extends AsyncNotifier<List<FavoriteItem>> {
  @override
  Future<List<FavoriteItem>> build() async {
    final repository = ref.read(favoritesRepositoryProvider);
    return repository.load();
  }

  Future<void> toggleFavorite(FavoriteItem item) async {
    final current = state.value ?? [];
    final exists = current.any(
      (favorite) => favorite.id == item.id && favorite.kind == item.kind,
    );
    final updated = exists
        ? current
            .where((favorite) =>
                !(favorite.id == item.id && favorite.kind == item.kind))
            .toList()
        : [...current, item];

    state = AsyncValue.data(updated);
    final repository = ref.read(favoritesRepositoryProvider);
    await repository.save(updated);
  }

  bool isFavorite(String id, FavoriteKind kind) {
    final current = state.value ?? [];
    return current.any(
      (favorite) => favorite.id == id && favorite.kind == kind,
    );
  }
}

final favoritesProvider =
    AsyncNotifierProvider<FavoritesController, List<FavoriteItem>>(
  FavoritesController.new,
);
