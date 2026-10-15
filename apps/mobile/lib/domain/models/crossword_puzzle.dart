/// One answer in the crossword, with its clue.
class CrosswordEntry {
  const CrosswordEntry({
    required this.lexemeId,
    required this.number,
    required this.direction,
    required this.row,
    required this.col,
    required this.word,
    required this.answer,
    required this.definition,
    required this.posCode,
    required this.points,
  });

  final String lexemeId;

  /// The clue number, shared with a perpendicular entry starting in the same
  /// cell, exactly as a printed crossword numbers them.
  final int number;

  /// 'across' | 'down'
  final String direction;
  final int row;
  final int col;
  final String word;

  /// The answer in lower case, which is what the cells hold.
  final String answer;
  final String definition;
  final String? posCode;

  /// What solving this clue is worth, before any speed bonus.
  final int points;

  bool get isAcross => direction == 'across';

  bool get isPlayable =>
      answer.length >= 2 && definition.isNotEmpty && (isAcross || direction == 'down');

  /// The cells this answer runs through, in reading order.
  List<CrosswordCell> get cells {
    final dr = isAcross ? 0 : 1;
    final dc = isAcross ? 1 : 0;
    return List<CrosswordCell>.generate(
      answer.length,
      (i) => CrosswordCell(row + dr * i, col + dc * i),
    );
  }

  factory CrosswordEntry.fromJson(Map<String, dynamic> json) {
    return CrosswordEntry(
      lexemeId: (json['lexeme_id'] ?? '').toString(),
      number: (json['number'] as num?)?.toInt() ?? 0,
      direction: (json['direction'] ?? 'across').toString(),
      row: (json['row'] as num?)?.toInt() ?? 0,
      col: (json['col'] as num?)?.toInt() ?? 0,
      word: (json['word'] ?? '').toString(),
      answer: (json['answer'] ?? '').toString().toLowerCase(),
      definition: (json['definition'] ?? '').toString(),
      posCode: json['pos_code']?.toString(),
      points: (json['points'] as num?)?.toInt() ?? 0,
    );
  }
}

class CrosswordCell {
  const CrosswordCell(this.row, this.col);

  final int row;
  final int col;

  @override
  bool operator ==(Object other) =>
      other is CrosswordCell && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => '($row,$col)';
}

class CrosswordPuzzle {
  const CrosswordPuzzle({
    required this.langCode,
    required this.size,
    required this.entries,
  });

  final String langCode;
  final int size;
  final List<CrosswordEntry> entries;

  bool get isEmpty => entries.isEmpty;

  /// Which cells are fillable, derived from the entries rather than sent:
  /// a grid in the payload would be a second source of truth for the same
  /// thing, and the two could disagree.
  Set<CrosswordCell> get filledCells {
    final cells = <CrosswordCell>{};
    for (final entry in entries) {
      cells.addAll(entry.cells);
    }
    return cells;
  }

  /// The number printed in a cell, if an answer starts there.
  Map<CrosswordCell, int> get cellNumbers {
    final numbers = <CrosswordCell, int>{};
    for (final entry in entries) {
      numbers[CrosswordCell(entry.row, entry.col)] = entry.number;
    }
    return numbers;
  }

  /// The right letter for a cell, from whichever answer covers it.
  Map<CrosswordCell, String> get solution {
    final letters = <CrosswordCell, String>{};
    for (final entry in entries) {
      final cells = entry.cells;
      for (var i = 0; i < cells.length; i++) {
        letters[cells[i]] = entry.answer[i];
      }
    }
    return letters;
  }

  /// Entries running through a cell — up to two, one each way.
  List<CrosswordEntry> entriesAt(CrosswordCell cell) =>
      entries.where((entry) => entry.cells.contains(cell)).toList();

  int get totalPoints =>
      entries.fold<int>(0, (sum, entry) => sum + entry.points);

  factory CrosswordPuzzle.fromJson(Map<String, dynamic> json) {
    final size = (json['size'] as num?)?.toInt() ?? 0;
    final entries = (json['entries'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(CrosswordEntry.fromJson)
            .where((entry) => entry.isPlayable)
            // An answer running off the grid would leave cells that can
            // never be drawn or filled.
            .where((entry) => entry.cells.every((cell) =>
                cell.row >= 0 &&
                cell.row < size &&
                cell.col >= 0 &&
                cell.col < size))
            .toList() ??
        const <CrosswordEntry>[];
    return CrosswordPuzzle(
      langCode: (json['lang_code'] ?? 'sw').toString(),
      size: size,
      entries: entries,
    );
  }
}

/// What a backspace should do: the square to clear, and where the cursor
/// lands afterwards.
///
/// Pulled out of the screen so it can be tested. Deleting used to clear the
/// square under the cursor and stop, which meant emptying a wrong answer was
/// tap-delete-tap-delete all the way along it. Each press now steps back, so
/// repeating or holding the key unwinds the whole word.
class EraseStep {
  const EraseStep({required this.clear, required this.cursor});

  /// The square to empty, or null when there is nothing left to erase.
  final CrosswordCell? clear;

  /// Where the cursor should be after the press.
  final CrosswordCell cursor;
}

EraseStep eraseStep({
  required List<CrosswordCell> cells,
  required CrosswordCell cursor,
  required bool cursorIsFilled,
}) {
  final index = cells.indexOf(cursor);

  if (cursorIsFilled) {
    // Clear where we are, then step back so the next press continues rather
    // than stalling on the square just emptied.
    return EraseStep(
      clear: cursor,
      cursor: index > 0 ? cells[index - 1] : cursor,
    );
  }
  if (index > 0) {
    // Already empty: take the one before it instead of doing nothing.
    return EraseStep(clear: cells[index - 1], cursor: cells[index - 1]);
  }
  // Start of the answer and nothing to clear.
  return EraseStep(clear: null, cursor: cursor);
}
