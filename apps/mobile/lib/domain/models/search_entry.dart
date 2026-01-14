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
    required this.matchKind,
  });

  final String id;
  final String targetType;
  final String targetId;
  final String langCode;
  final String text;
  final String normalized;
  final int? popularity;

  // NEW
  final String lexemeId;
  final String lemma;
  final String? posCode;
  final String? matchKind;

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
      matchKind: json['match_kind'] as String?,
    );
  }
}
