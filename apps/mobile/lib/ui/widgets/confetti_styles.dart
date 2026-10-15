import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_confetti/flutter_confetti.dart';

/// The catalogue of ways a win is allowed to look.
///
/// One celebration, however good, stops being a celebration around the fifth
/// time you see it — it becomes the screen the app shows when you finish.
/// Eight of them, rotated, means a player keeps meeting something they have
/// not seen, which is the cheapest form of delight there is.
///
/// Each style is a recipe for [Confetti.launch] rather than a widget: the
/// package draws into the overlay above everything, so the burst reads as
/// happening *in the room* rather than inside a box on the screen.
class ConfettiStyle {
  const ConfettiStyle({required this.name, required this.fire});

  /// For logs and tests, not for display. Players should never be told which
  /// confetti they got; being told turns a surprise into a feature list.
  final String name;

  final void Function(BuildContext context, List<Color> colors) fire;
}

/// Launch helpers shared by the styles below.
class _Fx {
  static final Random _random = Random();

  static double _between(double min, double max) =>
      min + _random.nextDouble() * (max - min);

  static void _burst(
    BuildContext context,
    ConfettiOptions options, {
    ParticleBuilder? particleBuilder,
  }) {
    // The dialog can be dismissed mid-sequence; a delayed burst into a dead
    // context would throw rather than celebrate.
    if (!context.mounted) {
      return;
    }
    Confetti.launch(context, options: options, particleBuilder: particleBuilder);
  }

  /// Fires [burst] [times] over [every], starting now.
  static void _repeat(
    BuildContext context,
    int times,
    Duration every,
    void Function(int index) burst,
  ) {
    for (var i = 0; i < times; i++) {
      if (i == 0) {
        burst(0);
        continue;
      }
      Timer(every * i, () {
        if (context.mounted) {
          burst(i);
        }
      });
    }
  }
}

/// All the styles, and the rotation that hands them out.
class ConfettiStyles {
  ConfettiStyles._();

  /// A straight burst up from low on the screen. The one everybody means
  /// when they say confetti, and the one worth seeing first.
  static final cannon = ConfettiStyle(
    name: 'cannon',
    fire: (context, colors) => _Fx._burst(
      context,
      ConfettiOptions(
        colors: colors,
        particleCount: 90,
        spread: 70,
        startVelocity: 46,
        y: 0.62,
      ),
    ),
  );

  /// Thrown off at an angle that changes every time, so two wins in a row
  /// do not look like the same animation replayed.
  static final randomDirection = ConfettiStyle(
    name: 'random-direction',
    fire: (context, colors) => _Fx._burst(
      context,
      ConfettiOptions(
        colors: colors,
        particleCount: 80,
        angle: _Fx._between(55, 125),
        spread: _Fx._between(50, 80),
        startVelocity: 50,
        y: _Fx._between(0.5, 0.7),
      ),
    ),
  );

  /// Five overlapping bursts of different weights. Real paper does not all
  /// leave the cannon at one speed, and the layering is what sells it.
  static final realistic = ConfettiStyle(
    name: 'realistic',
    fire: (context, colors) {
      void shot(double ratio, ConfettiOptions options) => _Fx._burst(
            context,
            options.copyWith(
              colors: colors,
              particleCount: (200 * ratio).round(),
            ),
          );
      shot(0.25, const ConfettiOptions(spread: 26, startVelocity: 55, y: 0.6));
      shot(0.2, const ConfettiOptions(spread: 60, y: 0.6));
      shot(0.35,
          const ConfettiOptions(spread: 100, decay: 0.91, scalar: 0.8, y: 0.6));
      shot(
        0.1,
        const ConfettiOptions(
            spread: 120, startVelocity: 25, decay: 0.92, scalar: 1.2, y: 0.6),
      );
      shot(0.1, const ConfettiOptions(spread: 120, startVelocity: 45, y: 0.6));
    },
  );

  /// Small shells going off around the screen for two seconds. The only
  /// style that lasts long enough to watch rather than catch.
  static final fireworks = ConfettiStyle(
    name: 'fireworks',
    fire: (context, colors) => _Fx._repeat(
      context,
      8,
      const Duration(milliseconds: 240),
      (_) {
        for (final side in const [(0.1, 0.35), (0.65, 0.9)]) {
          _Fx._burst(
            context,
            ConfettiOptions(
              colors: colors,
              particleCount: 36,
              startVelocity: 28,
              spread: 360,
              ticks: 70,
              decay: 0.92,
              x: _Fx._between(side.$1, side.$2),
              y: _Fx._between(0.2, 0.55),
            ),
          );
        }
      },
    ),
  );

