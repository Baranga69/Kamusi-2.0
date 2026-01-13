import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../domain/models/lexeme_public.dart';
import '../theme/kamusi_typography.dart';

class DefinitionRow extends StatelessWidget {
  const DefinitionRow({super.key, required this.definition});

  final Definition definition;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final language = (definition.langCode ?? '').isNotEmpty
        ? definition.langCode!.toUpperCase()
        : l10n.definitionLabel;
    final text = definition.definition?.isNotEmpty == true
        ? definition.definition!
        : (definition.gloss ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            language,
            style: textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          text,
          style: KamusiTypography.serif(
            textTheme.bodyLarge,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
