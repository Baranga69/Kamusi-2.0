import 'package:flutter_test/flutter_test.dart';
import 'package:kamusi_mobile/data/server_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('tidying what someone typed', () {
    test('assumes http when no scheme is given', () {
      // People type an address off a router page; refusing it would be
      // pedantry.
      expect(ServerStore.normalise('192.168.1.5:8000'), 'http://192.168.1.5:8000');
    });

    test('leaves an explicit scheme alone', () {
      expect(
        ServerStore.normalise('https://api.example.com'),
        'https://api.example.com',
      );
    });

    test('drops trailing slashes, since every path starts with one', () {
      expect(ServerStore.normalise('http://10.0.0.2:8000///'), 'http://10.0.0.2:8000');
    });

    test('trims surrounding space', () {
      expect(ServerStore.normalise('  10.0.0.2:8000  '), 'http://10.0.0.2:8000');
    });

    test('leaves an empty string empty', () {
      expect(ServerStore.normalise('   '), '');
    });
  });

  group('judging an address', () {
    test('accepts a bare host and port', () {
      expect(ServerStore.looksUsable('192.168.1.5:8000'), isTrue);
    });

    test('accepts https', () {
      expect(ServerStore.looksUsable('https://kamusi.example'), isTrue);
    });

    test('rejects nothing at all', () {
      expect(ServerStore.looksUsable(''), isFalse);
      expect(ServerStore.looksUsable('   '), isFalse);
    });

    test('rejects a scheme that is not http', () {
      expect(ServerStore.looksUsable('ftp://example.com'), isFalse);
    });
  });

  group('remembering it', () {
    test('round-trips an address', () async {
      final store = ServerStore();

      await store.save('192.168.1.5:8000');

      expect(await store.load(), 'http://192.168.1.5:8000');
    });

    test('nothing stored means nothing returned', () async {
      expect(await ServerStore().load(), isNull);
    });

    test('clearing falls back to the build-time address', () async {
      final store = ServerStore();
      await store.save('http://10.0.0.9:8000');

      await store.clear();

      expect(await store.load(), isNull);
    });

    test('a blank stored value reads as nothing set', () async {
      SharedPreferences.setMockInitialValues({'kamusi_server:base_url': '   '});

      expect(await ServerStore().load(), isNull);
    });
  });
}
