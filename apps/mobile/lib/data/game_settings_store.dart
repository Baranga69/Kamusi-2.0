import 'package:shared_preferences/shared_preferences.dart';

/// Preferences that apply across the Jifunze games.
///
/// One setting rather than a switch per game: timed or untimed is a mood a
/// player is in, not a property of a particular puzzle, and asking them again
/// on every board would be noise.
class GameSettingsStore {
  GameSettingsStore({this.namespace = 'kamusi_game_settings'});

  final String namespace;

  String get _timedKey => '$namespace:timed';
  String get _soundKey => '$namespace:sound';
  String get _hapticsKey => '$namespace:haptics';

  /// Off by default. A clock changes a learning game into a test, and that
  /// should be something a person opts into rather than meets unannounced.
  Future<bool> loadTimed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_timedKey) ?? false;
  }

  Future<bool> setTimed(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_timedKey, value);
    return value;
  }

  /// Both on by default. A game that is silent and still until you go
  /// looking for a switch has no way to tell you it is a game — but it must
  /// be one switch away for anyone on a bus, in a lecture, or simply tired
  /// of it.
  Future<bool> loadSound() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_soundKey) ?? true;
  }

  Future<bool> setSound(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundKey, value);
    return value;
  }

  Future<bool> loadHaptics() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hapticsKey) ?? true;
  }

  Future<bool> setHaptics(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticsKey, value);
    return value;
  }

  String _bestKey(String game) => '$namespace:best:$game';

  Future<int> bestScore(String game) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_bestKey(game)) ?? 0;
  }

  /// Keeps [score] if it beats what is stored, and reports the best after.
  ///
  /// Only the best is kept, not a history: this is a dictionary with a
  /// learning surface, not a leaderboard, and one number is enough to give
  /// a player something to beat.
  Future<int> recordScore(String game, int score) async {
    final prefs = await SharedPreferences.getInstance();
    final best = prefs.getInt(_bestKey(game)) ?? 0;
    if (score <= best) {
      return best;
    }
    await prefs.setInt(_bestKey(game), score);
    return score;
  }
}

/// Help, and what it costs.
///
/// Hints are limited and priced rather than free and endless, because a hint
/// you can take forever is just the answer with extra steps. Three is enough
/// to get unstuck on a board you would otherwise abandon, and the cost is
/// visible before you spend it.
class GameHints {
  /// Per board, not per word.
  static const perBoard = 3;

  /// Deducted from the score the moment a hint is taken. The score floors at
  /// zero: a bad round should not leave someone in debt.
  static const cost = 20;
}

/// How long each game gets when the clock is on.
///
/// Set from how long the boards actually take: the grid is a hunt and wants
/// room, the ring is quicker once you see the pangram, and the codeword is
/// deduction and needs the most.
class GameDurations {
  static const wordFind = Duration(minutes: 3);
  static const wordBuild = Duration(minutes: 3);
  static const crossword = Duration(minutes: 6);
}
