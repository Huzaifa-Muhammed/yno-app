// The "Account made for you? Claim it" link (widgets/common.dart).
//
// It sits on BOTH the login and sign-up screens and is the only way a player
// whose account a host created can get in — they have no password to type on
// either screen. If this stops routing, those players are locked out.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ynoapp/widgets/common.dart';

class _Spy extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
}

Future<_Spy> _pump(WidgetTester tester, {String? email}) async {
  final spy = _Spy();
  await tester.pumpWidget(MaterialApp(
    navigatorObservers: [spy],
    routes: {'/claim': (_) => const Scaffold(body: Text('claim stub'))},
    home: Scaffold(body: ClaimAccountLink(email: email)),
  ));
  return spy;
}

void main() {
  testWidgets('renders the prompt and the action', (tester) async {
    await _pump(tester);
    // The label is two TextSpans in one RichText, so the finder has to be told
    // to look inside rich text.
    expect(find.textContaining('Account made for you?', findRichText: true),
        findsOneWidget);
    expect(find.textContaining('Claim my account', findRichText: true),
        findsOneWidget);
  });

  testWidgets('carries a typed email through as the route argument',
      (tester) async {
    final spy = await _pump(tester, email: '  Sam@Example.com  ');
    await tester.tap(find.byType(ClaimAccountLink));
    await tester.pumpAndSettle();

    final route = spy.pushed.firstWhere((r) => r.settings.name == '/claim');
    // Trimmed, but NOT lower-cased — createPlayerAccount stores the address as
    // the host typed it, and the server matches both casings.
    expect(route.settings.arguments, 'Sam@Example.com');
  });

  testWidgets('passes null rather than an empty string when nothing is typed',
      (tester) async {
    final spy = await _pump(tester, email: '   ');
    await tester.tap(find.byType(ClaimAccountLink));
    await tester.pumpAndSettle();

    final route = spy.pushed.firstWhere((r) => r.settings.name == '/claim');
    // ClaimAccountScreen only pre-fills when the argument is a String, so an
    // empty one would autofocus a box it had already "filled" with nothing.
    expect(route.settings.arguments, isNull);
  });

  testWidgets('works with no email supplied at all', (tester) async {
    final spy = await _pump(tester);
    await tester.tap(find.byType(ClaimAccountLink));
    await tester.pumpAndSettle();

    expect(find.text('claim stub'), findsOneWidget);
    final route = spy.pushed.firstWhere((r) => r.settings.name == '/claim');
    expect(route.settings.arguments, isNull);
  });
}
