import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import '../data/language_store.dart';
import '../data/response_cache.dart';
import '../data/server_store.dart';
import '../data/kamusi_api_repository.dart';
import '../data/local_favorites_repository.dart';
import '../data/local_recent_searches_repository.dart';
import '../domain/repositories/favorites_repository.dart';
import '../domain/repositories/kamusi_repository.dart';
import '../domain/repositories/recent_searches_repository.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) {
  return ThemeMode.light;
});

final languageStoreProvider = Provider<LanguageStore>((ref) => LanguageStore());

/// The chosen interface language.
///
/// Overridden at startup with the stored preference so the first frame is
/// already in the right language. Swahili is the default: this is a
/// Swahili-first dictionary, and the phone's language is a poor proxy for
/// what someone would rather read.
final appLanguageProvider = StateProvider<AppLanguage>((ref) {
  return AppLanguage.swahili;
});

/// Null means "follow the device", which `localeResolutionCallback` then
/// resolves — to Swahili when the device language is not one we speak.
final localeProvider = Provider<Locale?>((ref) {
  return ref.watch(appLanguageProvider).locale;
});

/// The address baked in at build time.
///
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000   (Android emulator)
///   flutter run --dart-define=API_BASE_URL=http://localhost:8000  (iOS sim, desktop, web)
///   flutter build --dart-define=API_BASE_URL=https://api.example.com
///
/// The default targets a local API so a fresh checkout works against
/// `make api`. Release builds must pass the deployed URL explicitly.
const String buildTimeApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000',
);

final serverStoreProvider = Provider<ServerStore>((ref) => ServerStore());

/// Base URL of the Kamusi API, as the app is actually using it.
///
/// Writable, and overridden at startup with the stored address if there is
/// one. Everything downstream — the Dio client, the repository, every
/// provider that reads them — watches this, so setting it is all it takes to
/// point the app somewhere else. No rebuild, no reinstall.
final apiBaseUrlProvider = StateProvider<String>((ref) {
  return buildTimeApiBaseUrl;
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
