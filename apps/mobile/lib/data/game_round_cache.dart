import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// A queue of pre-fetched game rounds, kept on disk so Jifunze works offline.
///
/// [ResponseCache] keeps the last response per key, which is right for a
/// dictionary entry and wrong for a game: every request to `/learn/wordfind`
/// returns a *different* puzzle, so caching by key leaves a player offline
/// with one grid, replayed forever.
///
/// This stores a queue instead. Topped up while there is a connection, drawn
/// down one round at a time, and — once the queue runs dry with no way to
/// refill — it recycles what has already been played in a new order rather
/// than leaving someone on a bus with nothing. Ten distinct puzzles on
/// rotation is a far better answer than a locked screen.
class GameRoundCache {
  GameRoundCache({
    this.roundsPerGame = 10,
    this.namespace = 'kamusi_games',
    Random? random,
  }) : _random = random ?? Random();

  /// How many rounds of each game to hold. Ten is roughly a sitting, and at a
  /// few kilobytes a puzzle it is small enough for shared_preferences.
  final int roundsPerGame;
  final String namespace;
  final Random _random;

  String _key(String game) => '$namespace:$game';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<_Queues> _load(String game) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_key(game));
    if (raw == null || raw.isEmpty) {
      return _Queues(<Object?>[], <Object?>[]);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return _Queues(<Object?>[], <Object?>[]);
      }
      return _Queues(
        (decoded['pending'] as List?)?.toList() ?? <Object?>[],
        (decoded['played'] as List?)?.toList() ?? <Object?>[],
      );
    } catch (_) {
      // Written by an older, incompatible version. Dropping it costs one
      // refill; failing the read would break the game.
      await prefs.remove(_key(game));
      return _Queues(<Object?>[], <Object?>[]);
    }
  }

  Future<void> _save(String game, _Queues queues) async {
    final prefs = await _prefs;
    await prefs.setString(
      _key(game),
      jsonEncode({'pending': queues.pending, 'played': queues.played}),
    );
  }

  /// Rounds ready to play without a connection.
  Future<int> pendingCount(String game) async => (await _load(game)).pending.length;

  /// Everything held for this game, played or not.
  Future<int> totalCount(String game) async {
    final queues = await _load(game);
    return queues.pending.length + queues.played.length;
  }

  /// The next round, or null when none is stored at all.
  Future<Map<String, dynamic>?> take(String game) async {
    final queues = await _load(game);

    if (queues.pending.isEmpty) {
      if (queues.played.isEmpty) {
        return null;
      }
      // Out of fresh rounds and possibly offline: shuffle what has been
      // played back in rather than refusing to deal.
      queues.pending.addAll(queues.played..shuffle(_random));
      queues.played.clear();
    }

    final next = queues.pending.removeAt(0);
    queues.played.add(next);
    await _save(game, queues);
    return next is Map<String, dynamic> ? next : null;
  }

  /// Put a freshly fetched round at the back of the queue.
  Future<void> add(String game, Map<String, dynamic> round) async {
    final queues = await _load(game);
    queues.pending.add(round);
    _trim(queues);
    await _save(game, queues);
  }

  /// Fetch until this game holds [roundsPerGame] rounds.
  ///
  /// Returns how many were added. Stops at the first failure rather than
  /// hammering a connection that has already dropped — a partial top-up is
  /// still a useful one.
  Future<int> refill(
    String game,
    Future<Map<String, dynamic>?> Function() fetchOne,
  ) async {
    var added = 0;
    while (await totalCount(game) < roundsPerGame) {
      Map<String, dynamic>? round;
      try {
        round = await fetchOne();
      } catch (_) {
        break;
      }
      if (round == null) {
        break;
      }
      await add(game, round);
      added++;
    }
    return added;
  }

  Future<void> clear(String game) async {
    final prefs = await _prefs;
    await prefs.remove(_key(game));
  }

  /// Oldest played rounds go first: they are the ones a player has seen most
  /// recently and would least like to see again.
  void _trim(_Queues queues) {
    while (queues.pending.length + queues.played.length > roundsPerGame) {
      if (queues.played.isNotEmpty) {
        queues.played.removeAt(0);
      } else {
        queues.pending.removeAt(0);
      }
    }
  }
}

class _Queues {
  _Queues(this.pending, this.played);

  final List<Object?> pending;
  final List<Object?> played;
}

/// Game identifiers used as cache keys. Strings rather than an enum so a new
/// game needs no migration of what is already stored.
class GameIds {
  static const wordFind = 'wordfind';
  static const wordBuild = 'wordbuild';
  static String practice(String kind) => 'round:$kind';

  static const all = [wordFind, wordBuild];
}
