// The sign-up "we already have your data" dialog (screens/signup_screen.dart).
//
// The contract that matters: an **auto-created** account (one a host set up for
// this person) is CLAIMED through the email-OTP flow, and a real account is
// sent to the normal login. Neither ever shows a password.
//
// This dialog used to print the shared default password `123456` on screen for
// auto-created accounts, which made knowing someone's email address enough to
// sign in as them. These tests are what stop that coming back.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ynoapp/screens/signup_screen.dart';

/// Captures the route the dialog pushes and the argument it passes.
class _Spy extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) pushed.add(newRoute);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
}

Future<_Spy> _open(WidgetTester tester, {required bool autoCreated}) async {
  final spy = _Spy();
  await tester.pumpWidget(MaterialApp(
    navigatorObservers: [spy],
    // Stub destinations so both actions have somewhere to go.
    routes: {
      '/login': (_) => const Scaffold(body: Text('login stub')),
      '/claim': (_) => const Scaffold(body: Text('claim stub')),
    },
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showAccountExistsDialog(context,
              email: 'sam@example.com', autoCreated: autoCreated),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  spy.pushed.clear(); // drop the dialog route itself
  return spy;
}

void main() {
  testWidgets('an auto-created account is offered the claim flow, not a password',
      (tester) async {
    await _open(tester, autoCreated: true);
    expect(find.text('We already have your data'), findsOneWidget);
    expect(find.text('Claim my account'), findsOneWidget);
    expect(find.text('Use another email'), findsOneWidget);
    // The old default password must never appear again.
    expect(find.textContaining('123456'), findsNothing);
    expect(find.text('Log in'), findsNothing);
  });

  testWidgets('a real account is sent to login and shows no password',
      (tester) async {
    await _open(tester, autoCreated: false);
    expect(find.text('We already have your data'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Claim my account'), findsNothing);
    expect(find.textContaining('123456'), findsNothing);
  });

  testWidgets('claim navigates to /claim carrying the email as the argument',
      (tester) async {
    final spy = await _open(tester, autoCreated: true);
    await tester.tap(find.text('Claim my account'));
    await tester.pumpAndSettle();

    expect(find.text('claim stub'), findsOneWidget);
    final route = spy.pushed.firstWhere((r) => r.settings.name == '/claim');
    // ClaimAccountScreen reads the email straight off the route argument.
    expect(route.settings.arguments, 'sam@example.com');
  });

  testWidgets('a real account navigates to /login', (tester) async {
    await _open(tester, autoCreated: false);
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.text('login stub'), findsOneWidget);
  });
}
