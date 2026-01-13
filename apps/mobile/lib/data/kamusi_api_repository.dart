import 'package:dio/dio.dart';

import '../domain/models/expression_detail.dart';
import '../domain/models/lexeme_public.dart';
import '../domain/models/search_entry.dart';
import '../domain/repositories/kamusi_repository.dart';
import 'api_client.dart';
import 'dtos/expression_detail_dto.dart';

class KamusiApiRepository implements KamusiRepository {
  KamusiApiRepository({required this.client});

  final ApiClient client;

  @override
  Future<List<SearchEntry>> search(String query) async {
    return client.search(query);
  }

  @override
  Future<LexemePublic> fetchLexeme(String id) async {
    return client.getLexeme(id);
  }

  @override
  Future<LexemePublic> lookupLemma(String lemma) async {
    return client.lookupLemma(lemma);
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

}
