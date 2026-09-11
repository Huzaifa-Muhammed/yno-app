// Joining a match from the website's /join page.
//
// ⚠️ This is a port of `MatchRepository.guestJoin` AND `MatchRepository.joinMatch`
// in the Flutter app. All three write the SAME documents into the SAME shapes,
// and they must stay that way — a field renamed here and not there produces a
// player the app can read but not display, or a roster count that disagrees
// with the lobby.
//
// It lives on the server, not in the browser, for four reasons:
//
//   1. The host's "new player joined" bell entry is written under
//      `users/{adminUid}/notifications`, which security rules gate on
//      `signedIn()`. A web guest is not signed in, so a browser-side join simply
//      cannot notify anyone — the host would only find out by staring at the
//      lobby.
//   2. Creating an account needs admin credentials. Those can never live in a
//      page anyone can view-source.
//   3. Match state is validated here (does it exist, has it ended, has it
//      started) rather than trusted from a page anyone can edit.
//   4. One implementation instead of a second copy of the join logic in
//      JavaScript.
//
// ---------------------------------------------------------------------------
// Identity — the part that is NOT in the app
// ---------------------------------------------------------------------------
//
// The visitor gives a name and an email, and the email decides who joins:
//
//   * an account already exists for it -> they join as THEMSELVES, keyed by
//     their real uid, under their PROFILE name and position, so the match
//     counts towards their stats and the lobby shows who they really are;
//   * no account exists                -> one is created behind the scenes
//     (`autoCreated: true`, password `123456`) and they join with it, exactly as
//     `addNewPlayer` does when a host adds someone by email in the app. They can
//     claim it later through the OTP flow.
//
// ---------------------------------------------------------------------------
// 🔑 `isGuest` mirrors `autoCreated` — a stub profile IS a guest
// ---------------------------------------------------------------------------
//
// This is the app's own rule, lifted from `addTeamRoster`
// (`match_repository.dart:595`): `isGuest: u?.autoCreated ?? false`. Somebody a
// host created by email has a real uid but no position, no photo and no
// history — so the app already treats them as a guest until that data arrives,
// and the web must not disagree.
//
//   auto-created just now, or host-created and never claimed -> isGuest TRUE
//   a real account someone completed                         -> isGuest FALSE
//
// It resolves itself: `autoCreated` is cleared when the owner claims the
// account and sets a password, so their NEXT match joins as a real player.
//
// ⚠️ `isGuest` and "has a real uid" are two different things, and conflating
// them is the trap here. `playerUids` tracks the SECOND one — the app puts
// auto-created team members in it while still flagging them guests. So anyone
// with a real uid goes in `playerUids`; only the accountless `g_…` path stays
// out. The `accountless` flag below is what carries that distinction.
//
// The accountless `g_…` path from the first version survives for a caller that
// sends no email at all. The website always sends one.

import { createAuthAccount, profileWrite } from './account.js';
import { randomCode } from './codes.js';
import {
  appendToArray,
  commit,
  docPath,
  findMatchByCode,
  findUserByEmail,
  getDoc,
  incrementBy,
  serverTime,
  stringArray,
  v,
} from './firestore.js';
import { customToken } from './google.js';
import { isEmail } from './otp.js';

/** `TeamSideX.id` — UPPERCASE 'A' / 'B'. Getting this wrong puts every guest on Team A. */
const sideId = (side) => (side === 'b' ? 'B' : 'A');

const bad = (error, status, message) =>
    ({ status, body: { ok: false, error, message } });

/**
 * The app's guest rule, in one place: `isGuest: u?.autoCreated ?? false` from
 * `addTeamRoster`. A profile nobody has filled in yet is a guest, however real
 * its uid is.
 *
 * Exported so it can be unit-tested — it is one comparison, but it is the one
 * that decides whether a player earns career stats.
 */
export const isGuestProfile = (user) => !!user && user.autoCreated === true;

/**
 * Decide who is joining, and under what identity.
 *
 * @returns {Promise<{uid: string, accountless: boolean, isGuest: boolean,
 *                    isNewAccount: boolean, displayName: string,
 *                    position: string|null, profile: object|null}>}
 */
