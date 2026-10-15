import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/learn_progress_store.dart';
import '../domain/models/learn_round.dart';
import '../data/game_round_cache.dart';
import '../data/game_feedback.dart';
import '../data/game_settings_store.dart';
import '../data/game_rounds_service.dart';
import '../domain/models/crossword_puzzle.dart';
import '../domain/models/word_build_puzzle.dart';
import '../domain/models/word_find_puzzle.dart';
import 'app_providers.dart';

final learnProgressStoreProvider = Provider<LearnProgressStore>((ref) {
  return LearnProgressStore();
});

/// Today's challenge, fixed for the day by the API.
final dailyRoundProvider = FutureProvider<LearnRound>((ref) async {
  return ref.watch(kamusiRepositoryProvider).fetchDailyRound();
});

/// A practice round of a given kind. Fresh on every request, so the family
/// argument is the kind and the provider is invalidated to get a new one.
final practiceRoundProvider =
    FutureProvider.family<LearnRound, String>((ref, kind) async {
  return ref.watch(kamusiRepositoryProvider).fetchPracticeRound(kind);
});

final gameSettingsStoreProvider = Provider<GameSettingsStore>((ref) {
  return GameSettingsStore();
});

/// Whether the games run against a clock. One setting for all of them:
/// timed or untimed is a mood a player is in, not a property of a board.
class TimedModeController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    return ref.read(gameSettingsStoreProvider).loadTimed();
  }

  Future<void> set(bool value) async {
    state = AsyncValue.data(
      await ref.read(gameSettingsStoreProvider).setTimed(value),
    );
  }
}

final timedModeProvider =
    AsyncNotifierProvider<TimedModeController, bool>(TimedModeController.new);

/// Sound and haptics, mirrored into [GameFeedback] whenever they change so
/// the gesture handlers never have to look them up.
class FeedbackSettingsController extends AsyncNotifier<({bool sound, bool haptics})> {
  @override
  Future<({bool sound, bool haptics})> build() async {
    final store = ref.read(gameSettingsStoreProvider);
    final value = (sound: await store.loadSound(), haptics: await store.loadHaptics());
    GameFeedback.configure(sound: value.sound, haptics: value.haptics);
    return value;
  }

  Future<void> setSound(bool on) async {
    final store = ref.read(gameSettingsStoreProvider);
    await store.setSound(on);
    final value = (sound: on, haptics: state.value?.haptics ?? true);
    GameFeedback.configure(sound: value.sound, haptics: value.haptics);
    state = AsyncValue.data(value);
  }

  Future<void> setHaptics(bool on) async {
    final store = ref.read(gameSettingsStoreProvider);
    await store.setHaptics(on);
    final value = (sound: state.value?.sound ?? true, haptics: on);
    GameFeedback.configure(sound: value.sound, haptics: value.haptics);
    state = AsyncValue.data(value);
  }
}

final feedbackSettingsProvider = AsyncNotifierProvider<FeedbackSettingsController,
    ({bool sound, bool haptics})>(FeedbackSettingsController.new);

final gameRoundCacheProvider = Provider<GameRoundCache>((ref) {
  return GameRoundCache();
});

/// Watches the repository rather than reading it: the server address can be
/// changed from Settings at runtime, and a service holding a snapshot of the
/// old client would keep calling an address that has moved. Everything that
/// fetches depends on the client for the same reason.
final gameRoundsServiceProvider = Provider<GameRoundsService>((ref) {
  return GameRoundsService(
    repository: ref.watch(kamusiRepositoryProvider),
    cache: ref.read(gameRoundCacheProvider),
  );
});

/// A word-search grid, from the offline queue where possible. Invalidated to
/// get the next one.
final wordFindProvider = FutureProvider<WordFindPuzzle>((ref) async {
  return ref.watch(gameRoundsServiceProvider).nextWordFind();
});

/// A ring of letters, from the same queue.
final wordBuildProvider = FutureProvider<WordBuildPuzzle>((ref) async {
  return ref.watch(gameRoundsServiceProvider).nextWordBuild();
});

/// A crossword grid, from the same queue.
final crosswordProvider = FutureProvider<CrosswordPuzzle>((ref) async {
  return ref.watch(gameRoundsServiceProvider).nextCrossword();
});

/// Best score per game, for the cards on the Jifunze home.
final bestScoresProvider = FutureProvider<Map<String, int>>((ref) async {
  final store = ref.read(gameSettingsStoreProvider);
  final scores = <String, int>{};
  for (final game in GameIds.all) {
    scores[game] = await store.bestScore(game);
  }
  return scores;
});

/// How many rounds of each game are playable with no connection.
final gameRoundsReadyProvider = FutureProvider<Map<String, int>>((ref) async {
  return ref.watch(gameRoundsServiceProvider).readyCounts();
});

/// Fills the offline queues in the background when Jifunze is opened.
///
/// Watched rather than awaited anywhere a player is waiting: the games are
/// playable from whatever is already stored, and this quietly makes sure
/// there is enough for the next journey. Never throws — a dropped connection
/// mid-top-up is ordinary.
final gameTopUpProvider = FutureProvider<int>((ref) async {
  return ref.watch(gameRoundsServiceProvider).topUpAll();
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
