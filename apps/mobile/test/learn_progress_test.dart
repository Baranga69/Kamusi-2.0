import 'package:flutter_test/flutter_test.dart';
import 'package:kamusi_mobile/data/learn_progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final monday = DateTime.utc(2026, 10, 5, 9);
  final tuesday = DateTime.utc(2026, 10, 6, 9);
  final wednesday = DateTime.utc(2026, 10, 7, 9);
  final friday = DateTime.utc(2026, 10, 9, 9);

  test('starts with nothing', () async {
    final progress = await LearnProgressStore().load();
    expect(progress.currentStreak, 0);
    expect(progress.bestStreak, 0);
    expect(progress.lastCompletedDay, isNull);
    expect(progress.accuracyPercent, 0);
  });

  test('the first daily challenge starts a streak of one', () async {
    final store = LearnProgressStore();
    final progress = await store.completeDaily(correct: 4, answered: 5, at: monday);

    expect(progress.currentStreak, 1);
    expect(progress.bestStreak, 1);
    expect(progress.completedOn(LearnProgressStore.dayKey(monday)), isTrue);
  });

  test('consecutive days extend the streak', () async {
    final store = LearnProgressStore();
    await store.completeDaily(correct: 5, answered: 5, at: monday);
    await store.completeDaily(correct: 5, answered: 5, at: tuesday);
    final progress = await store.completeDaily(correct: 5, answered: 5, at: wednesday);

    expect(progress.currentStreak, 3);
    expect(progress.bestStreak, 3);
  });

  test('replaying the same day does not inflate the streak', () async {
    final store = LearnProgressStore();
    await store.completeDaily(correct: 3, answered: 5, at: monday);
    final progress = await store.completeDaily(correct: 5, answered: 5, at: monday);

    expect(progress.currentStreak, 1);
    // The practice still counts towards the tally.
    expect(progress.totalAnswered, 10);
    expect(progress.totalCorrect, 8);
  });

  test('a missed day restarts at one rather than zero', () async {
    final store = LearnProgressStore();
    await store.completeDaily(correct: 5, answered: 5, at: monday);
    await store.completeDaily(correct: 5, answered: 5, at: tuesday);
    // Nothing on Wednesday or Thursday.
    final progress = await store.completeDaily(correct: 5, answered: 5, at: friday);

    expect(progress.currentStreak, 1, reason: 'you did turn up today');
    expect(progress.bestStreak, 2, reason: 'the best run is remembered');
  });

  test('practice never touches the streak', () async {
    final store = LearnProgressStore();
    await store.completeDaily(correct: 5, answered: 5, at: monday);
    final progress = await store.recordPractice(correct: 2, answered: 5);

    expect(progress.currentStreak, 1);
    expect(progress.lastCompletedDay, LearnProgressStore.dayKey(monday));
    expect(progress.totalAnswered, 10);
  });

  test('accuracy is a share of everything answered', () async {
    final store = LearnProgressStore();
    await store.completeDaily(correct: 3, answered: 4, at: monday);
    final progress = await store.recordPractice(correct: 1, answered: 6);

    expect(progress.totalCorrect, 4);
    expect(progress.totalAnswered, 10);
    expect(progress.accuracyPercent, 40);
  });

  test('progress survives a new store, as it would a restart', () async {
    await LearnProgressStore().completeDaily(correct: 5, answered: 5, at: monday);
    final progress = await LearnProgressStore().load();
    expect(progress.currentStreak, 1);
    expect(progress.totalCorrect, 5);
  });

  test('the day key is UTC, so a time zone cannot game the streak', () async {
    // Late evening in UTC+3 is still the same UTC day.
    expect(
      LearnProgressStore.dayKey(DateTime.utc(2026, 10, 5, 23)),
      LearnProgressStore.dayKey(DateTime.utc(2026, 10, 5, 2)),
    );
    expect(LearnProgressStore.dayKey(DateTime.utc(2026, 10, 5)), '2026-10-05');
  });

  test('reset clears everything', () async {
    final store = LearnProgressStore();
    await store.completeDaily(correct: 5, answered: 5, at: monday);
    await store.reset();

    final progress = await store.load();
    expect(progress.currentStreak, 0);
    expect(progress.totalAnswered, 0);
  });
}
