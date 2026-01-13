import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../domain/models/favorite_item.dart';
import '../../domain/models/lexeme_public.dart';
import '../../providers/detail_providers.dart';
import '../../providers/favorites_provider.dart';
import '../widgets/error_state.dart';
import '../widgets/section_header.dart';

class LexemeDetailScreen extends ConsumerWidget {
  const LexemeDetailScreen({super.key, required this.lexemeId});

  final String lexemeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final detail = ref.watch(lexemeDetailProvider(lexemeId));
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.lexemeTitle),
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
                lexeme.lemma ?? '',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if ((lexeme.posId ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  lexeme.posId!,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                ),
              ],
              const SizedBox(height: 24),
              SectionHeader(title: l10n.lexemeSenses),
              const SizedBox(height: 12),
              ...lexeme.senses.map((sense) => _SenseCard(sense: sense)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorState(
          title: l10n.lexemeUnableLoad,
          message: error.toString(),
          onRetry: () => ref.refresh(lexemeDetailProvider(lexemeId)),
        ),
      ),
    );
  }

  FavoriteItem? _favoriteFromDetail(LexemePublic? detail) {
    if (detail == null || detail.id.isEmpty) {
      return null;
    }
    return FavoriteItem(
      id: detail.id,
      kind: FavoriteKind.lexeme,
      title: detail.lemma ?? '',
      subtitle: detail.posId ?? '',
    );
  }
}

class _SenseCard extends StatelessWidget {
  const _SenseCard({required this.sense});

  final Sense sense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
          if (sense.senseNumber != null)
            Text(
              l10n.lexemeSenseNumber(sense.senseNumber!),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          if (sense.senseNumber != null) const SizedBox(height: 8),
          _DefinitionRow(definition: primary),
          if (secondary.isNotEmpty) ...[
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(
                l10n.lexemeOtherMeanings,
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
            Text(l10n.examples, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            ...sense.examples
                .map(_preferredExampleText)
                .whereType<ExampleText>()
                .map(
                  (example) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('“${example.text ?? ''}”'),
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
            (definition.langCode ?? '').toLowerCase().startsWith('sw'))
        .toList();
    final others = definitions
        .where((definition) => !swahili.contains(definition))
        .toList();
    if (swahili.isNotEmpty) {
      return swahili;
    }
    final english = definitions
        .where((definition) =>
            (definition.langCode ?? '').toLowerCase().startsWith('en'))
        .toList();
    if (english.isNotEmpty) {
      return english;
    }
    return [...swahili, ...others];
  }

  ExampleText? _preferredExampleText(Example example) {
    if (example.texts.isEmpty) {
      return null;
    }
    final sw = example.texts.firstWhere(
      (text) => (text.langCode ?? '').toLowerCase().startsWith('sw'),
      orElse: () => example.texts.first,
    );
    final en = example.texts.firstWhere(
      (text) => (text.langCode ?? '').toLowerCase().startsWith('en'),
      orElse: () => sw,
    );
    final primary = example.texts.firstWhere(
      (text) => text.isPrimary == true,
      orElse: () => en,
    );
    return primary;
  }
}

class _DefinitionRow extends StatelessWidget {
  const _DefinitionRow({required this.definition});

  final Definition definition;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final language = (definition.langCode ?? '').isNotEmpty
        ? definition.langCode!.toUpperCase()
        : l10n.definitionLabel;
    final text = definition.definition?.isNotEmpty == true
        ? definition.definition!
        : (definition.gloss ?? '');
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
        Text(text),
      ],
    );
  }
}
