import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/learn_progress_store.dart';
import '../domain/models/learn_round.dart';
import '../data/game_round_cache.dart';
import '../data/game_rounds_service.dart';
import '../domain/models/word_build_puzzle.dart';
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

final gameRoundCacheProvider = Provider<GameRoundCache>((ref) {
  return GameRoundCache();
});

final gameRoundsServiceProvider = Provider<GameRoundsService>((ref) {
  return GameRoundsService(
    repository: ref.read(kamusiRepositoryProvider),
    cache: ref.read(gameRoundCacheProvider),
  );
});

/// A word-search grid, from the offline queue where possible. Invalidated to
/// get the next one.
final wordFindProvider = FutureProvider<WordFindPuzzle>((ref) async {
  return ref.read(gameRoundsServiceProvider).nextWordFind();
});

/// A ring of letters, from the same queue.
final wordBuildProvider = FutureProvider<WordBuildPuzzle>((ref) async {
  return ref.read(gameRoundsServiceProvider).nextWordBuild();
});

/// How many rounds of each game are playable with no connection.
final gameRoundsReadyProvider = FutureProvider<Map<String, int>>((ref) async {
  return ref.read(gameRoundsServiceProvider).readyCounts();
});

/// Fills the offline queues in the background when Jifunze is opened.
///
/// Watched rather than awaited anywhere a player is waiting: the games are
/// playable from whatever is already stored, and this quietly makes sure
/// there is enough for the next journey. Never throws — a dropped connection
/// mid-top-up is ordinary.
final gameTopUpProvider = FutureProvider<int>((ref) async {
  return ref.read(gameRoundsServiceProvider).topUpAll();
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
