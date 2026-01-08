import '../../domain/models/expression_detail.dart';

class ExpressionDetailDto {
  ExpressionDetailDto({
    required this.id,
    required this.text,
    required this.meanings,
    required this.examples,
  });

  final String id;
  final String text;
  final List<Meaning> meanings;
  final List<Example> examples;

  factory ExpressionDetailDto.fromJson(Map<String, dynamic> json) {
    return ExpressionDetailDto(
      id: (json['id'] ?? json['expression_id'] ?? '').toString(),
      text: (json['expression'] ?? json['text'] ?? json['display'] ?? '')
          .toString(),
      meanings: _parseMeanings(json['meanings'] ?? json['definitions']),
      examples: _parseExamples(json['examples']),
    );
  }

  ExpressionDetail toDomain() {
    return ExpressionDetail(
      id: id,
      text: text,
      meanings: meanings,
      examples: examples,
    );
  }

  static List<Meaning> _parseMeanings(dynamic raw) {
    if (raw == null) {
      return [];
    }
    if (raw is String) {
      return [Meaning(language: '', text: raw)];
    }
    if (raw is List) {
      return raw.map((meaning) {
        if (meaning is Map<String, dynamic>) {
          return Meaning(
            language: (meaning['language'] ?? meaning['lang'] ?? '').toString(),
            text: (meaning['text'] ?? meaning['meaning'] ?? meaning['definition'] ?? '')
                .toString(),
          );
        }
        return Meaning(language: '', text: meaning.toString());
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
}
