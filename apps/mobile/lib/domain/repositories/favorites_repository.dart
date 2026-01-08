import '../models/favorite_item.dart';

abstract class FavoritesRepository {
  Future<List<FavoriteItem>> load();
  Future<void> save(List<FavoriteItem> items);
}
