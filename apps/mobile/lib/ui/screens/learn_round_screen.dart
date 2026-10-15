import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../domain/models/learn_round.dart';
import '../../providers/learn_providers.dart';
import '../theme/kamusi_learn_colors.dart';
import '../theme/kamusi_typography.dart';
import '../widgets/learn_option_tile.dart';
import '../widgets/learn_progress_bar.dart';
import 'expression_detail_screen.dart';
import 'lexeme_detail_screen.dart';

/// Plays one round, question by question.
///
/// Answering is a single tap and feedback is immediate: the thing that teaches
/// is seeing the right answer the moment you commit to a guess, not a score at
/// the end. The round cannot be failed — a wrong answer reveals the correct
/// one and moves on.
class LearnRoundScreen extends ConsumerStatefulWidget {
  const LearnRoundScreen({
    super.key,
    required this.round,
    required this.isDaily,
    required this.title,
  });

  final LearnRound round;
  final bool isDaily;
  final String title;

  @override
  ConsumerState<LearnRoundScreen> createState() => _LearnRoundScreenState();
}

class _LearnRoundScreenState extends ConsumerState<LearnRoundScreen> {
  int _index = 0;
  int? _selected;
  int _correct = 0;
  bool _finished = false;

  LearnQuestion get _question => widget.round.questions[_index];
  bool get _answered => _selected != null;
  bool get _isLast => _index == widget.round.questions.length - 1;

  void _choose(int option) {
    if (_answered) {
      return;
    }
    final right = _question.isCorrect(option);
    // Haptics carry the result before the eye registers the colour.
    if (right) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
    setState(() {
      _selected = option;
      if (right) {
        _correct++;
      }
    });
  }

  Future<void> _advance() async {
    if (_isLast) {
      final total = widget.round.questions.length;
      final controller = ref.read(learnProgressProvider.notifier);
      if (widget.isDaily) {
        await controller.completeDaily(correct: _correct, answered: total);
      } else {
        await controller.recordPractice(correct: _correct, answered: total);
      }
      if (mounted) {
        setState(() => _finished = true);
      }
      return;
    }
    setState(() {
      _index++;
      _selected = null;
    });
  }

  void _openEntry() {
    final lexemeId = _question.lexemeId;
    final expressionId = _question.expressionId;
    if (lexemeId != null && lexemeId.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LexemeDetailScreen(lexemeId: lexemeId)),
      );
    } else if (expressionId != null && expressionId.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ExpressionDetailScreen(expressionId: expressionId),
        ),
      );
    }
  }

  String _ask(AppLocalizations l10n, String kind) {
    switch (kind) {
      case 'meaning':
        return l10n.learnAskMeaning;
      case 'methali':
        return l10n.learnAskMethali;
      default:
        return l10n.learnAskDefinition;
    }
  }

  OptionState _stateFor(int option) {
    if (!_answered) {
      return OptionState.idle;
    }
    if (option == _question.answerIndex) {
      return option == _selected ? OptionState.correct : OptionState.revealed;
    }
    return option == _selected ? OptionState.incorrect : OptionState.idle;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final questions = widget.round.questions;

    if (_finished) {
      return _RoundResult(
        correct: _correct,
        total: questions.length,
        onAgain: () => Navigator.of(context).pop(true),
        onDone: () => Navigator.of(context).pop(false),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final learn = KamusiLearnColors.of(context);
    // A definition or proverb is content, so the prompt is set in the reading
    // face; a bare headword is a label and stays in the UI face.
    final promptIsProse = _question.kind != 'definition';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LearnProgressBar(
            answered: _answered ? _index + 1 : _index,
            total: questions.length,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.learnProgressOf(_index + 1, questions.length),
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _ask(l10n, _question.kind),
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // The prompt is the hero of the screen; a new question
                    // fading and sliding in makes clear something changed.
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      child: Column(
                        key: ValueKey(_index),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _question.prompt,
                            style: KamusiTypography.serif(
                              (promptIsProse
                                      ? textTheme.headlineSmall
                                      : textTheme.displaySmall)
                                  ?.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.5,
                                height: 1.25,
                              ),
                            ),
                          ),
                          if ((_question.promptDetail ?? '').isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              _question.promptDetail!,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontStyle: _question.kind == 'methali'
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    for (var option = 0; option < _question.options.length; option++)
                      LearnOptionTile(
                        label: _question.options[option],
                        state: _stateFor(option),
                        serif: _question.kind != 'meaning',
                        onTap: _answered ? null : () => _choose(option),
                      ),
                  ],
                ),
              ),
            ),
            // The verdict and the way forward sit together at the thumb.
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: _answered
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _question.isCorrect(_selected!)
                                    ? Icons.check_circle
                                    : Icons.info_outline,
                                size: 20,
                                color: _question.isCorrect(_selected!)
                                    ? learn.correct
                                    : learn.incorrect,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _question.isCorrect(_selected!)
                                    ? l10n.learnCorrect
                                    : l10n.learnIncorrect,
                                style: textTheme.titleSmall?.copyWith(
                                  color: _question.isCorrect(_selected!)
                                      ? learn.correct
                                      : learn.incorrect,
                                ),
                              ),
                              const Spacer(),
                              if (_question.hasEntry)
                                TextButton(
                                  onPressed: _openEntry,
                                  child: Text(l10n.learnOpenEntry),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: _advance,
                            child: Text(_isLast ? l10n.learnFinish : l10n.learnContinue),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the round ends.
class _RoundResult extends StatelessWidget {
  const _RoundResult({
    required this.correct,
    required this.total,
    required this.onAgain,
    required this.onDone,
  });

  final int correct;
  final int total;
  final VoidCallback onAgain;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final learn = KamusiLearnColors.of(context);

    final perfect = correct == total;
    final good = correct * 2 >= total;
    final headline = perfect
        ? l10n.learnResultPerfect
        : good
            ? l10n.learnResultGood
            : l10n.learnResultKeepGoing;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // A single growing ring, not confetti: the reward for finishing
              // should feel earned rather than noisy.
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOutBack,
                  builder: (context, value, _) => Transform.scale(
                    scale: value,
                    child: Container(
                      width: 132,
                      height: 132,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: perfect ? learn.correctContainer : colorScheme.surface,
                        border: Border.all(
                          color: perfect ? learn.correct : colorScheme.outlineVariant,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$correct/$total',
                          style: KamusiTypography.serif(
                            textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                headline,
                textAlign: TextAlign.center,
                style: KamusiTypography.serif(
                  textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.learnScore(correct, total),
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 36),
              FilledButton(onPressed: onAgain, child: Text(l10n.learnPlayAgain)),
              const SizedBox(height: 10),
              TextButton(onPressed: onDone, child: Text(l10n.learnBackToLearn)),
            ],
          ),
        ),
      ),
    );
  }
}
