class LexemePublic {
  LexemePublic({
    required this.id,
    required this.lemma,
    required this.posId,
    required this.status,
    required this.defaultLanguageCode,
    required this.senses,
  });

  final String id;
  final String? lemma;
  final String? posId;
  final String? status;
  final String? defaultLanguageCode;
  final List<Sense> senses;

  factory LexemePublic.fromJson(Map<String, dynamic> json) {
    return LexemePublic(
      id: (json['id'] ?? '').toString(),
      lemma: json['lemma']?.toString(),
      posId: json['pos_id']?.toString(),
      status: json['status']?.toString(),
      defaultLanguageCode: json['default_language_code']?.toString(),
      senses: (json['senses'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(Sense.fromJson)
              .toList() ??
          const [],
    );
  }
}

class Sense {
  Sense({
    required this.id,
    required this.senseNumber,
    required this.domainId,
    required this.registerId,
    required this.usageNote,
    required this.definitions,
    required this.examples,
  });

  final String? id;
  final int? senseNumber;
  final String? domainId;
  final String? registerId;
  final String? usageNote;
  final List<Definition> definitions;
  final List<Example> examples;

  factory Sense.fromJson(Map<String, dynamic> json) {
    return Sense(
      id: json['id']?.toString(),
      senseNumber: (json['sense_number'] as num?)?.toInt(),
      domainId: json['domain_id']?.toString(),
      registerId: json['register_id']?.toString(),
      usageNote: json['usage_note']?.toString(),
      definitions: (json['definitions'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(Definition.fromJson)
              .toList() ??
          const [],
      examples: (json['examples'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(Example.fromJson)
              .toList() ??
          const [],
    );
  }
}

class Definition {
  Definition({
    required this.id,
    required this.langCode,
    required this.definition,
    required this.gloss,
    required this.isPrimary,
    required this.isAiGenerated,
    required this.reviewStatus,
  });

  final String? id;
  final String? langCode;
  final String? definition;
  final String? gloss;
  final bool? isPrimary;
  final bool? isAiGenerated;
  final String? reviewStatus;

  factory Definition.fromJson(Map<String, dynamic> json) {
    return Definition(
      id: json['id']?.toString(),
      langCode: json['lang_code']?.toString(),
      definition: json['definition']?.toString(),
      gloss: json['gloss']?.toString(),
      isPrimary: json['is_primary'] as bool?,
      isAiGenerated: json['is_ai_generated'] as bool?,
      reviewStatus: json['review_status']?.toString(),
    );
  }
}

class Example {
  Example({
    required this.id,
    required this.isAttested,
    required this.texts,
  });

  final String? id;
  final bool? isAttested;
  final List<ExampleText> texts;

  factory Example.fromJson(Map<String, dynamic> json) {
    return Example(
      id: json['id']?.toString(),
      isAttested: json['is_attested'] as bool?,
      texts: (json['texts'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(ExampleText.fromJson)
              .toList() ??
          const [],
    );
  }
}

class ExampleText {
  ExampleText({
    required this.id,
    required this.langCode,
    required this.text,
    required this.isPrimary,
  });

  final String? id;
  final String? langCode;
  final String? text;
  final bool? isPrimary;

  factory ExampleText.fromJson(Map<String, dynamic> json) {
    return ExampleText(
      id: json['id']?.toString(),
      langCode: json['lang_code']?.toString(),
      text: json['text']?.toString(),
      isPrimary: json['is_primary'] as bool?,
    );
  }
}
