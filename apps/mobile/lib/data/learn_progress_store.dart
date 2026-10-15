import 'package:shared_preferences/shared_preferences.dart';

/// How far along the learner is.
class LearnProgress {
  const LearnProgress({
    required this.currentStreak,
    required this.bestStreak,
    required this.lastCompletedDay,
    required this.totalCorrect,
    required this.totalAnswered,
  });

  static const empty = LearnProgress(
    currentStreak: 0,
    bestStreak: 0,
    lastCompletedDay: null,
    totalCorrect: 0,
    totalAnswered: 0,
  );

  final int currentStreak;
  final int bestStreak;

  /// UTC day, as `yyyy-MM-dd`, of the last finished daily challenge.
  final String? lastCompletedDay;
  final int totalCorrect;
  final int totalAnswered;

  bool completedOn(String day) => lastCompletedDay == day;

  int get accuracyPercent =>
      totalAnswered == 0 ? 0 : ((totalCorrect / totalAnswered) * 100).round();
}

/// Streak and tally, stored on the device.
///
/// Deliberately local: progress is a nudge for the learner, not a record the
/// dictionary needs. Keeping it off the server means no account is required to
/// start learning, and nothing to migrate if the shape changes.
class LearnProgressStore {
  static const _streakKey = 'kamusi_learn_streak';
  static const _bestStreakKey = 'kamusi_learn_best_streak';
  static const _lastDayKey = 'kamusi_learn_last_day';
  static const _correctKey = 'kamusi_learn_total_correct';
  static const _answeredKey = 'kamusi_learn_total_answered';

  /// UTC so a streak cannot be gamed by changing time zone, and so it matches
  /// the day the API seeds the daily round from.
  static String dayKey([DateTime? at]) {
    final moment = (at ?? DateTime.now()).toUtc();
    final month = moment.month.toString().padLeft(2, '0');
    final day = moment.day.toString().padLeft(2, '0');
    return '${moment.year}-$month-$day';
  }

  static String _previousDayKey(String day) {
    // The 'Z' matters: `DateTime.parse('2026-10-05')` is *local* midnight, so
    // converting it back to UTC shifts it a day in any positive offset and the
    // streak never joins up.
    final parsed = DateTime.tryParse('${day}T00:00:00Z');
    if (parsed == null) {
      return '';
    }
    return dayKey(parsed.subtract(const Duration(days: 1)));
  }

  Future<LearnProgress> load() async {
    final prefs = await SharedPreferences.getInstance();
    return LearnProgress(
      currentStreak: prefs.getInt(_streakKey) ?? 0,
      bestStreak: prefs.getInt(_bestStreakKey) ?? 0,
      lastCompletedDay: prefs.getString(_lastDayKey),
      totalCorrect: prefs.getInt(_correctKey) ?? 0,
      totalAnswered: prefs.getInt(_answeredKey) ?? 0,
    );
  }

  /// Record a finished daily challenge.
  ///
  /// Finishing the same day twice does not extend the streak, and a gap of
  /// more than a day restarts it at 1 rather than zeroing it — you turned up
  /// today, which is worth something.
  Future<LearnProgress> completeDaily({
    required int correct,
    required int answered,
    DateTime? at,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = dayKey(at);
    final previous = await load();

    var streak = previous.currentStreak;
    if (previous.lastCompletedDay != today) {
      streak = previous.lastCompletedDay == _previousDayKey(today) ? streak + 1 : 1;
      await prefs.setString(_lastDayKey, today);
      await prefs.setInt(_streakKey, streak);
    }

    final best = streak > previous.bestStreak ? streak : previous.bestStreak;
    await prefs.setInt(_bestStreakKey, best);
    await prefs.setInt(_correctKey, previous.totalCorrect + correct);
    await prefs.setInt(_answeredKey, previous.totalAnswered + answered);

    return LearnProgress(
      currentStreak: streak,
      bestStreak: best,
      lastCompletedDay: today,
      totalCorrect: previous.totalCorrect + correct,
      totalAnswered: previous.totalAnswered + answered,
    );
  }

  /// Practice counts towards the tally but never towards the streak.
  Future<LearnProgress> recordPractice({
    required int correct,
    required int answered,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = await load();
    await prefs.setInt(_correctKey, previous.totalCorrect + correct);
    await prefs.setInt(_answeredKey, previous.totalAnswered + answered);
    return LearnProgress(
      currentStreak: previous.currentStreak,
      bestStreak: previous.bestStreak,
      lastCompletedDay: previous.lastCompletedDay,
      totalCorrect: previous.totalCorrect + correct,
      totalAnswered: previous.totalAnswered + answered,
    );
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [_streakKey, _bestStreakKey, _lastDayKey, _correctKey, _answeredKey]) {
      await prefs.remove(key);
    }
  }
}
