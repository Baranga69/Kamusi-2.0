import 'package:flutter/material.dart';

import '../../domain/models/search_entry.dart';
import '../theme/app_theme.dart';

class ResultListTile extends StatelessWidget {
  final SearchEntry item;
  final VoidCallback onTap;

  const ResultListTile({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: KamusiColors.headerRed,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.text,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: KamusiColors.textDark,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.targetType,
                    style: const TextStyle(
                      color: KamusiColors.textMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: KamusiColors.textMuted),
          ],
        ),
      ),
    );
  }
}
