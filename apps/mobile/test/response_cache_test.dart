import 'package:flutter_test/flutter_test.dart';
import 'package:kamusi_mobile/data/response_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('round-trips a body', () async {
    final cache = ResponseCache();
    await cache.write('lexeme:sw:1', {'lemma': "ng'ombe"});

    final cached = await cache.read('lexeme:sw:1');
    expect(cached, isNotNull);
    expect((cached!.body as Map)['lemma'], "ng'ombe");
    expect(cached.savedAt, isNotNull);
  });

  test('returns null for an unknown key', () async {
    expect(await ResponseCache().read('nothing-here'), isNull);
  });

  test('round-trips a list body', () async {
    final cache = ResponseCache();
    await cache.write('search:sw:20:mti', [
      {'lemma': 'mti'},
    ]);
    expect((await cache.read('search:sw:20:mti'))!.body, isA<List<dynamic>>());
  });

  test('evicts the least recently used entry past the limit', () async {
    final cache = ResponseCache(maxEntries: 3);
    for (final key in ['a', 'b', 'c']) {
      await cache.write(key, {'key': key});
    }

    // Touch 'a' so 'b' becomes the oldest.
    await cache.read('a');
    await cache.write('d', {'key': 'd'});

    expect(await cache.size(), 3);
    expect(await cache.read('b'), isNull, reason: 'b was least recently used');
    expect(await cache.read('a'), isNotNull);
    expect(await cache.read('c'), isNotNull);
    expect(await cache.read('d'), isNotNull);
  });

  test('overwriting a key does not grow the cache', () async {
    final cache = ResponseCache(maxEntries: 5);
    await cache.write('same', {'v': 1});
    await cache.write('same', {'v': 2});

    expect(await cache.size(), 1);
    expect(((await cache.read('same'))!.body as Map)['v'], 2);
  });

  test('drops an entry it cannot decode rather than throwing', () async {
    SharedPreferences.setMockInitialValues({
      'kamusi_cache:entry:bad': 'not json',
      'kamusi_cache:index': <String>['bad'],
    });
    expect(await ResponseCache().read('bad'), isNull);
  });

  test('clear empties it', () async {
    final cache = ResponseCache();
    await cache.write('a', {'v': 1});
    await cache.clear();

    expect(await cache.size(), 0);
    expect(await cache.read('a'), isNull);
  });
}
