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
