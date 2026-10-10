// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swahili (`sw`).
class AppLocalizationsSw extends AppLocalizations {
  AppLocalizationsSw([String locale = 'sw']) : super(locale);

  @override
  String get appTitle => 'Kamusi';

  @override
  String get headerTitle => 'Kamusi';

  @override
  String get homeRecentHeader => 'Utafutaji wa hivi karibuni';

  @override
  String get homeRecentEmpty =>
      'Utafutaji wako wa hivi karibuni utaonekana hapa.';

  @override
  String get homeRecentClear => 'Futa';

  @override
  String get homeSearchHint => 'Tafuta neno...';

  @override
  String get homeWordOfDayTitle => 'Neno la siku';

  @override
  String homeWordOfDayDateLabel(String date) {
    return 'Leo · $date';
  }

  @override
  String get homeWordOfDayLoading => 'Inapakia neno la siku...';

  @override
  String get homeWordOfDayError => 'Imeshindikana kupakia neno la leo.';

  @override
  String get homeThemeToggleLight => 'Badili kwenda mwanga';

  @override
  String get homeThemeToggleDark => 'Badili kwenda giza';

  @override
  String get bottomNavHome => 'Mwanzo';

  @override
  String get bottomNavSearch => 'Tafuta';

  @override
  String get bottomNavFavorites => 'Vipendwa';

  @override
  String get bottomNavProfile => 'Wasifu';

  @override
  String get searchHeaderTitle => 'Tafuta kwenye kamusi';

  @override
  String get searchHint => 'Tafuta...';

  @override
  String get searchErrorFailed =>
      'Utafutaji haukufaulu. Tafadhali jaribu tena.';

  @override
  String get searchUnsupportedResultType => 'Aina ya matokeo hayatumiki.';

  @override
  String get searchStartPrompt => 'Anza kutafuta.';

  @override
  String get searchNoResults => 'Hakuna matokeo yaliyopatikana.';

  @override
  String get searchNoResultsFilter => 'Hakuna matokeo kwa kichujio hiki.';

  @override
  String get filterAll => 'Zote';

  @override
  String get filterLemma => 'Neno';

  @override
  String get filterDefinition => 'Ufafanuzi';

  @override
  String get filterExample => 'Mfano';

  @override
  String get filterExpression => 'Usemi';

  @override
  String get relatedEmpty => 'Hakuna maneno yanayohusiana.';

  @override
  String get retry => 'Jaribu tena';

  @override
  String get lexemeTitle => 'Leksema';

  @override
  String get lexemeSenses => 'Maana';

  @override
  String lexemeSenseNumber(int number) {
    return 'Maana $number';
  }

  @override
  String get lexemeOtherMeanings => 'Maana nyingine';

  @override
  String get examples => 'Mifano';

  @override
  String get lexemeUnableLoad => 'Imeshindikana kupakia leksema';

  @override
  String get definitionLabel => 'Ufafanuzi';

  @override
  String get favoritesTitle => 'Vipendwa';

  @override
  String get favoritesTabLexemes => 'Leksema';

  @override
  String get favoritesTabExpressions => 'Semi';

  @override
  String get favoritesUnableLoad => 'Imeshindikana kupakia vipendwa';

  @override
  String get favoritesEmptyTitle => 'Bado hakuna vipendwa';

  @override
  String get favoritesEmptyMessage =>
      'Hifadhi leksema au semi ili uirudie haraka.';

  @override
  String get favoritesEmptyAction => 'Anza kutafuta';

  @override
  String get expressionTitle => 'Semi';

  @override
  String get expressionMeanings => 'Maana';

  @override
  String get expressionUnableLoad => 'Imeshindikana kupakia semi';

  @override
  String get meaningLabel => 'Maana';

  @override
  String get offlineBanner =>
      'Nje ya mtandao — tunaonyesha maneno yaliyohifadhiwa.';
}
