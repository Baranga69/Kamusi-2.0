import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../domain/models/word_build_puzzle.dart';
import '../../data/game_round_cache.dart';
import '../../data/game_score.dart';
import '../../data/game_settings_store.dart';
import '../../providers/learn_providers.dart';
import '../widgets/game_timer_bar.dart';
import '../../data/game_feedback.dart';
import '../widgets/game_result_sheet.dart';
import '../widgets/hint_button.dart';
import '../theme/kamusi_learn_colors.dart';
import 'lexeme_detail_screen.dart';

/// Unda Neno — build words from a ring of eight letters.
///
/// Nothing is hidden here, unlike the grid: every answer is spellable from
/// the letters on screen, and the difficulty is knowing enough Swahili to see
/// them. That is what the two modes are for. In **easy** the definitions are
/// visible from the start, so the game is "which word means this?" and the
/// meanings are doing the teaching before you solve anything. In **hard** a
/// definition appears only once its word is built, so the meaning is the
/// reward rather than the route.
class WordBuildScreen extends ConsumerStatefulWidget {
  const WordBuildScreen({
    super.key,
    required this.puzzle,
    this.timed = false,
  });

  final WordBuildPuzzle puzzle;

  /// When true the ring runs against a clock and ends when it expires.
  final bool timed;

  @override
  ConsumerState<WordBuildScreen> createState() => _WordBuildScreenState();
}

class _WordBuildScreenState extends ConsumerState<WordBuildScreen> {
  /// Indices into the ring, in the order they were dragged over.
  final List<int> _selected = [];
  final Set<String> _found = {};

  late List<String> _ring = List<String>.from(widget.puzzle.letters);

  bool _easyMode = true;
  bool _dragLock = false;
  bool _lastAttemptFailed = false;

  /// Set when the clock runs out. Every answer is then revealed: being shown
  /// the words you could not see is the part worth having.
  bool _outOfTime = false;
  int _score = 0;
  Duration? _timeLeft;

  /// How many leading letters have been given away per word. One at a time,
  /// so a hint narrows the field rather than handing over the answer.
  final Map<String, int> _revealedLetters = {};
  int _hintsLeft = GameHints.perBoard;
  bool _finished = false;

  WordBuildPuzzle get _puzzle => widget.puzzle;

  String get _attempt => _selected.map((index) => _ring[index]).join();

  bool get _complete => _found.length == _puzzle.words.length;

  bool get _over => _complete || _outOfTime;

  /// How far the tiles sit from the middle.
  double _ringRadius(Size size) => size.shortestSide * 0.36;

  /// Tile centres on a circle, as fractions of the ring box.
  List<Offset> _centres(Size size) {
    final count = _ring.length;
    final radius = _ringRadius(size);
    final centre = Offset(size.width / 2, size.height / 2);
    return List<Offset>.generate(count, (index) {
      // Start at the top and go clockwise, so the ring reads the way a clock
      // does rather than starting from an arbitrary edge.
      final angle = -math.pi / 2 + (2 * math.pi * index / count);
      return centre + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
    });
  }

  double _tileRadius(Size size) => size.shortestSide * 0.115;

  int? _tileAt(Offset local, Size size) {
    final centres = _centres(size);
    final radius = _tileRadius(size);
    for (var index = 0; index < centres.length; index++) {
      if ((local - centres[index]).distance <= radius * 1.15) {
        return index;
      }
    }
    return null;
  }

  // --- the drag ----------------------------------------------------------

  void _onDown(Offset local, Size size) {
    if (_over) {
      return;
    }
    setState(() {
      _dragLock = true;
      _lastAttemptFailed = false;
      _selected.clear();
      final tile = _tileAt(local, size);
      if (tile != null) {
        _selected.add(tile);
      }
    });
  }

  void _onMove(Offset local, Size size) {
    final tile = _tileAt(local, size);
    if (tile == null) {
      return;
    }
    if (_selected.isNotEmpty && _selected.last == tile) {
      return;
    }
    // Dragging back onto the previous tile un-picks the last one, which is
    // how anyone expects to correct a slip without starting over.
    if (_selected.length >= 2 && _selected[_selected.length - 2] == tile) {
      GameFeedback.tick();
      setState(() => _selected.removeLast());
      return;
    }
    if (_selected.contains(tile)) {
      return;
    }
    // One tick per tile, so building a word has a texture under the finger.
    GameFeedback.tick();
    setState(() => _selected.add(tile));
  }

