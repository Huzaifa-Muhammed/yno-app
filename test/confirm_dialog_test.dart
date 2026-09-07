// The shared confirmation (widgets/confirm.dart). The contract that matters:
// it must never return true unless the user actually pressed confirm.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ynoapp/theme/app_colors.dart';
import 'package:ynoapp/widgets/buttons.dart';
import 'package:ynoapp/widgets/confirm.dart';

Future<bool?> _open(WidgetTester tester, {bool danger = false}) async {
  bool? result;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await showConfirm(
              context,
              title: 'Remove player?',
              message: 'Sam will be removed from the lobby.',
              confirmLabel: 'Remove',
              danger: danger,
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('shows the title, message and confirm label', (tester) async {
    await _open(tester);
    expect(find.text('Remove player?'), findsOneWidget);
    expect(find.text('Sam will be removed from the lobby.'), findsOneWidget);
    // PrimaryButton uppercases its label.
    expect(find.text('REMOVE'), findsOneWidget);
  });

  testWidgets('confirming returns true', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showConfirm(context,
                  title: 'T', message: 'M', confirmLabel: 'Yes');
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('YES'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('cancelling returns false', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showConfirm(context,
                  title: 'T', message: 'M', confirmLabel: 'Yes');
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('dismissing by tapping the barrier returns false, not null',
      (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showConfirm(context,
                  title: 'T', message: 'M', confirmLabel: 'Yes');
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // Tap well outside the dialog to dismiss it.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(result, isFalse, reason: 'a dismissed confirm must not read as yes');
  });

  testWidgets('a danger confirm marks its button destructive', (tester) async {
    await _open(tester, danger: true);
    expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).danger,
        isTrue);
  });

  testWidgets('a non-danger confirm keeps the default volt button',
      (tester) async {
    await _open(tester, danger: false);
    expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).danger,
        isFalse);
    expect(kDangerColor, isNot(AppColors.primary));
  });
}
