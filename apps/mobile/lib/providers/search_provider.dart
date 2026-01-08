import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/search_suggestion.dart';
import 'app_providers.dart';

class SearchSuggestionsController
    extends AutoDisposeAsyncNotifier<List<SearchSuggestion>> {
  @override
  Future<List<SearchSuggestion>> build() async {
    return [];
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }
    state = const AsyncValue.loading();
    final repository = ref.read(kamusiRepositoryProvider);
    state = await AsyncValue.guard(() => repository.search(query.trim()));
  }
}

final searchSuggestionsProvider =
    AutoDisposeAsyncNotifierProvider<SearchSuggestionsController,
        List<SearchSuggestion>>(
  SearchSuggestionsController.new,
);
