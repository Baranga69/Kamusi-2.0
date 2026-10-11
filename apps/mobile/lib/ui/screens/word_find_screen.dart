import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../domain/models/word_find_puzzle.dart';
import '../../providers/learn_providers.dart';
import '../theme/kamusi_learn_colors.dart';
import 'lexeme_detail_screen.dart';

/// Tafuta Neno — a word-search built from published vocabulary.
///
/// The grid is the way in; the definition is the thing a learner leaves with.
/// So finding a word does not just score a point and vanish: the meaning opens
/// underneath the puzzle and stays there, and tapping it goes to the full
/// entry. The found list is the real content of this screen.
class WordFindScreen extends ConsumerStatefulWidget {
  const WordFindScreen({super.key, required this.puzzle});

  final WordFindPuzzle puzzle;

  @override
  ConsumerState<WordFindScreen> createState() => _WordFindScreenState();
}

class _WordFindScreenState extends ConsumerState<WordFindScreen> {
  /// Words found, most recent first, so the newest meaning is at the top of
  /// the list where the eye already is.
  final List<WordFindWord> _found = [];
  final Set<WordFindCell> _foundCells = {};

  /// The drag in progress.
  WordFindCell? _dragStart;
  List<WordFindCell> _dragPath = const [];
  bool _dragIsWrong = false;

  WordFindPuzzle get _puzzle => widget.puzzle;

  bool get _complete => _found.length == _puzzle.words.length;

  // --- geometry ----------------------------------------------------------

