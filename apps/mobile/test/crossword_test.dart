import 'package:flutter_test/flutter_test.dart';
import 'package:kamusi_mobile/domain/models/crossword_puzzle.dart';

Map<String, dynamic> entry({
  int number = 1,
  String direction = 'across',
  int row = 0,
  int col = 0,
  String word = 'mti',
  String? answer,
  String definition = 'Mmea mkubwa wenye shina.',
  int points = 30,
}) {
  return {
    'lexeme_id': 'lex-$number$direction',
    'number': number,
    'direction': direction,
    'row': row,
    'col': col,
    'word': word,
    'answer': answer ?? word.toLowerCase(),
    'definition': definition,
    'pos_code': 'NOUN',
    'points': points,
  };
}

Map<String, dynamic> payload({int size = 5, List<Map<String, dynamic>>? entries}) {
  return {
    'lang_code': 'sw',
    'size': size,
    // "mti" across at (0,0) and "maji" down at (0,0) share the m.
    'entries': entries ??
        [
          entry(number: 1, direction: 'across', row: 0, col: 0, word: 'mti'),
          entry(
            number: 1,
            direction: 'down',
            row: 0,
            col: 0,
            word: 'maji',
            definition: 'Kiowevu kisicho na rangi.',
            points: 40,
          ),
        ],
  };
}

void main() {
  group('parsing', () {
    test('reads the entries', () {
      final puzzle = CrosswordPuzzle.fromJson(payload());

      expect(puzzle.size, 5);
      expect(puzzle.entries.length, 2);
      expect(puzzle.entries.first.isAcross, isTrue);
    });

    test('drops an answer that runs off the grid', () {
      // Its cells could never be drawn or filled.
      final puzzle = CrosswordPuzzle.fromJson(payload(
        size: 3,
        entries: [entry(word: 'kizingiti', row: 0, col: 0)],
      ));

      expect(puzzle.entries, isEmpty);
      expect(puzzle.isEmpty, isTrue);
    });

    test('drops an entry with no clue', () {
      final puzzle = CrosswordPuzzle.fromJson(
        payload(entries: [entry(definition: '')]),
      );

      expect(puzzle.entries, isEmpty);
    });

    test('survives an empty payload', () {
      final puzzle = CrosswordPuzzle.fromJson(const {});

      expect(puzzle.isEmpty, isTrue);
      expect(puzzle.filledCells, isEmpty);
    });
  });

  group('the grid derived from the entries', () {
    final puzzle = CrosswordPuzzle.fromJson(payload());

    test('cells come from the answers, not a second copy in the payload', () {
      // "mti" across plus "maji" down sharing (0,0) is 3 + 4 - 1 cells.
      expect(puzzle.filledCells.length, 6);
      expect(puzzle.filledCells.contains(const CrosswordCell(0, 2)), isTrue);
      expect(puzzle.filledCells.contains(const CrosswordCell(3, 0)), isTrue);
      expect(puzzle.filledCells.contains(const CrosswordCell(2, 2)), isFalse);
    });

    test('the shared cell holds one letter both answers agree on', () {
      expect(puzzle.solution[const CrosswordCell(0, 0)], 'm');
    });

    test('a start cell carries its number once', () {
      expect(puzzle.cellNumbers[const CrosswordCell(0, 0)], 1);
      expect(puzzle.cellNumbers.length, 1,
          reason: 'both answers start in the same cell');
    });

    test('a crossing cell belongs to both entries', () {
      final here = puzzle.entriesAt(const CrosswordCell(0, 0));

      expect(here.length, 2);
      expect(here.map((e) => e.direction).toSet(), {'across', 'down'});
    });

    test('a cell on one answer only belongs to that one', () {
      expect(puzzle.entriesAt(const CrosswordCell(0, 2)).length, 1);
    });

    test('an empty cell belongs to nothing', () {
      expect(puzzle.entriesAt(const CrosswordCell(4, 4)), isEmpty);
    });
  });

  group('scoring', () {
    test('a board totals what its clues are worth', () {
      expect(CrosswordPuzzle.fromJson(payload()).totalPoints, 70);
    });
  });

  group('cells', () {
    test('equal coordinates are equal cells', () {
      expect(const CrosswordCell(1, 2), const CrosswordCell(1, 2));
      expect(<CrosswordCell>{const CrosswordCell(1, 2), const CrosswordCell(1, 2)}.length, 1);
    });
  });
}
