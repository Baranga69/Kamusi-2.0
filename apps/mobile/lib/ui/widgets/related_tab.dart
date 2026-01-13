import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../theme/app_theme.dart';

class _RelatedTab extends StatelessWidget {
  final List<String> related;
  const _RelatedTab({required this.related});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: related.isEmpty
                ? Text(
                    l10n.relatedEmpty,
                    style: const TextStyle(color: KamusiColors.textMuted),
                  )
                : Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: related
                        .map(
                          (w) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: KamusiColors.cardBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              w,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: KamusiColors.textDark,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ),
      ],
    );
  }
}
