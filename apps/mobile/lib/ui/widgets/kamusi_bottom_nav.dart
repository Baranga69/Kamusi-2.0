import 'package:flutter/material.dart';

class _KamusiBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _KamusiBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      destinations: const [
        NavigationDestination(
            icon: Icon(Icons.home_outlined), label: "Ana Sayfa"),
        NavigationDestination(icon: Icon(Icons.search), label: "Ara"),
        NavigationDestination(icon: Icon(Icons.star_border), label: "Kaydet"),
        NavigationDestination(icon: Icon(Icons.history), label: "Geçmiş"),
      ],
    );
  }
}
