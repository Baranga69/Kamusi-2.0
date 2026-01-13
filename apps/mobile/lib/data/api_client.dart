import 'package:dio/dio.dart';

import '../domain/models/lexeme_public.dart';
import '../domain/models/search_entry.dart';
import '../domain/models/word_of_day.dart';

class ApiClient {
  ApiClient({required this.baseUrl}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
  }

  final String baseUrl;
  late final Dio _dio;

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<List<SearchEntry>> search(
    String q, {
    String lang = 'sw',
    int limit = 20,
    bool includeDrafts = false,
  }) async {
    if (includeDrafts) {
      // /search does not support drafts yet; reserved for future use.
    }
    final response = await get(
      '/search',
      queryParameters: {
        'q': q,
        'lang': lang,
        'limit': limit,
      },
    );
    final items = _extractList(response.data);
    return items
        .whereType<Map<String, dynamic>>()
        .map(SearchEntry.fromJson)
        .toList();
  }

  Future<LexemePublic> getLexeme(
    String id, {
    String lang = 'sw',
    bool includeDrafts = true,
  }) async {
    final response = await get(
      '/lexemes/${Uri.encodeComponent(id)}',
      queryParameters: {
        'lang': lang,
        if (includeDrafts) 'include_drafts': true, // Local dev only.
      },
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw DioException(
        requestOptions: response.requestOptions,
        error: 'Unexpected lexeme response',
      );
    }
    return LexemePublic.fromJson(data);
  }

  Future<LexemePublic> lookupLemma(
    String lemma, {
    String lang = 'sw',
    bool includeDrafts = true,
  }) async {
    final response = await get(
      '/lookup/lemma',
      queryParameters: {
        'lemma': lemma,
        'lang': lang,
        if (includeDrafts) 'include_drafts': true, // Local dev only.
      },
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw DioException(
        requestOptions: response.requestOptions,
        error: 'Unexpected lemma lookup response',
      );
    }
    return LexemePublic.fromJson(data);
  }

  Future<WordOfDay> getWordOfDay({String lang = 'sw'}) async {
    final response = await get(
      '/word-of-the-day',
      queryParameters: {'lang': lang},
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw DioException(
        requestOptions: response.requestOptions,
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
