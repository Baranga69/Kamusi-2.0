// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Kamusi';

  @override
  String get headerTitle => 'Kamusi';

  @override
  String get homeRecentHeader => 'Recent searches';

  @override
  String get homeRecentEmpty => 'Your recent searches will show up here.';

  @override
  String get homeRecentClear => 'Clear';

  @override
  String get homeSearchHint => 'Search for a word...';

  @override
  String get homeWordOfDayTitle => 'Word of the day';

  @override
  String homeWordOfDayDateLabel(String date) {
    return 'Today · $date';
  }

  @override
  String get homeWordOfDayLoading => 'Loading word of the day...';

  @override
  String get homeWordOfDayError => 'Unable to load today\'s word.';

  @override
  String get homeThemeToggleLight => 'Switch to light mode';

  @override
  String get homeThemeToggleDark => 'Switch to dark mode';

  @override
  String get bottomNavHome => 'Home';

  @override
  String get bottomNavSearch => 'Search';

  @override
  String get bottomNavFavorites => 'Favorites';

  @override
  String get bottomNavProfile => 'Profile';

  @override
  String get searchHeaderTitle => 'Search the dictionary';

  @override
  String get searchHint => 'Search...';

  @override
  String get searchErrorFailed => 'Search failed. Please try again.';

  @override
  String get searchUnsupportedResultType => 'Unsupported result type';

  @override
  String get searchStartPrompt => 'Start searching.';

  @override
  String get searchNoResults => 'No results found.';

  @override
  String get searchNoResultsFilter => 'No results for this filter.';

  @override
  String get filterAll => 'All';

  @override
  String get filterLemma => 'Lemma';

  @override
  String get filterDefinition => 'Definition';

  @override
  String get filterExample => 'Example';

  @override
  String get filterExpression => 'Expression';

  @override
  String get relatedEmpty => 'No related words.';

  @override
  String get retry => 'Retry';

  @override
  String get lexemeTitle => 'Lexeme';

  @override
  String get lexemeSenses => 'Senses';

  @override
  String lexemeSenseNumber(int number) {
    return 'Sense $number';
  }

  @override
  String get lexemeOtherMeanings => 'Other meanings';

  @override
  String get examples => 'Examples';

  @override
  String get lexemeUnableLoad => 'Unable to load lexeme';

  @override
  String get definitionLabel => 'Definition';

  @override
  String get favoritesTitle => 'Favorites';

  @override
  String get favoritesTabLexemes => 'Lexemes';

  @override
  String get favoritesTabExpressions => 'Expressions';

  @override
  String get favoritesUnableLoad => 'Unable to load favorites';

  @override
  String get favoritesEmptyTitle => 'No favorites yet';

  @override
  String get favoritesEmptyMessage =>
      'Save a lexeme or expression to revisit it quickly.';

  @override
  String get favoritesEmptyAction => 'Start searching';

  @override
  String get expressionTitle => 'Expression';

  @override
  String get expressionMeanings => 'Meanings';

  @override
  String get expressionUnableLoad => 'Unable to load expression';

  @override
  String get meaningLabel => 'Meaning';

  @override
  String get offlineBanner => 'Offline — showing saved words.';
}