async function resolveJoiner(env, name, email) {
  if (!email) {
    // No email: the original accountless guest. A `g_` id, no auth account, and
    // a `guests` record so the person can still be claimed later.
    return {
      uid: `g_${randomCode(10)}`,
      accountless: true,
      isGuest: true,
      isNewAccount: false,
      displayName: name,
      position: null,
      profile: null,
    };
  }

  const existing = await findUserByEmail(env, email);
  if (existing) {
    return {
      uid: existing.uid,
      accountless: false,
      isGuest: isGuestProfile(existing),
      isNewAccount: false,
      // Their PROFILE name and position win over whatever was typed into the
      // web form. This is what the in-app code join does — `match_actions.dart`
      // passes `me?.name` and `me?.position`, never a typed value — and it is
      // why a returning player shows up in the lobby as themselves. Falls back
      // to the typed name only if the profile has none.
      displayName: (existing.name || '').trim() || name,
      position: existing.position || null,
      profile: null,
    };
  }

  // No profile document. Creating the auth account may still report that the
  // login exists — a sign-up that died between creating the credential and
  // writing the profile leaves exactly that. Writing the profile then is a
  // repair rather than an overwrite: we only reach here when findUserByEmail
  // found nothing, so there is no document to lose.
  const account = await createAuthAccount(env, email, name);
  return {
    uid: account.uid,
    accountless: false,
    // A profile written a millisecond ago has autoCreated: true by definition,
    // so this is the same rule as the branch above, not a special case.
    isGuest: true,
    isNewAccount: account.created,
    displayName: name,
    position: null,
    profile: profileWrite(env, account.uid, { name, email }),
  };
}

/** Default join bonus — must equal `RewardsConfig.joinMatchPoints` in the app. */
export const DEFAULT_JOIN_POINTS = 50;

/**
 * The join-coin credit for a web joiner, or `null` when nobody qualifies.
 *
 * The app awards these in `MatchRepository._awardMatchCoins`, and a visitor who
 * arrives through the website has joined exactly the same match — so skipping
 * it here would make the reward depend on which door you came through.
 *
 * Three things have to match the app's behaviour:
 *
 *  * **The amount is not compiled in.** It comes from `config/rewards`, the
 *    document the super-admin panel edits, so changing it changes both clients
 *    at once. A missing document or a failed read falls back to
 *    [DEFAULT_JOIN_POINTS] rather than paying nothing, and 0 means the award
 *    has been switched off.
 *  * **Once per match per person**, tracked in `awardedCoinUids` on the match.
 *    The caller's “already in the roster” check does not cover this: leaving a
 *    lobby deletes the player document, so a rejoin looks brand new.
 *  * **Accountless `g_…` guests get nothing** — there is no profile to credit.
 *
 * ⚠️ Returns bare field TRANSFORMS, not writes, and that is deliberate.
 * `:commit` allows one write per document per request, and both documents these
 * touch are already being written by the join: `users/{uid}` by the profile
 * write when the account is new, `matches/{id}` by the `playerUids` append. The
 * caller folds them into those writes — see [duplicateWriteDocument].
 */
export async function joinCoinWrites(env, matchId, uid, { accountless }) {
  if (accountless || !uid) return null;
  let points = DEFAULT_JOIN_POINTS;
  try {
    const cfg = await getDoc(env, 'config', 'rewards');
    const raw = cfg?.fields?.joinMatchPoints?.integerValue;
    if (raw !== undefined) {
      const n = Number(raw);
      if (Number.isFinite(n) && n >= 0) points = n;
    }
  } catch (err) {
    console.error('guest join: rewards config read failed', err);
  }
  if (points <= 0) return null;
  try {
    const matchDoc = await getDoc(env, 'matches', matchId);
    if (stringArray(matchDoc, 'awardedCoinUids').includes(uid)) return null;
  } catch (err) {
    // Do not guess when the guard cannot be read — paying twice is worse than
    // not paying, and the app will not top it up later either way.
    console.error('guest join: awardedCoinUids read failed', err);
    return null;
  }
  return {
    points,
    userTransform: incrementBy('points', points),
    matchTransform: appendToArray('awardedCoinUids', v.str(uid)),
  };
}
/**
 * Add someone to a match from the website.
 *
 * @returns {{status: number, body: object}}
 */
