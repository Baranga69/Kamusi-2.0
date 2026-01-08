import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/favorite_item.dart';
import '../domain/repositories/favorites_repository.dart';

class LocalFavoritesRepository implements FavoritesRepository {
  static const _storageKey = 'kamusi_favorites';

  @override
  Future<List<FavoriteItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return [];
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(FavoriteItem.fromJson)
        .toList();
  }

  @override
  Future<void> save(List<FavoriteItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((item) => item.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}
