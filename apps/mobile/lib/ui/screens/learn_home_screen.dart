import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../data/learn_progress_store.dart';
import '../../domain/models/learn_round.dart';
import '../../providers/learn_providers.dart';
import '../theme/kamusi_learn_colors.dart';
import '../theme/kamusi_typography.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/learn_progress_bar.dart';
import 'learn_round_screen.dart';
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

  Future<void> _openWordFind(
      BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
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
        MaterialPageRoute(builder: (_) => WordFindScreen(puzzle: puzzle)),
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

  Future<void> _openWordBuild(
      BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
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
        MaterialPageRoute(builder: (_) => WordBuildScreen(puzzle: puzzle)),
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final daily = ref.watch(dailyRoundProvider);
    final progress = ref.watch(learnProgressProvider);

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
            // Their own cards rather than more practice tiles: these are a
            // different shape of game, not another quiz mix, and each takes a
            // board's worth of space to be worth opening.
            _GameCard(
              icon: Icons.grid_on_outlined,
              title: l10n.learnWordFindTitle,
              body: l10n.learnWordFindCardBody,
              onTap: () => _openWordFind(context, ref, l10n),
            ),
            const SizedBox(height: 12),
            _GameCard(
              icon: Icons.bubble_chart_outlined,
              title: l10n.learnWordBuildTitle,
              body: l10n.learnWordBuildCardBody,
              onTap: () => _openWordBuild(context, ref, l10n),
            ),
            const SizedBox(height: 10),
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
                          total > 0 ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
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

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: colorScheme.tertiaryContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icon, size: 32, color: colorScheme.onTertiaryContainer),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onTertiaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onTertiaryContainer.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward,
                color: colorScheme.onTertiaryContainer,
              ),
            ],
          ),
        ),
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
    final colorScheme = Theme.of(context).colorScheme;
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
    final colorScheme = Theme.of(context).colorScheme;
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
