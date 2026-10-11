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


  group('backspace', () {
    // "maji" across from (0,0): the cells a cursor walks.
    const cells = [
      CrosswordCell(0, 0),
      CrosswordCell(0, 1),
      CrosswordCell(0, 2),
      CrosswordCell(0, 3),
    ];

    test('clears the square you are on and steps back', () {
      final step = eraseStep(
        cells: cells,
        cursor: const CrosswordCell(0, 3),
        cursorIsFilled: true,
      );

      expect(step.clear, const CrosswordCell(0, 3));
      expect(step.cursor, const CrosswordCell(0, 2),
          reason: 'so the next press continues instead of stalling');
    });

    test('on an empty square it clears the one before instead', () {
      final step = eraseStep(
        cells: cells,
        cursor: const CrosswordCell(0, 2),
        cursorIsFilled: false,
      );

      expect(step.clear, const CrosswordCell(0, 1));
      expect(step.cursor, const CrosswordCell(0, 1));
    });

    test('repeated presses walk the whole answer backwards', () {
      // The complaint this fixes: emptying a word used to be tap, delete,
      // tap, delete, all the way along it.
      var cursor = const CrosswordCell(0, 3);
      final cleared = <CrosswordCell>[];
      for (var press = 0; press < 4; press++) {
        final step = eraseStep(
          cells: cells,
          cursor: cursor,
          cursorIsFilled: !cleared.contains(cursor),
        );
        if (step.clear != null) {
          cleared.add(step.clear!);
        }
        cursor = step.cursor;
      }

      expect(cleared, cells.reversed.toList());
    });

    test('at the start of an empty answer there is nothing left to do', () {
      final step = eraseStep(
        cells: cells,
        cursor: const CrosswordCell(0, 0),
        cursorIsFilled: false,
      );

      expect(step.clear, isNull);
      expect(step.cursor, const CrosswordCell(0, 0));
    });

    test('at the start of a filled answer it clears without moving', () {
      final step = eraseStep(
        cells: cells,
        cursor: const CrosswordCell(0, 0),
        cursorIsFilled: true,
      );

      expect(step.clear, const CrosswordCell(0, 0));
      expect(step.cursor, const CrosswordCell(0, 0));
    });
  });

  group('cells', () {
    test('equal coordinates are equal cells', () {
      expect(const CrosswordCell(1, 2), const CrosswordCell(1, 2));
      expect(<CrosswordCell>{const CrosswordCell(1, 2), const CrosswordCell(1, 2)}.length, 1);
    });
  });
}