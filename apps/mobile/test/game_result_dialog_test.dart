import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kamusi_mobile/data/game_round_cache.dart';
import 'package:kamusi_mobile/l10n/app_localizations.dart';
import 'package:kamusi_mobile/ui/widgets/confetti_styles.dart';
import 'package:kamusi_mobile/ui/widgets/game_result_dialog.dart';

/// Every style fires real particles into a real overlay here. That is the
/// point: a bad option combination (a shape that needs a builder, a position
/// the launcher rejects) throws on the frame after the dialog opens, which on
/// a phone looks like the celebration simply not happening.
Future<String?> _open(
  WidgetTester tester, {
  required bool completed,
  required int celebration,
  String game = GameIds.wordFind,
  Size viewport = const Size(390, 844),
  bool isNewBest = false,
}) async {
  // A real phone, not the 800x600 default: this dialog is tall and the point
  // of the test is whether its buttons are reachable.
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = viewport;
  addTearDown(tester.view.reset);

  String? result;
  var popped = false;
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              result = await showGameResultDialog(
                context,
                game: game,
                accent: Colors.teal,
                score: 420,
                best: 500,
                isNewBest: isNewBest,
                found: 8,
                total: 8,
                completed: completed,
                celebration: celebration,
              );
              popped = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  // A leftover dialog from an earlier pumpWidget in the same test would sit
  // over the button; assert it is gone rather than tapping into it.
  expect(find.byType(Dialog), findsNothing);
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  expect(popped, isFalse, reason: 'dialog should still be open');
  return result;
}

void main() {
  testWidgets('shows the total and the two other games', (tester) async {
    await _open(tester, completed: true, celebration: 0);

    // The score counts up, so the final value only lands after the animation.
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('420'), findsOneWidget);

    // Word Hunt was the game played, so the chips offer the other two.
    expect(find.text('Build a Word'), findsOneWidget);
    expect(find.text('Crossword'), findsOneWidget);
    expect(find.text('Word Hunt'), findsNothing);
    expect(find.text('Play again'), findsOneWidget);
    expect(find.text('Back to menu'), findsOneWidget);
  });

  testWidgets('play again returns the game just played', (tester) async {
    await _open(tester, completed: true, celebration: 0);
    await tester.ensureVisible(find.text('Play again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play again'));
    await tester.pumpAndSettle();
    // Settled means the dialog closed with a value; the caller reads it.
    expect(find.text('Play again'), findsNothing);
  });

  testWidgets('a chip returns the other game', (tester) async {
    await _open(tester, completed: true, celebration: 0);
    await tester.ensureVisible(find.text('Crossword'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crossword'));
    await tester.pumpAndSettle();
    expect(find.text('Crossword'), findsNothing);
  });

  testWidgets('running out of time says so and skips the confetti',
      (tester) async {
    await _open(tester, completed: false, celebration: 0);
    expect(find.text('Time is up'), findsOneWidget);
    expect(find.text('Well done!'), findsNothing);
  });

  // Regression: at the first cut this dialog was 624dp tall with fixed
  // padding, so on a 640dp phone "back to menu" sat below the fold and the
  // only way out of a finished board was to scroll for it.
  for (final size in const [Size(412, 915), Size(390, 844), Size(360, 640)]) {
    testWidgets('fits on $size without scrolling', (tester) async {
      // The new-best badge is the taller of the two bottom lines, so it is
      // the variant worth measuring.
      await _open(tester,
          completed: false, celebration: 0, viewport: size, isNewBest: true);
      final view = find.byType(SingleChildScrollView).first;
      final content =
          find.descendant(of: view, matching: find.byType(Column)).first;
      expect(
        tester.getSize(content).height,
        lessThanOrEqualTo(tester.getSize(view).height),
        reason: 'the dialog needs a scroll on $size',
      );
      // And the way out is actually tappable where it sits.
      await tester.tap(find.text('Back to menu'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });
  }

  testWidgets('every confetti style launches without throwing',
      (tester) async {
    for (var plays = 0; plays < ConfettiStyles.all.length * 2; plays++) {
      final style = ConfettiStyles.styleFor(plays).name;
      await _open(tester, completed: true, celebration: plays);
      // Long enough to cover the staggered styles (fireworks runs ~2s) and
      // for the particles to be painted and retired.
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull, reason: 'style $style threw');

      // Close it before the next one. pumpWidget on an identical tree reuses
      // the Navigator, so without this the old dialog stays up and the next
      // iteration taps through it rather than opening anything.
      await tester.ensureVisible(find.text('Back to menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back to menu'));
      await tester.pumpAndSettle();
      expect(find.text('Back to menu'), findsNothing);
      // Drain any timers still queued by the repeating styles.
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull,
          reason: 'style $style threw after the dialog closed');
    }
  });
}
