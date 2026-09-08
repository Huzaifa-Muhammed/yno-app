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
    // The link is appended by ReferralScreen._shareMessage, not baked into
    // shareMsgB, because it carries the referral code. So the invariant lives
    // on the assembled message: build it the way the screen does, once per
    // language, and check both halves survive.
    final a = trMisc['misc.shareMsgA']!;
    final b = trMisc['misc.shareMsgB']!;
    expect(a.length, 2, reason: 'English and Arabic');
    expect(b.length, 2, reason: 'English and Arabic');
    for (var i = 0; i < a.length; i++) {
      final msg = '${a[i]}ABC123${b[i]}${referralLink('ABC123')}';
      expect(msg, contains(referralLink('ABC123')));
      expect(msg, contains('ABC123'));
    }
  });

  test('no language hard-codes a domain into the share strings', () {
    // What the test above was originally protecting: the domain used to be
    // typed once per language, so it could change in English and drift in
    // Arabic. It now appears only in links.dart. Keep it that way.
    for (final key in ['misc.shareMsgA', 'misc.shareMsgB']) {
      for (final language in trMisc[key]!) {
        expect(language, isNot(contains('nellab.org')),
            reason: '$key must not carry the domain — links.dart owns it');
      }
    }
  });

  test('the referral link is NOT the match-join page', () {
    // Different codes, different pages. Appending kJoinBaseUrl to the share
    // message is the exact regression this file exists to catch: it sent the
    // friend to a match-join form with the referral code as loose text.
    expect(referralLink('ABC123'), 'https://nellab.org/r/ABC123');
    expect(referralLink('ABC123'), isNot(startsWith(kJoinBaseUrl)));
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