  void _onUp() {
    final attempt = _attempt;
    final solved = attempt.length >= 3 ? _puzzle.solve(attempt) : null;

    if (solved != null && !_found.contains(solved.letters)) {
      GameFeedback.correct();
    } else if (attempt.isNotEmpty && solved == null) {
      GameFeedback.wrong();
    }
    setState(() {
      _dragLock = false;
      if (solved != null && !_found.contains(solved.letters)) {
        _found.add(solved.letters);
        _score += GameScore.award(
          points: solved.points,
          timeLeft: widget.timed ? _timeLeft : null,
          total: widget.timed ? GameDurations.wordBuild : null,
        );
        _lastAttemptFailed = false;
      } else if (attempt.isNotEmpty) {
        _lastAttemptFailed = solved == null;
      }
      _selected.clear();
    });
    if (_complete) {
      _finish(completed: true);
    }
  }

  void _takeHint() {
    if (_over || _hintsLeft <= 0) {
      return;
    }
    // Shortest first: the cheap words are the way back into a board that has
    // stalled, and the pangram is no use to somebody stuck.
    final unsolved = _puzzle.words
        .where((word) => !_found.contains(word.letters))
        .where((word) => (_revealedLetters[word.letters] ?? 0) < word.letters.length - 1)
        .toList()
      ..sort((a, b) => a.letters.length - b.letters.length);
    if (unsolved.isEmpty) {
      return;
    }
    GameFeedback.hint();
    final word = unsolved.first;
    setState(() {
      _hintsLeft--;
      _score = (_score - GameHints.cost).clamp(0, 1 << 30);
      _revealedLetters[word.letters] = (_revealedLetters[word.letters] ?? 0) + 1;
    });
  }

  void _shuffle() {
    setState(() {
      _ring = List<String>.from(_ring)..shuffle();
      _selected.clear();
    });
  }

