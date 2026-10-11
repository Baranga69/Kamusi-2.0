/// A ring of letters and every published word they spell.
///
/// The whole solution set arrives from the API, as with the other rounds:
/// nothing is at stake, the puzzle has to work from the cache with no
/// connection, and it is what lets easy mode offer the definitions as hints
/// without asking the server mid-game.
class WordBuildWord {
  const WordBuildWord({
    required this.lexemeId,
    required this.word,
    required this.letters,
    required this.definition,
    required this.posCode,
    required this.points,
    required this.isPangram,
  });

  final String lexemeId;
  final String word;

  /// The word in lower case, which is what a player's tiles spell.
  final String letters;
  final String definition;
  final String? posCode;

  /// What building this word is worth, before any speed bonus.
  final int points;

  /// True for the one word that uses every letter in the ring.
  final bool isPangram;

  bool get isPlayable => letters.length >= 3 && definition.isNotEmpty;

  factory WordBuildWord.fromJson(Map<String, dynamic> json) {
    return WordBuildWord(
      lexemeId: (json['lexeme_id'] ?? '').toString(),
      word: (json['word'] ?? '').toString(),
      letters: (json['letters'] ?? '').toString().toLowerCase(),
      definition: (json['definition'] ?? '').toString(),
      posCode: json['pos_code']?.toString(),
      points: (json['points'] as num?)?.toInt() ?? 0,
      isPangram: json['is_pangram'] == true,
    );
  }
}

class WordBuildPuzzle {
  const WordBuildPuzzle({
    required this.langCode,
    required this.letters,
    required this.words,
  });

  final String langCode;

  /// The ring, already shuffled by the API. One character each.
  final List<String> letters;
  final List<WordBuildWord> words;

  bool get isEmpty => letters.isEmpty || words.isEmpty;

  /// The word using every letter, if the payload still has it.
  WordBuildWord? get pangram {
    for (final word in words) {
      if (word.isPangram) {
        return word;
      }
    }
    return null;
  }

  /// The solution spelled by [attempt], or null when it spells nothing.
  WordBuildWord? solve(String attempt) {
    final normalised = attempt.toLowerCase();
    for (final word in words) {
      if (word.letters == normalised) {
        return word;
      }
    }
    return null;
  }

  factory WordBuildPuzzle.fromJson(Map<String, dynamic> json) {
    final letters = (json['letters'] as List?)
            ?.map((letter) => letter?.toString().toLowerCase() ?? '')
            .where((letter) => letter.length == 1)
            .toList() ??
        const <String>[];
    final words = (json['words'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(WordBuildWord.fromJson)
            .where((word) => word.isPlayable)
            .toList() ??
        const <WordBuildWord>[];
    return WordBuildPuzzle(
      langCode: (json['lang_code'] ?? 'sw').toString(),
      letters: letters,
      // A word the ring cannot spell would be unwinnable, and the player
      // would have no way to know why.
      words: words.where((word) => _spellable(word.letters, letters)).toList(),
    );
  }

  static bool _spellable(String word, List<String> letters) {
    final available = <String, int>{};
    for (final letter in letters) {
      available[letter] = (available[letter] ?? 0) + 1;
    }
    for (final letter in word.split('')) {
      final left = available[letter] ?? 0;
      if (left == 0) {
        return false;
      }
      available[letter] = left - 1;
    }
    return true;
  }
}
