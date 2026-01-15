import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import '../data/kamusi_api_repository.dart';
import '../data/local_favorites_repository.dart';
import '../data/local_recent_searches_repository.dart';
import '../domain/repositories/favorites_repository.dart';
import '../domain/repositories/kamusi_repository.dart';
import '../domain/repositories/recent_searches_repository.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) {
  return ThemeMode.light;
});

final apiBaseUrlProvider = Provider<String>((ref) {
  return const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://kamusi-2-0.onrender.com/',
  );
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  return ApiClient(baseUrl: baseUrl);
});

final kamusiRepositoryProvider = Provider<KamusiRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return KamusiApiRepository(client: client);
});

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return LocalFavoritesRepository();
});

final recentSearchesRepositoryProvider =
    Provider<RecentSearchesRepository>((ref) {
  return LocalRecentSearchesRepository();
});
