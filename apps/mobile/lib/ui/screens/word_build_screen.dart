import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../domain/models/word_build_puzzle.dart';
import '../../providers/learn_providers.dart';
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
  const WordBuildScreen({super.key, required this.puzzle});

  final WordBuildPuzzle puzzle;

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

  WordBuildPuzzle get _puzzle => widget.puzzle;

  String get _attempt => _selected.map((index) => _ring[index]).join();

  bool get _complete => _found.length == _puzzle.words.length;

  /// Tile centres on a circle, as fractions of the ring box.
  List<Offset> _centres(Size size) {
    final count = _ring.length;
    final radius = size.shortestSide * 0.36;
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
      setState(() => _selected.removeLast());
      return;
    }
    if (_selected.contains(tile)) {
      return;
    }
    setState(() => _selected.add(tile));
  }

  void _onUp() {
    final attempt = _attempt;
    final solved = attempt.length >= 3 ? _puzzle.solve(attempt) : null;

    setState(() {
      _dragLock = false;
      if (solved != null && !_found.contains(solved.letters)) {
        _found.add(solved.letters);
        _lastAttemptFailed = false;
      } else if (attempt.isNotEmpty) {
        _lastAttemptFailed = solved == null;
      }
      _selected.clear();
    });
  }

  void _shuffle() {
    setState(() {
      _ring = List<String>.from(_ring)..shuffle();
      _selected.clear();
    });
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

    // Longest first: the pangram is the headline answer and the short words
    // read as the warm-up they are.
    final words = [..._puzzle.words]
      ..sort((a, b) => a.letters.length == b.letters.length
          ? a.letters.compareTo(b.letters)
          : b.letters.length - a.letters.length);

    return Scaffold(
      appBar: AppBar(
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
          _ModeSwitch(
            easy: _easyMode,
            easyLabel: l10n.learnWordBuildEasy,
            hardLabel: l10n.learnWordBuildHard,
            onChanged: (easy) => setState(() => _easyMode = easy),
          ),
          const SizedBox(height: 6),
          Text(
            _easyMode
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
                      painter: _RingLinkPainter(
                        centres: _centres(size),
                        selected: _selected,
                        color: theme.colorScheme.primary,
                      ),
                      child: Stack(
                        children: [
                          for (var index = 0; index < _ring.length; index++)
                            _RingTile(
                              letter: _ring[index],
                              centre: _centres(size)[index],
                              radius: _tileRadius(size),
                              selected: _selected.contains(index),
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
          _ProgressRow(
            found: _found.length,
            total: _puzzle.words.length,
            complete: _complete,
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
              showDefinition: _easyMode || _found.contains(word.letters),
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
  });

  final String attempt;
  final bool failed;
  final String placeholder;
  final KamusiLearnColors? learnColors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final empty = attempt.isEmpty;
    final background = failed && empty
        ? (learnColors?.incorrectContainer ?? theme.colorScheme.errorContainer)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45);
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
  });

  final String letter;
  final Offset centre;
  final double radius;
  final bool selected;

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
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              letter.toUpperCase(),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The line joining the tiles picked so far, so a long word stays legible as
/// a shape rather than a guess about which letters are lit.
class _RingLinkPainter extends CustomPainter {
  _RingLinkPainter({
    required this.centres,
    required this.selected,
    required this.color,
  });

  final List<Offset> centres;
  final List<int> selected;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (selected.length < 2) {
      return;
    }
    final paint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(centres[selected.first].dx, centres[selected.first].dy);
    for (final index in selected.skip(1)) {
      path.lineTo(centres[index].dx, centres[index].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_RingLinkPainter old) =>
      old.selected.length != selected.length || old.color != color;
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.found,
    required this.total,
    required this.complete,
    required this.doneLabel,
    required this.learnColors,
  });

  final int found;
  final int total;
  final bool complete;
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
              valueColor: AlwaysStoppedAnimation<Color>(
                learnColors?.correct ?? theme.colorScheme.primary,
              ),
            ),
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
  });

  final WordBuildWord word;
  final bool found;
  final bool showDefinition;
  final VoidCallback onTap;
  final KamusiLearnColors? learnColors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Unsolved words show their length, never their letters: the dashes are
    // the puzzle, and in easy mode the definition beside them is the clue.
    final label = found ? word.word : '·' * word.letters.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: found
            ? (learnColors?.correctContainer ?? theme.colorScheme.secondaryContainer)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: found ? onTap : null,
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
                      letterSpacing: found ? 0 : 3,
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
