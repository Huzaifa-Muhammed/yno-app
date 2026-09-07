// Public web links (lib/links.dart).
//
// The domain used to be typed out at each call site — once in lobby_screen and
// once per language in misc.shareMsgB — so a domain change could update English
// and miss Arabic, shipping a dead link to half the users. It has already moved
// once (from yno.app, which was never ours). These tests fail if that drift
// comes back.
import 'package:flutter_test/flutter_test.dart';
import 'package:ynoapp/l10n/tr_misc.dart';
import 'package:ynoapp/links.dart';

void main() {
  test('joinLink builds a code URL on the shared base', () {
    expect(joinLink('ABC123'), '$kJoinBaseUrl?code=ABC123');
  });

  test('joinLink matches the route the website actually serves', () {
    // The page is a React route at /join reading ?code= — see the website
    // project's src/pages/match-pages/JoinMatchPage.js. A double slash or a
    // missing one both still resolve, but only this exact shape is tested
    // there, so keep the two in step.
    expect(joinLink('ABC123'), 'https://nellab.org/join?code=ABC123');
  });

  test('the referral share text carries the link in BOTH languages', () {
    final msg = trMisc['misc.shareMsgB']!;
    expect(msg.length, 2, reason: 'English and Arabic');
    for (final language in msg) {
      expect(language, contains(kJoinBaseUrl));
    }
  });

  test('no stale yno.app anywhere in the misc strings', () {
    for (final entry in trMisc.entries) {
      for (final language in entry.value) {
        expect(language, isNot(contains('yno.app')),
            reason: '${entry.key} still points at a domain we do not own');
      }
    }
  });
}
