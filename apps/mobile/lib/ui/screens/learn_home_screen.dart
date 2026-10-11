import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../data/game_round_cache.dart';
import '../../data/learn_progress_store.dart';
import '../../domain/models/learn_round.dart';
import '../../providers/learn_providers.dart';
import '../theme/kamusi_learn_colors.dart';
import '../theme/kamusi_typography.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/learn_progress_bar.dart';
import 'learn_round_screen.dart';
import 'crossword_screen.dart';
import 'word_build_screen.dart';
import 'word_find_screen.dart';

/// The Jifunze surface.
///
/// Where the dictionary is deliberately quiet, this screen is allowed warmth
/// and motion — but it earns it by being a place you choose to go, so looking
/// a word up is never interrupted by a game. One obvious thing to do today,
/// then practice if you want more.
class LearnHomeScreen extends ConsumerWidget {
  const LearnHomeScreen({super.key});

  static const _practiceKinds = ['definition', 'meaning', 'methali', 'mixed'];

  String _kindLabel(AppLocalizations l10n, String kind) {
    switch (kind) {
      case 'definition':
        return l10n.learnKindDefinition;
      case 'meaning':
        return l10n.learnKindMeaning;
      case 'methali':
        return l10n.learnKindMethali;
      default:
        return l10n.learnKindMixed;
    }
  }

  IconData _kindIcon(String kind) {
    switch (kind) {
      case 'definition':
        return Icons.menu_book_outlined;
      case 'meaning':
        return Icons.lightbulb_outline;
      case 'methali':
        return Icons.format_quote_outlined;
      default:
        return Icons.shuffle;
    }
  }

