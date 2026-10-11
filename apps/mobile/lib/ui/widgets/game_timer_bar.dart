import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/kamusi_learn_colors.dart';

/// A countdown across the top of a timed game.
///
/// Owns its own ticker so a game screen does not have to: the screens are
/// already busy with gesture state, and three of them would otherwise repeat
/// the same timer plumbing three times.
///
/// It warns before it ends. Running out with no notice feels like the app
/// broke rather than like losing, so the bar turns amber for the last quarter
/// and the remaining seconds are always readable.
class GameTimerBar extends StatefulWidget {
  const GameTimerBar({
    super.key,
    required this.duration,
    required this.onExpired,
    this.paused = false,
  });

  final Duration duration;
  final VoidCallback onExpired;

  /// True once the game is over, so the clock stops where it stopped rather
  /// than carrying on under a finished board.
  final bool paused;

  @override
  State<GameTimerBar> createState() => _GameTimerBarState();
}

class _GameTimerBarState extends State<GameTimerBar> {
  Timer? _ticker;
  late Duration _left = widget.duration;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(GameTimerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.paused && !oldWidget.paused) {
      _ticker?.cancel();
    } else if (!widget.paused && oldWidget.paused) {
      _start();
    }
  }

  void _start() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      final next = _left - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        setState(() => _left = Duration.zero);
        _ticker?.cancel();
        widget.onExpired();
        return;
      }
      setState(() => _left = next);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String get _label {
    final minutes = _left.inMinutes;
    final seconds = _left.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final learnColors = theme.extension<KamusiLearnColors>();
    final fraction = widget.duration.inSeconds == 0
        ? 0.0
        : _left.inSeconds / widget.duration.inSeconds;
    final runningLow = fraction <= 0.25;

    final barColor = runningLow
        ? (learnColors?.incorrect ?? theme.colorScheme.error)
        : (learnColors?.correct ?? theme.colorScheme.primary);

    return Row(
      children: [
        Icon(
          Icons.timer_outlined,
          size: 16,
          color: runningLow ? barColor : theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          child: Text(
            _label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              // Fixed width digits, so the bar does not jitter every second.
              fontFeatures: const [FontFeature.tabularFigures()],
              color: runningLow ? barColor : theme.colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 400),
              tween: Tween(begin: fraction, end: fraction),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: learnColors?.progressTrack ??
                    theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
