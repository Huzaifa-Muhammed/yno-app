import 'package:cloud_firestore/cloud_firestore.dart';
import 'rewards_config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_options.dart';
import 'codes.dart';
import 'models.dart';
import 'notification_repository.dart';
import 'push_service.dart';

/// Human-friendly message for a [FirebaseAuthException].
String authErrorMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-email':
      return 'That email address looks invalid.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'Wrong email or password.';
    case 'email-already-in-use':
      return 'That email is already registered.';
    case 'weak-password':
      return 'Password should be at least 6 characters.';
    case 'network-request-failed':
      return 'Network error — check your connection.';
    case 'too-many-requests':
      return 'Too many attempts. Try again later.';
    default:
      return e.message ?? 'Something went wrong. Try again.';
  }
}

/// The password every host-created account is given.
///
/// ⚠️ Shared and guessable **by design** — a deliberate product decision
/// (2026-08-18). The email-OTP claim flow (`ClaimAccountScreen`) signs a player
/// in with it silently once they prove the address, and only then offers to set
/// a real one. It is no longer displayed anywhere in the UI, but it remains a
/// valid credential on the normal login screen, so knowing a host-created
/// player's email address is enough to sign in as them. Closing that means
/// switching the claim flow to `signInWithCustomToken` (the OTP service already
/// returns the token) and randomising this value.
const kAutoAccountPassword = '123456';

/// Result of a Google sign-in: the credential + whether the profile is new
/// (new Google users still need the onboarding profile screens).
class GoogleAuthResult {
  const GoogleAuthResult({required this.uid, required this.isNew});
  final String uid;
  final bool isNew;
}

/// Auth + account creation. Wraps [FirebaseAuth] and seeds `users/{uid}`.
class AuthRepository {
  AuthRepository._();
  static final AuthRepository instance = AuthRepository._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  User? get currentUser => _auth.currentUser;
  String? get uid => _auth.currentUser?.uid;
  Stream<User?> get authState => _auth.authStateChanges();

  /// Credit a referral to both parties + notify them. Returns the referrer uid.
  Future<String?> _applyReferral(
      String code, String newUid, String newName) async {
    final c = code.trim().toUpperCase();
    if (c.isEmpty) return null;
    final q = await _users.where('referralCode', isEqualTo: c).limit(1).get();
    if (q.docs.isEmpty || q.docs.first.id == newUid) return null;
    final referrerUid = q.docs.first.id;
    await _users.doc(referrerUid).update({
      'points': FieldValue.increment(RewardsRepository.current.referralPoints),
    });
    await _users.doc(newUid).update({
      'points': FieldValue.increment(RewardsRepository.current.referralPoints),
    });
    final notifs = NotificationRepository.instance;
    await notifs.emit(referrerUid,
        title: 'Referral bonus 🎁',
        body: '$newName joined with your code! +${RewardsRepository.current.referralPoints} points.',
        category: NotifCategory.points);
    await notifs.add(newUid,
        title: 'Welcome bonus 🎁',
        body: 'You earned +${RewardsRepository.current.referralPoints} points for using a referral code.',
        category: NotifCategory.points);
    return referrerUid;
  }

  /// Register a new email/password account. Onboarding is now minimal: name,
  /// email, password (+ optional referral). The @username is auto-generated from
  /// the name if not supplied; everything else (position, foot, photo, …) is
  /// collected later. Preferred foot defaults to Right.
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? username,
    DateTime? dob,
    String? gender,
    String? phone,
    String language = 'English',
    String? photoUrl,
    String? photoPublicId,
    String? referralCode,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = cred.user!.uid;
    final fullName = '${firstName.trim()} ${lastName.trim()}'.trim();

    final uname = (username == null || username.trim().isEmpty)
        ? await _generateUniqueUsername(firstName, lastName, email)
        : username.trim();

    final referrer = await _findReferrer(referralCode ?? '', uid);

    await _users.doc(uid).set(AppUser(
          uid: uid,
          name: fullName,
          firstName: firstName.trim(),
          lastName: lastName.trim(),
          username: uname,
          email: email.trim(),
          phone: phone,
          dob: dob,
          gender: gender,
          language: language,
          preferredFoot: 'Right',
          photoUrl: photoUrl,
          photoPublicId: photoPublicId,
          referralCode: randomCode(6),
          referredBy: referrer,
          tcAcceptedAt: DateTime.now(),
        ).toMap());

    if (referrer != null) {
      await _applyReferral(referralCode ?? '', uid, fullName);
    }

