import '../../domain/models/lexeme_detail.dart';

class LexemeDetailDto {
  LexemeDetailDto({
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

  factory LexemeDetailDto.fromJson(Map<String, dynamic> json) {
    final pronunciations = _parsePronunciations(json['pronunciations']);
    final senses = _parseSenses(json['senses']);
    final linkedExpressions = _parseLinkedExpressions(
      json['linked_expressions'] ?? json['expressions'],
    );

    return LexemeDetailDto(
      id: (json['id'] ?? json['lexeme_id'] ?? '').toString(),
      headword: (json['headword'] ?? json['lemma'] ?? json['display'] ?? '')
          .toString(),
      partOfSpeech:
          (json['part_of_speech'] ?? json['pos'] ?? '').toString(),
      pronunciations: pronunciations,
      senses: senses,
      linkedExpressions: linkedExpressions,
    );
  }

  LexemeDetail toDomain() {
    return LexemeDetail(
      id: id,
      headword: headword,
      partOfSpeech: partOfSpeech,
      pronunciations: pronunciations,
      senses: senses,
      linkedExpressions: linkedExpressions,
    );
  }

  static List<Pronunciation> _parsePronunciations(dynamic raw) {
    if (raw is! List) {
      return [];
    }
    return raw
        .map((item) {
          if (item is Map<String, dynamic>) {
            return Pronunciation(
              ipa: (item['ipa'] ?? item['pronunciation'] ?? '').toString(),
              audioUrl: (item['audio_url'] ?? item['audio'] ?? '').toString(),
            );
          }
          return Pronunciation(ipa: item.toString(), audioUrl: '');
        })
        .where((item) => item.ipa.isNotEmpty || item.audioUrl.isNotEmpty)
        .toList();
  }

  static List<Sense> _parseSenses(dynamic raw) {
    if (raw is! List) {
      return [];
    }
    return raw
        .map((item) {
          if (item is Map<String, dynamic>) {
            final definitions = _parseDefinitions(
              item['definitions'] ?? item['meanings'] ?? item['definition'],
            );
            final examples = _parseExamples(item['examples']);
            return Sense(
              definitions: definitions,
              examples: examples,
            );
          }
          return Sense(
            definitions: [Definition(language: '', text: item.toString())],
            examples: const [],
          );
        })
        .toList();
  }

  static List<Definition> _parseDefinitions(dynamic raw) {
    if (raw == null) {
      return [];
    }
    if (raw is String) {
      return [Definition(language: '', text: raw)];
    }
    if (raw is List) {
      return raw.map((definition) {
        if (definition is Map<String, dynamic>) {
          return Definition(
            language:
                (definition['language'] ?? definition['lang'] ?? '').toString(),
            text: (definition['text'] ?? definition['definition'] ?? '')
                .toString(),
          );
        }
        return Definition(language: '', text: definition.toString());
      }).toList();
    }
    return [];
  }

  static List<Example> _parseExamples(dynamic raw) {
    if (raw is! List) {
      return [];
    }
    return raw.map((example) {
      if (example is Map<String, dynamic>) {
        return Example(
          text: (example['text'] ?? example['example'] ?? '').toString(),
        );
      }
      return Example(text: example.toString());
    }).where((example) => example.text.isNotEmpty).toList();
  }

  static List<LinkedExpression> _parseLinkedExpressions(dynamic raw) {
    if (raw is! List) {
      return [];
    }
    return raw.map((item) {
      if (item is Map<String, dynamic>) {
        return LinkedExpression(
          id: (item['id'] ?? item['expression_id'] ?? '').toString(),
          text: (item['text'] ?? item['expression'] ?? item['display'] ?? '')
              .toString(),
        );
      }
      return LinkedExpression(id: '', text: item.toString());
    }).where((expression) => expression.id.isNotEmpty).toList();
  }
}
