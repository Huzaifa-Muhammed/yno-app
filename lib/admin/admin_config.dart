/// Super-admin web dashboard configuration.
///
/// ⚠️ SECURITY — READ BEFORE SHIPPING:
/// The web build shows a login screen ([_AdminLogin]) that signs in with an
/// email + password. Only the accounts listed below can use the panel, and the
/// panel can wipe the whole database once signed in.
///
/// 🔑 **No password lives in this file, and none ever should.** This repository
/// is public, so anything written here is published. The super-admin account is
/// created by hand once, in the Firebase console
/// (Authentication → Users → Add user), and the panel only ever *signs in* —
/// it has no account-bootstrapping path. If the login says "wrong email or
/// password" on a fresh project, the account has not been created yet.
///
/// The email in [kSuperAdmins] must also be listed in `isSuperAdmin()` in
/// `firestore.rules` (and the rules deployed) or deletes will be denied.
library;

/// The super-admin account. Must match `isSuperAdmin()` in `firestore.rules`.
///
/// Not a secret: the same address is already in the deployed security rules,
/// which anyone can read. The password is what protects the panel — set a
/// strong one on the account in the Firebase console.
const String kSuperAdminEmail = 'huzaifa@admin.com';

/// Emails allowed to use the panel — kept as a list in case more are added.
/// Keep this in sync with the allowlist in `firestore.rules`.
const List<String> kSuperAdmins = [kSuperAdminEmail];