  /// Gold stars with gravity turned off, so they hang and fade instead of
  /// falling. Reads as "achievement" where paper reads as "party".
  static final stars = ConfettiStyle(
    name: 'stars',
    fire: (context, colors) {
      final palette = [
        const Color(0xFFFFD700),
        const Color(0xFFFFC400),
        const Color(0xFFFF9E00),
        ...colors.take(2),
      ];
      void shot(double scalar, int count) => _Fx._burst(
            context,
            ConfettiOptions(
              colors: palette,
              particleCount: count,
              spread: 360,
              ticks: 90,
              gravity: 0,
              decay: 0.94,
              startVelocity: 26,
              scalar: scalar,
              y: 0.5,
            ),
            particleBuilder: (_) => Star(),
          );
      shot(1.2, 40);
      Timer(const Duration(milliseconds: 120), () {
        if (context.mounted) {
          shot(0.8, 24);
        }
      });
    },
  );

  /// A slow fall from the top edge across the full width. The quiet one —
  /// it earns its place by not being loud, which the others all are.
  static final snow = ConfettiStyle(
    name: 'snow',
    fire: (context, colors) => _Fx._repeat(
      context,
      4,
      const Duration(milliseconds: 400),
      (_) => _Fx._burst(
        context,
        ConfettiOptions(
          colors: [Colors.white, const Color(0xFFE3F2FD), ...colors.take(1)],
          particleCount: 24,
          angle: 270,
          spread: 50,
          startVelocity: 6,
          gravity: 0.32,
          decay: 0.99,
          ticks: 420,
          scalar: 1.1,
          randomX: true,
          driftVariance: 0.9,
          y: 0,
        ),
        particleBuilder: (_) => Snowflake(),
      ),
    ),
  );

  /// Two cannons firing in from the edges, three volleys. The stadium one.
  static final sideCannons = ConfettiStyle(
    name: 'side-cannons',
    fire: (context, colors) => _Fx._repeat(
      context,
      3,
      const Duration(milliseconds: 280),
      (_) {
        for (final cannon in const [(0.0, 60.0), (1.0, 120.0)]) {
          _Fx._burst(
            context,
            ConfettiOptions(
              colors: colors,
              particleCount: 50,
              angle: cannon.$2,
              spread: 60,
              startVelocity: 58,
              x: cannon.$1,
              y: 0.72,
            ),
          );
        }
      },
    ),
  );

  /// Emoji instead of paper. Silly on purpose: it is the style that makes
  /// someone show the screen to the person next to them.
  static final emoji = ConfettiStyle(
    name: 'emoji',
    fire: (context, colors) {
      const faces = ['🎉', '🎊', '✨', '🏆', '💫', '🥳'];
      _Fx._burst(
        context,
        ConfettiOptions(
          colors: colors,
          particleCount: 34,
          spread: 100,
          startVelocity: 42,
          scalar: 2.2,
          ticks: 160,
          y: 0.65,
        ),
        particleBuilder: (index) => Emoji(emoji: faces[index % faces.length]),
      );
    },
  );

  /// Order matters only in that [cannon] is first: a brand-new player's very
  /// first win gets the one that is unmistakably confetti.
  static final List<ConfettiStyle> all = [
    cannon,
    realistic,
    fireworks,
    stars,
    sideCannons,
    emoji,
    randomDirection,
    snow,
  ];

  /// Which style the [plays]-th celebration gets.
  ///
  /// Not `Random().nextInt` — a coin flip repeats, and a player can easily
  /// see the same burst three times running and conclude there is only one.
  /// This deals out every style once before any repeats, then reshuffles, so
  /// over a dozen games you meet all eight and never in the same order twice.
  static int indexFor(int plays) {
    final count = all.length;
    final cycle = plays ~/ count;
    final step = plays % count;
    // First cycle is left in authored order so the first win is the cannon.
    if (cycle == 0) {
      return step;
    }
    final order = List<int>.generate(count, (i) => i)..shuffle(Random(cycle));
    return order[step];
  }

  static ConfettiStyle styleFor(int plays) => all[indexFor(plays)];
}