  /// Which cell a local offset falls in, or null if it is outside the grid.
  WordFindCell? _cellAt(Offset local, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return null;
    }
    final cell = size.width / _puzzle.size;
    final col = (local.dx / cell).floor();
    final row = (local.dy / cell).floor();
    if (row < 0 || row >= _puzzle.size || col < 0 || col >= _puzzle.size) {
      return null;
    }
    return WordFindCell(row, col);
  }

  /// The straight line from `start` to `end`, or empty if they are not on one.
  ///
  /// A word search is only selectable along a row, a column or a 45° diagonal.
  /// Anything else is a drag the player did not mean, so it highlights nothing
  /// rather than guessing.
  List<WordFindCell> _lineBetween(WordFindCell start, WordFindCell end) {
    final dRow = end.row - start.row;
    final dCol = end.col - start.col;
    if (dRow == 0 && dCol == 0) {
      return [start];
    }
    final straight = dRow == 0 || dCol == 0 || dRow.abs() == dCol.abs();
    if (!straight) {
      return const [];
    }
    final steps = dRow.abs() > dCol.abs() ? dRow.abs() : dCol.abs();
    final stepRow = dRow == 0 ? 0 : dRow ~/ dRow.abs();
    final stepCol = dCol == 0 ? 0 : dCol ~/ dCol.abs();
    return List<WordFindCell>.generate(
      steps + 1,
      (i) => WordFindCell(start.row + stepRow * i, start.col + stepCol * i),
    );
  }

  // --- the drag ----------------------------------------------------------

  void _onPanStart(Offset local, Size size) {
    final cell = _cellAt(local, size);
    if (cell == null) {
      return;
    }
    setState(() {
      _dragStart = cell;
      _dragPath = [cell];
      _dragIsWrong = false;
    });
  }

  void _onPanUpdate(Offset local, Size size) {
    final start = _dragStart;
    if (start == null) {
      return;
    }
    final cell = _cellAt(local, size);
    if (cell == null) {
      return;
    }
    final path = _lineBetween(start, cell);
    if (path.isEmpty || _sameAs(path, _dragPath)) {
      return;
    }
    setState(() => _dragPath = path);
  }

  bool _sameAs(List<WordFindCell> a, List<WordFindCell> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  void _onPanEnd() {
    final path = _dragPath;
    if (path.length < 2) {
      setState(() {
        _dragStart = null;
        _dragPath = const [];
      });
      return;
    }

    WordFindWord? hit;
    for (final word in _puzzle.words) {
      if (!_found.contains(word) && word.matches(path)) {
        hit = word;
        break;
      }
    }

    if (hit == null) {
      // Wrong: hold the selection red for a beat so it is clear the drag was
      // read, then clear it. Silently dropping it reads as an unresponsive
      // grid.
      setState(() => _dragIsWrong = true);
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) {
          return;
        }
        setState(() {
          _dragStart = null;
          _dragPath = const [];
          _dragIsWrong = false;
        });
      });
      return;
    }

    final found = hit;
    setState(() {
      _found.insert(0, found);
      _foundCells.addAll(found.cells);
      _dragStart = null;
      _dragPath = const [];
      _dragIsWrong = false;
    });
  }

  void _openEntry(WordFindWord word) {
    if (word.lexemeId.isEmpty) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LexemeDetailScreen(lexemeId: word.lexemeId),
      ),
    );
  }

  // --- build -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final learnColors = theme.extension<KamusiLearnColors>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.learnWordFindTitle),
        actions: [
          IconButton(
            tooltip: l10n.learnWordFindNew,
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(wordFindProvider);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _ProgressHeader(
            found: _found.length,
            total: _puzzle.words.length,
            complete: _complete,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final side = constraints.maxWidth;
              final size = Size(side, side);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) => _onPanStart(details.localPosition, size),
                onPanUpdate: (details) => _onPanUpdate(details.localPosition, size),
                onPanEnd: (_) => _onPanEnd(),
                onPanCancel: _onPanEnd,
                child: SizedBox(
                  width: side,
                  height: side,
                  child: _Grid(
                    puzzle: _puzzle,
                    foundCells: _foundCells,
                    selection: _dragPath,
                    selectionIsWrong: _dragIsWrong,
                    learnColors: learnColors,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            _complete ? l10n.learnWordFindDone : l10n.learnWordFindHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          // The point of the screen. Empty until the first find, because a
          // list of blanks would give the answers away by their shape.
          if (_found.isEmpty)
            _StillHunting(
              remaining: _puzzle.words.length,
              message: l10n.learnWordFindEmpty,
            )
          else ...[
            Text(
              l10n.learnWordFindFoundTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            for (final word in _found)
              _FoundWordCard(
                word: word,
                onTap: () => _openEntry(word),
                openLabel: l10n.learnOpenEntry,
              ),
          ],
        ],
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.found,
    required this.total,
    required this.complete,
  });

  final int found;
  final int total;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final learnColors = theme.extension<KamusiLearnColors>();
    final fraction = total == 0 ? 0.0 : found / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$found / $total',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (complete)
              Icon(
                Icons.celebration_outlined,
                color: learnColors?.correct ?? theme.colorScheme.primary,
              ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor:
                learnColors?.progressTrack ?? theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              learnColors?.correct ?? theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.puzzle,
    required this.foundCells,
    required this.selection,
    required this.selectionIsWrong,
    required this.learnColors,
  });

  final WordFindPuzzle puzzle;
  final Set<WordFindCell> foundCells;
  final List<WordFindCell> selection;
  final bool selectionIsWrong;
  final KamusiLearnColors? learnColors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = selection.toSet();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            for (var row = 0; row < puzzle.size; row++)
              Expanded(
                child: Row(
                  children: [
                    for (var col = 0; col < puzzle.size; col++)
                      Expanded(
                        child: _LetterCell(
                          letter: puzzle.letterAt(row, col),
                          isFound: foundCells.contains(WordFindCell(row, col)),
                          isSelected: selected.contains(WordFindCell(row, col)),
                          selectionIsWrong: selectionIsWrong,
                          learnColors: learnColors,
                        ),
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

class _LetterCell extends StatelessWidget {
  const _LetterCell({
    required this.letter,
    required this.isFound,
    required this.isSelected,
    required this.selectionIsWrong,
    required this.learnColors,
  });

  final String letter;
  final bool isFound;
  final bool isSelected;
  final bool selectionIsWrong;
  final KamusiLearnColors? learnColors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color? background;
    Color foreground = colorScheme.onSurface;
    if (isSelected) {
      background = selectionIsWrong
          ? (learnColors?.incorrectContainer ?? colorScheme.errorContainer)
          : colorScheme.primaryContainer;
      foreground = selectionIsWrong
          ? (learnColors?.onIncorrect ?? colorScheme.onErrorContainer)
          : colorScheme.onPrimaryContainer;
    } else if (isFound) {
      background = learnColors?.correctContainer ?? colorScheme.secondaryContainer;
      foreground = learnColors?.onCorrect ?? colorScheme.onSecondaryContainer;
    }

    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Text(
              letter.toUpperCase(),
              style: theme.textTheme.titleMedium?.copyWith(
                color: foreground,
                fontWeight: isFound || isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StillHunting extends StatelessWidget {
  const _StillHunting({required this.remaining, required this.message});

  final int remaining;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A found word and its meaning. This is what the game is for.
class _FoundWordCard extends StatelessWidget {
  const _FoundWordCard({
    required this.word,
    required this.onTap,
    required this.openLabel,
  });

  final WordFindWord word;
  final VoidCallback onTap;
  final String openLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final learnColors = theme.extension<KamusiLearnColors>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: learnColors?.correctContainer ??
            theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: word.lexemeId.isEmpty ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        word.word,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: learnColors?.onCorrect,
                        ),
                      ),
                    ),
                    if (word.posCode != null && word.posCode!.isNotEmpty)
                      Text(
                        word.posCode!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: learnColors?.onCorrect.withValues(alpha: 0.75),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  word.definition,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: learnColors?.onCorrect,
                  ),
                ),
                if (word.lexemeId.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        openLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: learnColors?.onCorrect,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: learnColors?.onCorrect,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
