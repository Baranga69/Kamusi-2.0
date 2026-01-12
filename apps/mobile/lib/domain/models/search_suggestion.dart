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

class SearchResultItem {
  final String id;
  final String title;
  final String subtitle; // e.g. "noun", "proverb", etc.
  final String? example;

  const SearchResultItem({
    required this.id,
    required this.title,
    required this.subtitle,
    this.example,
  });
}

class DictionaryEntry {
  final String id;
  final String lemma;
  final String? pronunciation;
  final List<EntrySense> senses;
  final List<String> related;

  const DictionaryEntry({
    required this.id,
    required this.lemma,
    this.pronunciation,
    required this.senses,
    required this.related,
  });
}

class EntrySense {
  final String pos; // noun/verb/etc
  final String definition;
  final String? example;

  const EntrySense({
    required this.pos,
    required this.definition,
    this.example,
  });
}
