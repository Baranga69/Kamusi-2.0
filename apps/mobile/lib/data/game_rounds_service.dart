import '../domain/models/codeword_puzzle.dart';
import '../domain/models/word_build_puzzle.dart';
import '../domain/models/word_find_puzzle.dart';
import '../domain/repositories/kamusi_repository.dart';
import 'game_round_cache.dart';

/// Where a game gets its next round.
///
/// Always from the queue first. That is what makes Jifunze work on a bus:
/// the queue was filled while there was a connection, and taking from it
/// needs none. Only when the queue is empty — a fresh install, or storage
/// cleared — does this reach for the network, and a failure there is a real
/// failure rather than a silent blank.
///
/// Topping the queue back up happens after the round has been handed over,
/// so starting a game never waits on it.
class GameRoundsService {
  GameRoundsService({required this.repository, required this.cache});

  final KamusiRepository repository;
  final GameRoundCache cache;

  Future<Map<String, dynamic>> Function() _fetcherFor(String game) {
    switch (game) {
      case GameIds.wordBuild:
        return repository.fetchWordBuildJson;
      case GameIds.codeword:
        return repository.fetchCodewordJson;
      case GameIds.wordFind:
      default:
        return repository.fetchWordFindJson;
    }
  }

  /// The next round's raw JSON, from the queue where possible.
  Future<Map<String, dynamic>> nextRound(String game) async {
    final cached = await cache.take(game);
    if (cached != null) {
      return cached;
    }
    final round = await _fetcherFor(game)();
    // Not added to the queue: it is being played now, and queueing it would
    // mean the next round is one just seen.
    return round;
  }

  Future<WordFindPuzzle> nextWordFind() async =>
      WordFindPuzzle.fromJson(await nextRound(GameIds.wordFind));

  Future<WordBuildPuzzle> nextWordBuild() async =>
      WordBuildPuzzle.fromJson(await nextRound(GameIds.wordBuild));

  Future<CodewordPuzzle> nextCodeword() async =>
      CodewordPuzzle.fromJson(await nextRound(GameIds.codeword));

  /// Top every game back up to its target.
  ///
  /// Returns how many rounds were stored across all games. Never throws: this
  /// runs in the background off the back of a screen opening, and a dropped
  /// connection mid-top-up is ordinary, not an error to show anybody.
  Future<int> topUpAll() async {
    var added = 0;
    for (final game in GameIds.all) {
      try {
        final fetch = _fetcherFor(game);
        added += await cache.refill(game, () async => fetch());
      } catch (_) {
        // refill already stops at the first failure; this catches a failure
        // getting that far.
      }
    }
    return added;
  }

  /// How many rounds of each game are playable with no connection.
  Future<Map<String, int>> readyCounts() async {
    final counts = <String, int>{};
    for (final game in GameIds.all) {
      counts[game] = await cache.totalCount(game);
    }
    return counts;
  }
}
