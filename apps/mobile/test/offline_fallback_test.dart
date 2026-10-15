import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamusi_mobile/data/api_client.dart';
import 'package:kamusi_mobile/data/response_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Answers requests from a script instead of the network, so these tests
/// exercise the real Dio pipeline — decoding included — with no server.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);

  /// Return a body to succeed, or throw to fail.
  final Object? Function(String path) respond;
  final List<String> requested = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requested.add(options.path);
    final body = respond(options.path);
    if (body is int) {
      // An HTTP status to fail with.
      return ResponseBody.fromString(
        jsonEncode({'detail': 'error'}),
        body,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _lexeme = {
  'id': 'lex-1',
  'lemma': "ng'ombe",
  'senses': [
    {
      'id': 'sense-1',
      'sense_number': 1,
      'definitions': [
        {'id': 'def-1', 'lang_code': 'sw', 'definition': 'Mnyama wa maziwa.'},
      ],
      'examples': <dynamic>[],
    },
  ],
};

const _searchResults = [
  {'id': 's1', 'target_type': 'lexeme', 'lemma': "ng'ombe", 'text': "ng'ombe"},
];

Never _dropConnection(String path) => throw DioException(
      requestOptions: RequestOptions(path: path),
      type: DioExceptionType.connectionError,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ApiClient clientFor(_FakeAdapter adapter, ResponseCache cache) {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'))
      ..httpClientAdapter = adapter;
    return ApiClient(baseUrl: 'http://localhost:8000', dio: dio, cache: cache);
  }

  test('a word read once stays readable when the connection drops', () async {
    var online = true;
    final client = clientFor(
      _FakeAdapter((path) => online ? _lexeme : _dropConnection(path)),
      ResponseCache(),
    );

    expect((await client.getLexeme('lex-1')).lemma, "ng'ombe");
    expect(client.servingCachedData.value, isFalse);

    online = false;
    expect((await client.getLexeme('lex-1')).lemma, "ng'ombe");
    expect(client.servingCachedData.value, isTrue);
  });

  test('a word never opened still fails when offline', () async {
    final client = clientFor(_FakeAdapter(_dropConnection), ResponseCache());
    await expectLater(
      client.getLexeme('never-seen'),
      throwsA(isA<DioException>()),
    );
  });

  test('search results come back offline', () async {
    var online = true;
    final client = clientFor(
      _FakeAdapter((path) => online ? _searchResults : _dropConnection(path)),
      ResponseCache(),
    );

    expect((await client.search('ngombe')).length, 1);
    online = false;
    expect((await client.search('ngombe')).single.lemma, "ng'ombe");
    expect(client.servingCachedData.value, isTrue);
  });

  test('a different query is not answered from another query\'s cache', () async {
    var online = true;
    final client = clientFor(
      _FakeAdapter((path) => online ? _searchResults : _dropConnection(path)),
      ResponseCache(),
    );

    await client.search('ngombe');
    online = false;
    await expectLater(client.search('kitabu'), throwsA(isA<DioException>()));
  });

  test('a 404 is a real answer and is not masked by a stale copy', () async {
    var missing = false;
    final client = clientFor(
      _FakeAdapter((path) => missing ? 404 : _lexeme),
      ResponseCache(),
    );

    await client.getLexeme('lex-1');
    missing = true;
    // The entry was removed upstream; showing the saved copy would be a lie.
    await expectLater(client.getLexeme('lex-1'), throwsA(isA<DioException>()));
  });

  test('a server error does fall back, since the content still exists', () async {
    var broken = false;
    final client = clientFor(
      _FakeAdapter((path) => broken ? 503 : _lexeme),
      ResponseCache(),
    );

    await client.getLexeme('lex-1');
    broken = true;
    expect((await client.getLexeme('lex-1')).lemma, "ng'ombe");
    expect(client.servingCachedData.value, isTrue);
  });

  test('recovering the connection clears the offline flag', () async {
    var online = true;
    final client = clientFor(
      _FakeAdapter((path) => online ? _lexeme : _dropConnection(path)),
      ResponseCache(),
    );

    await client.getLexeme('lex-1');
    online = false;
    await client.getLexeme('lex-1');
    expect(client.servingCachedData.value, isTrue);

    online = true;
    await client.getLexeme('lex-1');
    expect(client.servingCachedData.value, isFalse);
  });

  test('the cache survives a new client, as it would a restart', () async {
    final cache = ResponseCache();
    await clientFor(_FakeAdapter((path) => _lexeme), cache).getLexeme('lex-1');

    final restarted = clientFor(_FakeAdapter(_dropConnection), cache);
    expect((await restarted.getLexeme('lex-1')).lemma, "ng'ombe");
  });
}
