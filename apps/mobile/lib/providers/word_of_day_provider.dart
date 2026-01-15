import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/word_of_day.dart';
import 'app_providers.dart';

final wordOfDayProvider = FutureProvider<WordOfDay>((ref) async {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  final uri = Uri.parse(baseUrl)
      .resolve('/word-of-the-day')
      .replace(queryParameters: {'lang': 'sw'});
  debugPrint('[Kamusi] GET $uri (word of the day)');
  final repository = ref.watch(kamusiRepositoryProvider);
  return repository.fetchWordOfDay();
});