  /// Close the board: record the score, then say so.
  Future<void> _finish({required bool completed}) async {
    if (_finished) {
      return;
    }
    _finished = true;

    final store = ref.read(gameSettingsStoreProvider);
    final previousBest = await store.bestScore(GameIds.wordBuild);
    final best = await store.recordScore(GameIds.wordBuild, _score);
    if (!mounted) {
      return;
    }
    ref.invalidate(bestScoresProvider);
    if (completed) {
      GameFeedback.complete();
    }

    final theme = Theme.of(context);
    final accent = theme.extension<KamusiLearnColors>()?.gameAccentB ??
        theme.colorScheme.secondary;
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
        found: _found.length,
        total: _puzzle.words.length,
        completed: completed,
        onAgain: () {
          Navigator.of(sheetContext).pop();
          ref.invalidate(wordBuildProvider);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _openEntry(WordBuildWord word) {
    if (word.lexemeId.isEmpty) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LexemeDetailScreen(lexemeId: word.lexemeId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final learnColors = theme.extension<KamusiLearnColors>();
    // The amber this game wears on the shelf, carried inside.
    final accent = learnColors?.gameAccentB ?? theme.colorScheme.secondary;

    // Longest first: the pangram is the headline answer and the short words
    // read as the warm-up they are.
    final words = [..._puzzle.words]
      ..sort((a, b) => a.letters.length == b.letters.length
          ? a.letters.compareTo(b.letters)
          : b.letters.length - a.letters.length);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: accent.withValues(alpha: 0.16),
        title: Text(l10n.learnWordBuildTitle),
        actions: [
          IconButton(
            tooltip: l10n.learnWordBuildShuffle,
            icon: const Icon(Icons.shuffle),
            onPressed: _shuffle,
          ),
          IconButton(
            tooltip: l10n.learnWordBuildNew,
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(wordBuildProvider);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: ListView(
        // Frozen while a finger is on the ring, for the same reason the grid
        // does it: a downward drag must build a word, not scroll the screen.
        physics: _dragLock
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (widget.timed) ...[
            GameTimerBar(
              duration: GameDurations.wordBuild,
              paused: _over,
              onTick: (left) => _timeLeft = left,
              onExpired: () {
                setState(() => _outOfTime = true);
                _finish(completed: false);
              },
            ),
            const SizedBox(height: 14),
          ],
          _ModeSwitch(
            easy: _easyMode,
            easyLabel: l10n.learnWordBuildEasy,
            hardLabel: l10n.learnWordBuildHard,
            onChanged: (easy) => setState(() => _easyMode = easy),
          ),
          const SizedBox(height: 6),
          Text(
            _outOfTime
                ? l10n.learnGameTimeUp
                : _easyMode
                    ? l10n.learnWordBuildEasyHint
                    : l10n.learnWordBuildHardHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _AttemptBox(
            attempt: _attempt,
            failed: _lastAttemptFailed,
            placeholder: l10n.learnWordBuildHint,
            learnColors: learnColors,
            accent: accent,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final side = math.min(constraints.maxWidth, 340.0);
              final size = Size(side, side);
              return Center(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (event) => _onDown(event.localPosition, size),
                  onPointerMove: (event) => _onMove(event.localPosition, size),
                  onPointerUp: (_) => _onUp(),
                  onPointerCancel: (_) => _onUp(),
                  child: SizedBox(
                    width: side,
                    height: side,
                    child: CustomPaint(
                      painter: _RingPainter(
                        centres: _centres(size),
                        selected: _selected,
                        ringRadius: _ringRadius(size),
                        tileRadius: _tileRadius(size),
                        linkColor: accent,
                        ringColor: accent.withValues(alpha: 0.45),
                        ringFill: accent.withValues(alpha: 0.10),
                      ),
                      child: Stack(
                        children: [
                          for (var index = 0; index < _ring.length; index++)
                            _RingTile(
                              letter: _ring[index],
                              centre: _centres(size)[index],
                              radius: _tileRadius(size),
                              selected: _selected.contains(index),
                              accent: accent,
                              // One colour per tile, so the ring reads as a
                              // set of pieces rather than eight grey discs.
                              tileColor: (learnColors?.tilePalette.isNotEmpty ??
                                      false)
                                  ? learnColors!
                                      .tilePalette[index % learnColors.tilePalette.length]
                                  : null,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
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
          _ProgressRow(
            found: _found.length,
            total: _puzzle.words.length,
            complete: _complete,
            score: _score,
            accent: accent,
            doneLabel: l10n.learnWordBuildDone,
            learnColors: learnColors,
          ),
          const SizedBox(height: 16),
          for (final word in words)
            _SolutionRow(
              word: word,
              found: _found.contains(word.letters),
              // Easy mode shows the meaning before the word is built; hard
              // mode keeps it back until it is.
              showDefinition:
                  _easyMode || _outOfTime || _found.contains(word.letters),
              revealed: _outOfTime,
              revealedLetters: _revealedLetters[word.letters] ?? 0,
              onTap: () => _openEntry(word),
              learnColors: learnColors,
            ),
        ],
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({
    required this.easy,
    required this.easyLabel,
    required this.hardLabel,
    required this.onChanged,
  });

  final bool easy;
  final String easyLabel;
  final String hardLabel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SegmentedButton<bool>(
        segments: [
          ButtonSegment(value: true, label: Text(easyLabel)),
          ButtonSegment(value: false, label: Text(hardLabel)),
        ],
        selected: {easy},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}

/// The word being spelled, above the ring where a player is already looking.
class _AttemptBox extends StatelessWidget {
  const _AttemptBox({
    required this.attempt,
    required this.failed,
    required this.placeholder,
    required this.learnColors,
    required this.accent,
  });

  final String attempt;
  final bool failed;
  final String placeholder;
  final KamusiLearnColors? learnColors;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final empty = attempt.isEmpty;
    final background = failed && empty
        ? (learnColors?.incorrectContainer ?? theme.colorScheme.errorContainer)
        : accent.withValues(alpha: 0.14);
    final foreground = failed && empty
        ? (learnColors?.onIncorrectContainer ?? theme.colorScheme.onErrorContainer)
        : theme.colorScheme.onSurface;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        empty ? placeholder : attempt.toUpperCase(),
        style: empty
            ? theme.textTheme.bodyMedium?.copyWith(
                color: foreground.withValues(alpha: 0.7),
              )
            : theme.textTheme.headlineSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
              ),
      ),
    );
  }
}

class _RingTile extends StatelessWidget {
  const _RingTile({
    required this.letter,
    required this.centre,
    required this.radius,
    required this.selected,
    required this.accent,
    required this.tileColor,
  });

  final String letter;
  final Offset centre;
  final double radius;
  final bool selected;
  final Color accent;
  final Color? tileColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned(
      left: centre.dx - radius,
      top: centre.dy - radius,
      width: radius * 2,
      height: radius * 2,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? accent : (tileColor ?? theme.colorScheme.surfaceContainerHighest),
          border: Border.all(
            color: selected ? accent : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (selected ? accent : (tileColor ?? Colors.black))
                  .withValues(alpha: 0.32),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              letter.toUpperCase(),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The ring the letters sit on, and the line joining the ones picked so far.
///
/// The ring is drawn always, not only mid-drag: without it the tiles read as
/// eight loose circles, and the shape is what tells a player these letters
/// belong to one puzzle. The link line keeps a long word legible as a shape
/// rather than a guess about which letters are lit.
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.centres,
    required this.selected,
    required this.ringRadius,
    required this.tileRadius,
    required this.linkColor,
    required this.ringColor,
    required this.ringFill,
  });

  final List<Offset> centres;
  final List<int> selected;
  final double ringRadius;
  final double tileRadius;
  final Color linkColor;
  final Color ringColor;
  final Color ringFill;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    // Outside the tiles, with a little air, so the band encloses them rather
    // than cutting through the letters.
    final radius = ringRadius + tileRadius + tileRadius * 0.22;

    canvas.drawCircle(centre, radius, Paint()..color = ringFill);
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..color = ringColor
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    if (selected.length < 2) {
      return;
    }
    final link = Paint()
      ..color = linkColor.withValues(alpha: 0.45)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(centres[selected.first].dx, centres[selected.first].dy);
    for (final index in selected.skip(1)) {
      path.lineTo(centres[index].dx, centres[index].dy);
    }
    canvas.drawPath(path, link);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.selected.length != selected.length ||
      old.linkColor != linkColor ||
      old.ringColor != ringColor ||
      old.ringRadius != ringRadius;
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.found,
    required this.total,
    required this.complete,
    required this.score,
    required this.accent,
    required this.doneLabel,
    required this.learnColors,
  });

  final int found;
  final int total;
  final bool complete;
  final int score;
  final Color accent;
  final String doneLabel;
  final KamusiLearnColors? learnColors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          '$found / $total',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : found / total,
              minHeight: 6,
              backgroundColor: learnColors?.progressTrack ??
                  theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$score',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: accent,
          ),
        ),
        if (complete) ...[
          const SizedBox(width: 10),
          Text(
            doneLabel,
            style: theme.textTheme.labelMedium?.copyWith(
              color: learnColors?.correct,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _SolutionRow extends StatelessWidget {
  const _SolutionRow({
    required this.word,
    required this.found,
    required this.showDefinition,
    required this.onTap,
    required this.learnColors,
    this.revealed = false,
    this.revealedLetters = 0,
  });

  final WordBuildWord word;
  final bool found;
  final bool showDefinition;
  final VoidCallback onTap;
  final KamusiLearnColors? learnColors;

  /// Shown because the clock ran out rather than because it was solved.
  final bool revealed;

  /// Leading letters given away by hints.
  final int revealedLetters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Unsolved words show their length, never their letters: the dashes are
    // the puzzle, and in easy mode the definition beside them is the clue.
    // Dots for what is still hidden, letters for what a hint has given.
    final label = found || revealed
        ? word.word
        : word.letters.substring(0, revealedLetters).toUpperCase() +
            '·' * (word.letters.length - revealedLetters);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: found
            ? (learnColors?.correctContainer ?? theme.colorScheme.secondaryContainer)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: found || revealed ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: found || revealed ? 0 : 3,
                      color: found
                          ? learnColors?.onCorrectContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    showDefinition ? word.definition : '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: found
                          ? learnColors?.onCorrectContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (word.isPangram)
                  Icon(
                    Icons.star,
                    size: 16,
                    color: found
                        ? learnColors?.onCorrectContainer
                        : theme.colorScheme.outline,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
