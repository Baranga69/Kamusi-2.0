import 'package:flutter/material.dart';

/// Colour roles that only the Jifunze (learn) surface uses.
///
/// The dictionary is deliberately calm; a learning game needs to say "right"
/// and "wrong" instantly and without reading, which the reading palette has no
/// role for. Rather than reach for raw hex in a widget — which DESIGN_SYSTEM.md
/// rules out — these are named roles on the theme, so the learn surface is
/// still themed rather than improvised, and dark mode is handled in one place.
@immutable
class KamusiLearnColors extends ThemeExtension<KamusiLearnColors> {
  const KamusiLearnColors({
    required this.correct,
    required this.onCorrect,
    required this.correctContainer,
    required this.onCorrectContainer,
    required this.incorrect,
    required this.onIncorrect,
    required this.incorrectContainer,
    required this.onIncorrectContainer,
    required this.gameCard,
    required this.onGameCard,
    required this.gameAccentA,
    required this.gameAccentB,
    required this.gameAccentC,
    required this.streak,
    required this.progressTrack,
  });

  /// Affirmation. Green reads as "right" almost universally, but it is muted
  /// here so a correct answer feels like approval rather than a slot machine.
  final Color correct;
  final Color onCorrect;
  final Color correctContainer;

  /// Text and icons on `correctContainer`. A separate role because
  /// `onCorrect` is white: it belongs on the solid colour, and putting it on
  /// the pale container makes a found word unreadable — which is exactly how
  /// this role came to exist.
  final Color onCorrectContainer;

  /// A wrong answer is information, not a failure, so this is the warm amber
  /// end of things rather than the error red the dictionary reserves for
  /// genuine problems.
  final Color incorrect;
  final Color onIncorrect;
  final Color incorrectContainer;

  /// Text and icons on `incorrectContainer`, for the same reason.
  final Color onIncorrectContainer;

  /// The cards that open a game.
  ///
  /// Their own role because the obvious shortcut — `tertiaryContainer` —
  /// comes out pink: the scheme is seeded from the navy primary and derives
  /// tertiary automatically, with no regard for the rest of this surface.
  /// Teal keeps the games next to the app's secondary colour and clearly
  /// apart from both the lavender daily card and the plain practice tiles.
  final Color gameCard;
  final Color onGameCard;

  /// One accent per game.
  ///
  /// Three identical cards read as a list of settings; three colours read as
  /// a shelf of games, which is what this section is. The card tints itself
  /// from its accent, so adding a fourth game means adding one colour rather
  /// than redesigning anything.
  final Color gameAccentA;
  final Color gameAccentB;
  final Color gameAccentC;

  /// The streak flame. The one place the app is allowed to be a bit bright.
  final Color streak;

  final Color progressTrack;

  static const light = KamusiLearnColors(
    correct: Color(0xFF2E7D62),
    onCorrect: Color(0xFFFFFFFF),
    correctContainer: Color(0xFFDCEFE7),
    onCorrectContainer: Color(0xFF123D2E),
    incorrect: Color(0xFFB4690E),
    onIncorrect: Color(0xFFFFFFFF),
    incorrectContainer: Color(0xFFFBEEDC),
    onIncorrectContainer: Color(0xFF53330A),
    gameCard: Color(0xFFD9EBEA),
    onGameCard: Color(0xFF16403D),
    gameAccentA: Color(0xFF2E8B82),
    gameAccentB: Color(0xFFC8761F),
    gameAccentC: Color(0xFF5A5AC8),
    streak: Color(0xFFE07A3F),
    progressTrack: Color(0xFFE9EBF0),
  );

  static const dark = KamusiLearnColors(
    correct: Color(0xFF6FC3A3),
    onCorrect: Color(0xFF0F141B),
    correctContainer: Color(0xFF1C3A30),
    onCorrectContainer: Color(0xFFCFEBDF),
    incorrect: Color(0xFFE0A860),
    onIncorrect: Color(0xFF0F141B),
    incorrectContainer: Color(0xFF3A2E1C),
    onIncorrectContainer: Color(0xFFF4DEBB),
    gameCard: Color(0xFF17352F),
    onGameCard: Color(0xFFCCE7E3),
    gameAccentA: Color(0xFF6FC3B8),
    gameAccentB: Color(0xFFE6A663),
    gameAccentC: Color(0xFF9A9AF0),
    streak: Color(0xFFF2985C),
    progressTrack: Color(0xFF1F2834),
  );

  /// Never null in this app: `buildKamusiTheme` always registers it.
  static KamusiLearnColors of(BuildContext context) =>
      Theme.of(context).extension<KamusiLearnColors>() ?? light;

  @override
  KamusiLearnColors copyWith({
    Color? correct,
    Color? onCorrect,
    Color? correctContainer,
    Color? onCorrectContainer,
    Color? incorrect,
    Color? onIncorrect,
    Color? incorrectContainer,
    Color? onIncorrectContainer,
    Color? gameCard,
    Color? onGameCard,
    Color? gameAccentA,
    Color? gameAccentB,
    Color? gameAccentC,
    Color? streak,
    Color? progressTrack,
  }) {
    return KamusiLearnColors(
      correct: correct ?? this.correct,
      onCorrect: onCorrect ?? this.onCorrect,
      correctContainer: correctContainer ?? this.correctContainer,
      onCorrectContainer: onCorrectContainer ?? this.onCorrectContainer,
      incorrect: incorrect ?? this.incorrect,
      onIncorrect: onIncorrect ?? this.onIncorrect,
      incorrectContainer: incorrectContainer ?? this.incorrectContainer,
      onIncorrectContainer: onIncorrectContainer ?? this.onIncorrectContainer,
      gameCard: gameCard ?? this.gameCard,
      onGameCard: onGameCard ?? this.onGameCard,
      gameAccentA: gameAccentA ?? this.gameAccentA,
      gameAccentB: gameAccentB ?? this.gameAccentB,
      gameAccentC: gameAccentC ?? this.gameAccentC,
      streak: streak ?? this.streak,
      progressTrack: progressTrack ?? this.progressTrack,
    );
  }

  @override
  KamusiLearnColors lerp(ThemeExtension<KamusiLearnColors>? other, double t) {
    if (other is! KamusiLearnColors) {
      return this;
    }
    return KamusiLearnColors(
      correct: Color.lerp(correct, other.correct, t)!,
      onCorrect: Color.lerp(onCorrect, other.onCorrect, t)!,
      correctContainer: Color.lerp(correctContainer, other.correctContainer, t)!,
      onCorrectContainer:
          Color.lerp(onCorrectContainer, other.onCorrectContainer, t)!,
      incorrect: Color.lerp(incorrect, other.incorrect, t)!,
      onIncorrect: Color.lerp(onIncorrect, other.onIncorrect, t)!,
      incorrectContainer: Color.lerp(incorrectContainer, other.incorrectContainer, t)!,
      onIncorrectContainer:
          Color.lerp(onIncorrectContainer, other.onIncorrectContainer, t)!,
      gameCard: Color.lerp(gameCard, other.gameCard, t)!,
      onGameCard: Color.lerp(onGameCard, other.onGameCard, t)!,
      gameAccentA: Color.lerp(gameAccentA, other.gameAccentA, t)!,
      gameAccentB: Color.lerp(gameAccentB, other.gameAccentB, t)!,
      gameAccentC: Color.lerp(gameAccentC, other.gameAccentC, t)!,
      streak: Color.lerp(streak, other.streak, t)!,
      progressTrack: Color.lerp(progressTrack, other.progressTrack, t)!,
    );
  }
}
