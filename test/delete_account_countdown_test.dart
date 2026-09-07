// The 10-second hold on the delete-account warning.
//
// This is a safety mechanism, so it is tested rather than trusted. What matters
// is not that a number ticks — it is that the destructive action CANNOT be
// triggered while it does. A countdown that merely relabels an already-live
// button would look identical on screen and protect nobody.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ynoapp/l10n/l10n.dart';
import 'package:ynoapp/screens/delete_account_screen.dart';
import 'package:ynoapp/widgets/buttons.dart';

void main() {
  setUp(() => L.setLanguage('en'));

  // The screen is a ListView, which only builds what fits. At the default
  // 800x600 test surface the confirm button is below the fold and simply does
  // not exist, so every assertion about it fails for the wrong reason. Give the
  // tests a tall phone instead.
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .views.first;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  /// The confirm button on the warning step, whatever its current label.
  PrimaryButton confirmButton(WidgetTester tester) => tester.widget<PrimaryButton>(
        find.byWidgetPredicate((w) => w is PrimaryButton && w.danger),
      );

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: DeleteAccountScreen()));
    await tester.pump();
  }

  testWidgets('the destructive button is INERT while the countdown runs',
      (tester) async {
    await pumpScreen(tester);

    // t = 0
    expect(confirmButton(tester).onTap, isNull,
        reason: 'a disabled-looking button that still fires protects nobody');

    // Half way through it must still be inert.
    await tester.pump(const Duration(seconds: 5));
    expect(confirmButton(tester).onTap, isNull);

    await tester.pump(const Duration(seconds: 5));
    expect(confirmButton(tester).onTap, isNotNull,
        reason: 'after the hold the user may proceed');
  });

  testWidgets('it counts down visibly, so the wait is explained not mysterious',
      (tester) async {
    await pumpScreen(tester);
    expect(find.textContaining('10'), findsWidgets);

    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('9'), findsWidgets);

    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('6'), findsWidgets);
  });

  testWidgets('the warning states plainly that it cannot be undone',
      (tester) async {
    await pumpScreen(tester);
    expect(find.text(L.t('auth.deleteWarnTitle')), findsOneWidget);
    expect(find.text(L.t('auth.deleteWarnBody')), findsOneWidget);
    // And what is lost, itemised.
    expect(find.text(L.t('auth.deleteLoses1')), findsOneWidget);
    expect(find.text(L.t('auth.deleteLoses2')), findsOneWidget);
    expect(find.text(L.t('auth.deleteLoses3')), findsOneWidget);
  });

  testWidgets('cancel is available immediately — only deletion is delayed',
      (tester) async {
    await pumpScreen(tester);
    final cancel = tester.widget<SecondaryButton>(
      find.byWidgetPredicate(
          (w) => w is SecondaryButton && w.label == L.t('common.cancel')),
    );
    expect(cancel.onTap, isNotNull,
        reason: 'holding someone on a scary screen would be hostile');
  });

  testWidgets('the label becomes the real action once the hold expires',
      (tester) async {
    await pumpScreen(tester);
    expect(confirmButton(tester).label, isNot(L.t('auth.deleteContinue')));

    await tester.pump(const Duration(seconds: 10));
    expect(confirmButton(tester).label, L.t('auth.deleteContinue'));
  });

  testWidgets('Arabic renders the same gate', (tester) async {
    L.setLanguage('ar');
    await pumpScreen(tester);
    expect(find.text(L.t('auth.deleteWarnTitle')), findsOneWidget);
    expect(confirmButton(tester).onTap, isNull);
    await tester.pump(const Duration(seconds: 10));
    expect(confirmButton(tester).onTap, isNotNull);
    L.setLanguage('en');
  });
}
