import 'dart:async';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../data/game_round_cache.dart';
import '../../data/game_score.dart';
import '../../data/game_settings_store.dart';
import '../../domain/models/crossword_puzzle.dart';
import '../../providers/learn_providers.dart';
import '../theme/kamusi_learn_colors.dart';
import '../widgets/game_timer_bar.dart';
import '../../data/game_feedback.dart';
import '../widgets/game_result_sheet.dart';
import '../widgets/hint_button.dart';
import 'lexeme_detail_screen.dart';

/// Chemsha Bongo — a crossword.
///
/// The crossings are the point. A letter you are sure of in one answer is a
/// letter given to another, so a clue you cannot read becomes solvable from
/// the ones you can — which is exactly how reading in a new language works.
///
/// Typing happens one cell at a time with a letter strip rather than the
/// system keyboard: a 13-wide grid and a keyboard do not fit on a phone
/// together, and the strip can be restricted to letters Swahili uses.
class CrosswordScreen extends ConsumerStatefulWidget {
  const CrosswordScreen({super.key, required this.puzzle, this.timed = false});

  final CrosswordPuzzle puzzle;
  final bool timed;

  @override
  ConsumerState<CrosswordScreen> createState() => _CrosswordScreenState();
}

class _CrosswordScreenState extends ConsumerState<CrosswordScreen>
    with SingleTickerProviderStateMixin {
  final Map<CrosswordCell, String> _filled = {};
  final Set<int> _scored = {};

  CrosswordCell? _cursor;
  bool _cursorAcross = true;
  bool _outOfTime = false;
  int _score = 0;
  Duration? _timeLeft;
  int _hintsLeft = GameHints.perBoard;
  bool _finished = false;

  /// Shakes the grid when a finished answer turns out to be wrong.
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  CrosswordPuzzle get _puzzle => widget.puzzle;

  late final Map<CrosswordCell, String> _solution = _puzzle.solution;
  late final Set<CrosswordCell> _cells = _puzzle.filledCells;
  late final Map<CrosswordCell, int> _numbers = _puzzle.cellNumbers;

  bool _solved(CrosswordEntry entry) {
    final cells = entry.cells;
    for (var i = 0; i < cells.length; i++) {
      if (_filled[cells[i]] != entry.answer[i]) {
        return false;
      }
    }
    return true;
  }

  /// True once every square of an answer has a letter in it, right or not.
  bool _filledThrough(CrosswordEntry entry) =>
      entry.cells.every((cell) => (_filled[cell] ?? '').isNotEmpty);

  /// Answers the player has finished and got wrong.
  ///
  /// The game used to say nothing at all here: you could fill a word
  /// incorrectly and the board would look exactly as it does when you are
  /// right, which leaves checking your own crossword as an exercise.
  Set<CrosswordEntry> get _wrongEntries => _puzzle.entries
      .where((entry) => _filledThrough(entry) && !_solved(entry))
      .toSet();

  /// How a square should read: null while its answers are unfinished, true
  /// once a finished answer through it is right, false once one is wrong.
  ///
  /// Wrong wins where an across and a down disagree, because that is the one
  /// the player can still do something about.
  bool? _cellVerdict(CrosswordCell cell) {
    bool? verdict;
    for (final entry in _puzzle.entriesAt(cell)) {
      if (!_filledThrough(entry)) {
        continue;
      }
      if (!_solved(entry)) {
        return false;
      }
      verdict = true;
    }
    return verdict;
  }

  int get _solvedCount => _puzzle.entries.where(_solved).length;

  bool get _complete => _solvedCount == _puzzle.entries.length;

  bool get _over => _complete || _outOfTime;

  /// The entry the cursor is working in, so the clue can be shown without
  /// making the player hunt for it in the list.
  CrosswordEntry? get _activeEntry {
    final cursor = _cursor;
    if (cursor == null) {
      return null;
    }
    final here = _puzzle.entriesAt(cursor);
    if (here.isEmpty) {
      return null;
    }
    for (final entry in here) {
      if (entry.isAcross == _cursorAcross) {
        return entry;
      }
    }
    return here.first;
  }

  void _tapCell(CrosswordCell cell) {
    if (_over || !_cells.contains(cell)) {
      return;
    }
    setState(() {
      if (_cursor == cell) {
        // Tapping the cell you are already in turns the corner, which is how
        // every crossword app works and the only way to reach a down clue
        // whose cells all belong to an across one too.
        _cursorAcross = !_cursorAcross;
      } else {
        _cursor = cell;
      }
    });
  }

  void _type(String letter) {
    final cursor = _cursor;
    if (cursor == null || _over) {
      return;
    }
    final wrongBefore = _wrongEntries.length;
    final solvedBefore = _solvedCount;
    setState(() {
      _filled[cursor] = letter;
      _awardNewlySolved();
      _advance();
    });

    if (_solvedCount > solvedBefore) {
      GameFeedback.correct();
    } else if (_wrongEntries.length > wrongBefore) {
      // A finished answer that is wrong: say so now rather than leaving it
      // to be discovered at the end.
      GameFeedback.wrong();
      _shake.forward(from: 0);
    } else {
      GameFeedback.tick();
    }

    if (_complete) {
      _finish(completed: true);
    }
  }

  /// Fill in the square the cursor is on, or the first empty one in the
  /// answer being worked on. A letter, not a whole entry: the crossings mean
  /// one letter is already worth a great deal.
  void _takeHint() {
    if (_over || _hintsLeft <= 0) {
      return;
    }
    var target = _cursor;
    final entry = _activeEntry;
    if (entry != null) {
      for (final cell in entry.cells) {
        if (_filled[cell] != _solution[cell]) {
          target = cell;
          break;
        }
      }
    }
    if (target == null || _solution[target] == null) {
      return;
    }
    GameFeedback.hint();
    setState(() {
      _hintsLeft--;
      _score = (_score - GameHints.cost).clamp(0, 1 << 30);
      _filled[target!] = _solution[target]!;
      _cursor = target;
      _awardNewlySolved();
    });
    if (_complete) {
      _finish(completed: true);
    }
  }

  /// Delete, the way a crossword should.
  ///
  /// It used to clear the square under the cursor and stop there, so
  /// emptying a wrong answer meant tapping each square and pressing delete
  /// again — five taps to undo five letters. Now each press steps back
  /// through the answer, so holding or repeating it unwinds the whole word.
  void _erase() {
    final cursor = _cursor;
    if (cursor == null || _over) {
      return;
    }
    final step = eraseStep(
      cells: _activeEntry?.cells ?? [cursor],
      cursor: cursor,
      cursorIsFilled: _filled[cursor] != null,
    );
    setState(() {
      if (step.clear != null) {
        _filled.remove(step.clear);
      }
      _cursor = step.cursor;
    });
  }

  /// Score each entry once, the moment it is completed.
  void _awardNewlySolved() {
    for (final entry in _puzzle.entries) {
      final key = Object.hash(entry.number, entry.direction);
      if (_scored.contains(key) || !_solved(entry)) {
        continue;
      }
      _scored.add(key);
      _score += GameScore.award(
        points: entry.points,
        timeLeft: widget.timed ? _timeLeft : null,
        total: widget.timed ? GameDurations.crossword : null,
      );
    }
  }

  void _advance() {
    final cursor = _cursor;
    final entry = _activeEntry;
    if (cursor == null || entry == null) {
      return;
    }
    final cells = entry.cells;
    final index = cells.indexOf(cursor);
    if (index >= 0 && index + 1 < cells.length) {
      _cursor = cells[index + 1];
    }
  }

  Future<void> _finish({required bool completed}) async {
    if (_finished) {
      return;
    }
    _finished = true;

    final store = ref.read(gameSettingsStoreProvider);
    final previousBest = await store.bestScore(GameIds.crossword);
    final best = await store.recordScore(GameIds.crossword, _score);
    if (!mounted) {
      return;
    }
    ref.invalidate(bestScoresProvider);
    if (completed) {
      GameFeedback.complete();
    }

    final theme = Theme.of(context);
    final accent = theme.extension<KamusiLearnColors>()?.gameAccentC ??
        theme.colorScheme.tertiary;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => GameResultSheet(
        accent: accent,
        score: _score,
        best: best,
        isNewBest: _score > previousBest && _score > 0,
        found: _solvedCount,
        total: _puzzle.entries.length,
        completed: completed,
        onAgain: () {
          Navigator.of(sheetContext).pop();
          ref.invalidate(crosswordProvider);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _openEntry(CrosswordEntry entry) {
    if (entry.lexemeId.isEmpty) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LexemeDetailScreen(lexemeId: entry.lexemeId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final learnColors = theme.extension<KamusiLearnColors>();
    // The indigo this game wears on the shelf, carried inside.
    final accent = learnColors?.gameAccentC ?? theme.colorScheme.tertiary;
    final active = _activeEntry;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: accent.withValues(alpha: 0.16),
        title: Text(l10n.learnCrosswordTitle),
        actions: [
          IconButton(
            tooltip: l10n.learnWordBuildNew,
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(crosswordProvider);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              children: [
                if (widget.timed) ...[
                  GameTimerBar(
                    duration: GameDurations.crossword,
                    paused: _over,
                    onTick: (left) => _timeLeft = left,
                    onExpired: () {
                      setState(() => _outOfTime = true);
                      _finish(completed: false);
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                if (!_over)
                  Align(
                    alignment: Alignment.centerRight,
                    child: HintButton(
                      remaining: _hintsLeft,
                      cost: GameHints.cost,
                      label: _hintsLeft > 0 ? l10n.learnHint : l10n.learnHintNone,
                      onPressed: _takeHint,
                    ),
                  ),
                _ScoreRow(
                  score: _score,
                  solved: _solvedCount,
                  total: _puzzle.entries.length,
                  learnColors: learnColors,
                  accent: accent,
                ),
                const SizedBox(height: 10),
                Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final side = constraints.maxWidth;
                      return SizedBox(
                        width: side,
                        height: side,
                        child: AnimatedBuilder(
                          animation: _shake,
                          builder: (context, child) {
                            // A quick side-to-side, decaying — enough to
                            // notice without throwing the board around.
                            final t = _shake.value;
                            final offset =
                                math.sin(t * math.pi * 6) * 9 * (1 - t);
                            return Transform.translate(
                              offset: Offset(offset, 0),
                              child: child,
                            );
                          },
                          child: _Grid(
                          accent: accent,
                          verdict: _cellVerdict,
                          puzzle: _puzzle,
                          cells: _cells,
                          numbers: _numbers,
                          filled: _filled,
                          solution: _solution,
                          cursor: _cursor,
                          cursorAcross: _cursorAcross,
                          revealAll: _outOfTime,
                          onTap: _tapCell,
                          learnColors: learnColors,
                        ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                if (active != null && !_over)
                  _ActiveClue(entry: active, accent: accent)
                else
                  Text(
                    _outOfTime
                        ? l10n.learnGameTimeUp
                        : _complete
                            ? l10n.learnCrosswordDone
                            : l10n.learnCrosswordHint,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                const SizedBox(height: 16),
                for (final direction in const ['across', 'down']) ...[
                  Text(
                    direction == 'across'
                        ? l10n.learnCrosswordAcross
                        : l10n.learnCrosswordDown,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  for (final entry in _puzzle.entries
                      .where((entry) => entry.direction == direction))
                    _ClueRow(
                      entry: entry,
                      solved: _solved(entry) || _outOfTime,
                      active: active == entry,
                      onTap: () {
                        if (_solved(entry) || _outOfTime) {
                          _openEntry(entry);
                        } else {
                          setState(() {
                            _cursor = CrosswordCell(entry.row, entry.col);
                            _cursorAcross = entry.isAcross;
                          });
                        }
                      },
                      learnColors: learnColors,
                    ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          if (!_over)
            _LetterStrip(
              onLetter: _type,
              onErase: _erase,
              enabled: _cursor != null,
            ),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.score,
    required this.solved,
    required this.total,
    required this.learnColors,
    required this.accent,
  });

  final int score;
  final int solved;
  final int total;
  final KamusiLearnColors? learnColors;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          '$solved / $total',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : solved / total,
              minHeight: 6,
              backgroundColor: learnColors?.progressTrack ??
                  theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$score',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: accent,
          ),
        ),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.accent,
    required this.verdict,
    required this.puzzle,
    required this.cells,
    required this.numbers,
    required this.filled,
    required this.solution,
    required this.cursor,
    required this.cursorAcross,
    required this.revealAll,
    required this.onTap,
    required this.learnColors,
  });

  final Color accent;

  /// Null while a square's answers are unfinished, true once a finished one
  /// through it is right, false once one is wrong.
  final bool? Function(CrosswordCell) verdict;
  final CrosswordPuzzle puzzle;
  final Set<CrosswordCell> cells;
  final Map<CrosswordCell, int> numbers;
  final Map<CrosswordCell, String> filled;
  final Map<CrosswordCell, String> solution;
  final CrosswordCell? cursor;
  final bool cursorAcross;
  final bool revealAll;
  final void Function(CrosswordCell) onTap;
  final KamusiLearnColors? learnColors;

  /// The cells of the answer the cursor is in, so the whole clue is lit
  /// rather than one square — without it there is no telling which way you
  /// are typing.
  Set<CrosswordCell> get _highlighted {
    final at = cursor;
    if (at == null) {
      return const {};
    }
    for (final entry in puzzle.entriesAt(at)) {
      if (entry.isAcross == cursorAcross) {
        return entry.cells.toSet();
      }
    }
    return {at};
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlighted = _highlighted;
    return Column(
      children: [
        for (var row = 0; row < puzzle.size; row++)
          Expanded(
            child: Row(
              children: [
                for (var col = 0; col < puzzle.size; col++)
                  Expanded(
                    child: _Cell(
                      cell: CrosswordCell(row, col),
                      active: cells.contains(CrosswordCell(row, col)),
                      number: numbers[CrosswordCell(row, col)],
                      letter: revealAll
                          ? solution[CrosswordCell(row, col)]
                          : filled[CrosswordCell(row, col)],
                      isCursor: cursor == CrosswordCell(row, col),
                      inClue: highlighted.contains(CrosswordCell(row, col)),
                      onTap: () => onTap(CrosswordCell(row, col)),
                      learnColors: learnColors,
                      accent: accent,
                      verdict: verdict(CrosswordCell(row, col)),
                      theme: theme,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.cell,
    required this.active,
    required this.number,
    required this.letter,
    required this.isCursor,
    required this.inClue,
    required this.onTap,
    required this.learnColors,
    required this.accent,
    required this.verdict,
    required this.theme,
  });

  final CrosswordCell cell;
  final bool active;
  final int? number;
  final String? letter;
  final bool isCursor;
  final bool inClue;
  final VoidCallback onTap;
  final KamusiLearnColors? learnColors;
  final Color accent;
  final bool? verdict;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (!active) {
      // A blocked square. Nothing to tap, nothing to read.
      return const SizedBox.shrink();
    }
    final colorScheme = theme.colorScheme;
    // A finished answer colours its squares: green for right, red for
    // wrong. Nothing before that — judging a half-typed word would be
    // telling the player the answer one letter at a time.
    final correct = learnColors?.correctContainer ?? colorScheme.secondaryContainer;
    final incorrect = learnColors?.incorrectContainer ?? colorScheme.errorContainer;

    final Color background;
    if (verdict == false) {
      background = incorrect;
    } else if (verdict == true) {
      background = correct;
    } else if (isCursor) {
      background = accent.withValues(alpha: 0.42);
    } else if (inClue) {
      // Light enough to read a letter through, strong enough to show which
      // answer you are typing into — the only reason this highlight exists.
      background = accent.withValues(alpha: 0.24);
    } else {
      background = colorScheme.surface;
    }

    return Padding(
      padding: const EdgeInsets.all(0.8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: background,
            border: Border.all(
              color: isCursor
                  ? accent
                  : verdict == false
                      ? (learnColors?.incorrect ?? colorScheme.error)
                      : colorScheme.outlineVariant,
              width: isCursor || verdict == false ? 1.4 : 0.8,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Stack(
            children: [
              if (number != null)
                Positioned(
                  left: 1.5,
                  top: 0.5,
                  child: Text(
                    '$number',
                    style: TextStyle(
                      fontSize: 7,
                      height: 1,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              Center(
                child: FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Text(
                      (letter ?? '').toUpperCase(),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: verdict == false
                            ? (learnColors?.onIncorrectContainer ??
                                colorScheme.onErrorContainer)
                            : verdict == true
                                ? (learnColors?.onCorrectContainer ??
                                    colorScheme.onSecondaryContainer)
                                : colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveClue extends StatelessWidget {
  const _ActiveClue({required this.entry, required this.accent});

  final CrosswordEntry entry;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${entry.number}${entry.isAcross ? "→" : "↓"}',
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w700, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(entry.definition, style: theme.textTheme.bodyMedium),
          ),
          Text(
            '${entry.points}',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ClueRow extends StatelessWidget {
  const _ClueRow({
    required this.entry,
    required this.solved,
    required this.active,
    required this.onTap,
    required this.learnColors,
  });

  final CrosswordEntry entry;
  final bool solved;
  final bool active;
  final VoidCallback onTap;
  final KamusiLearnColors? learnColors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 26,
              child: Text(
                '${entry.number}.',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  color: solved ? learnColors?.correct : null,
                ),
              ),
            ),
            Expanded(
              child: Text(
                solved ? '${entry.word} — ${entry.definition}' : entry.definition,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: solved
                      ? learnColors?.correct
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Letters to type with.
///
/// Not the system keyboard: a 13-wide grid and a keyboard do not fit on a
/// phone together, and this can be limited to the letters Swahili uses —
/// no q, no x — so there is one less way to go wrong.
class _LetterStrip extends StatelessWidget {
  const _LetterStrip({
    required this.onLetter,
    required this.onErase,
    required this.enabled,
  });

  final void Function(String) onLetter;
  final VoidCallback onErase;
  final bool enabled;

  static const _letters = 'abcdefghijklmnoprstuvwyz';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final letter in _letters.split(''))
                  _Key(
                    label: letter.toUpperCase(),
                    onTap: enabled ? () => onLetter(letter) : null,
                  ),
                _Key(
                  label: '⌫',
                  wide: true,
                  onTap: enabled ? onErase : null,
                  // Held down it repeats, so clearing a long answer is one
                  // press rather than nine.
                  onHoldRepeat: enabled ? onErase : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Key extends StatefulWidget {
  const _Key({
    required this.label,
    required this.onTap,
    this.wide = false,
    this.onHoldRepeat,
  });

  final String label;
  final VoidCallback? onTap;
  final bool wide;

  /// Called repeatedly while the key is held, for backspace.
  final VoidCallback? onHoldRepeat;

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  Timer? _repeat;

  void _startRepeat() {
    final action = widget.onHoldRepeat;
    if (action == null) {
      return;
    }
    _repeat?.cancel();
    // A pause before it takes off, so an ordinary press is one letter and
    // only a deliberate hold runs on.
    _repeat = Timer(const Duration(milliseconds: 350), () {
      _repeat = Timer.periodic(const Duration(milliseconds: 90), (_) => action());
    });
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  void dispose() {
    _stopRepeat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: widget.wide ? 68 : 32,
      height: 40,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: widget.onTap,
          onTapDown: (_) => _startRepeat(),
          onTapUp: (_) => _stopRepeat(),
          onTapCancel: _stopRepeat,
          child: Center(
            child: Text(
              widget.label,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}