  Future<void> _play(
    BuildContext context,
    WidgetRef ref, {
    required LearnRound round,
    required bool isDaily,
    required String title,
  }) async {
    final again = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LearnRoundScreen(round: round, isDaily: isDaily, title: title),
      ),
    );
    if (again == true && context.mounted) {
      // "Play again" after the daily round means a fresh practice round of
      // the same mix, since the daily one is fixed for the day.
      ref.invalidate(practiceRoundProvider('mixed'));
      final practice = await ref.read(practiceRoundProvider('mixed').future);
      if (practice.isEmpty || !context.mounted) {
        return;
      }
      await _play(
        context,
        ref,
        round: practice,
        isDaily: false,
        title: _kindLabel(AppLocalizations.of(context)!, 'mixed'),
      );
    }
  }

  Future<void> _openWordFind(BuildContext context, WidgetRef ref,
      AppLocalizations l10n, bool timed) async {
    ref.invalidate(wordFindProvider);
    try {
      final puzzle = await ref.read(wordFindProvider.future);
      if (!context.mounted) {
        return;
      }
      if (puzzle.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.learnEmptyBody)));
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WordFindScreen(puzzle: puzzle, timed: timed),
        ),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      // 404 when nothing published is shaped for a board yet, which is a
      // content state rather than a failure.
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.learnEmptyBody)));
    }
    ref.invalidate(gameRoundsReadyProvider);
  }

  Future<void> _openWordBuild(BuildContext context, WidgetRef ref,
      AppLocalizations l10n, bool timed) async {
    ref.invalidate(wordBuildProvider);
    try {
      final puzzle = await ref.read(wordBuildProvider.future);
      if (!context.mounted) {
        return;
      }
      if (puzzle.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.learnEmptyBody)));
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WordBuildScreen(puzzle: puzzle, timed: timed),
        ),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.learnEmptyBody)));
    }
    ref.invalidate(gameRoundsReadyProvider);
  }

  Future<void> _openCrossword(BuildContext context, WidgetRef ref,
      AppLocalizations l10n, bool timed) async {
    ref.invalidate(crosswordProvider);
    try {
      final puzzle = await ref.read(crosswordProvider.future);
      if (!context.mounted) {
        return;
      }
      if (puzzle.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.learnEmptyBody)));
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CrosswordScreen(puzzle: puzzle, timed: timed),
        ),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.learnEmptyBody)));
    }
    ref.invalidate(gameRoundsReadyProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final daily = ref.watch(dailyRoundProvider);
    final progress = ref.watch(learnProgressProvider);
    final timed = ref.watch(timedModeProvider).value ?? false;
    final learnColors = theme.extension<KamusiLearnColors>();
    final best = ref.watch(bestScoresProvider).value ?? const <String, int>{};

    // Top the offline queues up in the background on the way in, and refresh
    // the "ready offline" line once it has. Nothing here waits on it.
    ref.listen(gameTopUpProvider, (previous, next) {
      if (next.hasValue && (next.value ?? 0) > 0) {
        ref.invalidate(gameRoundsReadyProvider);
      }
    });
    ref.watch(gameTopUpProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.learnTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dailyRoundProvider);
          await ref.read(dailyRoundProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            progress.when(
              data: (value) => _ProgressRow(progress: value),
              loading: () => const SizedBox(height: 32),
              error: (_, __) => const SizedBox(height: 32),
            ),
            const SizedBox(height: 20),
            daily.when(
              loading: () => _DailyCardSkeleton(message: l10n.learnLoading),
              error: (_, __) => ErrorState(
                title: l10n.learnErrorTitle,
                message: l10n.searchErrorFailed,
                onRetry: () => ref.invalidate(dailyRoundProvider),
              ),
              data: (round) {
                if (round.isEmpty) {
                  return EmptyState(
                    icon: Icons.school_outlined,
                    title: l10n.learnEmptyTitle,
                    message: l10n.learnEmptyBody,
                  );
                }
                final doneToday = progress.value?.completedOn(
                      LearnProgressStore.dayKey(),
                    ) ??
                    false;
                return _DailyCard(
                  questionCount: round.questions.length,
                  doneToday: doneToday,
                  onPlay: () => _play(
                    context,
                    ref,
                    round: round,
                    isDaily: true,
                    title: l10n.learnDailyTitle,
                  ),
                );
              },
            ),
            const SizedBox(height: 28),
            Text(
              l10n.learnGamesHeading,
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              l10n.learnGamesSubheading,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            // Three cards, three colours. Identical ones read as a list of
            // settings; these should read as a shelf of games.
            _GameCard(
              index: 0,
              icon: Icons.grid_on_rounded,
              accent: learnColors?.gameAccentA ?? colorScheme.primary,
              title: l10n.learnWordFindTitle,
              body: l10n.learnWordFindCardBody,
              best: best[GameIds.wordFind] ?? 0,
              onTap: () => _openWordFind(context, ref, l10n, timed),
            ),
            const SizedBox(height: 12),
            _GameCard(
              index: 1,
              icon: Icons.bubble_chart_rounded,
              accent: learnColors?.gameAccentB ?? colorScheme.secondary,
              title: l10n.learnWordBuildTitle,
              body: l10n.learnWordBuildCardBody,
              best: best[GameIds.wordBuild] ?? 0,
              onTap: () => _openWordBuild(context, ref, l10n, timed),
            ),
            const SizedBox(height: 12),
            _GameCard(
              index: 2,
              icon: Icons.grid_4x4_rounded,
              accent: learnColors?.gameAccentC ?? colorScheme.tertiary,
              title: l10n.learnCrosswordTitle,
              body: l10n.learnCrosswordCardBody,
              best: best[GameIds.crossword] ?? 0,
              onTap: () => _openCrossword(context, ref, l10n, timed),
            ),
            const SizedBox(height: 6),
            // One switch for every game: timed or untimed is a mood a player
            // is in, not a property of a particular board.
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: timed,
              onChanged: (value) =>
                  ref.read(timedModeProvider.notifier).set(value),
              title: Text(l10n.learnGameTimed, style: textTheme.bodyMedium),
              subtitle: Text(
                timed ? l10n.learnGameTimedOn : l10n.learnGameTimedOff,
                style: textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
            // What is playable with no connection. Worth stating plainly:
            // the whole point of the queue is that someone can check before
            // they lose signal.
            ref.watch(gameRoundsReadyProvider).when(
                  loading: () => const SizedBox(height: 18),
                  error: (_, __) => const SizedBox(height: 18),
                  data: (counts) {
                    final total = counts.values.fold<int>(0, (a, b) => a + b);
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          total > 0
                              ? Icons.cloud_done_outlined
                              : Icons.cloud_off_outlined,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          total > 0
                              ? l10n.learnGamesOfflineReady(total)
                              : l10n.learnGamesOfflineNone,
                          style: textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    );
                  },
                ),
            const SizedBox(height: 32),
            Text(
              l10n.learnPracticeTitle,
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.learnQuestionCount(5),
              style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            // Two columns: enough choice to feel like a menu, few enough to
            // take in at a glance.
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.45,
              children: [
                for (final kind in _practiceKinds)
                  _PracticeTile(
                    label: _kindLabel(l10n, kind),
                    icon: _kindIcon(kind),
                    onTap: () async {
                      ref.invalidate(practiceRoundProvider(kind));
                      final round = await ref.read(practiceRoundProvider(kind).future);
                      if (!context.mounted) {
                        return;
                      }
                      if (round.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.learnEmptyBody)),
                        );
                        return;
                      }
                      await _play(
                        context,
                        ref,
                        round: round,
                        isDaily: false,
                        title: _kindLabel(l10n, kind),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A game on the shelf.
///
/// Tinted from its own accent rather than sharing one colour with the
/// others, lifted by a soft shadow, and animated on the way in and under a
/// finger. DESIGN_SYSTEM.md §0 gives Jifunze licence for warmth and motion
/// that the dictionary does not get; this is where it is spent.
class _GameCard extends StatefulWidget {
  const _GameCard({
    required this.index,
    required this.icon,
    required this.accent,
    required this.title,
    required this.body,
    required this.onTap,
    this.best = 0,
  });

  /// Position on the shelf, used only to stagger the entrance.
  final int index;
  final IconData icon;
  final Color accent;
  final String title;
  final String body;
  final Future<void> Function() onTap;

  /// Highest score so far, or zero when this one has not been played.
  final int best;

  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard> {
  bool _shown = false;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    // Staggered, so the shelf assembles itself rather than appearing all at
    // once. Short enough that nobody waiting to tap notices it.
    Future<void>.delayed(Duration(milliseconds: 70 * widget.index + 40), () {
      if (mounted) {
        setState(() => _shown = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = widget.accent;
    final dark = theme.brightness == Brightness.dark;

    return AnimatedSlide(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      offset: _shown ? Offset.zero : const Offset(0, 0.14),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 320),
        opacity: _shown ? 1 : 0,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 110),
          scale: _pressed ? 0.975 : 1,
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            onTap: widget.onTap,
            child: Container(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: dark ? 0.20 : 0.13),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: dark ? 0.0 : 0.16),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    // A disc of the accent sliding off the corner. Cheap
                    // decoration that stops the card reading as a form field.
                    Positioned(
                      right: -28,
                      top: -34,
                      child: Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              widget.icon,
                              size: 27,
                              color: dark ? const Color(0xFF10151C) : Colors.white,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  widget.body,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    height: 1.3,
                                  ),
                                ),
                                if (widget.best > 0) ...[
                                  const SizedBox(height: 8),
                                  _BestChip(score: widget.best, accent: accent),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.play_arrow_rounded, color: accent, size: 28),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The score to beat, when there is one.
class _BestChip extends StatelessWidget {
  const _BestChip({required this.score, required this.accent});

  final int score;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_rounded, size: 13, color: accent),
          const SizedBox(width: 5),
          Text(
            AppLocalizations.of(context)!.learnGameBest(score),
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.progress});

  final LearnProgress progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasStreak = progress.currentStreak > 0;

    return Row(
      children: [
        StreakChip(
          lit: hasStreak,
          label: hasStreak
              ? l10n.learnStreakDays(progress.currentStreak)
              : l10n.learnStreakNone,
        ),
        const Spacer(),
        if (progress.totalAnswered > 0)
          Text(
            l10n.learnAccuracy(progress.accuracyPercent),
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({
    required this.questionCount,
    required this.doneToday,
    required this.onPlay,
  });

  final int questionCount;
  final bool doneToday;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final learn = KamusiLearnColors.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        // A soft wash rather than a flat panel: the one gradient in the app,
        // reserved for the one thing to do today.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.secondaryContainer,
            colorScheme.surfaceContainerHighest,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                doneToday ? Icons.task_alt : Icons.bolt,
                size: 18,
                color: doneToday ? learn.correct : colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 8),
              Text(
                doneToday ? l10n.learnDailyDone : l10n.learnDailyTitle,
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            l10n.learnQuestionCount(questionCount),
            style: KamusiTypography.serif(
              textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPlay,
              child: Text(doneToday ? l10n.learnDailyAgain : l10n.learnDailyStart),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyCardSkeleton extends StatelessWidget {
  const _DailyCardSkeleton({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PracticeTile extends StatelessWidget {
  const _PracticeTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 22, color: colorScheme.secondary),
              Text(
                label,
                style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurface,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
