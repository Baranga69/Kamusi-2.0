class SearchSuggestionDto {
  SearchSuggestionDto({
    required this.entryType,
    required this.targetId,
    required this.display,
    required this.snippet,
    required this.tags,
  });

  final String entryType;
  final String targetId;
  final String display;
  final String snippet;
  final List<String> tags;

  factory SearchSuggestionDto.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    return SearchSuggestionDto(
      entryType: (json['entry_type'] ?? json['type'] ?? '').toString(),
      targetId: (json['target_id'] ?? json['id'] ?? '').toString(),
      display: (json['display'] ?? json['title'] ?? '').toString(),
      snippet: (json['snippet'] ?? json['subtitle'] ?? '').toString(),
      tags: rawTags is List
          ? rawTags.map((tag) => tag.toString()).toList()
          : <String>[],
    );
  }
}
