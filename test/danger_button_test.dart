// The destructive-action convention (see kDangerColor in widgets/buttons.dart):
// anything that loses data must render red, never volt-green.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ynoapp/theme/app_colors.dart';
import 'package:ynoapp/widgets/buttons.dart';

Color? _fillOf(WidgetTester tester) {
  final ink = tester.widget<Ink>(find.byType(Ink));
  return (ink.decoration as BoxDecoration).color;
}

Color? _labelColorOf(WidgetTester tester) =>
    tester.widget<Text>(find.byType(Text)).style?.color;

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  group('PrimaryButton danger convention', () {
    testWidgets('a normal button fills with the volt-green primary',
        (tester) async {
      await _pump(tester, PrimaryButton(label: 'Save', onTap: () {}));
      expect(_fillOf(tester), AppColors.primary);
    });

    testWidgets('a danger button fills with the danger colour, not primary',
        (tester) async {
      await _pump(
          tester, PrimaryButton(label: 'Delete', danger: true, onTap: () {}));
      expect(_fillOf(tester), kDangerColor);
      expect(_fillOf(tester), isNot(AppColors.primary));
    });

    testWidgets('danger overrides an explicitly passed colour', (tester) async {
      await _pump(
        tester,
        PrimaryButton(
            label: 'Delete',
            danger: true,
            color: AppColors.primary,
            onTap: () {}),
      );
      expect(_fillOf(tester), kDangerColor);
    });

    testWidgets('a disabled danger button reads as disabled, not red',
        (tester) async {
      await _pump(tester, const PrimaryButton(label: 'Delete', danger: true));
      expect(_fillOf(tester), AppColors.surface3);
    });
  });

  group('SecondaryButton danger convention', () {
    testWidgets('a normal button labels in the default text colour',
        (tester) async {
      await _pump(tester, SecondaryButton(label: 'Cancel', onTap: () {}));
      expect(_labelColorOf(tester), AppColors.txt);
    });

    testWidgets('a danger button labels in the danger colour', (tester) async {
      await _pump(
          tester, SecondaryButton(label: 'Remove', danger: true, onTap: () {}));
      expect(_labelColorOf(tester), kDangerColor);
    });
  });

  test('the danger colour is the semantic loss colour and is not the primary',
      () {
    expect(kDangerColor, AppColors.loss);
    expect(kDangerColor, isNot(AppColors.primary));
  });
}
