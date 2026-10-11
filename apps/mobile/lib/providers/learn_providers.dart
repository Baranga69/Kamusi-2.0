import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/learn_progress_store.dart';
import '../domain/models/learn_round.dart';
import '../domain/models/word_find_puzzle.dart';
import 'app_providers.dart';

final learnProgressStoreProvider = Provider<LearnProgressStore>((ref) {
  return LearnProgressStore();
});

/// Today's challenge, fixed for the day by the API.
final dailyRoundProvider = FutureProvider<LearnRound>((ref) async {
  return ref.read(kamusiRepositoryProvider).fetchDailyRound();
});

/// A practice round of a given kind. Fresh on every request, so the family
/// argument is the kind and the provider is invalidated to get a new one.
final practiceRoundProvider =
    FutureProvider.family<LearnRound, String>((ref, kind) async {
  return ref.read(kamusiRepositoryProvider).fetchPracticeRound(kind);
});

/// A fresh word-search grid. Invalidated to get another one.
final wordFindProvider = FutureProvider<WordFindPuzzle>((ref) async {
  return ref.read(kamusiRepositoryProvider).fetchWordFind();
});

class LearnProgressController extends AsyncNotifier<LearnProgress> {
  @override
  Future<LearnProgress> build() async {
    return ref.read(learnProgressStoreProvider).load();
  }

  Future<void> completeDaily({required int correct, required int answered}) async {
    final store = ref.read(learnProgressStoreProvider);
    state = AsyncValue.data(
      await store.completeDaily(correct: correct, answered: answered),
    );
  }

  Future<void> recordPractice({required int correct, required int answered}) async {
    final store = ref.read(learnProgressStoreProvider);
    state = AsyncValue.data(
      await store.recordPractice(correct: correct, answered: answered),
    );
  }

  /// Whether today's challenge is already done, so the UI can offer practice
  /// instead of inviting the same round again.
  bool get doneToday {
    final progress = state.value;
    return progress != null && progress.completedOn(LearnProgressStore.dayKey());
  }
}

final learnProgressProvider =
    AsyncNotifierProvider<LearnProgressController, LearnProgress>(
  LearnProgressController.new,
);
