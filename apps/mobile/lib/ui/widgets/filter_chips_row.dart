import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

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
    Widget chip(String label, SearchFilter value) {
      final isActive = selected == value;
      return GestureDetector(
        onTap: () => onChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color:
                isActive ? KamusiColors.chipBg : Colors.white.withOpacity(0.22),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isActive
                  ? Colors.transparent
                  : Colors.white.withOpacity(0.35),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip("Tümü", SearchFilter.all),
          const SizedBox(width: 10),
          chip("Kelime", SearchFilter.word),
          const SizedBox(width: 10),
          chip("Atasözü", SearchFilter.proverb),
          const SizedBox(width: 10),
          chip("Deyim", SearchFilter.idiom),
        ],
      ),
    );
  }
}

enum SearchFilter { all, word, proverb, idiom }
