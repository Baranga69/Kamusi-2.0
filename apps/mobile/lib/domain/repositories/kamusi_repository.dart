import '../models/expression_detail.dart';
import '../models/lexeme_detail.dart';
import '../models/search_suggestion.dart';

abstract class KamusiRepository {
  Future<List<SearchSuggestion>> search(String query);
  Future<LexemeDetail> fetchLexeme(String id);
  Future<ExpressionDetail> fetchExpression(String id);
}
