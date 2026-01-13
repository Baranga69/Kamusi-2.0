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
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: colorScheme.secondary,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        title: Text(
          item.text,
          style: KamusiTypography.serif(
            textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        subtitle: Text(
          item.targetType,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}
