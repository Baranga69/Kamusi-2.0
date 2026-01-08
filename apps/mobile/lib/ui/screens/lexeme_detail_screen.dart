import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/favorite_item.dart';
import '../../domain/models/lexeme_detail.dart';
import '../../providers/detail_providers.dart';
import '../../providers/favorites_provider.dart';
import '../widgets/error_state.dart';
import '../widgets/section_header.dart';
import 'expression_detail_screen.dart';

class LexemeDetailScreen extends ConsumerWidget {
  const LexemeDetailScreen({super.key, required this.lexemeId});

  final String lexemeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(lexemeDetailProvider(lexemeId));
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lexeme'),
        actions: [
          favorites.when(
            data: (items) {
              final isFavorite = ref
                  .read(favoritesProvider.notifier)
                  .isFavorite(lexemeId, FavoriteKind.lexeme);
              return IconButton(
                onPressed: () {
                  final item = _favoriteFromDetail(detail.value);
                  if (item != null) {
                    ref.read(favoritesProvider.notifier).toggleFavorite(item);
                  }
                },
                icon: Icon(isFavorite ? Icons.star : Icons.star_border),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: detail.when(
        data: (lexeme) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                lexeme.headword,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (lexeme.partOfSpeech.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  lexeme.partOfSpeech,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                ),
              ],
              if (lexeme.pronunciations.isNotEmpty) ...[
                const SizedBox(height: 16),
                _PronunciationRow(pronunciations: lexeme.pronunciations),
              ],
              const SizedBox(height: 24),
              const SectionHeader(title: 'Senses'),
              const SizedBox(height: 12),
              ...lexeme.senses.map((sense) => _SenseCard(sense: sense)),
              if (lexeme.linkedExpressions.isNotEmpty) ...[
                const SizedBox(height: 24),
                const SectionHeader(title: 'Linked expressions'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: lexeme.linkedExpressions
                      .map(
                        (expression) => ActionChip(
                          label: Text(expression.text),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ExpressionDetailScreen(
                                  expressionId: expression.id,
                                ),
                              ),
                            );
                          },
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorState(
          title: 'Unable to load lexeme',
          message: error.toString(),
          onRetry: () => ref.refresh(lexemeDetailProvider(lexemeId)),
        ),
      ),
    );
  }

  FavoriteItem? _favoriteFromDetail(LexemeDetail? detail) {
    if (detail == null || detail.id.isEmpty) {
      return null;
    }
    return FavoriteItem(
      id: detail.id,
      kind: FavoriteKind.lexeme,
      title: detail.headword,
      subtitle: detail.partOfSpeech,
    );
  }
}

class _PronunciationRow extends StatelessWidget {
  const _PronunciationRow({required this.pronunciations});

  final List<Pronunciation> pronunciations;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pronunciation', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: pronunciations.map((pronunciation) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(pronunciation.ipa.isEmpty ? 'IPA' : pronunciation.ipa),
                  if (pronunciation.audioUrl.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.volume_up, size: 16),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _SenseCard extends StatelessWidget {
  const _SenseCard({required this.sense});

  final Sense sense;

  @override
  Widget build(BuildContext context) {
    final definitions = _prioritizeSwahili(sense.definitions);
    if (definitions.isEmpty) {
      return const SizedBox.shrink();
    }

    final primary = definitions.first;
    final secondary = definitions.length > 1 ? definitions.sublist(1) : [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DefinitionRow(definition: primary),
          if (secondary.isNotEmpty) ...[
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(
                'Other meanings',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              children: secondary
                  .map(
                    (definition) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _DefinitionRow(definition: definition),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (sense.examples.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Examples', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            ...sense.examples.map(
              (example) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('“${example.text}”'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Definition> _prioritizeSwahili(List<Definition> definitions) {
    final swahili = definitions
        .where((definition) =>
            definition.language.toLowerCase().startsWith('sw') ||
            definition.language.toLowerCase().contains('swahili'))
        .toList();
    final others = definitions
        .where((definition) => !swahili.contains(definition))
        .toList();
    return [...swahili, ...others];
  }
}

class _DefinitionRow extends StatelessWidget {
  const _DefinitionRow({required this.definition});

  final Definition definition;

  @override
  Widget build(BuildContext context) {
    final language = definition.language.isNotEmpty
        ? definition.language.toUpperCase()
        : 'Definition';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          language,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(definition.text),
      ],
    );
  }
}