    await cred.user!.updateDisplayName(fullName);
    await PushService.instance.registerCurrentDevice();
    return cred;
  }

  Future<String?> _findReferrer(String code, String newUid) async {
    final c = code.trim().toUpperCase();
    if (c.isEmpty) return null;
    final q = await _users.where('referralCode', isEqualTo: c).limit(1).get();
    if (q.docs.isEmpty || q.docs.first.id == newUid) return null;
    return q.docs.first.id;
  }

  /// Build a unique lowercase @handle from the user's name (falling back to the
  /// email local-part). Appends a short random suffix until one is free.
  Future<String> _generateUniqueUsername(
      String first, String last, String email) async {
    String clean(String s) =>
        s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    var base = clean('$first$last');
    if (base.isEmpty) base = clean(email.split('@').first);
    if (base.isEmpty) base = 'player';
    if (base.length > 15) base = base.substring(0, 15);
    for (var attempt = 0; attempt < 8; attempt++) {
      final candidate =
          attempt == 0 ? base : '$base${randomCode(3).toLowerCase()}';
      final taken = await _users
          .where('usernameLower', isEqualTo: candidate.toLowerCase())
          .limit(1)
          .get();
      if (taken.docs.isEmpty) return candidate;
    }
    return '$base${randomCode(5).toLowerCase()}';
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await PushService.instance.registerCurrentDevice();
    return cred;
  }

  /// Native Google sign-in. Creates a full profile doc if new (auto-generated
  /// @handle, foot defaults Right) and applies an optional referral code, so a
  /// new Google user only still needs to pick a position on Home.
  /// Sign in (or sign up) with Google.
  ///
  /// [forceAccountPicker] decides which Google account you get, and the two
  /// screens want opposite things (client decision, 2026-09-07):
  ///
  /// * **Sign up — `true`.** Always show the chooser. A phone with several
  ///   Google accounts would otherwise silently reuse whichever one was last
  ///   used, and the person creating a *new* YNO account is exactly the person
  ///   most likely to want a different one. This needs `disconnect()`, not
  ///   `signOut()` — see the note at the call below for why signing out alone
  ///   silently failed to bring the chooser back.
  /// * **Log in — `false`.** Reuse the remembered account and get the user
  ///   straight in. [GoogleSignIn.signInSilently] returns it without any UI;
  ///   when there is nothing remembered it returns null and we fall back to the
  ///   normal interactive flow.
  Future<GoogleAuthResult?> signInWithGoogle({
    String? referralCode,
    bool forceAccountPicker = false,
  }) async {
    final google = GoogleSignIn();
    GoogleSignInAccount? googleUser;
    if (forceAccountPicker) {
      // ⚠️ `signOut()` alone is NOT enough on Android, which is why sign-up
      // appeared to ignore this flag. It clears the plugin's cached account,
      // but the app's OAuth grant with Google survives it — so Play Services
      // is still free to hand the same account straight back with no chooser,
      // which is precisely what this flag exists to stop.
      //
      // `disconnect()` revokes that grant, so the next `signIn()` has to ask
      // again (account chooser, then a re-consent). That re-consent is the
      // price of the guarantee; there is no lighter lever in google_sign_in v6,
      // and v7 is a hard API break — see the signing notes.
      //
      // Both calls are best-effort: they throw when nothing is connected or
      // cached, which is the normal first-run case, and neither failure should
      // block a sign-up. `signOut()` still runs after `disconnect()` so the
      // local selection is dropped even if the revoke was the thing that threw.
      try {
        await google.disconnect();
      } catch (_) {/* nothing connected */}
      try {
        await google.signOut();
      } catch (_) {/* nothing cached */}
      googleUser = await google.signIn();
    } else {
      try {
        googleUser = await google.signInSilently();
      } catch (_) {/* no remembered account; ask below */}
      googleUser ??= await google.signIn();
    }
    if (googleUser == null) return null; // cancelled
    final auth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );
    final cred = await _auth.signInWithCredential(credential);
    final uid = cred.user!.uid;
    final doc = await _users.doc(uid).get();
    final isNew = !doc.exists || (doc.data()?['username'] ?? '') == '';
    if (!doc.exists) {
      final name = cred.user!.displayName ?? 'Player';
      final parts = name.split(' ');
      final first = parts.first;
      final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      final email = cred.user!.email ?? '';
      final uname = await _generateUniqueUsername(first, last, email);
      final referrer = await _findReferrer(referralCode ?? '', uid);
      await _users.doc(uid).set(AppUser(
            uid: uid,
            name: name,
            firstName: first,
            lastName: last,
            username: uname,
            email: email,
            preferredFoot: 'Right',
            photoUrl: cred.user!.photoURL,
            referralCode: randomCode(6),
            referredBy: referrer,
            tcAcceptedAt: DateTime.now(),
          ).toMap());
      if (referrer != null) {
        await _applyReferral(referralCode ?? '', uid, name);
      }
    }
    await PushService.instance.registerCurrentDevice();
    return GoogleAuthResult(uid: uid, isNew: isNew);
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {/* not signed in with Google */}
    await _auth.signOut();
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<AppUser> ensureProfile({String? name}) async {
    final user = _auth.currentUser!;
    final ref = _users.doc(user.uid);
    final doc = await ref.get();
    if (doc.exists) return AppUser.fromDoc(doc);
    final created = AppUser(
      uid: user.uid,
      name: name ?? user.displayName ?? user.email?.split('@').first ?? 'Player',
      email: user.email ?? '',
      referralCode: randomCode(6),
    );
    await ref.set(created.toMap());
    return created;
  }

  /// Permanently delete ALL of the current user's data from the backend:
  /// profile doc + subcollections (notifications, playedWith), friendship edges,
  /// follow references held by other users, team memberships (teams they OWN are
  /// deleted, others are left with the user removed), then the Firebase Auth
  /// account itself. Each section is best-effort so a partial failure still wipes
  /// as much as possible. The user ends up signed out.
  Future<void> deleteAllData() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final uid = user.uid;

    Future<void> wipe(Query<Map<String, dynamic>> q) async {
      final snap = await q.get();
      for (final d in snap.docs) {
        await d.reference.delete();
      }
    }

    // Subcollections under the user doc.
    try {
      await wipe(_users.doc(uid).collection('notifications'));
    } catch (_) {}
    try {
      await wipe(_users.doc(uid).collection('playedWith'));
    } catch (_) {}

    // Friendship edges involving the user.
    try {
      await wipe(
          _db.collection('friendships').where('users', arrayContains: uid));
    } catch (_) {}

    // Remove this user from everyone who follows them.
    try {
      final followers =
          await _users.where('following', arrayContains: uid).get();
      for (final d in followers.docs) {
        await d.reference.update({
          'following': FieldValue.arrayRemove([uid]),
          'followersCount': FieldValue.increment(-1),
        });
      }
    } catch (_) {}

    // Teams: delete the ones they own, leave the ones they're only a member of.
    try {
      final teams =
          await _db.collection('teams').where('memberUids', arrayContains: uid).get();
      for (final d in teams.docs) {
        if ((d.data()['ownerUid'] ?? '') == uid) {
          await d.reference.delete();
        } else {
          await d.reference
              .update({'memberUids': FieldValue.arrayRemove([uid])});
        }
      }
    } catch (_) {}

    // The profile document itself.
    try {
      await _users.doc(uid).delete();
    } catch (_) {}

    // Finally the auth account. If it needs a recent login, the data is already
    // gone — just sign out so the session ends cleanly.
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    try {
      await user.delete();
    } catch (_) {
      await _auth.signOut();
    }
  }

  /// Create an account for a player who isn't on the app yet without disturbing
  /// the current admin's session (secondary [FirebaseApp],
  /// password [kAutoAccountPassword]).
  ///
  /// The password is no longer shown to anyone. The player takes the account
  /// over through the email-OTP claim flow (`ClaimAccountScreen`), which signs
  /// them in with it silently and then offers to set their own.
  Future<String> createPlayerAccount({
    required String name,
    required String email,
    String? position,
  }) async {
    FirebaseApp secondary;
    try {
      secondary = Firebase.app('playerCreator');
    } catch (_) {
      secondary = await Firebase.initializeApp(
        name: 'playerCreator',
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondary);
      final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: kAutoAccountPassword,
      );
      final uid = cred.user!.uid;
      await _users.doc(uid).set(AppUser(
            uid: uid,
            name: name.trim(),
            firstName: name.trim().split(' ').first,
            email: email.trim(),
            position: position,
            referralCode: randomCode(6),
            autoCreated: true,
          ).toMap());
      await secondaryAuth.signOut();
      return uid;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        final existing =
            await _users.where('email', isEqualTo: email.trim()).limit(1).get();
        if (existing.docs.isNotEmpty) return existing.docs.first.id;
      }
      rethrow;
    } finally {
      await secondary.delete();
    }
  }
}
