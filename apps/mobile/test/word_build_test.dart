import 'package:flutter_test/flutter_test.dart';
import 'package:kamusi_mobile/domain/models/word_build_puzzle.dart';

Map<String, dynamic> payload({List<String>? letters, List<Map<String, dynamic>>? words}) {
  return {
    'lang_code': 'sw',
    'letters': letters ?? ['m', 'o', 'm', 'o', 'n', 'y', 'o', 'a'],
    'words': words ??
        [
          {
            'lexeme_id': 'lex-1',
            'word': 'momonyoa',
            'letters': 'momonyoa',
            'definition': 'Kuondoa ardhi kwa taratibu.',
            'pos_code': 'VERB',
            'is_pangram': true,
          },
          {
            'lexeme_id': 'lex-2',
            'word': 'nyoa',
            'letters': 'nyoa',
            'definition': 'Kukata nywele.',
            'pos_code': 'VERB',
            'is_pangram': false,
          },
        ],
  };
}

void main() {
  group('parsing', () {
    test('a round queued before points existed still parses', () {
      final puzzle = WordBuildPuzzle.fromJson(payload());
      expect(puzzle.words.first.points, 0);
    });

    test('reads the ring and its words', () {
      final puzzle = WordBuildPuzzle.fromJson(payload());

      expect(puzzle.letters.length, 8);
      expect(puzzle.words.length, 2);
      expect(puzzle.pangram?.word, 'momonyoa');
    });

    test('drops a word the ring cannot spell', () {
      // Unwinnable, and the player would have no way to know why.
      final puzzle = WordBuildPuzzle.fromJson(payload(words: [
        {
          'lexeme_id': 'lex-3',
          'word': 'kitabu',
          'letters': 'kitabu',
          'definition': 'Karatasi zilizofungwa pamoja.',
          'is_pangram': false,
        },
      ]));

      expect(puzzle.words, isEmpty);
    });

    test('respects how many times a letter appears', () {
      // The ring has three o's and two m's; "mmmo" needs three m's.
      final puzzle = WordBuildPuzzle.fromJson(payload(words: [
        {
          'lexeme_id': 'x',
          'word': 'mmmo',
          'letters': 'mmmo',
          'definition': 'Si neno halisi, ni jaribio tu.',
          'is_pangram': false,
        },
      ]));

      expect(puzzle.words, isEmpty);
    });

    test('drops a word with no meaning to show', () {
      final puzzle = WordBuildPuzzle.fromJson(payload(words: [
        {
          'lexeme_id': 'x',
          'word': 'nyoa',
          'letters': 'nyoa',
          'definition': '',
          'is_pangram': false,
        },
      ]));

      expect(puzzle.words, isEmpty);
    });

    test('survives an empty payload', () {
      final puzzle = WordBuildPuzzle.fromJson(const {});

      expect(puzzle.isEmpty, isTrue);
      expect(puzzle.pangram, isNull);
    });
  });

  group('solving', () {
    final puzzle = WordBuildPuzzle.fromJson(payload());

    test('accepts a word in the set', () {
      expect(puzzle.solve('nyoa')?.word, 'nyoa');
    });

    test('ignores case, since the tiles are drawn in capitals', () {
      expect(puzzle.solve('NYOA')?.word, 'nyoa');
    });

    test('rejects letters that spell nothing', () {
      expect(puzzle.solve('mmoo'), isNull);
    });

    test('rejects an empty attempt', () {
      expect(puzzle.solve(''), isNull);
    });

    test('rejects a real Swahili word that is not in this ring', () {
      expect(puzzle.solve('kitabu'), isNull);
    });
  });
}