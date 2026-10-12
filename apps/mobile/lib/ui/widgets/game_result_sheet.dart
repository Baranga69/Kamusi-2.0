import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/kamusi_learn_colors.dart';
import 'confetti_overlay.dart';

/// What a finished board says back.
///
/// Before this, completing a game did nothing at all: the last word turned
/// green and the screen sat there. Finishing something has to feel like
/// finishing something — the score counts up rather than appearing, paper
/// falls, and a new personal best is called out, because that is the number
/// anyone comes back to beat.
///
/// Shown for a timed board that ran out too. Running out is also an ending,
/// and it is the moment a player most wants to know what they scored.
class GameResultSheet extends StatefulWidget {
  const GameResultSheet({
    super.key,
    required this.accent,
    required this.score,
    required this.best,
    required this.isNewBest,
    required this.found,
    required this.total,
    required this.completed,
    required this.onAgain,
  });

  final Color accent;
  final int score;
  final int best;
  final bool isNewBest;
  final int found;
  final int total;

  /// True when every word was solved, false when the clock ended it.
  final bool completed;

  final VoidCallback onAgain;

  @override
  State<GameResultSheet> createState() => _GameResultSheetState();
}

class _GameResultSheetState extends State<GameResultSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final Animation<double> _count = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final learnColors = theme.extension<KamusiLearnColors>();

    return Stack(
      children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: widget.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.completed
                        ? Icons.emoji_events_rounded
                        : Icons.timer_off_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.completed ? l10n.learnDoneTitle : l10n.learnDonePartial,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.learnDoneFound(widget.found, widget.total),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 22),
                Text(
                  l10n.learnDoneScore,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                // Counts up. A number that lands all at once reads as a label;
                // one that climbs reads as something you earned.
                AnimatedBuilder(
                  animation: _count,
                  builder: (context, _) => Text(
                    '${(widget.score * _count.value).round()}',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: widget.accent,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (widget.isNewBest)
                  _Badge(
                    label: l10n.learnDoneNewBest,
                    color: learnColors?.streak ?? widget.accent,
                    icon: Icons.local_fire_department_rounded,
                  )
                else
                  Text(
                    l10n.learnDoneBest(widget.best),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.learnDoneClose),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: widget.accent,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: widget.onAgain,
                        child: Text(l10n.learnDoneAgain),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Only when the board was actually finished. Paper for running out of
        // time would be the app laughing at you.
        if (widget.completed)
          Positioned.fill(
            child: ConfettiOverlay(
              colors: [
                widget.accent,
                learnColors?.streak ?? theme.colorScheme.tertiary,
                learnColors?.correct ?? theme.colorScheme.primary,
                theme.colorScheme.primary,
              ],
            ),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, required this.icon});

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}
