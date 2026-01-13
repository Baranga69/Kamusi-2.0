class WordOfDay {
  WordOfDay({
    required this.date,
    required this.lexemeId,
    required this.lemma,
    required this.definition,
    required this.langCode,
  });

  final String date;
  final String lexemeId;
  final String lemma;
  final String definition;
  final String langCode;

  factory WordOfDay.fromJson(Map<String, dynamic> json) {
    return WordOfDay(
      date: (json['date'] ?? '').toString(),
      lexemeId: (json['lexeme_id'] ?? '').toString(),
      lemma: (json['lemma'] ?? '').toString(),
      definition: (json['definition'] ?? '').toString(),
      langCode: (json['lang_code'] ?? '').toString(),
    );
  }
}
