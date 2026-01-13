import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class _KamusiBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _KamusiBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      destinations: [
        NavigationDestination(
            icon: const Icon(Icons.home_outlined), label: l10n.bottomNavHome),
        NavigationDestination(
            icon: const Icon(Icons.search), label: l10n.bottomNavSearch),
        NavigationDestination(
            icon: const Icon(Icons.star_border),
            label: l10n.bottomNavFavorites),
        NavigationDestination(
            icon: const Icon(Icons.history), label: l10n.bottomNavProfile),
      ],
    );
  }
}
