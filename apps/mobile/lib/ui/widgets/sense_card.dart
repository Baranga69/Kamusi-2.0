import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../domain/models/lexeme_public.dart';
import 'definition_row.dart';

class SenseCard extends StatelessWidget {
  const SenseCard({super.key, required this.sense});

  final Sense sense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
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
        color: colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sense.senseNumber != null)
            Text(
              l10n.lexemeSenseNumber(sense.senseNumber!),
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          if (sense.senseNumber != null) const SizedBox(height: 10),
          DefinitionRow(definition: primary),
          if (secondary.isNotEmpty) ...[
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              iconColor: colorScheme.onSurfaceVariant,
              collapsedIconColor: colorScheme.onSurfaceVariant,
              title: Text(
                l10n.lexemeOtherMeanings,
                style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              children: secondary
                  .map(
                    (definition) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: DefinitionRow(definition: definition),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (sense.examples.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              l10n.examples,
              style: textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            ...sense.examples
                .map(_preferredExampleText)
                .whereType<ExampleText>()
                .map(
                  (example) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '“${example.text ?? ''}”',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
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
