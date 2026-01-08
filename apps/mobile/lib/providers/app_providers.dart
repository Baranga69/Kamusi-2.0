import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import '../data/kamusi_api_repository.dart';
import '../data/local_favorites_repository.dart';
import '../domain/repositories/favorites_repository.dart';
import '../domain/repositories/kamusi_repository.dart';

final apiBaseUrlProvider = Provider<String>((ref) {
  return const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
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
