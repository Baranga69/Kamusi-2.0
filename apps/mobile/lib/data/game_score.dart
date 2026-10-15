/// What a solved word is worth.
///
/// The difficulty half comes from the server, which scores every word the
/// same way for every game — finding "momonyoa" in the grid is worth what
/// building it in the ring is. The speed half can only be worked out here,
/// since only the client knows how long the player took.
class GameScore {
  const GameScore._();

  /// Points for one word, with the speed bonus applied.
  ///
  /// Solving the moment the clock starts is worth double; solving as it
  /// expires is worth the difficulty alone. Untimed play scores the
  /// difficulty with no bonus rather than no score: playing without a clock
  /// should not mean playing for nothing.
  static int award({
    required int points,
    Duration? timeLeft,
    Duration? total,
  }) {
    if (timeLeft == null || total == null || total.inSeconds <= 0) {
      return points;
    }
    final fraction = (timeLeft.inSeconds / total.inSeconds).clamp(0.0, 1.0);
    return (points * (1 + fraction)).round();
  }
}
