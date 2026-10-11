import '../domain/models/expression_detail.dart';
import '../domain/models/learn_round.dart';
import '../domain/models/word_find_puzzle.dart';
import '../domain/models/lexeme_public.dart';
import '../domain/models/search_entry.dart';
import '../domain/models/word_of_day.dart';
import '../domain/repositories/kamusi_repository.dart';
import 'api_client.dart';

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
    return client.getExpression(id);
  }

  @override
  Future<WordOfDay> fetchWordOfDay() async {
    return client.getWordOfDay();
  }

  @override
  Future<LearnRound> fetchDailyRound() async {
    return client.getDailyRound();
  }

  @override
  Future<LearnRound> fetchPracticeRound(String kind) async {
    return client.getPracticeRound(kind: kind);
  }

  @override
  Future<WordFindPuzzle> fetchWordFind() async {
    return client.getWordFind();
  }

}
