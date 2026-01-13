class SearchEntry {
  SearchEntry({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.langCode,
    required this.text,
    required this.normalized,
    required this.popularity,
  });

  final String id;
  final String targetType;
  final String targetId;
  final String langCode;
  final String text;
  final String normalized;
  final int? popularity;

  factory SearchEntry.fromJson(Map<String, dynamic> json) {
    return SearchEntry(
      id: (json['id'] ?? '').toString(),
      targetType: (json['target_type'] ?? '').toString(),
      targetId: (json['target_id'] ?? '').toString(),
      langCode: (json['lang_code'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      normalized: (json['normalized'] ?? '').toString(),
      popularity: (json['popularity'] as num?)?.toInt(),
    );
  }
}
