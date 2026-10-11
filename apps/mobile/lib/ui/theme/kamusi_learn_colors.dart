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
      streak: Color.lerp(streak, other.streak, t)!,
      progressTrack: Color.lerp(progressTrack, other.progressTrack, t)!,
    );
  }
}
