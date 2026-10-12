import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Paper falling down the screen when a board is finished.
///
/// Hand-rolled rather than a package: it is one painter and a physics step,
/// and a dependency for this would be heavier than the thing it draws. Each
/// piece gets its own speed, drift, spin and colour so the fall reads as a
/// scatter rather than a grid of rectangles descending in step.
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({
    super.key,
    required this.colors,
    this.pieces = 70,
    this.duration = const Duration(seconds: 4),
  });

  final List<Color> colors;
  final int pieces;
  final Duration duration;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  late final List<_Piece> _pieces = List<_Piece>.generate(
    widget.pieces,
    (index) => _Piece.random(math.Random(index * 7919), widget.colors),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_pieces, _controller.value),
        ),
      ),
    );
  }
}

class _Piece {
  _Piece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.drift,
    required this.spin,
    required this.size,
    required this.color,
    required this.rectangular,
  });

  /// Horizontal start, as a fraction of the width.
  final double x;

  /// How far into the animation this piece starts falling, so they do not all
  /// leave the top edge together.
  final double delay;
  final double speed;
  final double drift;
  final double spin;
  final double size;
  final Color color;
  final bool rectangular;

  factory _Piece.random(math.Random random, List<Color> colors) {
    return _Piece(
      x: random.nextDouble(),
      delay: random.nextDouble() * 0.35,
      speed: 0.75 + random.nextDouble() * 0.6,
      drift: (random.nextDouble() - 0.5) * 0.36,
      spin: (random.nextDouble() - 0.5) * 14,
      size: 7 + random.nextDouble() * 9,
      color: colors[random.nextInt(colors.length)],
      rectangular: random.nextBool(),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.progress);

  final List<_Piece> pieces;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final piece in pieces) {
      final t = (progress - piece.delay) / (1 - piece.delay);
      if (t <= 0) {
        continue;
      }
      final fall = t * piece.speed;
      // Start just above the top edge so nothing pops into existence.
      final y = -0.08 * size.height + fall * size.height * 1.25;
      if (y > size.height) {
        continue;
      }
      // Drift sideways on a sine, so it sways rather than slides.
      final x = (piece.x + piece.drift * math.sin(t * math.pi * 2)) * size.width;

      // Fade out over the last third rather than vanishing mid-air.
      final opacity = t > 0.7 ? (1 - (t - 0.7) / 0.3).clamp(0.0, 1.0) : 1.0;
      paint.color = piece.color.withValues(alpha: opacity);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * piece.spin);
      if (piece.rectangular) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: piece.size,
            height: piece.size * 0.55,
          ),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, piece.size * 0.38, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
