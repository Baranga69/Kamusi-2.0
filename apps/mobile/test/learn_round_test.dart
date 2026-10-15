import 'package:flutter_test/flutter_test.dart';
import 'package:kamusi_mobile/domain/models/learn_round.dart';

Map<String, dynamic> question({
  String kind = 'definition',
  String prompt = 'mti',
  List<String>? options,
  int answerIndex = 0,
  String? lexemeId = 'lex-1',
  String? expressionId,
  String? promptDetail = 'NOUN',
}) {
  return {
    'kind': kind,
    'prompt': prompt,
    'prompt_detail': promptDetail,
    'options': options ?? ['Mmea mkubwa', 'Kitabu', 'Maji', 'Mwalimu'],
    'answer_index': answerIndex,
    'lexeme_id': lexemeId,
    'expression_id': expressionId,
  };
}

void main() {
  test('parses a round', () {
    final round = LearnRound.fromJson({
      'kind': 'daily',
      'lang_code': 'sw',
      'date': '2026-10-10',
      'questions': [question()],
    });

    expect(round.kind, 'daily');
    expect(round.date, DateTime.utc(2026, 10, 10));
    expect(round.questions.single.prompt, 'mti');
    expect(round.questions.single.answer, 'Mmea mkubwa');
  });

  test('marks the right answer and only that', () {
    final q = LearnQuestion.fromJson(question(answerIndex: 2));
    expect(q.isCorrect(2), isTrue);
    for (final wrong in [0, 1, 3]) {
      expect(q.isCorrect(wrong), isFalse);
    }
  });

  test('knows whether there is an entry to open', () {
    expect(LearnQuestion.fromJson(question()).hasEntry, isTrue);
    expect(
      LearnQuestion.fromJson(
        question(lexemeId: null, expressionId: 'expr-1'),
      ).hasEntry,
      isTrue,
    );
    expect(
      LearnQuestion.fromJson(question(lexemeId: null, expressionId: null)).hasEntry,
      isFalse,
    );
    expect(
      LearnQuestion.fromJson(question(lexemeId: '', expressionId: '')).hasEntry,
      isFalse,
    );
  });

  test('drops questions that cannot be played', () {
    final round = LearnRound.fromJson({
      'kind': 'daily',
      'lang_code': 'sw',
      'questions': [
        question(),
        // An out-of-range answer would be unanswerable.
        question(prompt: 'broken', answerIndex: 9),
        // One option is no choice at all.
        question(prompt: 'single', options: ['only'], answerIndex: 0),
        question(prompt: 'none', options: [], answerIndex: 0),
      ],
    });

    expect(round.questions.map((q) => q.prompt), ['mti']);
  });

  test('a round with no usable questions is empty, not broken', () {
    final round = LearnRound.fromJson({
      'kind': 'mixed',
      'lang_code': 'sw',
      'questions': [],
    });
    expect(round.isEmpty, isTrue);
  });

  test('tolerates missing and null fields', () {
    final round = LearnRound.fromJson({'questions': null});
    expect(round.isEmpty, isTrue);
    expect(round.langCode, 'sw');
    expect(round.date, isNull);

    final q = LearnQuestion.fromJson({'options': ['a', 'b'], 'answer_index': 1});
    expect(q.prompt, '');
    expect(q.promptDetail, isNull);
    expect(q.hasEntry, isFalse);
    expect(q.isPlayable, isTrue);
  });

  test('blank options are discarded', () {
    final q = LearnQuestion.fromJson(
      question(options: ['Mmea', '', '  ', 'Maji'], answerIndex: 0),
    );
    expect(q.options, ['Mmea', '  ', 'Maji']);
  });

  test('a methali question carries its meaning as the hint', () {
    final q = LearnQuestion.fromJson(question(
      kind: 'methali',
      prompt: 'Haraka haraka',
      promptDetail: 'Kufanya mambo kwa pupa huleta makosa.',
      options: ['haina baraka', 'ndivyo akuavyo', 'mbivu za mtini', 'ni nguvu'],
      lexemeId: null,
      expressionId: 'expr-1',
    ));

    expect(q.kind, 'methali');
    expect(q.promptDetail, contains('pupa'));
    expect(q.expressionId, 'expr-1');
    expect('${q.prompt} ${q.answer}', 'Haraka haraka haina baraka');
  });
}
