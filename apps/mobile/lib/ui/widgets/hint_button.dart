import 'package:flutter/material.dart';

import '../theme/kamusi_learn_colors.dart';

/// Ask for help, with what is left and what it costs both on the button.
///
/// Priced and limited rather than free and endless: a hint you can take
/// forever is just the answer with extra steps. Showing the cost up front
/// means nobody spends points by accident.
class HintButton extends StatelessWidget {
  const HintButton({
    super.key,
    required this.remaining,
    required this.cost,
    required this.label,
    required this.onPressed,
  });

  final int remaining;
  final int cost;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final learnColors = theme.extension<KamusiLearnColors>();
    final spent = remaining <= 0;
    final accent = learnColors?.streak ?? theme.colorScheme.tertiary;

    return TextButton.icon(
      onPressed: spent ? null : onPressed,
      style: TextButton.styleFrom(
        foregroundColor: accent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      icon: Icon(spent ? Icons.lightbulb_outline : Icons.lightbulb, size: 18),
      label: Text(
        spent ? label : '$label  ·  $remaining  ·  −$cost',
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: spent ? theme.colorScheme.onSurfaceVariant : accent,
        ),
      ),
    );
  }
}
