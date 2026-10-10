import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'l10n/app_localizations.dart';

import 'providers/app_providers.dart';
import 'ui/screens/root_shell.dart';
import 'ui/theme/kamusi_theme.dart';
import 'ui/widgets/offline_banner.dart';

void main() {
  runApp(const ProviderScope(child: KamusiApp()));
}

class KamusiApp extends ConsumerWidget {
  const KamusiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildKamusiTheme(brightness: Brightness.light),
      darkTheme: buildKamusiTheme(brightness: Brightness.dark),
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      // Wrapping here rather than per screen means pushed routes are covered
      // too, and there is one place that decides how offline is presented.
      builder: (context, child) => OfflineBanner(child: child ?? const SizedBox.shrink()),
      home: const RootShell(),
    );
  }
}
