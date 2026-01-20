import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class FilterChipsRow extends StatelessWidget {
  final SearchFilter selected;
  final ValueChanged<SearchFilter> onChanged;

  const FilterChipsRow({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    Widget chip(String label, SearchFilter value) {
      final isActive = selected == value;
      return ChoiceChip(
        label: Text(label),
        selected: isActive,
        onSelected: (_) => onChanged(value),
        labelStyle: textTheme.labelLarge?.copyWith(
          color: isActive
              ? colorScheme.onSecondaryContainer
              : colorScheme.onSurfaceVariant,
        ),
        selectedColor: colorScheme.secondaryContainer,
        backgroundColor: colorScheme.surfaceVariant,
        shape: const StadiumBorder(),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(l10n.filterAll, SearchFilter.all),
          const SizedBox(width: 10),
          chip(l10n.filterLemma, SearchFilter.lemma),
          const SizedBox(width: 10),
          chip(l10n.filterDefinition, SearchFilter.definition),
          const SizedBox(width: 10),
          chip(l10n.filterExample, SearchFilter.example),
        ],
      ),
    );
  }
}

enum SearchFilter { all, lemma, definition, example }
