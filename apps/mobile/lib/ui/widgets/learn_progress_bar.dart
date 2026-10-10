import 'package:flutter/material.dart';

import '../theme/kamusi_learn_colors.dart';

/// How far through a round you are.
///
/// A bar rather than "3 of 5" alone: progress you can see at a glance is what
/// makes a five-question round feel finishable.
class LearnProgressBar extends StatelessWidget {
  const LearnProgressBar({
    super.key,
    required this.answered,
    required this.total,
  });

  final int answered;
  final int total;

  @override
  Widget build(BuildContext context) {
    final learn = KamusiLearnColors.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final fraction = total == 0 ? 0.0 : (answered / total).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: fraction),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => LinearProgressIndicator(
          value: value,
          minHeight: 6,
          backgroundColor: learn.progressTrack,
          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.secondary),
        ),
      ),
    );
  }
}

/// A streak, shown as a count beside a flame.
class StreakChip extends StatelessWidget {
  const StreakChip({super.key, required this.label, this.lit = true});

  final String label;

  /// Unlit when there is no streak yet, so the flame is something to earn.
  final bool lit;

  @override
  Widget build(BuildContext context) {
    final learn = KamusiLearnColors.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tint = lit ? learn.streak : colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            lit ? Icons.local_fire_department : Icons.local_fire_department_outlined,
            size: 16,
            color: tint,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: lit ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
