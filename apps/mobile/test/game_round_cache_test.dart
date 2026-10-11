import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kamusi_mobile/data/game_round_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> round(int n) => {'id': n, 'words': ['w$n']};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  GameRoundCache cache({int rounds = 10}) =>
      GameRoundCache(roundsPerGame: rounds, random: Random(1));

  group('filling up', () {
    test('tops up to the target and stops', () async {
      final store = cache(rounds: 10);
      var fetched = 0;

      final added = await store.refill('g', () async => round(fetched++));

      expect(added, 10);
      expect(await store.pendingCount('g'), 10);
      expect(fetched, 10, reason: 'no request beyond the target');
    });

    test('a second top-up with a full queue fetches nothing', () async {
      final store = cache(rounds: 3);
      var fetched = 0;
      await store.refill('g', () async => round(fetched++));

      final added = await store.refill('g', () async => round(fetched++));

      expect(added, 0);
      expect(fetched, 3);
    });

    test('a connection that drops part-way keeps what it got', () async {
      final store = cache(rounds: 10);
      var fetched = 0;

      final added = await store.refill('g', () async {
        if (fetched >= 4) {
          throw Exception('offline');
        }
        return round(fetched++);
      });

      expect(added, 4, reason: 'a partial top-up is still useful');
      expect(await store.pendingCount('g'), 4);
    });

    test('a fetch returning nothing stops the top-up', () async {
      final store = cache(rounds: 10);

      final added = await store.refill('g', () async => null);

      expect(added, 0);
    });

    test('never holds more than the target', () async {
      final store = cache(rounds: 3);
      for (var i = 0; i < 8; i++) {
        await store.add('g', round(i));
      }

      expect(await store.totalCount('g'), 3);
    });
  });

  group('playing offline', () {
    test('hands out a different round each time', () async {
      final store = cache(rounds: 5);
      var fetched = 0;
      await store.refill('g', () async => round(fetched++));

      final seen = <int>[];
      for (var i = 0; i < 5; i++) {
        seen.add((await store.take('g'))!['id'] as int);
      }

      expect(seen.toSet().length, 5, reason: 'no repeats while stock lasts');
      expect(await store.pendingCount('g'), 0);
    });

    test('recycles rather than running out', () async {
      // Someone on a bus past their tenth round should get a puzzle they have
      // seen before, not a locked screen.
      final store = cache(rounds: 3);
      var fetched = 0;
      await store.refill('g', () async => round(fetched++));
      for (var i = 0; i < 3; i++) {
        await store.take('g');
      }

      final again = await store.take('g');

      expect(again, isNotNull);
      expect(await store.totalCount('g'), 3, reason: 'recycled, not refetched');
    });

    test('an empty store hands out nothing', () async {
      expect(await cache().take('never-filled'), isNull);
    });

    test('games do not share a queue', () async {
      final store = cache(rounds: 2);
      await store.add(GameIds.wordFind, round(1));

      expect(await store.pendingCount(GameIds.wordFind), 1);
      expect(await store.pendingCount(GameIds.wordBuild), 0);
    });
  });

  group('durability', () {
    test('rounds survive a new instance', () async {
      await cache().add('g', round(7));

      final reopened = cache();

      expect((await reopened.take('g'))!['id'], 7);
    });

    test('unreadable stored data is dropped, not thrown', () async {
      SharedPreferences.setMockInitialValues({'kamusi_games:g': 'not json'});

      final store = cache();

      expect(await store.pendingCount('g'), 0);
      expect(await store.take('g'), isNull);
    });

    test('clearing one game leaves the others', () async {
      final store = cache();
      await store.add(GameIds.wordFind, round(1));
      await store.add(GameIds.wordBuild, round(2));

      await store.clear(GameIds.wordFind);

      expect(await store.totalCount(GameIds.wordFind), 0);
      expect(await store.totalCount(GameIds.wordBuild), 1);
    });
  });
}
