import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../data/game_settings_store.dart';
import '../../domain/models/codeword_puzzle.dart';
import '../../providers/learn_providers.dart';
import '../theme/kamusi_learn_colors.dart';
import '../widgets/game_timer_bar.dart';
import 'lexeme_detail_screen.dart';

/// Neno la Siri — a codeword.
///
/// Every letter is a number, the same number everywhere it appears, so
/// cracking one letter opens it in every word at once. That is the pleasure
/// of the form, and it happens to drill the thing a learner of a new
/// orthography most needs: which letters actually recur in this language.
///
/// Two letters are given. The clues are the definitions, so even a board you
/// cannot finish has taught you five words by the time you give up on it.
class CodewordScreen extends ConsumerStatefulWidget {
  const CodewordScreen({super.key, required this.puzzle, this.timed = false});

  final CodewordPuzzle puzzle;
  final bool timed;

  @override
  ConsumerState<CodewordScreen> createState() => _CodewordScreenState();
}

class _CodewordScreenState extends ConsumerState<CodewordScreen> {
  /// number -> the letter the player has put against it.
  final Map<int, String> _guesses = {};

  int? _selectedCode;
  bool _outOfTime = false;

  CodewordPuzzle get _puzzle => widget.puzzle;

  @override
  void initState() {
    super.initState();
    // The given letters are guesses the board starts with, so everything
    // downstream can treat them identically.
    for (final letter in _puzzle.revealed) {
      final code = _puzzle.codeFor(letter);
      if (code != null) {
        _guesses[code] = letter;
      }
    }
  }

  bool _isGiven(int code) {
    final letter = _puzzle.letterFor(code);
    return _puzzle.revealed.contains(letter);
  }

  bool _isCorrect(int code) =>
      _guesses[code] != null && _guesses[code] == _puzzle.letterFor(code);

  bool _entrySolved(CodewordEntry entry) =>
      entry.letters.split('').every((letter) {
        final code = _puzzle.codeFor(letter);
        return code != null && _guesses[code] == letter;
      });

  int get _solvedCount => _puzzle.entries.where(_entrySolved).length;

  bool get _complete => _solvedCount == _puzzle.entries.length;

  bool get _over => _complete || _outOfTime;

  /// Letters already committed to another number, so the picker can grey
  /// them out rather than letting a player assign one letter twice.
  Set<String> get _usedLetters {
    final used = <String>{};
    _guesses.forEach((code, letter) {
      if (letter.isNotEmpty) {
        used.add(letter);
      }
    });
    return used;
  }

