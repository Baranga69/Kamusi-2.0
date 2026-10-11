import 'package:flutter_test/flutter_test.dart';
import 'package:kamusi_mobile/domain/models/codeword_puzzle.dart';

Map<String, dynamic> payload({
  Map<String, dynamic>? codes,
  List<Map<String, dynamic>>? entries,
  List<String>? revealed,
}) {
  return {
    'lang_code': 'sw',
    'codes': codes ?? {'n': 1, 'i': 2, 'u': 3, 'a': 4},
    'revealed': revealed ?? ['n'],
    'entries': entries ??
        [
          {
            'lexeme_id': 'lex-1',
            'word': 'nini',
            'letters': 'nini',
            'definition': 'Neno la kuuliza.',
            'pos_code': 'PRON',
          },
          {
            'lexeme_id': 'lex-2',
            'word': 'nuna',
            'letters': 'nuna',
            'definition': 'Kuonyesha kutoridhika.',
            'pos_code': 'VERB',
          },
        ],
  };
}

void main() {
  group('parsing', () {
    test('reads the key and the words', () {
      final puzzle = CodewordPuzzle.fromJson(payload());

      expect(puzzle.codes.length, 4);
      expect(puzzle.entries.length, 2);
      expect(puzzle.revealed, ['n']);
    });

    test('maps letters to numbers both ways', () {
      final puzzle = CodewordPuzzle.fromJson(payload());

      expect(puzzle.codeFor('i'), 2);
      expect(puzzle.letterFor(2), 'i');
      expect(puzzle.letterFor(99), '', reason: 'a number with no letter');
    });

    test('drops a word using a letter the key does not cover', () {
      // Its cell could never be filled, and the board would be unfinishable.
      final puzzle = CodewordPuzzle.fromJson(payload(entries: [
        {
          'lexeme_id': 'x',
          'word': 'kitabu',
          'letters': 'kitabu',
          'definition': 'Karatasi zilizofungwa.',
        },
      ]));

      expect(puzzle.entries, isEmpty);
      expect(puzzle.isEmpty, isTrue);
    });

    test('ignores a revealed letter that is not in the key', () {
      final puzzle = CodewordPuzzle.fromJson(payload(revealed: ['n', 'z']));

      expect(puzzle.revealed, ['n']);
    });

    test('drops an entry with no clue', () {
      final puzzle = CodewordPuzzle.fromJson(payload(entries: [
        {
          'lexeme_id': 'x',
          'word': 'nini',
          'letters': 'nini',
          'definition': '',
        },
      ]));

      expect(puzzle.entries, isEmpty);
    });

    test('survives an empty payload', () {
      final puzzle = CodewordPuzzle.fromJson(const {});

      expect(puzzle.isEmpty, isTrue);
      expect(puzzle.codes, isEmpty);
    });

    test('tolerates numbers arriving as strings', () {
      final puzzle = CodewordPuzzle.fromJson(payload(codes: {
        'n': '1',
        'i': 2,
        'u': 3,
        'a': 4,
      }));

      expect(puzzle.codeFor('n'), 1);
    });
  });

  group('the key', () {
    test('numbers are listed in order for drawing', () {
      final puzzle = CodewordPuzzle.fromJson(payload());

      expect(puzzle.numbers, [1, 2, 3, 4]);
    });

    test('every letter in every word has a number', () {
      final puzzle = CodewordPuzzle.fromJson(payload());

      for (final entry in puzzle.entries) {
        for (final letter in entry.letters.split('')) {
          expect(puzzle.codeFor(letter), isNotNull, reason: letter);
        }
      }
    });
  });
}
