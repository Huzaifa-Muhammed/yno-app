/// Every public web URL the app hands to a user.
///
/// One place on purpose. The domain used to be written out at each call site —
/// once in `lobby_screen` and once per language in `misc.shareMsgB` — so
/// changing it meant finding all three, and missing one shipped a link that
/// silently went nowhere. It has already moved twice (from `yno.app`, which was
/// never ours, and then off the `join.` subdomain).
library;

/// Base URL of the web join page.
///
/// A **path on the main site**, not a subdomain: nellab.org is already served by
/// Firebase Hosting, so `/join` ships with the rest of the site and needs no DNS
/// record, no second custom domain and no certificate wait. The `join.`
/// subdomain this used to point at was dropped for exactly that reason.
///
/// The page is **live** — deployed 2026-08-20 from the website project
/// (`D:\Web\yno`, `src/pages/match-pages/`). Its companion is
/// `https://nellab.org/live`, which the join page navigates to itself; the app
/// never links there directly.
const kJoinBaseUrl = 'https://nellab.org/join';

/// Shareable link that opens the web join page for a match [code].
///
/// No slash before the query: the route is `/join`, and `/join/?code=…` would
/// rely on the router's trailing-slash leniency for no reason.
///
/// ⚠️ **Uncalled since 2026-09-12** — the lobby stopped handing out join links
/// (client request; see `lobby_screen._codeCard`). Left in place deliberately:
/// the page it points at is still live and still serves anyone holding an old
/// link, so restoring the button is one call site, not a URL hunt.
String joinLink(String code) => '$kJoinBaseUrl?code=$code';

/// Base URL of the referral landing page.
///
/// A **separate path from `/join`**, which is deliberate: `/join` joins a
/// *match* by its code, and the two codes are different things. The share
/// message used to append `kJoinBaseUrl` with the referral code sitting beside
/// it as loose text, so a friend who tapped the link landed on the match-join
/// page with nothing filled in, and the code — the entire point of the message
/// — travelled as something they had to read and retype.
const kReferralBaseUrl = 'https://nellab.org/r';

/// Shareable link that carries a referral [code].
///
/// Path segment rather than a query string because this is also the App Link
/// pattern registered in `AndroidManifest.xml` (`/r/*`), and a path is what the
/// Play Store's `referrer` parameter round-trips most cleanly for the
/// not-installed case. See `ReferralLinkService`.
String referralLink(String code) => '$kReferralBaseUrl/$code';

/// Support address shown on the Help screen.
///
/// ⚠️ A real contact route, not decoration — it has to be a mailbox that
/// somebody reads. It was `support@yno.app` until 2026-08-18, on a domain that
/// was never ours, so anyone who wrote to it reached a stranger or a bounce.
const kSupportEmail = 'support@nellab.org';

/// The app's legal documents, hosted on the website.
///
/// These live on the web rather than only inside the app because the app
/// stores require a publicly reachable URL for each one at submission time —
/// a screen buried behind a login does not satisfy that. The About screen and
/// the welcome screen link to the same URLs, so there is one canonical text.
///
/// Deployed from the website project (the nellab.org React app,
/// src/pages/terms-and-policy-pages/).
const kTermsUrl = 'https://nellab.org/app/terms';
const kPrivacyUrl = 'https://nellab.org/app/privacy';
