/// A question in a learning round.
///
/// `answerIndex` arrives from the API on purpose: nothing is at stake, and a
/// round has to be playable from the cache with no connection, which rules out
/// asking the server to mark it.
class LearnQuestion {
  const LearnQuestion({
    required this.kind,
    required this.prompt,
    required this.promptDetail,
    required this.options,
    required this.answerIndex,
    required this.lexemeId,
    required this.expressionId,
  });

  /// 'definition' | 'meaning' | 'methali'
  final String kind;
  final String prompt;

  /// A hint: the part of speech, or a proverb's meaning.
  final String? promptDetail;
  final List<String> options;
  final int answerIndex;

  /// The entry this question came from, so answering can lead to reading.
  final String? lexemeId;
  final String? expressionId;

  String get answer =>
      answerIndex >= 0 && answerIndex < options.length ? options[answerIndex] : '';

  bool isCorrect(int selected) => selected == answerIndex;

  /// True when there is an entry to open after answering.
  bool get hasEntry =>
      (lexemeId?.isNotEmpty ?? false) || (expressionId?.isNotEmpty ?? false);

  factory LearnQuestion.fromJson(Map<String, dynamic> json) {
    final options = (json['options'] as List?)
            ?.map((option) => option?.toString() ?? '')
            .where((option) => option.isNotEmpty)
            .toList() ??
        const <String>[];
    return LearnQuestion(
      kind: (json['kind'] ?? '').toString(),
      prompt: (json['prompt'] ?? '').toString(),
      promptDetail: json['prompt_detail']?.toString(),
      options: options,
      answerIndex: (json['answer_index'] as num?)?.toInt() ?? -1,
      lexemeId: json['lexeme_id']?.toString(),
      expressionId: json['expression_id']?.toString(),
    );
  }

  /// A question is only usable if it has choices and one of them is right.
  bool get isPlayable =>
      options.length >= 2 && answerIndex >= 0 && answerIndex < options.length;
}

DateTime? _parseUtcDate(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw.endsWith('Z') ? raw : '${raw}T00:00:00Z');
}

class LearnRound {
  const LearnRound({
    required this.kind,
    required this.langCode,
    required this.questions,
    required this.date,
  });

  final String kind;
  final String langCode;
  final List<LearnQuestion> questions;

  /// Set on the daily round: which day it belongs to.
  final DateTime? date;

  bool get isEmpty => questions.isEmpty;

  factory LearnRound.fromJson(Map<String, dynamic> json) {
    return LearnRound(
      kind: (json['kind'] ?? '').toString(),
      langCode: (json['lang_code'] ?? 'sw').toString(),
      questions: (json['questions'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(LearnQuestion.fromJson)
              .where((question) => question.isPlayable)
              .toList() ??
          const <LearnQuestion>[],
      // The API sends a calendar date; the round is seeded by the UTC day, so
      // parse it as UTC rather than letting it become local midnight.
      date: _parseUtcDate(json['date']?.toString()),
    );
  }
}