  Future<void> _pickLetter(int code) async {
    if (_over || _isGiven(code)) {
      return;
    }
    setState(() => _selectedCode = code);
    final l10n = AppLocalizations.of(context)!;
    final letters = _puzzle.codes.keys.toList()..sort();
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => _LetterPicker(
        title: l10n.learnCodewordPick(code),
        clearLabel: l10n.learnCodewordClear,
        letters: letters,
        used: _usedLetters,
        current: _guesses[code],
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedCode = null;
      if (chosen == null) {
        return;
      }
      if (chosen.isEmpty) {
        _guesses.remove(code);
        return;
      }
      // One letter cannot stand for two numbers; taking it here releases it
      // wherever it was before, which is what a player means by changing
      // their mind.
      _guesses.removeWhere((other, letter) => letter == chosen && other != code);
      _guesses[code] = chosen;
    });
  }

  void _openEntry(CodewordEntry entry) {
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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.learnCodewordTitle),
        actions: [
          IconButton(
            tooltip: l10n.learnWordBuildNew,
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(codewordProvider);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (widget.timed) ...[
            GameTimerBar(
              duration: GameDurations.codeword,
              paused: _over,
              onExpired: () => setState(() => _outOfTime = true),
            ),
            const SizedBox(height: 14),
          ],
          Row(
            children: [
              Text(
                '$_solvedCount / ${_puzzle.entries.length}',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: _puzzle.entries.isEmpty
                        ? 0
                        : _solvedCount / _puzzle.entries.length,
                    minHeight: 6,
                    backgroundColor: learnColors?.progressTrack ??
                        theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      learnColors?.correct ?? theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _outOfTime
                ? l10n.learnGameTimeUp
                : _complete
                    ? l10n.learnCodewordDone
                    : l10n.learnCodewordHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          for (final entry in _puzzle.entries) ...[
            _EntryRow(
              entry: entry,
              puzzle: _puzzle,
              guesses: _guesses,
              selectedCode: _selectedCode,
              revealAll: _outOfTime,
              solved: _entrySolved(entry),
              isGiven: _isGiven,
              isCorrect: _isCorrect,
              onTapCode: _pickLetter,
              onOpen: () => _openEntry(entry),
              learnColors: learnColors,
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

/// One word: its numbered cells above, its clue below.
class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.puzzle,
    required this.guesses,
    required this.selectedCode,
    required this.revealAll,
    required this.solved,
    required this.isGiven,
    required this.isCorrect,
    required this.onTapCode,
    required this.onOpen,
    required this.learnColors,
  });

  final CodewordEntry entry;
  final CodewordPuzzle puzzle;
  final Map<int, String> guesses;
  final int? selectedCode;
  final bool revealAll;
  final bool solved;
  final bool Function(int) isGiven;
  final bool Function(int) isCorrect;
  final void Function(int) onTapCode;
  final VoidCallback onOpen;
  final KamusiLearnColors? learnColors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final letter in entry.letters.split(''))
              _CodeCell(
                code: puzzle.codeFor(letter) ?? 0,
                letter: revealAll ? letter : guesses[puzzle.codeFor(letter)],
                given: isGiven(puzzle.codeFor(letter) ?? -1),
                correct: revealAll || isCorrect(puzzle.codeFor(letter) ?? -1),
                selected: selectedCode == puzzle.codeFor(letter),
                onTap: () => onTapCode(puzzle.codeFor(letter) ?? 0),
                learnColors: learnColors,
              ),
          ],
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: solved || revealAll ? onOpen : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.definition,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (solved || revealAll)
                  Icon(
                    Icons.arrow_forward,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CodeCell extends StatelessWidget {
  const _CodeCell({
    required this.code,
    required this.letter,
    required this.given,
    required this.correct,
    required this.selected,
    required this.onTap,
    required this.learnColors,
  });

  final int code;
  final String? letter;
  final bool given;
  final bool correct;
  final bool selected;
  final VoidCallback onTap;
  final KamusiLearnColors? learnColors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filled = letter != null && letter!.isNotEmpty;

    // A given letter looks settled, a right answer looks right, a filled but
    // wrong one looks ordinary — the board never says "wrong" on its own,
    // because working that out is the game.
    Color background;
    Color foreground;
    if (given) {
      background = theme.colorScheme.surfaceContainerHighest;
      foreground = theme.colorScheme.onSurface;
    } else if (filled && correct) {
      background =
          learnColors?.correctContainer ?? theme.colorScheme.secondaryContainer;
      foreground =
          learnColors?.onCorrectContainer ?? theme.colorScheme.onSecondaryContainer;
    } else if (filled) {
      background = theme.colorScheme.primaryContainer;
      foreground = theme.colorScheme.onPrimaryContainer;
    } else {
      background = theme.colorScheme.surface;
      foreground = theme.colorScheme.onSurfaceVariant;
    }

    return InkWell(
      onTap: given ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 38,
        height: 46,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              filled ? letter!.toUpperCase() : '',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: foreground,
                height: 1.1,
              ),
            ),
            Text(
              '$code',
              style: theme.textTheme.labelSmall?.copyWith(
                color: foreground.withValues(alpha: 0.65),
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LetterPicker extends StatelessWidget {
  const _LetterPicker({
    required this.title,
    required this.clearLabel,
    required this.letters,
    required this.used,
    required this.current,
  });

  final String title;
  final String clearLabel;
  final List<String> letters;
  final Set<String> used;
  final String? current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final letter in letters)
                  _PickerTile(
                    letter: letter,
                    // Greyed, not hidden: knowing which letters are spoken
                    // for is part of the deduction.
                    spent: used.contains(letter) && letter != current,
                    selected: letter == current,
                    onTap: () => Navigator.of(context).pop(letter),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(''),
                child: Text(clearLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.letter,
    required this.spent,
    required this.selected,
    required this.onTap,
  });

  final String letter;
  final bool spent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          letter.toUpperCase(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: selected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface
                    .withValues(alpha: spent ? 0.3 : 1.0),
          ),
        ),
      ),
    );
  }
}
