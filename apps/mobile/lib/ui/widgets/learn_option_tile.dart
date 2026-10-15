import 'package:flutter/material.dart';

import '../theme/kamusi_learn_colors.dart';
import '../theme/kamusi_typography.dart';

enum OptionState { idle, selected, correct, incorrect, revealed }

/// One answer choice.
///
/// The feedback is colour *and* an icon, never colour alone — a learner who
/// cannot distinguish the greens still needs to know whether they were right
/// (DESIGN_SYSTEM.md, accessibility).
class LearnOptionTile extends StatelessWidget {
  const LearnOptionTile({
    super.key,
    required this.label,
    required this.state,
    required this.onTap,
    this.serif = false,
  });

  final String label;
  final OptionState state;
  final VoidCallback? onTap;

  /// Definitions and proverbs are content, so they get the reading face.
  final bool serif;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final learn = KamusiLearnColors.of(context);

    late final Color background;
    late final Color border;
    late final Color foreground;
    IconData? icon;

    switch (state) {
      case OptionState.idle:
        background = colorScheme.surface;
        border = colorScheme.outlineVariant;
        foreground = colorScheme.onSurface;
      case OptionState.selected:
        background = colorScheme.secondaryContainer;
        border = colorScheme.secondary;
        foreground = colorScheme.onSecondaryContainer;
      case OptionState.correct:
        background = learn.correctContainer;
        border = learn.correct;
        foreground = colorScheme.onSurface;
        icon = Icons.check_circle_outline;
      case OptionState.incorrect:
        background = learn.incorrectContainer;
        border = learn.incorrect;
        foreground = colorScheme.onSurface;
        icon = Icons.cancel_outlined;
      case OptionState.revealed:
        // The right answer, shown after a wrong guess.
        background = learn.correctContainer;
        border = learn.correct;
        foreground = colorScheme.onSurface;
        icon = Icons.arrow_right_alt;
    }

    final style = textTheme.bodyLarge?.copyWith(color: foreground, height: 1.4);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: state == OptionState.idle ? 1 : 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(label, style: serif ? KamusiTypography.serif(style) : style),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 12),
                  Icon(icon, size: 20, color: border),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
