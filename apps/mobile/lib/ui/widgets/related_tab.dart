import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class _RelatedTab extends StatelessWidget {
  final List<String> related;
  const _RelatedTab({required this.related});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: related.isEmpty
                ? const Text(
                    "İlişkili kelime yok.",
                    style: TextStyle(color: KamusiColors.textMuted),
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
