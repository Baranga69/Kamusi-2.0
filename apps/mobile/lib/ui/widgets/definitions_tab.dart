import 'package:flutter/material.dart';
import '../../domain/models/search_suggestion.dart';
import '../theme/app_theme.dart';

class _DefinitionsTab extends StatelessWidget {
  final DictionaryEntry entry;
  const _DefinitionsTab({required this.entry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < entry.senses.length; i++) ...[
                  _SenseBlock(index: i + 1, sense: entry.senses[i]),
                  if (i != entry.senses.length - 1) const Divider(height: 22),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SenseBlock extends StatelessWidget {
  final int index;
  final EntrySense sense;

  const _SenseBlock({required this.index, required this.sense});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "$index.",
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: KamusiColors.headerRed,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: KamusiColors.cardBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                sense.pos,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: KamusiColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          sense.definition,
          style: const TextStyle(
            fontSize: 14.5,
            height: 1.3,
            fontWeight: FontWeight.w700,
            color: KamusiColors.textDark,
          ),
        ),
        if (sense.example != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: KamusiColors.cardBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              "“${sense.example!}”",
              style: const TextStyle(
                color: KamusiColors.textMuted,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
