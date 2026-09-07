/// Super-admin web dashboard configuration.
///
/// ⚠️ SECURITY — READ BEFORE SHIPPING:
/// The web build shows a login screen ([_AdminLogin]) that signs in with an
/// email + password. Only the super-admin account below can use the panel. The
/// account is bootstrapped (created) on the first successful login with the
/// configured email + password, so:
///   • KEEP THE WEB BUILD PRIVATE. Never host it at a public URL — the panel can
///     wipe the whole database once signed in.
///   • [kSuperAdminPassword] is the bootstrap password used to CREATE the account
///     on first run. Change it (and the login) to something only you know before
///     any real use — `123456` is a placeholder.
///   • The email in [kSuperAdmins] must also be listed in `isSuperAdmin()` in
///     `firestore.rules` (and the rules deployed) or deletes will be denied.
library;

/// The super-admin account. Must match `isSuperAdmin()` in `firestore.rules`.
const String kSuperAdminEmail = 'huzaifa@admin.com';

/// Bootstrap password for the super-admin account. On first login the account is
/// created with this password; afterwards the entered password must match the
/// account's real password. CHANGE THIS before real use.
const String kSuperAdminPassword = '123456';

/// Emails allowed to use the panel — kept as a list in case more are added.
/// Keep this in sync with the allowlist in `firestore.rules`.
const List<String> kSuperAdmins = [kSuperAdminEmail];
