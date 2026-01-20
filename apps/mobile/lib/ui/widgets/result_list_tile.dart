import 'package:flutter/material.dart';

import '../../domain/models/search_entry.dart';
import '../theme/kamusi_typography.dart';

class SearchResultTile extends StatelessWidget {
  final SearchEntry item;
  final VoidCallback onTap;

  const SearchResultTile({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final badges = <String>[];
    if ((item.posCode ?? '').isNotEmpty) {
      badges.add(item.posCode!.toUpperCase());
    }
    final matchKind = _matchKindLabel(item.matchKind);
    if (matchKind != null) {
      badges.add(matchKind);
    }
    final titleText = item.lemma.isNotEmpty ? item.lemma : item.text;
    final showSnippet = item.text.isNotEmpty && item.text != titleText;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        isThreeLine: showSnippet,
        leading: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: colorScheme.secondary,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        title: Text(
          titleText,
          style: KamusiTypography.serif(
            textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (badges.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: badges
                      .map((label) => _ResultBadge(label: label))
                      .toList(),
                ),
              ),
            if (showSnippet)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  item.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
      ),
    );
  }

  String? _matchKindLabel(String? kind) {
    if (kind == null || kind.isEmpty) {
      return null;
    }
    return kind.toUpperCase();
  }
}

class _ResultBadge extends StatelessWidget {
  const _ResultBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
