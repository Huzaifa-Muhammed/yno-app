// The shared language picker (widgets/common.dart).
//
// 🐛 Regression guard. The side drawer used to carry its own copy of this
// sheet whose row `onTap` called only `Navigator.pop()` — it closed and changed
// nothing, so the language switch was dead from the drawer while the identical
// control in Settings worked. Both now call showLanguagePicker; this test is
// what stops a "harmless" local copy coming back.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ynoapp/l10n/l10n.dart';
import 'package:ynoapp/widgets/common.dart';

void main() {
  // Every test starts from English and leaves the locale as it found it —
  // L.locale is global, so a leaked value would bleed into other suites.
  setUp(() => L.setLanguage('en'));
  tearDown(() => L.setLanguage('en'));

  Future<bool?> openAndTap(WidgetTester tester, String label) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async => result = await showLanguagePicker(context),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    if (label.isEmpty) return result; // just opened, tapped nothing
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('tapping العربية actually switches the app to Arabic',
      (tester) async {
    expect(L.isAr, isFalse);
    final changed = await openAndTap(tester, 'العربية');
    expect(L.isAr, isTrue, reason: 'the whole point — the locale must change');
    expect(changed, isTrue, reason: 'callers rebuild on this');
  });

  testWidgets('tapping English switches back', (tester) async {
    L.setLanguage('ar');
    expect(L.isAr, isTrue);
    final changed = await openAndTap(tester, 'English');
    expect(L.isAr, isFalse);
    expect(changed, isTrue);
  });

  testWidgets('re-picking the current language reports no change',
      (tester) async {
    final changed = await openAndTap(tester, 'English');
    expect(L.isAr, isFalse);
    expect(changed, isFalse, reason: 'nothing changed, so nothing to rebuild');
  });

  testWidgets('the sheet offers both languages and marks the active one',
      (tester) async {
    await openAndTap(tester, '');
    expect(find.text('English'), findsOneWidget);
    expect(find.text('العربية'), findsOneWidget);
    // Exactly one check mark, against the language currently in use.
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('dismissing without choosing leaves the language alone',
      (tester) async {
    await openAndTap(tester, '');
    await tester.tapAt(const Offset(10, 10)); // barrier
    await tester.pumpAndSettle();
    expect(L.isAr, isFalse);
  });
}
