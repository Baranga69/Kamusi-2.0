import '../models/expression_detail.dart';
import '../models/lexeme_public.dart';
import '../models/search_entry.dart';
import '../models/word_of_day.dart';

abstract class KamusiRepository {
  Future<List<SearchEntry>> search(String query);
  Future<LexemePublic> fetchLexeme(String id);
  Future<LexemePublic> lookupLemma(String lemma);
  Future<ExpressionDetail> fetchExpression(String id);
  Future<WordOfDay> fetchWordOfDay();
}