export async function guestJoin(env, { code, name, email, phone }) {
  const cleanName = String(name || '').trim();
  const cleanEmail = String(email || '').trim();
  const cleanPhone = String(phone || '').trim();

  if (cleanName.length < 2 || cleanName.length > 60) {
    return bad('invalid_name', 400, 'Enter your name.');
  }
  if (cleanEmail && !isEmail(cleanEmail)) {
    return bad('invalid_email', 400, 'Enter a valid email address.');
  }

  const match = await findMatchByCode(env, code);
  if (!match) {
    return bad('no_match', 404, 'No match found for that code.');
  }

  const status = match.status || 'lobby';
  if (status === 'ended' || status === 'abandoned') {
    return bad('match_over', 409, 'That match is already over.');
  }

  // Side B only when the code IS codeB — exactly what the app derives, and what
  // the join page has already promised the visitor on screen.
  const wanted = String(code || '').trim().toUpperCase();
  const side = match.codeB === wanted ? 'b' : 'a';

  // Live matches queue for the host's approval instead of joining outright;
  // pre-match joins go straight onto the roster. Same branch as guestJoin's
  // `midGame` flag.
  const live = status === 'live';

  const joiner = await resolveJoiner(env, cleanName, cleanEmail);
  const { uid, accountless, isGuest, isNewAccount, displayName, position } = joiner;
  const teamName =
      (side === 'b' ? match.teamBName : match.teamAName) ||
      (side === 'b' ? 'Team B' : 'Team A');

  const done = (extra) => ({
    status: 200,
    body: {
      ok: true,
      uid,
      guestId: uid, // the field the first version returned; kept for callers.
      matchId: match.id,
      name: displayName,
      isGuest,
      isNewAccount,
      pending: live,
      team: sideId(side),
      teamName: (side === 'b' ? match.teamBName : match.teamAName) || null,
      ...extra,
    },
  });

  // Already in? A `g_` id was always fresh, so the first version could not
  // collide. A real uid can, and joining twice would rewrite the player
  // document — resetting goals and assists to zero, possibly mid-match.
  if (!accountless) {
    const already =
        await getDoc(env, `matches/${match.id}/${live ? 'pending' : 'players'}`, uid);
    if (already) return done({ already: true });
  }

  const writes = [];
  let coins = null;
  if (joiner.profile) writes.push(joiner.profile);

  if (accountless) {
    const guestDoc = {
      name: v.str(displayName),
      matchId: v.str(match.id),
      claimed: v.bool(false),
    };
    guestDoc.email = cleanEmail ? v.str(cleanEmail) : v.nul();
    guestDoc.phone = cleanPhone ? v.str(cleanPhone) : v.nul();
    writes.push({
      update: { name: docPath(env, `guests/${uid}`), fields: guestDoc },
      updateTransforms: [serverTime('at')],
    });
  }

  if (live) {
    // PendingPlayer.toMap()
    writes.push({
      update: {
        name: docPath(env, `matches/${match.id}/pending/${uid}`),
        fields: {
          name: v.str(displayName),
          team: v.str(sideId(side)),
          isGuest: v.bool(isGuest),
          midGame: v.bool(true),
        },
      },
      updateTransforms: [serverTime('at')],
    });
  } else {
    // MatchPlayer.toMap() — every field, including the ones left at defaults,
    // so a document written here is indistinguishable from one written by the app.
    writes.push({
      update: {
        name: docPath(env, `matches/${match.id}/players/${uid}`),
        fields: {
          name: v.str(displayName),
          team: v.str(sideId(side)),
          // Carried from the joiner's profile, as the in-app code join does
          // (`match_actions.dart` passes `me?.position`). Null for a brand-new
          // account, which has not picked one yet.
          position: position ? v.str(position) : v.nul(),
          goals: v.int(0),
          assists: v.int(0),
          joinedVia: v.str('link'),
          isAdmin: v.bool(false),
          isGuest: v.bool(isGuest),
          isCaptain: v.bool(false),
        },
      },
      updateTransforms: [serverTime('joinedAt')],
    });
    // ⚠️ Gated on `accountless`, NOT on `isGuest`. `playerUids` is the list of
    // real uids in this match, and the app puts auto-created players in it while
    // still flagging them guests (`addTeamRoster`). Only a `g_…` id stays out —
    // it is not a uid and every query reading this array would choke on it.
    // Join coins, in this same commit so the credit cannot land without the
    // roster entry. Only on this branch: a live match queues the visitor in
    // `pending` instead, and the host's approval runs `approvePending` ->
    // `joinMatch` in the app, which pays them there.
    coins = await joinCoinWrites(env, match.id, uid, { accountless });
    if (coins) {
      if (joiner.profile) {
        // A brand-new account: `users/{uid}` is ALREADY being written by the
        // profile write pushed above, and a second write to it would have the
        // whole commit rejected. Mutating that write (it is the same object
        // sitting in `writes`) is the only way to touch the document twice.
        // `updateTransforms` run after the update, so `points: 0` from
        // `profileFields` becomes the bonus rather than overwriting it.
        joiner.profile.updateTransforms.push(coins.userTransform);
      } else {
        writes.push({
          transform: {
            document: docPath(env, `users/${uid}`),
            fieldTransforms: [coins.userTransform],
          },
        });
      }
    }
    if (!accountless) {
      writes.push({
        transform: {
          document: docPath(env, `matches/${match.id}`),
          // One write per document per commit: `playerUids` and
          // `awardedCoinUids` are two transforms on the SAME match document and
          // have to share one. `coins` is null whenever `accountless` is, so
          // this never adds a stray transform for a `g_…` id.
          fieldTransforms: [
            appendToArray('playerUids', v.str(uid)),
            ...(coins ? [coins.matchTransform] : []),
          ],
        },
      });
    }
  }

  await commit(env, writes);

  // The joiner's own bell entry for the coins. Best-effort and after the
  // commit, like the host's below: the points are already banked, and a failed
  // notification must not look like a failed join.
  if (coins) {
    try {
      await commit(env, [{
        update: {
          name: docPath(env, `users/${uid}/notifications/join-${match.id}`),
          fields: {
            title: v.str('Match joined'),
            body: v.str(`You earned +${coins.points} points for joining a match.`),
            category: v.str('points'),
            route: v.str('/home'),
            arg: v.str(match.id),
            read: v.bool(false),
          },
        },
        updateTransforms: [serverTime('at')],
      }]);
    } catch (err) {
      console.error('guest join: coin notification failed', err);
    }
  }

  // The host's bell entry. Best-effort, exactly as it is in the app: a failure
  // here must not undo a join that already succeeded. Skipped when the joiner IS
  // the host, which joinMatch also does — nobody needs telling they arrived.
  if (match.adminUid && match.adminUid !== uid) {
    try {
      await commit(env, [{
        update: {
          name: docPath(env, `users/${match.adminUid}/notifications/${uid}`),
          fields: {
            title: v.str(live ? 'Player waiting' : 'New player joined'),
            body: v.str(live
                ? `${displayName} is waiting to join (mid-game).`
                : `${displayName} joined "${teamName}".`),
            category: v.str('matchUpdate'),
            route: v.str(live ? '/live' : '/lobby'),
            arg: v.str(match.id),
            read: v.bool(false),
          },
        },
        updateTransforms: [serverTime('at')],
      }]);
    } catch (err) {
      console.error('guest join: host notification failed', err);
    }
  }

  // 🔑 A credential is returned ONLY for an account this request just created.
  //
  // This endpoint is public and accepts any address, so returning a token for an
  // account that already existed would let anyone type a stranger's email and be
  // signed in as them. For an account created a millisecond ago there is nothing
  // to take — it holds this one match, and its password is the well-known
  // `123456` regardless — so the silent sign-in costs nothing and saves the
  // visitor a login.
  if (isNewAccount) {
    try {
      return done({ customToken: await customToken(env, uid, { webJoin: true }) });
    } catch (err) {
      // The join succeeded; not being signed in on the website is cosmetic.
      console.error('guest join: custom token failed', err);
    }
  }
  return done({});
}
