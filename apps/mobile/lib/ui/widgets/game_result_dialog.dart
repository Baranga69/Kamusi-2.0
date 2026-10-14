import 'package:flutter/material.dart';

import '../../data/game_round_cache.dart';
import '../../l10n/app_localizations.dart';
import '../theme/kamusi_learn_colors.dart';
import 'confetti_styles.dart';

/// What a finished board says back, and where it sends you next.
///
/// This replaced a bottom sheet. A sheet slides up from the edge and reads as
/// a panel of options attached to the board you just left; finishing deserves
/// to take over the screen for a moment. It is also the only place a player
/// sees their total, so the total is the biggest thing on it — bigger than
/// the buttons, bigger than the title.
///
/// Shown for a timed board that ran out too. Running out is also an ending,
/// and it is the moment a player most wants to know what they scored. The
/// confetti is the one thing withheld: paper for running out of time would be
/// the app laughing at you.
///
/// Returns the id of the game to play next, or null to go back to Jifunze.
/// The caller pops with that value so the hub can launch it, which keeps the
/// screens from having to know how to start each other.
Future<String?> showGameResultDialog(
  BuildContext context, {
  required String game,
  required Color accent,
  required int score,
  required int best,
  required bool isNewBest,
  required int found,
  required int total,
  required bool completed,
  required int celebration,
}) {
  return showDialog<String>(
    context: context,
    // Not dismissible by tapping away: the two choices are "play" and
    // "menu", and a stray tap on the barrier would quietly pick menu and
    // close the board with it.
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    builder: (dialogContext) => _GameResultDialog(
      game: game,
      accent: accent,
      score: score,
      best: best,
      isNewBest: isNewBest,
      found: found,
      total: total,
      completed: completed,
      celebration: celebration,
    ),
  );
}

class _GameResultDialog extends StatefulWidget {
  const _GameResultDialog({
    required this.game,
    required this.accent,
    required this.score,
    required this.best,
    required this.isNewBest,
    required this.found,
    required this.total,
    required this.completed,
    required this.celebration,
  });

  final String game;
  final Color accent;
  final int score;
  final int best;
  final bool isNewBest;
  final int found;
  final int total;
  final bool completed;

  /// How many wins this player has celebrated. Picks the confetti.
  final int celebration;

  @override
  State<_GameResultDialog> createState() => _GameResultDialogState();
}

class _GameResultDialogState extends State<_GameResultDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  late final Animation<double> _count = CurvedAnimation(
    parent: _controller,
    // Fast then settling, so the number looks like it is landing on a value
    // rather than being typed out.
    curve: const Interval(0.1, 0.8, curve: Curves.easeOutCubic),
  );

  late final Animation<double> _badge = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.5, curve: Curves.elasticOut),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
    if (widget.completed) {
      // After the first frame: the overlay the confetti inserts into does not
      // exist until this route is up, and firing into it early does nothing.
      WidgetsBinding.instance.addPostFrameCallback((_) => _celebrate());
    }
  }

  void _celebrate() {
    if (!mounted) {
      return;
    }
    final theme = Theme.of(context);
    final learnColors = theme.extension<KamusiLearnColors>();
    ConfettiStyles.styleFor(widget.celebration).fire(context, [
      widget.accent,
      learnColors?.streak ?? theme.colorScheme.tertiary,
      learnColors?.correct ?? theme.colorScheme.primary,
      learnColors?.gameAccentB ?? theme.colorScheme.secondary,
      theme.colorScheme.primary,
    ]);
  }

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
    final others =
        GameIds.all.where((id) => id != widget.game).toList(growable: false);
    // Everything here is sized so the "back to menu" button stays above the
    // fold: a celebration you have to scroll to leave is not a celebration.
    // Short screens get the same dialog, tightened, rather than a scrollbar.
    final compact = MediaQuery.sizeOf(context).height < 740;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // A band of accent behind the badge, so the dialog is coloured by
            // the game you just played rather than being the same white card
            // for all three.
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                  top: compact ? 20 : 28, bottom: compact ? 14 : 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.accent.withValues(alpha: 0.26),
                    widget.accent.withValues(alpha: 0.06),
                  ],
                ),
              ),
              child: Column(
                children: [
                  ScaleTransition(
                    scale: _badge,
                    child: Container(
                      width: compact ? 62 : 76,
                      height: compact ? 62 : 76,
                      decoration: BoxDecoration(
                        color: widget.accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: widget.accent.withValues(alpha: 0.45),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.completed
                            ? Icons.emoji_events_rounded
                            : Icons.timer_off_rounded,
                        color: Colors.white,
                        size: compact ? 32 : 40,
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 10 : 14),
                  Text(
                    widget.completed
                        ? l10n.learnDoneTitle
                        : l10n.learnDonePartial,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.learnDoneFound(widget.found, widget.total),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(22, compact ? 14 : 20, 22, compact ? 12 : 20),
              child: Column(
                children: [
                  Text(
                    l10n.learnDoneTotal,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 1.2,
                    ),
                  ),
                  // The whole point of the dialog. Counts up, because a number
                  // that simply appears reads as a label and one that climbs
                  // reads as something you earned.
                  AnimatedBuilder(
                    animation: _count,
                    builder: (context, _) => Text(
                      '${(widget.score * _count.value).round()}',
                      style: (compact
                              ? theme.textTheme.displayMedium
                              : theme.textTheme.displayLarge)
                          ?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: widget.accent,
                        height: 1.05,
                        letterSpacing: -2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 6 : 8),
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
                  SizedBox(height: compact ? 16 : 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.accent,
                        foregroundColor: Colors.white,
                        padding:
                            EdgeInsets.symmetric(vertical: compact ? 13 : 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        textStyle: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(l10n.learnDoneAgain),
                      onPressed: () =>
                          Navigator.of(context).pop(widget.game),
                    ),
                  ),
                  SizedBox(height: compact ? 13 : 18),
                  Text(
                    l10n.learnDoneOther,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  SizedBox(height: compact ? 8 : 10),
                  // Straight into either of the other two games. Finishing is
                  // exactly when someone is most willing to play again, and
                  // making them walk back to the hub to choose spends that.
                  Row(
                    children: [
                      for (final id in others) ...[
                        Expanded(child: _NextGameChip(game: id)),
                        if (id != others.last) const SizedBox(width: 10),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.learnDoneMenu),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the other two games, as something you can tap from here.
class _NextGameChip extends StatelessWidget {
  const _NextGameChip({required this.game});

  final String game;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final learnColors = theme.extension<KamusiLearnColors>();
    final (label, icon, accent) = switch (game) {
      GameIds.wordFind => (
          l10n.learnWordFindTitle,
          Icons.grid_on_rounded,
          learnColors?.gameAccentA ?? theme.colorScheme.primary,
        ),
      GameIds.wordBuild => (
          l10n.learnWordBuildTitle,
          Icons.bubble_chart_rounded,
          learnColors?.gameAccentB ?? theme.colorScheme.secondary,
        ),
      _ => (
          l10n.learnCrosswordTitle,
          Icons.grid_4x4_rounded,
          learnColors?.gameAccentC ?? theme.colorScheme.tertiary,
        ),
    };

    return Material(
      color: accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).pop(game),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: accent, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: accent,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
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
