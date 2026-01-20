import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/app_providers.dart';
import '../../providers/recent_searches_provider.dart';
import '../../providers/word_of_day_provider.dart';
import '../widgets/search_bar.dart';
import '../widgets/word_of_day_card.dart';
import 'favorites_screen.dart';
import 'lexeme_detail_screen.dart';

class DictionaryHomeScreen extends ConsumerStatefulWidget {
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback? onOpenSearch;

  const DictionaryHomeScreen({
    super.key,
    required this.onSearchSubmitted,
    this.onOpenSearch,
  });

  @override
  ConsumerState<DictionaryHomeScreen> createState() =>
      _DictionaryHomeScreenState();
}

class _DictionaryHomeScreenState
    extends ConsumerState<DictionaryHomeScreen> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  Timer? _wordOfDayTimer;
  DateTime _wordOfDayAnchor = DateTime.utc(1970, 1, 1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wordOfDayAnchor = _utcToday();
    _scheduleWordOfDayRefresh();
  }

  @override
  void dispose() {
    _wordOfDayTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshWordOfDayIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final recents = ref.watch(recentSearchesProvider);
    final wordOfDaySection = ref.watch(wordOfDayProvider).when(
          data: (word) => WordOfDayCard(
            title: l10n.homeWordOfDayTitle,
            subtitle: _wordOfDaySubtitle(context, word.date),
            lemma: word.lemma,
            definition: word.definition,
            onTap: () => _openLexeme(word.lexemeId),
          ),
          loading: () => WordOfDayCard(
            title: l10n.homeWordOfDayTitle,
            isLoading: true,
            message: l10n.homeWordOfDayLoading,
          ),
          error: (_, __) => WordOfDayCard(
            title: l10n.homeWordOfDayTitle,
            message: l10n.homeWordOfDayError,
          ),
        );
    final bodyCard = Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history,
                    size: 18, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  l10n.homeRecentHeader,
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (recents.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      ref.read(recentSearchesProvider.notifier).clear();
                    },
                    style: TextButton.styleFrom(
                      textStyle: textTheme.labelLarge,
                      foregroundColor: colorScheme.primary,
                    ),
                    child: Text(l10n.homeRecentClear),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (recents.isEmpty)
              Text(
                l10n.homeRecentEmpty,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: recents
                    .map(
                      (query) => ActionChip(
                        avatar: Icon(
                          Icons.search,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        label: Text(query),
                        onPressed: () => widget.onSearchSubmitted(query),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.headerTitle),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            onPressed: () {
              ref.read(themeModeProvider.notifier).state =
                  isDarkMode ? ThemeMode.light : ThemeMode.dark;
            },
            tooltip:
                isDarkMode ? l10n.homeThemeToggleLight : l10n.homeThemeToggleDark,
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(color: colorScheme.surfaceVariant),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    l10n.headerTitle,
                    style: textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.search),
                title: Text(l10n.bottomNavSearch),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onOpenSearch?.call();
                },
              ),
              ListTile(
                leading: const Icon(Icons.star_border),
                title: Text(l10n.bottomNavFavorites),
                onTap: () {
                  Navigator.of(context).pop();
                  _openFavorites();
                },
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: KamusiSearchBar(
              hint: l10n.homeSearchHint,
              controller: _controller,
              readOnly: true,
              onTap: widget.onOpenSearch,
              onClear: () {
                _controller.clear();
                setState(() {});
              },
              onSubmitted: (q) {
                if (q.trim().isNotEmpty) widget.onSearchSubmitted(q.trim());
              },
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 12),
          wordOfDaySection,
          bodyCard,
        ],
      ),
    );
  }

  void _openLexeme(String lexemeId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LexemeDetailScreen(lexemeId: lexemeId),
      ),
    );
  }

  void _openFavorites() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FavoritesScreen(
          onOpenSearch: widget.onOpenSearch,
        ),
      ),
    );
  }

  String? _wordOfDaySubtitle(BuildContext context, String rawDate) {
    if (rawDate.trim().isEmpty) {
      return null;
    }
    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) {
      return AppLocalizations.of(context)!.homeWordOfDayDateLabel(rawDate);
    }
    final locale = Localizations.localeOf(context).toLanguageTag();
    final formatted = DateFormat.MMMd(locale).format(parsed);
    return AppLocalizations.of(context)!.homeWordOfDayDateLabel(formatted);
  }

  DateTime _utcToday() {
    final now = DateTime.now().toUtc();
    return DateTime.utc(now.year, now.month, now.day);
  }

  void _refreshWordOfDayIfNeeded() {
    final today = _utcToday();
    if (today != _wordOfDayAnchor) {
      _wordOfDayAnchor = today;
      ref.invalidate(wordOfDayProvider);
    }
    _scheduleWordOfDayRefresh();
  }

  void _scheduleWordOfDayRefresh() {
    _wordOfDayTimer?.cancel();
    final now = DateTime.now().toUtc();
    final nextMidnight =
        DateTime.utc(now.year, now.month, now.day).add(const Duration(days: 1));
    final delay = nextMidnight.difference(now) + const Duration(seconds: 1);
    _wordOfDayTimer = Timer(delay, _refreshWordOfDayIfNeeded);
  }
}
