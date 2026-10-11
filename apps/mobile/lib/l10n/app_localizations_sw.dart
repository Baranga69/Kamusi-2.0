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

  @override
  String get navDictionary => 'Kamusi';

  @override
  String get navLearn => 'Jifunze';

  @override
  String get navFavorites => 'Vipendwa';

  @override
  String get learnTitle => 'Jifunze';

  @override
  String get learnDailyTitle => 'Changamoto ya leo';

  @override
  String get learnDailyStart => 'Anza';

  @override
  String get learnDailyDone => 'Umekamilisha leo';

  @override
  String get learnDailyAgain => 'Jaribu tena';

  @override
  String get learnStreakNone => 'Anza mfululizo wako';

  @override
  String get learnPracticeTitle => 'Mazoezi';

  @override
  String get learnKindDefinition => 'Neno kwa maana';

  @override
  String get learnKindMeaning => 'Maana kwa neno';

  @override
  String get learnKindMethali => 'Methali';

  @override
  String get learnKindMixed => 'Mchanganyiko';

  @override
  String get learnAskDefinition => 'Neno hili lina maana gani?';

  @override
  String get learnAskMeaning => 'Neno gani lina maana hii?';

  @override
  String get learnAskMethali => 'Kamilisha methali';

  @override
  String get learnCorrect => 'Sawa';

  @override
  String get learnIncorrect => 'Bado kidogo';

  @override
  String get learnContinue => 'Endelea';

  @override
  String get learnFinish => 'Maliza';

  @override
  String get learnOpenEntry => 'Soma neno';

  @override
  String get learnResultPerfect => 'Zote sawa';

  @override
  String get learnResultGood => 'Vizuri';

  @override
  String get learnResultKeepGoing => 'Endelea kujifunza';

  @override
  String get learnPlayAgain => 'Jaribu tena';

  @override
  String get learnBackToLearn => 'Rudi Jifunze';

  @override
  String get learnEmptyTitle => 'Hakuna maswali bado';

  @override
  String get learnEmptyBody =>
      'Maneno zaidi yaliyochapishwa yanahitajika kuunda duru.';

  @override
  String get learnErrorTitle => 'Imeshindikana kupakia duru';

  @override
  String get learnLoading => 'Tunatayarisha duru yako...';

  @override
  String learnStreakDays(int count) {
    return 'Siku $count mfululizo';
  }

  @override
  String learnBestStreak(int count) {
    return 'Bora: siku $count';
  }

  @override
  String learnQuestionCount(int count) {
    return 'Maswali $count';
  }

  @override
  String learnProgressOf(int current, int total) {
    return '$current kati ya $total';
  }

  @override
  String learnScore(int correct, int total) {
    return '$correct kati ya $total sahihi';
  }

  @override
  String learnAccuracy(int percent) {
    return 'Usahihi wa $percent%';
  }

  @override
  String get settingsLanguage => 'Lugha';

  @override
  String get languageSwahili => 'Kiswahili';

  @override
  String get languageEnglish => 'Kiingereza';

  @override
  String get languageSystem => 'Fuata mipangilio ya simu';

  @override
  String get learnWordFindTitle => 'Tafuta Neno';

  @override
  String get learnWordFindCardBody =>
      'Tafuta maneno yaliyofichwa, kisha ujifunze maana zao.';

  @override
  String get learnWordFindHint =>
      'Chora kutoka herufi ya kwanza hadi ya mwisho.';

  @override
  String get learnWordFindFoundTitle => 'Maneno uliyoyapata';

  @override
  String get learnWordFindEmpty =>
      'Hakuna neno lililopatikana bado. Maana zitaonekana hapa.';

  @override
  String get learnWordFindDone => 'Umepata maneno yote. Hongera!';

  @override
  String get learnWordFindNew => 'Chemsha bongo mpya';

  @override
  String get learnWordBuildTitle => 'Unda Neno';

  @override
  String get learnWordBuildCardBody =>
      'Unganisha herufi nane kuunda maneno na maana zake.';

  @override
  String get learnWordBuildHint => 'Vuruta kwenye herufi kuunda neno';

  @override
  String get learnWordBuildEasy => 'Rahisi';

  @override
  String get learnWordBuildHard => 'Ngumu';

  @override
  String get learnWordBuildEasyHint =>
      'Maana zinaonekana tangu mwanzo kama vidokezo.';

  @override
  String get learnWordBuildHardHint => 'Maana huonekana baada ya kuunda neno.';

  @override
  String get learnWordBuildShuffle => 'Changanya herufi';

  @override
  String get learnWordBuildNew => 'Chemsha bongo mpya';

  @override
  String get learnWordBuildDone => 'Umemaliza!';

  @override
  String learnGamesOfflineReady(int count) {
    return 'Raundi $count tayari bila intaneti';
  }

  @override
  String get learnGamesOfflineNone => 'Hakuna raundi iliyohifadhiwa bado';
}
