class LexemeDetail {
  LexemeDetail({
    required this.id,
    required this.headword,
    required this.partOfSpeech,
    required this.pronunciations,
    required this.senses,
    required this.linkedExpressions,
  });

  final String id;
  final String headword;
  final String partOfSpeech;
  final List<Pronunciation> pronunciations;
  final List<Sense> senses;
  final List<LinkedExpression> linkedExpressions;
}

class Pronunciation {
  Pronunciation({required this.ipa, required this.audioUrl});

  final String ipa;
  final String audioUrl;
}

class Sense {
  Sense({required this.definitions, required this.examples});

  final List<Definition> definitions;
  final List<Example> examples;
}

class Definition {
  Definition({required this.language, required this.text});

  final String language;
  final String text;
}

class Example {
  Example({required this.text});

  final String text;
}

class LinkedExpression {
  LinkedExpression({required this.id, required this.text});

  final String id;
  final String text;
}
