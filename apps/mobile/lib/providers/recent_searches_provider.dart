import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/repositories/recent_searches_repository.dart';
import 'app_providers.dart';

final recentSearchesProvider =
    StateNotifierProvider<RecentSearchesNotifier, List<String>>((ref) {
  final repository = ref.watch(recentSearchesRepositoryProvider);
  return RecentSearchesNotifier(repository: repository);
});

class RecentSearchesNotifier extends StateNotifier<List<String>> {
  static const int maxItems = 10;

  RecentSearchesNotifier({required this.repository}) : super(const []) {
    _load();
  }

  final RecentSearchesRepository repository;

  Future<void> add(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final key = trimmed.toLowerCase();
    final next = <String>[trimmed];
    for (final item in state) {
      if (item.toLowerCase() == key) {
        continue;
      }
      if (next.length >= maxItems) {
        break;
      }
      next.add(item);
    }
    state = next;
    await repository.save(state);
  }

  Future<void> clear() async {
    state = const [];
    await repository.save(state);
  }

  Future<void> _load() async {
    try {
      final items = await repository.load();
      state = _cap(items);
    } catch (_) {
      state = const [];
    }
  }

  List<String> _cap(List<String> items) {
    final seen = <String>{};
    final result = <String>[];
    for (final item in items) {
      final trimmed = item.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final key = trimmed.toLowerCase();
      if (!seen.add(key)) {
        continue;
      }
      result.add(trimmed);
      if (result.length >= maxItems) {
        break;
      }
    }
    return result;
  }
}
