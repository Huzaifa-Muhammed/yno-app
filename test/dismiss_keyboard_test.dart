// The app-wide tap-to-dismiss-the-keyboard wrapper (widgets/common.dart).
//
// 🐛 Regression guard for client point C17. `unfocus()` appeared nowhere in
// `lib/` — a focused field kept the keyboard up until the hardware back button
// was pressed, because nothing in the app ever dropped focus. DismissKeyboard
// is wrapped once around MaterialApp.builder in app.dart; this test is what
// stops it being unwrapped, or downgraded to HitTestBehavior.opaque.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ynoapp/widgets/common.dart';

void main() {
  final fieldFocus = FocusNode();
  tearDownAll(fieldFocus.dispose);

  // Mirrors app.dart: the wrapper sits above the route, not inside a screen.
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) =>
          DismissKeyboard(child: child ?? const SizedBox.shrink()),
      home: Scaffold(
        body: Column(
          children: [
            TextField(focusNode: fieldFocus),
            ElevatedButton(
              onPressed: () {},
              child: const Text('TAP ME'),
            ),
            // The empty space a user actually taps to dismiss.
            const Expanded(child: SizedBox.expand()),
          ],
        ),
      ),
    ));
  }

  testWidgets('a tap on empty space drops focus', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(fieldFocus.hasFocus, isTrue, reason: 'field should focus on tap');

    // The gap below the button — no widget of its own claims this tap, so it
    // reaches the translucent recogniser wrapping the app.
    await tester.tapAt(tester.getCenter(find.byType(SizedBox).last));
    await tester.pump();
    expect(fieldFocus.hasFocus, isFalse,
        reason: 'tapping outside the field must close the keyboard');
  });

  testWidgets('taps still reach the widgets underneath', (tester) async {
    // The failure mode of getting this wrong: HitTestBehavior.opaque swallows
    // every tap in the app, so the dismissal "works" and nothing else does.
    var pressed = false;
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) =>
          DismissKeyboard(child: child ?? const SizedBox.shrink()),
      home: Scaffold(
        body: ElevatedButton(
          onPressed: () => pressed = true,
          child: const Text('TAP ME'),
        ),
      ),
    ));

    await tester.tap(find.text('TAP ME'));
    await tester.pump();
    expect(pressed, isTrue,
        reason: 'the wrapper must not swallow taps meant for the app');
  });
}
