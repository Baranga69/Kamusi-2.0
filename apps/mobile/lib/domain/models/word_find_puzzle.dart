/// A word-search grid and the words hidden in it.
///
/// `cells` arrives from the API for the same reason `LearnQuestion.answerIndex`
/// does: nothing is at stake, the puzzle has to be playable from the cache with
/// no connection, and checking a drag locally is instant where a round trip per
/// attempt would make the grid feel broken.
class WordFindWord {
  const WordFindWord({
    required this.lexemeId,
    required this.word,
    required this.letters,
    required this.definition,
    required this.posCode,
    required this.points,
    required this.cells,
  });

  final String lexemeId;

  /// The headword as it should be read, capitals and all.
  final String word;

  /// The same word reduced to the letters in the grid.
  final String letters;

  /// What the learner takes away once they have found it.
  final String definition;
  final String? posCode;

  /// What finding this word is worth, before any speed bonus.
  final int points;

  /// The solution path, in reading order.
  final List<WordFindCell> cells;

  factory WordFindWord.fromJson(Map<String, dynamic> json) {
    return WordFindWord(
      lexemeId: (json['lexeme_id'] ?? '').toString(),
      word: (json['word'] ?? '').toString(),
      letters: (json['letters'] ?? '').toString(),
      definition: (json['definition'] ?? '').toString(),
      posCode: json['pos_code']?.toString(),
      points: (json['points'] as num?)?.toInt() ?? 0,
      cells: (json['cells'] as List?)
              ?.whereType<List>()
              .where((pair) => pair.length >= 2)
              .map((pair) => WordFindCell(
                    (pair[0] as num).toInt(),
                    (pair[1] as num).toInt(),
                  ))
              .toList() ??
          const <WordFindCell>[],
    );
  }

  /// True when the path is as long as the word and leads somewhere.
  bool get isPlayable =>
      letters.isNotEmpty && cells.length == letters.length && definition.isNotEmpty;

  /// Whether `path` traces this word, in either direction.
  ///
  /// Reversed counts: the grid only hides words left-to-right, but dragging
  /// right-to-left across one is the same gesture to a player and refusing it
  /// would feel like a bug.
  bool matches(List<WordFindCell> path) {
    if (path.length != cells.length) {
      return false;
    }
    final forward = List<WordFindCell>.generate(cells.length, (i) => cells[i]);
    final backward = forward.reversed.toList();
    bool same(List<WordFindCell> a) {
      for (var i = 0; i < a.length; i++) {
        if (a[i] != path[i]) {
          return false;
        }
      }
      return true;
    }

    return same(forward) || same(backward);
  }
}

/// A grid position. A value type so it can key a set of found cells.
class WordFindCell {
  const WordFindCell(this.row, this.col);

  final int row;
  final int col;

  @override
  bool operator ==(Object other) =>
      other is WordFindCell && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => '($row,$col)';
}

class WordFindPuzzle {
  const WordFindPuzzle({
    required this.langCode,
    required this.size,
    required this.rows,
    required this.words,
  });

  final String langCode;
  final int size;

  /// One string per row, each `size` letters long.
  final List<String> rows;
  final List<WordFindWord> words;

  bool get isEmpty => words.isEmpty || rows.isEmpty;

  String letterAt(int row, int col) {
    if (row < 0 || row >= rows.length) {
      return '';
    }
    final line = rows[row];
    if (col < 0 || col >= line.length) {
      return '';
    }
    return line[col];
  }

  factory WordFindPuzzle.fromJson(Map<String, dynamic> json) {
    final rows = (json['rows'] as List?)
            ?.map((row) => row?.toString() ?? '')
            .where((row) => row.isNotEmpty)
            .toList() ??
        const <String>[];
    final size = (json['size'] as num?)?.toInt() ?? rows.length;
    final words = (json['words'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(WordFindWord.fromJson)
            .where((word) => word.isPlayable)
            // A path that runs outside the grid we were given would wedge the
            // game, so drop it rather than trust the payload.
            .where((word) => word.cells.every((cell) =>
                cell.row >= 0 &&
                cell.row < rows.length &&
                cell.col >= 0 &&
                cell.col < (rows.isEmpty ? 0 : rows.first.length)))
            .toList() ??
        const <WordFindWord>[];
    return WordFindPuzzle(
      langCode: (json['lang_code'] ?? 'sw').toString(),
      size: size,
      rows: rows,
      words: words,
    );
  }
}
