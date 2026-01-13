import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/expression_detail.dart';
import '../domain/models/lexeme_public.dart';
import 'app_providers.dart';

final lexemeDetailProvider =
    FutureProvider.family<LexemePublic, String>((ref, id) async {
  final repository = ref.read(kamusiRepositoryProvider);
  return repository.fetchLexeme(id);
});

final expressionDetailProvider =
    FutureProvider.family<ExpressionDetail, String>((ref, id) async {
  final repository = ref.read(kamusiRepositoryProvider);
  return repository.fetchExpression(id);
});
