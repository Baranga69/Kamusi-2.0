import 'package:flutter_test/flutter_test.dart';
import 'package:kamusi_mobile/domain/models/word_find_puzzle.dart';

/// A grid whose solution paths are known, so matching can be checked exactly.
///
///   row 0: k a l a m u
///   "kalamu" runs east from (0,0)
Map<String, dynamic> _payload({
  List<List<int>>? cells,
  String word = 'kalamu',
  String letters = 'kalamu',
  String definition = 'Chombo cha kuandikia chenye wino.',
}) {
  return {
    'lang_code': 'sw',
    'size': 6,
    'rows': ['kalamu', 'abcdef', 'ghijkl', 'mnopqr', 'stuvwx', 'yzabcd'],
    'words': [
      {
        'lexeme_id': 'lex-1',
        'word': word,
        'letters': letters,
        'definition': definition,
        'pos_code': 'NOUN',
        'cells': cells ??
            const [
              [0, 0],
              [0, 1],
              [0, 2],
              [0, 3],
              [0, 4],
              [0, 5],
            ],
      },
    ],
  };
}

List<WordFindCell> _path(List<List<int>> pairs) =>
    pairs.map((pair) => WordFindCell(pair[0], pair[1])).toList();

void main() {
  group('parsing', () {
    test('reads the grid and the words', () {
      final puzzle = WordFindPuzzle.fromJson(_payload());

      expect(puzzle.size, 6);
      expect(puzzle.rows.length, 6);
      expect(puzzle.words.single.word, 'kalamu');
      expect(puzzle.words.single.cells.length, 6);
      expect(puzzle.letterAt(0, 0), 'k');
      expect(puzzle.letterAt(0, 5), 'u');
    });

    test('letterAt is safe outside the grid', () {
      final puzzle = WordFindPuzzle.fromJson(_payload());

      expect(puzzle.letterAt(-1, 0), '');
      expect(puzzle.letterAt(0, 99), '');
      expect(puzzle.letterAt(99, 0), '');
    });

    test('drops a word whose path is the wrong length', () {
      // The path must spell the word; four cells cannot hold six letters.
      final puzzle = WordFindPuzzle.fromJson(_payload(cells: const [
        [0, 0],
        [0, 1],
        [0, 2],
        [0, 3],
      ]));

      expect(puzzle.words, isEmpty);
      expect(puzzle.isEmpty, isTrue);
    });

    test('drops a word whose path leaves the grid', () {
      // Trusting this would wedge the game on an out-of-range lookup.
      final puzzle = WordFindPuzzle.fromJson(_payload(cells: const [
        [0, 0],
        [0, 1],
        [0, 2],
        [0, 3],
        [0, 4],
        [0, 99],
      ]));

      expect(puzzle.words, isEmpty);
    });

    test('drops a word with no meaning to reveal', () {
      final puzzle = WordFindPuzzle.fromJson(_payload(definition: ''));

      expect(puzzle.words, isEmpty);
    });

    test('survives a payload with nothing in it', () {
      final puzzle = WordFindPuzzle.fromJson(const {});

      expect(puzzle.isEmpty, isTrue);
      expect(puzzle.rows, isEmpty);
      expect(puzzle.words, isEmpty);
    });
  });

  group('matching a drag', () {
    final word = WordFindPuzzle.fromJson(_payload()).words.single;

    test('accepts the exact path', () {
      expect(
        word.matches(_path(const [
          [0, 0],
          [0, 1],
          [0, 2],
          [0, 3],
          [0, 4],
          [0, 5],
        ])),
        isTrue,
      );
    });

    test('accepts the path dragged backwards', () {
      // The grid only hides words left-to-right, but dragging right-to-left
      // across one is the same gesture to a player.
      expect(
        word.matches(_path(const [
          [0, 5],
          [0, 4],
          [0, 3],
          [0, 2],
          [0, 1],
          [0, 0],
        ])),
        isTrue,
      );
    });

    test('rejects the right cells in the wrong order', () {
      expect(
        word.matches(_path(const [
          [0, 1],
          [0, 0],
          [0, 2],
          [0, 3],
          [0, 4],
          [0, 5],
        ])),
        isFalse,
      );
    });

    test('rejects a path that is too short', () {
      expect(
        word.matches(_path(const [
          [0, 0],
          [0, 1],
        ])),
        isFalse,
      );
    });

    test('rejects a path that overshoots the word', () {
      expect(
        word.matches(_path(const [
          [0, 0],
          [0, 1],
          [0, 2],
          [0, 3],
          [0, 4],
          [0, 5],
          [1, 5],
        ])),
        isFalse,
      );
    });

    test('rejects an empty drag', () {
      expect(word.matches(const []), isFalse);
    });
  });

  group('cells', () {
    test('two cells with the same coordinates are equal', () {
      // The found-cell set depends on this.
      expect(const WordFindCell(2, 3), const WordFindCell(2, 3));
      expect(
        const WordFindCell(2, 3).hashCode,
        const WordFindCell(2, 3).hashCode,
      );
      expect(<WordFindCell>{const WordFindCell(1, 1), const WordFindCell(1, 1)}.length, 1);
    });

    test('different coordinates are not equal', () {
      expect(const WordFindCell(2, 3) == const WordFindCell(3, 2), isFalse);
    });
  });
}
