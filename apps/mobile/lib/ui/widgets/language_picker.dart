import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/language_store.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_providers.dart';

/// Choose the interface language.
///
/// Deliberately prominent rather than buried in a settings screen: a Swahili
/// speaker whose phone is set to English should be able to find this without
/// hunting, and the labels are written so each option is legible whichever
/// language is currently showing.
class LanguagePicker extends ConsumerWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final selected = ref.watch(appLanguageProvider);

    String label(AppLanguage language) => switch (language) {
          AppLanguage.swahili => l10n.languageSwahili,
          AppLanguage.english => l10n.languageEnglish,
          AppLanguage.system => l10n.languageSystem,
        };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            l10n.settingsLanguage,
            style: textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        for (final language in AppLanguage.values)
          RadioListTile<AppLanguage>(
            value: language,
            groupValue: selected,
            dense: true,
            title: Text(label(language)),
            onChanged: (chosen) async {
              if (chosen == null) {
                return;
              }
              ref.read(appLanguageProvider.notifier).state = chosen;
              await ref.read(languageStoreProvider).save(chosen);
            },
          ),
      ],
    );
  }
}
