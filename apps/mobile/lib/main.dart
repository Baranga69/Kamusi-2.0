import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kamusi_mobile/ui/screens/dictionary_home_screen.dart';

import 'domain/models/search_suggestion.dart';
import 'ui/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: KamusiApp()));
}

class KamusiApp extends StatelessWidget {
  const KamusiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kamusi',
      theme: buildAppTheme(),
      home: DictionaryHomeScreen(
        recent: const [
          SearchResultItem(id: "1", title: "kula", subtitle: "Kitenzi (kitz)"),
          SearchResultItem(id: "2", title: "fyata", subtitle: "Kiulizi (kil)"),
          SearchResultItem(id: "3", title: "ndizi", subtitle: "Kijina (kin)"),
        ],
        onOpenSearch: () {},
        onSearchSubmitted: (q) {},
      ),
    );
  }
}
