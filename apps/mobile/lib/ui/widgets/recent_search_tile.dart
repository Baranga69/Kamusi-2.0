import 'package:flutter/material.dart';

import '../theme/kamusi_typography.dart';

class RecentSearchTile extends StatelessWidget {
  final String query;
  final VoidCallback onTap;

  const RecentSearchTile({
    super.key,
    required this.query,
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
        leading: Icon(
          Icons.history,
          color: colorScheme.onSurfaceVariant,
          size: 20,
        ),
        title: Text(
          query,
          style: KamusiTypography.serif(
            textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}
