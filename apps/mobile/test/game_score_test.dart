import 'package:flutter_test/flutter_test.dart';
import 'package:kamusi_mobile/data/game_score.dart';

void main() {
  const minute = Duration(minutes: 1);

  group('untimed', () {
    test('scores the difficulty with no bonus', () {
      // Playing without a clock must not mean playing for nothing.
      expect(GameScore.award(points: 60), 60);
    });

    test('a missing total is treated as untimed', () {
      expect(GameScore.award(points: 60, timeLeft: minute), 60);
    });

    test('a zero-length round does not divide by zero', () {
      expect(
        GameScore.award(points: 60, timeLeft: Duration.zero, total: Duration.zero),
        60,
      );
    });
  });

  group('timed', () {
    test('solving immediately is worth double', () {
      expect(
        GameScore.award(points: 60, timeLeft: minute, total: minute),
        120,
      );
    });

    test('solving as the clock expires is worth the difficulty alone', () {
      expect(
        GameScore.award(points: 60, timeLeft: Duration.zero, total: minute),
        60,
      );
    });

    test('halfway through is worth one and a half', () {
      expect(
        GameScore.award(
          points: 60,
          timeLeft: const Duration(seconds: 30),
          total: minute,
        ),
        90,
      );
    });

    test('a harder word is worth more at the same moment', () {
      final easy = GameScore.award(points: 40, timeLeft: minute, total: minute);
      final hard = GameScore.award(points: 90, timeLeft: minute, total: minute);

      expect(hard, greaterThan(easy));
    });

    test('the same word is worth more earlier than later', () {
      final early = GameScore.award(points: 60, timeLeft: minute, total: minute);
      final late = GameScore.award(
        points: 60,
        timeLeft: const Duration(seconds: 5),
        total: minute,
      );

      expect(early, greaterThan(late));
    });

    test('more time left than the round had cannot inflate the bonus', () {
      expect(
        GameScore.award(
          points: 60,
          timeLeft: const Duration(minutes: 10),
          total: minute,
        ),
        120,
      );
    });
  });
}
