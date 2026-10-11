import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../domain/models/expression_detail.dart';
import '../domain/models/learn_round.dart';
import '../domain/models/word_find_puzzle.dart';
import '../domain/models/lexeme_public.dart';
import '../domain/models/search_entry.dart';
import '../domain/models/word_of_day.dart';
import 'dtos/expression_detail_dto.dart';
import 'response_cache.dart';

class ApiClient {
  ApiClient({
    required this.baseUrl,
    this.includeDrafts = false,
    ResponseCache? cache,
    Dio? dio,
  })  : cache = cache ?? ResponseCache() {
    _dio = dio ??
        Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
          ),
        );
  }

  final String baseUrl;

  /// Whether to request unpublished content. Off outside local development;
  /// see `includeDraftsProvider`.
  final bool includeDrafts;

  final ResponseCache cache;

  /// True while the most recent read was served from the cache because the
  /// network could not be reached. The UI watches this to say so.
  final ValueNotifier<bool> servingCachedData = ValueNotifier<bool>(false);

  late final Dio _dio;

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _dio.get(path, queryParameters: queryParameters);
  }

  /// A request that survives a dead connection.
  ///
  /// On success the body is cached and returned. When the request fails for a
  /// reason that retrying would not fix right now — no connection, a timeout,
  /// a server error — the last cached body is returned instead, if there is
  /// one. A 404 is a real answer and is not masked by a stale copy.
  Future<Object?> _read(
    String path, {
    required String cacheKey,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await get(path, queryParameters: queryParameters);
      await cache.write(cacheKey, response.data);
      servingCachedData.value = false;
      return response.data;
    } on DioException catch (error) {
      if (!_isRecoverable(error)) {
        rethrow;
      }
      final cached = await cache.read(cacheKey);
      if (cached == null) {
        rethrow;
      }
      servingCachedData.value = true;
      return cached.body;
    }
  }

  /// Whether a cached copy is a reasonable stand-in for this failure.
  static bool _isRecoverable(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.unknown:
        return true;
      case DioExceptionType.badResponse:
        // The server answered, so trust it — except for its own failures,
        // where yesterday's copy is better than an error screen.
        final status = error.response?.statusCode ?? 0;
        return status >= 500;
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
        return false;
    }
  }

  Future<List<SearchEntry>> search(
    String q, {
    String lang = 'sw',
    int limit = 20,
  }) async {
    // /search has no draft switch: it reads search_entry, which is only
    // written when an entry is published.
    final data = await _read(
      '/search',
      cacheKey: 'search:$lang:$limit:${q.trim().toLowerCase()}',
      queryParameters: {
        'q': q,
        'lang': lang,
        'limit': limit,
      },
    );
    final items = _extractList(data);
    return items
        .whereType<Map<String, dynamic>>()
        .map(SearchEntry.fromJson)
        .toList();
  }

  Future<LexemePublic> getLexeme(
    String id, {
    String lang = 'sw',
    bool? includeDrafts,
  }) async {
    final data = await _read(
      '/lexemes/${Uri.encodeComponent(id)}',
      cacheKey: 'lexeme:$lang:$id',
      queryParameters: {
        'lang': lang,
        if (includeDrafts ?? this.includeDrafts) 'include_drafts': true,
      },
    );
    if (data is! Map<String, dynamic>) {
      throw DioException(
        requestOptions: RequestOptions(path: '/lexemes/$id'),
        error: 'Unexpected lexeme response',
      );
    }
    return LexemePublic.fromJson(data);
  }

  Future<LexemePublic> lookupLemma(
    String lemma, {
    String lang = 'sw',
    bool? includeDrafts,
  }) async {
    final data = await _read(
      '/lookup/lemma',
      cacheKey: 'lemma:$lang:${lemma.trim().toLowerCase()}',
      queryParameters: {
        'lemma': lemma,
        'lang': lang,
        if (includeDrafts ?? this.includeDrafts) 'include_drafts': true,
      },
    );
    if (data is! Map<String, dynamic>) {
      throw DioException(
        requestOptions: RequestOptions(path: '/lookup/lemma'),
        error: 'Unexpected lemma lookup response',
      );
    }
    return LexemePublic.fromJson(data);
  }

  /// Today's challenge. Cached by day, so finishing it on the bus works and
  /// yesterday's round is never shown as today's.
  Future<LearnRound> getDailyRound({String lang = 'sw', int count = 5}) async {
    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    final data = await _read(
      '/learn/daily',
      cacheKey: 'learn-daily:$lang:$count:$today',
      queryParameters: {'lang': lang, 'count': count},
    );
    if (data is! Map<String, dynamic>) {
      throw DioException(
        requestOptions: RequestOptions(path: '/learn/daily'),
        error: 'Unexpected daily round response',
      );
    }
    return LearnRound.fromJson(data);
  }

  /// A practice round. Cached per kind as a fallback, so going offline leaves
  /// you with the last round of that kind rather than nothing.
  Future<LearnRound> getPracticeRound({
    String kind = 'mixed',
    String lang = 'sw',
    int count = 5,
  }) async {
    final data = await _read(
      '/learn/round',
      cacheKey: 'learn-round:$lang:$kind:$count',
      queryParameters: {'kind': kind, 'lang': lang, 'count': count},
    );
    if (data is! Map<String, dynamic>) {
      throw DioException(
        requestOptions: RequestOptions(path: '/learn/round'),
        error: 'Unexpected practice round response',
      );
    }
    return LearnRound.fromJson(data);
  }

  /// A word-search grid. Cached so a puzzle survives losing signal part-way
  /// through; the key has no date in it because a new grid on request is the
  /// point, and the cache is only a fallback.
  Future<WordFindPuzzle> getWordFind({
    String lang = 'sw',
    int size = 11,
    int count = 7,
  }) async {
    final data = await _read(
      '/learn/wordfind',
      cacheKey: 'learn-wordfind:$lang:$size:$count',
      queryParameters: {'lang': lang, 'size': size, 'count': count},
    );
    if (data is! Map<String, dynamic>) {
      throw DioException(
        requestOptions: RequestOptions(path: '/learn/wordfind'),
        error: 'Unexpected word find response',
      );
    }
    return WordFindPuzzle.fromJson(data);
  }

  Future<ExpressionDetail> getExpression(String id, {String lang = 'sw'}) async {
    final data = await _read(
      '/expressions/${Uri.encodeComponent(id)}',
      cacheKey: 'expression:$lang:$id',
      queryParameters: {'lang': lang},
    );
    if (data is! Map<String, dynamic>) {
      throw DioException(
        requestOptions: RequestOptions(path: '/expressions/$id'),
        error: 'Unexpected expression response',
      );
    }
    return ExpressionDetailDto.fromJson(data).toDomain();
  }

  Future<WordOfDay> getWordOfDay({String lang = 'sw'}) async {
    // Keyed by date as well as language: yesterday's word should not be
    // served as today's just because the connection dropped.
    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    final data = await _read(
      '/word-of-the-day',
      cacheKey: 'word-of-the-day:$lang:$today',
      queryParameters: {'lang': lang},
    );
    if (data is! Map<String, dynamic>) {
      throw DioException(
        requestOptions: RequestOptions(path: '/word-of-the-day'),
        error: 'Unexpected word of the day response',
      );
    }
    return WordOfDay.fromJson(data);
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is List) {
      return data;
    }
    if (data is Map<String, dynamic>) {
      final results = data['results'];
      if (results is List) {
        return results;
      }
    }
    return const [];
  }
}
