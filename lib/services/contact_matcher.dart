import 'package:flutter_contacts/flutter_contacts.dart';

import 'friend_repository.dart';
import 'models.dart';
import 'user_repository.dart';

/// How a contact lookup ended.
enum ContactLookupStatus {
  ok,

  /// The user refused the OS contacts permission.
  permissionDenied,

  /// Reading the address book threw.
  failed,
}

/// Outcome of [findRegisteredContacts]: a status plus the players matched.
class ContactLookup {
  const ContactLookup(this.status, [this.matches = const []]);

  final ContactLookupStatus status;
  final List<AppUser> matches;

  bool get ok => status == ContactLookupStatus.ok;
}

/// Match the device address book against the registered player base.
///
/// **Contacts are never stored or uploaded** — the numbers are normalised in
/// memory, used for a single `whereIn` lookup, and dropped. Callers get back
/// only players who already have a YNO account.
///
/// Lives here rather than in a screen because both the Community "Contacts"
/// tab and the Friends page need it: they had two copies, one of which was a
/// stub that matched against an empty list and so could only ever find nobody.
Future<ContactLookup> findRegisteredContacts(String uid) async {
  if (uid.isEmpty) return const ContactLookup(ContactLookupStatus.ok);
  try {
    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!granted) {
      return const ContactLookup(ContactLookupStatus.permissionDenied);
    }
    final contacts = await FlutterContacts.getContacts(withProperties: true);
    final candidates = <String>{};
    for (final c in contacts) {
      for (final p in c.phones) {
        candidates.addAll(normalisePhone(p.number));
      }
    }
    final matches =
        await UserRepository.instance.findByPhones(candidates.take(300).toList());
    // De-dupe + drop myself + drop people who are already friends.
    final friendUids = (await FriendRepository.instance.friendUids(uid)).toSet();
    final seen = <String>{};
    final result = <AppUser>[];
    for (final u in matches) {
      if (u.uid == uid || friendUids.contains(u.uid)) continue;
      if (seen.add(u.uid)) result.add(u);
    }
    return ContactLookup(ContactLookupStatus.ok, result);
  } catch (_) {
    return const ContactLookup(ContactLookupStatus.failed);
  }
}

/// Candidate phone strings for a raw contact number, so it can match however
/// the number happened to be stored at sign-up: punctuation stripped, bare
/// digits, `+digits`, and the UAE `0…` → `+971…` form.
///
/// Best-effort by design — numbers are not E.164-normalised at sign-up, so
/// matching casts a slightly wide net rather than missing real friends.
Set<String> normalisePhone(String raw) {
  final trimmed = raw.replaceAll(RegExp(r'[\s\-()]'), '');
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return const {};
  final out = <String>{trimmed, digits, '+$digits'};
  if (digits.startsWith('0')) out.add('+971${digits.substring(1)}');
  if (digits.length >= 9) out.add('+971${digits.substring(digits.length - 9)}');
  return out;
}
