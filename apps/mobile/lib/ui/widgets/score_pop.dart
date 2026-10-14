import 'package:flutter/material.dart';

/// "+45" drifting up off the board when a word lands.
///
/// The score already changed in the corner, but a number that quietly becomes
/// a different number tells you nothing about *why*. This ties the points to
/// the moment you earned them, which is the whole reason a scoring game feels
/// like one.
///
/// Self-removing: it reports back when the animation ends so the parent can
/// drop it, rather than accumulating invisible widgets over a long board.
class ScorePop extends StatefulWidget {
  const ScorePop({
    super.key,
    required this.points,
    required this.color,
    required this.onDone,
  });

  final int points;
  final Color color;
  final VoidCallback onDone;

  @override
  State<ScorePop> createState() => _ScorePopState();
}

class _ScorePopState extends State<ScorePop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  )..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          // Up and out: fast at first, then easing, so it reads as a thing
          // thrown rather than a thing scrolled.
          final rise = Curves.easeOutCubic.transform(t);
          // Hold at full strength briefly, then fade. Fading from the first
          // frame makes it look like a mistake.
          final opacity = t < 0.25 ? 1.0 : (1 - (t - 0.25) / 0.75).clamp(0.0, 1.0);
          // A small overshoot on the way in gives it a bit of weight.
          final scale = 0.75 + Curves.easeOutBack.transform(t.clamp(0.0, 0.4) / 0.4) * 0.35;

          return Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(0, -64 * rise),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    '+${widget.points}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The running score, big and bare.
///
/// Modelled on the reference: a large dark numeral with no label and no
/// container, which reads as a scoreboard where a small figure beside a
/// progress bar reads as a statistic. It rolls to each new value rather than
/// cutting, so a jump of forty looks like forty.
class BigScore extends StatelessWidget {
  const BigScore({super.key, required this.score, this.color});

  final int score;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: score.toDouble()),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => Text(
        '${value.round()}',
        style: theme.textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w900,
          color: color ?? theme.colorScheme.onSurface,
          height: 1,
          // Fixed-width digits, so the number does not jitter as it rolls.
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
