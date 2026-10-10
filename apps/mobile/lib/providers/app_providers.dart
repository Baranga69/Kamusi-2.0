import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import '../data/response_cache.dart';
import '../data/kamusi_api_repository.dart';
import '../data/local_favorites_repository.dart';
import '../data/local_recent_searches_repository.dart';
import '../domain/repositories/favorites_repository.dart';
import '../domain/repositories/kamusi_repository.dart';
import '../domain/repositories/recent_searches_repository.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) {
  return ThemeMode.light;
});

/// Base URL of the Kamusi API.
///
/// Override per build, never per file:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000   (Android emulator)
///   flutter run --dart-define=API_BASE_URL=http://localhost:8000  (iOS sim, desktop, web)
///   flutter build --dart-define=API_BASE_URL=https://api.example.com
///
/// The default targets a local API so a fresh checkout works against
/// `make api`. Release builds must pass the deployed URL explicitly.
final apiBaseUrlProvider = Provider<String>((ref) {
  return const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
});

/// Whether to ask the API for draft content.
///
/// Draft entries are unpublished and unreviewed, so this stays off unless a
/// developer opts in for a local session:
///   flutter run --dart-define=INCLUDE_DRAFTS=true
final includeDraftsProvider = Provider<bool>((ref) {
  return const bool.fromEnvironment('INCLUDE_DRAFTS', defaultValue: false);
});

/// On-disk cache of API responses, so a word opened once stays readable
/// without a connection.
final responseCacheProvider = Provider<ResponseCache>((ref) {
  return ResponseCache();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  final includeDrafts = ref.watch(includeDraftsProvider);
  return ApiClient(
    baseUrl: baseUrl,
    includeDrafts: includeDrafts,
    cache: ref.watch(responseCacheProvider),
  );
});

/// True while the app is showing saved copies because the network is
/// unreachable. Drives the offline banner.
final servingCachedDataProvider = Provider<ValueNotifier<bool>>((ref) {
  return ref.watch(apiClientProvider).servingCachedData;
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
