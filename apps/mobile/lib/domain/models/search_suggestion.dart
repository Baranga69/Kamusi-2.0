class SearchSuggestion {
  SearchSuggestion({
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
}
