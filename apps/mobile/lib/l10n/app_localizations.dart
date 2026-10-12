import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_sw.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('sw')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Kamusi'**
  String get appTitle;

  /// No description provided for @headerTitle.
  ///
  /// In en, this message translates to:
  /// **'Kamusi'**
  String get headerTitle;

  /// No description provided for @homeRecentHeader.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get homeRecentHeader;

  /// No description provided for @homeRecentEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your recent searches will show up here.'**
  String get homeRecentEmpty;

  /// No description provided for @homeRecentClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get homeRecentClear;

  /// No description provided for @homeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search for a word...'**
  String get homeSearchHint;

  /// No description provided for @homeWordOfDayTitle.
  ///
  /// In en, this message translates to:
  /// **'Word of the day'**
  String get homeWordOfDayTitle;

  /// Label shown under word of the day title.
  ///
  /// In en, this message translates to:
  /// **'Today · {date}'**
  String homeWordOfDayDateLabel(String date);

  /// No description provided for @homeWordOfDayLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading word of the day...'**
  String get homeWordOfDayLoading;

  /// No description provided for @homeWordOfDayError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load today\'s word.'**
  String get homeWordOfDayError;

  /// No description provided for @homeThemeToggleLight.
  ///
  /// In en, this message translates to:
  /// **'Switch to light mode'**
  String get homeThemeToggleLight;

  /// No description provided for @homeThemeToggleDark.
  ///
  /// In en, this message translates to:
  /// **'Switch to dark mode'**
  String get homeThemeToggleDark;

  /// No description provided for @bottomNavHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get bottomNavHome;

  /// No description provided for @bottomNavSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get bottomNavSearch;

  /// No description provided for @bottomNavFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get bottomNavFavorites;

  /// No description provided for @bottomNavProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get bottomNavProfile;

  /// No description provided for @searchHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Search the dictionary'**
  String get searchHeaderTitle;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get searchHint;

  /// No description provided for @searchErrorFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed. Please try again.'**
  String get searchErrorFailed;

  /// No description provided for @searchUnsupportedResultType.
  ///
  /// In en, this message translates to:
  /// **'Unsupported result type'**
  String get searchUnsupportedResultType;

  /// No description provided for @searchStartPrompt.
  ///
  /// In en, this message translates to:
  /// **'Start searching.'**
  String get searchStartPrompt;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found.'**
  String get searchNoResults;

  /// No description provided for @searchNoResultsFilter.
  ///
  /// In en, this message translates to:
  /// **'No results for this filter.'**
  String get searchNoResultsFilter;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterLemma.
  ///
  /// In en, this message translates to:
  /// **'Lemma'**
  String get filterLemma;

  /// No description provided for @filterDefinition.
  ///
  /// In en, this message translates to:
  /// **'Definition'**
  String get filterDefinition;

  /// No description provided for @filterExample.
  ///
  /// In en, this message translates to:
  /// **'Example'**
  String get filterExample;

  /// No description provided for @filterExpression.
  ///
  /// In en, this message translates to:
  /// **'Expression'**
  String get filterExpression;

  /// No description provided for @relatedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No related words.'**
  String get relatedEmpty;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @lexemeTitle.
  ///
  /// In en, this message translates to:
  /// **'Lexeme'**
  String get lexemeTitle;

  /// No description provided for @lexemeSenses.
  ///
  /// In en, this message translates to:
  /// **'Senses'**
  String get lexemeSenses;

  /// Label for a sense number in a lexeme entry.
  ///
  /// In en, this message translates to:
  /// **'Sense {number}'**
  String lexemeSenseNumber(int number);

  /// No description provided for @lexemeOtherMeanings.
  ///
  /// In en, this message translates to:
  /// **'Other meanings'**
  String get lexemeOtherMeanings;

  /// No description provided for @examples.
  ///
  /// In en, this message translates to:
  /// **'Examples'**
  String get examples;

  /// No description provided for @lexemeUnableLoad.
  ///
  /// In en, this message translates to:
  /// **'Unable to load lexeme'**
  String get lexemeUnableLoad;

  /// No description provided for @definitionLabel.
  ///
  /// In en, this message translates to:
  /// **'Definition'**
  String get definitionLabel;

  /// No description provided for @favoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favoritesTitle;

  /// No description provided for @favoritesTabLexemes.
  ///
  /// In en, this message translates to:
  /// **'Lexemes'**
  String get favoritesTabLexemes;

  /// No description provided for @favoritesTabExpressions.
  ///
  /// In en, this message translates to:
  /// **'Expressions'**
  String get favoritesTabExpressions;

  /// No description provided for @favoritesUnableLoad.
  ///
  /// In en, this message translates to:
  /// **'Unable to load favorites'**
  String get favoritesUnableLoad;

  /// No description provided for @favoritesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get favoritesEmptyTitle;

  /// No description provided for @favoritesEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Save a lexeme or expression to revisit it quickly.'**
  String get favoritesEmptyMessage;

  /// No description provided for @favoritesEmptyAction.
  ///
  /// In en, this message translates to:
  /// **'Start searching'**
  String get favoritesEmptyAction;

  /// No description provided for @expressionTitle.
  ///
  /// In en, this message translates to:
  /// **'Expression'**
  String get expressionTitle;

  /// No description provided for @expressionMeanings.
  ///
  /// In en, this message translates to:
  /// **'Meanings'**
  String get expressionMeanings;

  /// No description provided for @expressionUnableLoad.
  ///
  /// In en, this message translates to:
  /// **'Unable to load expression'**
  String get expressionUnableLoad;

  /// No description provided for @meaningLabel.
  ///
  /// In en, this message translates to:
  /// **'Meaning'**
  String get meaningLabel;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'Offline — showing saved words.'**
  String get offlineBanner;

  /// No description provided for @navDictionary.
  ///
  /// In en, this message translates to:
  /// **'Dictionary'**
  String get navDictionary;

  /// No description provided for @navLearn.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get navLearn;

  /// No description provided for @navFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get navFavorites;

  /// No description provided for @learnTitle.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get learnTitle;

  /// No description provided for @learnDailyTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s challenge'**
  String get learnDailyTitle;

  /// No description provided for @learnDailyStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get learnDailyStart;

  /// No description provided for @learnDailyDone.
  ///
  /// In en, this message translates to:
  /// **'Done for today'**
  String get learnDailyDone;

  /// No description provided for @learnDailyAgain.
  ///
  /// In en, this message translates to:
  /// **'Play again'**
  String get learnDailyAgain;

  /// No description provided for @learnStreakNone.
  ///
  /// In en, this message translates to:
  /// **'Start your streak'**
  String get learnStreakNone;

  /// No description provided for @learnPracticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get learnPracticeTitle;

  /// No description provided for @learnKindDefinition.
  ///
  /// In en, this message translates to:
  /// **'Word to meaning'**
  String get learnKindDefinition;

  /// No description provided for @learnKindMeaning.
  ///
  /// In en, this message translates to:
  /// **'Meaning to word'**
  String get learnKindMeaning;

  /// No description provided for @learnKindMethali.
  ///
  /// In en, this message translates to:
  /// **'Proverbs'**
  String get learnKindMethali;

  /// No description provided for @learnKindMixed.
  ///
  /// In en, this message translates to:
  /// **'A bit of everything'**
  String get learnKindMixed;

  /// No description provided for @learnAskDefinition.
  ///
  /// In en, this message translates to:
  /// **'What does this word mean?'**
  String get learnAskDefinition;

  /// No description provided for @learnAskMeaning.
  ///
  /// In en, this message translates to:
  /// **'Which word means this?'**
  String get learnAskMeaning;

  /// No description provided for @learnAskMethali.
  ///
  /// In en, this message translates to:
  /// **'Complete the proverb'**
  String get learnAskMethali;

  /// No description provided for @learnCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get learnCorrect;

  /// No description provided for @learnIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Not quite'**
  String get learnIncorrect;

  /// No description provided for @learnContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get learnContinue;

  /// No description provided for @learnFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get learnFinish;

  /// No description provided for @learnOpenEntry.
  ///
  /// In en, this message translates to:
  /// **'Read the entry'**
  String get learnOpenEntry;

  /// No description provided for @learnResultPerfect.
  ///
  /// In en, this message translates to:
  /// **'Every one right'**
  String get learnResultPerfect;

  /// No description provided for @learnResultGood.
  ///
  /// In en, this message translates to:
  /// **'Nicely done'**
  String get learnResultGood;

  /// No description provided for @learnResultKeepGoing.
  ///
  /// In en, this message translates to:
  /// **'Keep going'**
  String get learnResultKeepGoing;

  /// No description provided for @learnPlayAgain.
  ///
  /// In en, this message translates to:
  /// **'Play again'**
  String get learnPlayAgain;

  /// No description provided for @learnBackToLearn.
  ///
  /// In en, this message translates to:
  /// **'Back to Learn'**
  String get learnBackToLearn;

  /// No description provided for @learnEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No questions yet'**
  String get learnEmptyTitle;

  /// No description provided for @learnEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'More published words are needed before a round can be built.'**
  String get learnEmptyBody;

  /// No description provided for @learnErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load a round'**
  String get learnErrorTitle;

  /// No description provided for @learnLoading.
  ///
  /// In en, this message translates to:
  /// **'Preparing your round...'**
  String get learnLoading;

  /// No description provided for @learnStreakDays.
  ///
  /// In en, this message translates to:
  /// **'{count}-day streak'**
  String learnStreakDays(int count);

  /// No description provided for @learnBestStreak.
  ///
  /// In en, this message translates to:
  /// **'Best: {count} days'**
  String learnBestStreak(int count);

  /// No description provided for @learnQuestionCount.
  ///
  /// In en, this message translates to:
  /// **'{count} questions'**
  String learnQuestionCount(int count);

  /// No description provided for @learnProgressOf.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String learnProgressOf(int current, int total);

  /// No description provided for @learnScore.
  ///
  /// In en, this message translates to:
  /// **'{correct} of {total} correct'**
  String learnScore(int correct, int total);

  /// No description provided for @learnAccuracy.
  ///
  /// In en, this message translates to:
  /// **'{percent}% accurate overall'**
  String learnAccuracy(int percent);

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @languageSwahili.
  ///
  /// In en, this message translates to:
  /// **'Kiswahili'**
  String get languageSwahili;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow device'**
  String get languageSystem;

  /// No description provided for @learnWordFindTitle.
  ///
  /// In en, this message translates to:
  /// **'Word Hunt'**
  String get learnWordFindTitle;

  /// No description provided for @learnWordFindCardBody.
  ///
  /// In en, this message translates to:
  /// **'Find the hidden words, then learn what they mean.'**
  String get learnWordFindCardBody;

  /// No description provided for @learnWordFindHint.
  ///
  /// In en, this message translates to:
  /// **'Drag from the first letter to the last.'**
  String get learnWordFindHint;

  /// No description provided for @learnWordFindFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Words you have found'**
  String get learnWordFindFoundTitle;

  /// No description provided for @learnWordFindEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing found yet. Meanings will appear here.'**
  String get learnWordFindEmpty;

  /// No description provided for @learnWordFindDone.
  ///
  /// In en, this message translates to:
  /// **'You found them all. Well done!'**
  String get learnWordFindDone;

  /// No description provided for @learnWordFindNew.
  ///
  /// In en, this message translates to:
  /// **'New puzzle'**
  String get learnWordFindNew;

  /// No description provided for @learnWordBuildTitle.
  ///
  /// In en, this message translates to:
  /// **'Build a Word'**
  String get learnWordBuildTitle;

  /// No description provided for @learnWordBuildCardBody.
  ///
  /// In en, this message translates to:
  /// **'Join eight letters into words, and learn what they mean.'**
  String get learnWordBuildCardBody;

  /// No description provided for @learnWordBuildHint.
  ///
  /// In en, this message translates to:
  /// **'Drag across the letters to build a word'**
  String get learnWordBuildHint;

  /// No description provided for @learnWordBuildEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get learnWordBuildEasy;

  /// No description provided for @learnWordBuildHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get learnWordBuildHard;

  /// No description provided for @learnWordBuildEasyHint.
  ///
  /// In en, this message translates to:
  /// **'Meanings are shown from the start as clues.'**
  String get learnWordBuildEasyHint;

  /// No description provided for @learnWordBuildHardHint.
  ///
  /// In en, this message translates to:
  /// **'A meaning appears once you build its word.'**
  String get learnWordBuildHardHint;

  /// No description provided for @learnWordBuildShuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle letters'**
  String get learnWordBuildShuffle;

  /// No description provided for @learnWordBuildNew.
  ///
  /// In en, this message translates to:
  /// **'New puzzle'**
  String get learnWordBuildNew;

  /// No description provided for @learnWordBuildDone.
  ///
  /// In en, this message translates to:
  /// **'All done!'**
  String get learnWordBuildDone;

  /// No description provided for @learnGamesOfflineReady.
  ///
  /// In en, this message translates to:
  /// **'{count} rounds ready offline'**
  String learnGamesOfflineReady(int count);

  /// No description provided for @learnGamesOfflineNone.
  ///
  /// In en, this message translates to:
  /// **'No rounds saved yet'**
  String get learnGamesOfflineNone;

  /// No description provided for @learnGameTimeUp.
  ///
  /// In en, this message translates to:
  /// **'Time is up!'**
  String get learnGameTimeUp;

  /// No description provided for @learnGameMissed.
  ///
  /// In en, this message translates to:
  /// **'Words you missed'**
  String get learnGameMissed;

  /// No description provided for @learnGameTimed.
  ///
  /// In en, this message translates to:
  /// **'Timed'**
  String get learnGameTimed;

  /// No description provided for @learnGameTimedOn.
  ///
  /// In en, this message translates to:
  /// **'A clock runs while you play.'**
  String get learnGameTimedOn;

  /// No description provided for @learnGameTimedOff.
  ///
  /// In en, this message translates to:
  /// **'Play without a clock.'**
  String get learnGameTimedOff;

  /// No description provided for @learnCrosswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Crossword'**
  String get learnCrosswordTitle;

  /// No description provided for @learnCrosswordCardBody.
  ///
  /// In en, this message translates to:
  /// **'Fill interlocking words from their meanings.'**
  String get learnCrosswordCardBody;

  /// No description provided for @learnCrosswordHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a square, then type a letter.'**
  String get learnCrosswordHint;

  /// No description provided for @learnCrosswordAcross.
  ///
  /// In en, this message translates to:
  /// **'Across'**
  String get learnCrosswordAcross;

  /// No description provided for @learnCrosswordDown.
  ///
  /// In en, this message translates to:
  /// **'Down'**
  String get learnCrosswordDown;

  /// No description provided for @learnCrosswordDone.
  ///
  /// In en, this message translates to:
  /// **'The whole grid is filled!'**
  String get learnCrosswordDone;

  /// No description provided for @learnGameScore.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get learnGameScore;

  /// No description provided for @learnGameBest.
  ///
  /// In en, this message translates to:
  /// **'Best {score}'**
  String learnGameBest(int score);

  /// No description provided for @learnGameNewBest.
  ///
  /// In en, this message translates to:
  /// **'New best: {score} points!'**
  String learnGameNewBest(int score);

  /// No description provided for @learnHint.
  ///
  /// In en, this message translates to:
  /// **'Hint'**
  String get learnHint;

  /// No description provided for @learnHintNone.
  ///
  /// In en, this message translates to:
  /// **'No hints left'**
  String get learnHintNone;

  /// No description provided for @learnHintUsed.
  ///
  /// In en, this message translates to:
  /// **'Hint used'**
  String get learnHintUsed;

  /// No description provided for @learnGamesHeading.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get learnGamesHeading;

  /// No description provided for @learnGamesSubheading.
  ///
  /// In en, this message translates to:
  /// **'Learn words by playing.'**
  String get learnGamesSubheading;

  /// No description provided for @learnDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Well done!'**
  String get learnDoneTitle;

  /// No description provided for @learnDonePartial.
  ///
  /// In en, this message translates to:
  /// **'Time is up'**
  String get learnDonePartial;

  /// No description provided for @learnDoneScore.
  ///
  /// In en, this message translates to:
  /// **'Your score'**
  String get learnDoneScore;

  /// No description provided for @learnDoneBest.
  ///
  /// In en, this message translates to:
  /// **'Your best: {score}'**
  String learnDoneBest(int score);

  /// No description provided for @learnDoneNewBest.
  ///
  /// In en, this message translates to:
  /// **'New best!'**
  String get learnDoneNewBest;

  /// No description provided for @learnDoneFound.
  ///
  /// In en, this message translates to:
  /// **'You found {found} of {total}'**
  String learnDoneFound(int found, int total);

  /// No description provided for @learnDoneAgain.
  ///
  /// In en, this message translates to:
  /// **'Play again'**
  String get learnDoneAgain;

  /// No description provided for @learnDoneClose.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get learnDoneClose;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get settingsServerTitle;

  /// No description provided for @settingsServerBody.
  ///
  /// In en, this message translates to:
  /// **'Where the app looks for its data. Change this if your computer\'s address has moved.'**
  String get settingsServerBody;

  /// No description provided for @settingsServerLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get settingsServerLabel;

  /// No description provided for @settingsServerHint.
  ///
  /// In en, this message translates to:
  /// **'192.168.1.5:8000'**
  String get settingsServerHint;

  /// No description provided for @settingsServerInvalid.
  ///
  /// In en, this message translates to:
  /// **'That address cannot be read.'**
  String get settingsServerInvalid;

  /// No description provided for @settingsTest.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get settingsTest;

  /// No description provided for @settingsTesting.
  ///
  /// In en, this message translates to:
  /// **'Testing…'**
  String get settingsTesting;

  /// No description provided for @settingsTestOk.
  ///
  /// In en, this message translates to:
  /// **'Connected!'**
  String get settingsTestOk;

  /// No description provided for @settingsTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not connect.'**
  String get settingsTestFailed;

  /// No description provided for @settingsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get settingsSave;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get settingsSaved;

  /// No description provided for @settingsReset.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get settingsReset;

  /// No description provided for @settingsDefaultIs.
  ///
  /// In en, this message translates to:
  /// **'Default: {url}'**
  String settingsDefaultIs(String url);

  /// No description provided for @settingsOpen.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsOpen;

  /// No description provided for @settingsSound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get settingsSound;

  /// No description provided for @settingsSoundBody.
  ///
  /// In en, this message translates to:
  /// **'A light ping when a word lands.'**
  String get settingsSoundBody;

  /// No description provided for @settingsHaptics.
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get settingsHaptics;

  /// No description provided for @settingsHapticsBody.
  ///
  /// In en, this message translates to:
  /// **'A light buzz while drawing a word.'**
  String get settingsHapticsBody;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get settingsDone;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'sw'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'sw':
      return AppLocalizationsSw();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
