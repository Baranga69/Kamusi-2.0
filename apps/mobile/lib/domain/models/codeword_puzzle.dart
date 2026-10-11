/// A set of words written as numbers, one number per letter.
///
/// The key arrives from the API like every other round's answers: nothing is
/// at stake, and the board has to be solvable from the cache with no
/// connection. Deduction is the game, and a player who wanted to skip it can
/// already read the clues.
class CodewordEntry {
  const CodewordEntry({
    required this.lexemeId,
    required this.word,
    required this.letters,
    required this.definition,
    required this.posCode,
  });

  final String lexemeId;
  final String word;
  final String letters;
  final String definition;
  final String? posCode;

  bool get isPlayable => letters.isNotEmpty && definition.isNotEmpty;

  factory CodewordEntry.fromJson(Map<String, dynamic> json) {
    return CodewordEntry(
      lexemeId: (json['lexeme_id'] ?? '').toString(),
      word: (json['word'] ?? '').toString(),
      letters: (json['letters'] ?? '').toString().toLowerCase(),
      definition: (json['definition'] ?? '').toString(),
      posCode: json['pos_code']?.toString(),
    );
  }
}

class CodewordPuzzle {
  const CodewordPuzzle({
    required this.langCode,
    required this.codes,
    required this.revealed,
    required this.entries,
  });

  final String langCode;

  /// letter -> its number.
  final Map<String, int> codes;

  /// Letters filled in from the start.
  final List<String> revealed;
  final List<CodewordEntry> entries;

  bool get isEmpty => entries.isEmpty || codes.isEmpty;

  /// The numbers in play, in order, which is how the key is drawn.
  List<int> get numbers {
    final all = codes.values.toList()..sort();
    return all;
  }

  /// The letter a number stands for.
  String letterFor(int code) {
    for (final entry in codes.entries) {
      if (entry.value == code) {
        return entry.key;
      }
    }
    return '';
  }

  int? codeFor(String letter) => codes[letter.toLowerCase()];

  factory CodewordPuzzle.fromJson(Map<String, dynamic> json) {
    final codes = <String, int>{};
    final raw = json['codes'];
    if (raw is Map) {
      raw.forEach((key, value) {
        final letter = key?.toString().toLowerCase() ?? '';
        final code = value is num ? value.toInt() : int.tryParse('$value');
        if (letter.length == 1 && code != null) {
          codes[letter] = code;
        }
      });
    }

    final entries = (json['entries'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(CodewordEntry.fromJson)
            .where((entry) => entry.isPlayable)
            // A word using a letter the key does not cover would have an
            // unfillable cell, and the player could never finish.
            .where((entry) =>
                entry.letters.split('').every(codes.containsKey))
            .toList() ??
        const <CodewordEntry>[];

    final revealed = (json['revealed'] as List?)
            ?.map((letter) => letter?.toString().toLowerCase() ?? '')
            .where((letter) => letter.length == 1 && codes.containsKey(letter))
            .toList() ??
        const <String>[];

    return CodewordPuzzle(
      langCode: (json['lang_code'] ?? 'sw').toString(),
      codes: codes,
      revealed: revealed,
      entries: entries,
    );
  }
}
