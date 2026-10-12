import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// The small noises and nudges a game makes.
///
/// Haptics tell you *that* something happened; sound tells you *which*. A
/// board that answers a correct word with the same silence as a wrong one is
/// the difference between a game and a form, and that difference is most of
/// what "fun" means to anyone under about twenty-five.
///
/// Everything here is fire-and-forget and swallows its own failures: audio
/// and vibration are both allowed to be unavailable — a muted phone, a device
/// without a motor, an emulator — and none of that should interrupt play.
class GameFeedback {
  const GameFeedback._();

  // One player, reused. A new one per sound leaks handles on Android and
  // stacks overlapping cues into mush.
  static final AudioPlayer _player = AudioPlayer(playerId: 'kamusi_game')
    ..setReleaseMode(ReleaseMode.stop);

  static Future<void> _play(String file) async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/$file'), volume: 0.7);
    } catch (_) {
      // No audio on this device, or the file is missing in a stripped build.
    }
  }

  static void _buzz(Future<void> Function() haptic) {
    haptic().catchError((_) {});
  }

  /// A letter picked up while dragging. The lightest thing available, because
  /// it fires on every cell of every swipe.
  static void tick() => _buzz(HapticFeedback.selectionClick);

  /// A word found, built or solved.
  static void correct() {
    _buzz(HapticFeedback.mediumImpact);
    _play('correct.wav');
  }

  /// A guess that spells nothing. Gentle on purpose: a wrong answer here is
  /// information, not a failure, and a buzzer would say otherwise.
  static void wrong() {
    _buzz(HapticFeedback.lightImpact);
    _play('wrong.wav');
  }

  /// The whole board finished.
  static void complete() {
    _buzz(HapticFeedback.heavyImpact);
    _play('complete.wav');
  }

  /// A hint spent. Lower than [correct] so it never reads as having solved
  /// something.
  static void hint() {
    _buzz(HapticFeedback.selectionClick);
    _play('hint.wav');
  }
}
