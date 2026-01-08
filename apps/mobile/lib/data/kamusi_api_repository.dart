import 'package:dio/dio.dart';

import '../domain/models/expression_detail.dart';
import '../domain/models/lexeme_detail.dart';
import '../domain/models/search_suggestion.dart';
import '../domain/repositories/kamusi_repository.dart';
import 'api_client.dart';
import 'dtos/expression_detail_dto.dart';
import 'dtos/lexeme_detail_dto.dart';
import 'dtos/search_suggestion_dto.dart';

class KamusiApiRepository implements KamusiRepository {
  KamusiApiRepository({required this.client});

  final ApiClient client;

  @override
  Future<List<SearchSuggestion>> search(String query) async {
    final response = await client.get(
      '/search',
      queryParameters: {
        'q': query,
        'lang': 'sw',
        'limit': 20,
      },
    );

    final data = response.data;
    final items = _extractList(data);

    return items
        .whereType<Map<String, dynamic>>()
        .map(SearchSuggestionDto.fromJson)
        .map(
          (dto) => SearchSuggestion(
            entryType: dto.entryType,
            targetId: dto.targetId,
            display: dto.display,
            snippet: dto.snippet,
            tags: dto.tags,
          ),
        )
        .toList();
  }

  @override
  Future<LexemeDetail> fetchLexeme(String id) async {
    final response = await client.get(
      '/lexemes/$id',
      queryParameters: {'lang': 'sw'},
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw DioException(
        requestOptions: response.requestOptions,
        error: 'Unexpected lexeme response',
      );
    }
    return LexemeDetailDto.fromJson(data).toDomain();
  }

  @override
  Future<ExpressionDetail> fetchExpression(String id) async {
    final response = await client.get(
      '/expressions/$id',
      queryParameters: {'lang': 'sw'},
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw DioException(
        requestOptions: response.requestOptions,
        error: 'Unexpected expression response',
      );
    }
    return ExpressionDetailDto.fromJson(data).toDomain();
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
