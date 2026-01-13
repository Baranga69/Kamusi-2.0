import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/word_of_day.dart';
import 'app_providers.dart';

final wordOfDayProvider = FutureProvider<WordOfDay>((ref) async {
  final repository = ref.watch(kamusiRepositoryProvider);
  return repository.fetchWordOfDay();
});
