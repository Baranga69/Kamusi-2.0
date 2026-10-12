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

  @override
  String get navDictionary => 'Dictionary';

  @override
  String get navLearn => 'Learn';

  @override
  String get navFavorites => 'Favourites';

  @override
  String get learnTitle => 'Learn';

  @override
  String get learnDailyTitle => 'Today\'s challenge';

  @override
  String get learnDailyStart => 'Start';

  @override
  String get learnDailyDone => 'Done for today';

  @override
  String get learnDailyAgain => 'Play again';

  @override
  String get learnStreakNone => 'Start your streak';

  @override
  String get learnPracticeTitle => 'Practice';

  @override
  String get learnKindDefinition => 'Word to meaning';

  @override
  String get learnKindMeaning => 'Meaning to word';

  @override
  String get learnKindMethali => 'Proverbs';

  @override
  String get learnKindMixed => 'A bit of everything';

  @override
  String get learnAskDefinition => 'What does this word mean?';

  @override
  String get learnAskMeaning => 'Which word means this?';

  @override
  String get learnAskMethali => 'Complete the proverb';

  @override
  String get learnCorrect => 'Correct';

  @override
  String get learnIncorrect => 'Not quite';

  @override
  String get learnContinue => 'Continue';

  @override
  String get learnFinish => 'Finish';

  @override
  String get learnOpenEntry => 'Read the entry';

  @override
  String get learnResultPerfect => 'Every one right';

  @override
  String get learnResultGood => 'Nicely done';

  @override
  String get learnResultKeepGoing => 'Keep going';

  @override
  String get learnPlayAgain => 'Play again';

  @override
  String get learnBackToLearn => 'Back to Learn';

  @override
  String get learnEmptyTitle => 'No questions yet';

  @override
  String get learnEmptyBody =>
      'More published words are needed before a round can be built.';

  @override
  String get learnErrorTitle => 'Could not load a round';

  @override
  String get learnLoading => 'Preparing your round...';

  @override
  String learnStreakDays(int count) {
    return '$count-day streak';
  }

  @override
  String learnBestStreak(int count) {
    return 'Best: $count days';
  }

  @override
  String learnQuestionCount(int count) {
    return '$count questions';
  }

  @override
  String learnProgressOf(int current, int total) {
    return '$current of $total';
  }

  @override
  String learnScore(int correct, int total) {
    return '$correct of $total correct';
  }

  @override
  String learnAccuracy(int percent) {
    return '$percent% accurate overall';
  }

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageSwahili => 'Kiswahili';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSystem => 'Follow device';

  @override
  String get learnWordFindTitle => 'Word Hunt';

  @override
  String get learnWordFindCardBody =>
      'Find the hidden words, then learn what they mean.';

  @override
  String get learnWordFindHint => 'Drag from the first letter to the last.';

  @override
  String get learnWordFindFoundTitle => 'Words you have found';

  @override
  String get learnWordFindEmpty =>
      'Nothing found yet. Meanings will appear here.';

  @override
  String get learnWordFindDone => 'You found them all. Well done!';

  @override
  String get learnWordFindNew => 'New puzzle';

  @override
  String get learnWordBuildTitle => 'Build a Word';

  @override
  String get learnWordBuildCardBody =>
      'Join eight letters into words, and learn what they mean.';

  @override
  String get learnWordBuildHint => 'Drag across the letters to build a word';

  @override
  String get learnWordBuildEasy => 'Easy';

  @override
  String get learnWordBuildHard => 'Hard';

  @override
  String get learnWordBuildEasyHint =>
      'Meanings are shown from the start as clues.';

  @override
  String get learnWordBuildHardHint =>
      'A meaning appears once you build its word.';

  @override
  String get learnWordBuildShuffle => 'Shuffle letters';

  @override
  String get learnWordBuildNew => 'New puzzle';

  @override
  String get learnWordBuildDone => 'All done!';

  @override
  String learnGamesOfflineReady(int count) {
    return '$count rounds ready offline';
  }

  @override
  String get learnGamesOfflineNone => 'No rounds saved yet';

  @override
  String get learnGameTimeUp => 'Time is up!';

  @override
  String get learnGameMissed => 'Words you missed';

  @override
  String get learnGameTimed => 'Timed';

  @override
  String get learnGameTimedOn => 'A clock runs while you play.';

  @override
  String get learnGameTimedOff => 'Play without a clock.';

  @override
  String get learnCrosswordTitle => 'Crossword';

  @override
  String get learnCrosswordCardBody =>
      'Fill interlocking words from their meanings.';

  @override
  String get learnCrosswordHint => 'Tap a square, then type a letter.';

  @override
  String get learnCrosswordAcross => 'Across';

  @override
  String get learnCrosswordDown => 'Down';

  @override
  String get learnCrosswordDone => 'The whole grid is filled!';

  @override
  String get learnGameScore => 'Score';

  @override
  String learnGameBest(int score) {
    return 'Best $score';
  }

  @override
  String learnGameNewBest(int score) {
    return 'New best: $score points!';
  }

  @override
  String get learnHint => 'Hint';

  @override
  String get learnHintNone => 'No hints left';

  @override
  String get learnHintUsed => 'Hint used';

  @override
  String get learnGamesHeading => 'Games';

  @override
  String get learnGamesSubheading => 'Learn words by playing.';

  @override
  String get learnDoneTitle => 'Well done!';

  @override
  String get learnDonePartial => 'Time is up';

  @override
  String get learnDoneScore => 'Your score';

  @override
  String learnDoneBest(int score) {
    return 'Your best: $score';
  }

  @override
  String get learnDoneNewBest => 'New best!';

  @override
  String learnDoneFound(int found, int total) {
    return 'You found $found of $total';
  }

  @override
  String get learnDoneAgain => 'Play again';

  @override
  String get learnDoneClose => 'Back';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsServerTitle => 'Server address';

  @override
  String get settingsServerBody =>
      'Where the app looks for its data. Change this if your computer\'s address has moved.';

  @override
  String get settingsServerLabel => 'Address';

  @override
  String get settingsServerHint => '192.168.1.5:8000';

  @override
  String get settingsServerInvalid => 'That address cannot be read.';

  @override
  String get settingsTest => 'Test';

  @override
  String get settingsTesting => 'Testing…';

  @override
  String get settingsTestOk => 'Connected!';

  @override
  String get settingsTestFailed => 'Could not connect.';

  @override
  String get settingsSave => 'Save';

  @override
  String get settingsSaved => 'Saved.';

  @override
  String get settingsReset => 'Reset to default';

  @override
  String settingsDefaultIs(String url) {
    return 'Default: $url';
  }

  @override
  String get settingsOpen => 'Settings';
}
