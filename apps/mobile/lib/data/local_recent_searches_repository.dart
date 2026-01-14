import 'package:shared_preferences/shared_preferences.dart';

import '../domain/repositories/recent_searches_repository.dart';

class LocalRecentSearchesRepository implements RecentSearchesRepository {
  static const _storageKey = 'kamusi_recent_searches';

  @override
  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final items = prefs.getStringList(_storageKey);
    if (items == null) {
      return [];
    }
    return items.where((item) => item.trim().isNotEmpty).toList();
  }

  @override
  Future<void> save(List<String> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey, items);
  }
}
