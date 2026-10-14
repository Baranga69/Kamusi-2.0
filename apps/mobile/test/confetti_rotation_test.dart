import 'package:flutter_test/flutter_test.dart';
import 'package:kamusi_mobile/ui/widgets/confetti_styles.dart';

/// The promise this makes is "you will see all of them": a player should meet
/// every confetti style before any of them comes round again. That is easy to
/// break by reaching for Random, and impossible to notice by hand, since it
/// takes a dozen finished boards to show up.
void main() {
  final count = ConfettiStyles.all.length;

  test('there is more than one style to rotate through', () {
    expect(count, greaterThan(1));
  });

  test('every style is handed out exactly once per cycle', () {
    for (var cycle = 0; cycle < 12; cycle++) {
      final dealt = <int>[];
      for (var step = 0; step < count; step++) {
        dealt.add(ConfettiStyles.indexFor(cycle * count + step));
      }
      expect(
        dealt.toSet().length,
        count,
        reason: 'cycle $cycle repeated a style before using them all: $dealt',
      );
    }
  });

  test('a first win always gets the plain cannon', () {
    expect(ConfettiStyles.styleFor(0).name, 'cannon');
  });

  test('the order changes between cycles', () {
    List<int> order(int cycle) => [
          for (var step = 0; step < count; step++)
            ConfettiStyles.indexFor(cycle * count + step),
        ];
    // Not every pair has to differ — a shuffle may coincide — but ten cycles
    // all in the authored order would mean the shuffle is not running.
    final orders = {for (var cycle = 0; cycle < 10; cycle++) order(cycle).join(',')};
    expect(orders.length, greaterThan(1));
  });

  test('indexes stay inside the catalogue', () {
    for (var plays = 0; plays < 500; plays++) {
      final index = ConfettiStyles.indexFor(plays);
      expect(index, inInclusiveRange(0, count - 1));
    }
  });

  test('styles are distinctly named', () {
    expect(
      ConfettiStyles.all.map((style) => style.name).toSet().length,
      count,
    );
  });
}
