class SearchEntry {
  SearchEntry({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.langCode,
    required this.text,
    required this.normalized,
    required this.popularity,
    required this.lexemeId,
    required this.lemma,
    required this.posCode,
    required this.expressionId,
    required this.expressionText,
    required this.matchKind,
  });

  final String id;
  final String targetType;
  final String targetId;
  final String langCode;
  final String text;
  final String normalized;
  final int? popularity;

  /// Set when the hit resolves to a lexeme; empty for expression hits.
  final String lexemeId;
  final String lemma;
  final String? posCode;

  /// Set when the hit resolves to an expression (methali, semi, nahau).
  final String expressionId;
  final String expressionText;

  /// lemma | definition | example | expression | meaning
  final String? matchKind;

  bool get isExpression => expressionId.isNotEmpty;

  bool get isLexeme => lexemeId.isNotEmpty;

  /// What to show as the result's headline.
  String get title {
    if (lemma.isNotEmpty) return lemma;
    if (expressionText.isNotEmpty) return expressionText;
    return text;
  }

  factory SearchEntry.fromJson(Map<String, dynamic> json) {
    return SearchEntry(
      id: (json['id'] ?? '').toString(),
      targetType: (json['target_type'] ?? '').toString(),
      targetId: (json['target_id'] ?? '').toString(),
      langCode: (json['lang_code'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      normalized: (json['normalized'] ?? '').toString(),
      popularity: (json['popularity'] as num?)?.toInt(),
      lexemeId: (json['lexeme_id'] ?? '').toString(),
      lemma: (json['lemma'] ?? '').toString(),
      posCode: json['pos_code'] as String?,
      expressionId: (json['expression_id'] ?? '').toString(),
      expressionText: (json['expression_text'] ?? '').toString(),
      matchKind: json['match_kind'] as String?,
    );
  }
}
