// Minimal Firestore REST client — only what the OTP service needs.
// The service account bypasses security rules, which is why `emailOtps` can be
// locked to `allow read, write: if false` and still work.

import { accessToken } from './google.js';

function base(env) {
  const pid = env.FIREBASE_PROJECT_ID;
  if (!pid) throw new Error('FIREBASE_PROJECT_ID is not set');
  return `https://firestore.googleapis.com/v1/projects/${pid}/databases/(default)/documents`;
}

async function call(env, path, init) {
  const token = await accessToken(env);
  const res = await fetch(`${base(env)}${path}`, {
    ...init,
    headers: {
      authorization: `Bearer ${token}`,
      'content-type': 'application/json',
      ...(init && init.headers ? init.headers : {}),
    },
  });
  return res;
}

// ---- value encoding ------------------------------------------------------
export const v = {
  str: (s) => ({ stringValue: s }),
  int: (n) => ({ integerValue: String(n) }),
  bool: (b) => ({ booleanValue: b }),
  // A Dart `null` inside a toMap() is a real stored null, not an absent field.
  // `AppUser.fromDoc` would read a missing key the same way, but a document
  // written here has to be byte-comparable with one written by the app —
  // otherwise "did the website write this correctly?" stops being answerable by
  // diffing two documents.
  nul: () => ({ nullValue: null }),
  arr: (values = []) => ({ arrayValue: { values } }),
  map: (fieldMap = {}) => ({ mapValue: { fields: fieldMap } }),
};

/** Firestore's typed value -> a plain JS value (only the types we store). */
export function plain(value) {
  if (!value) return null;
  if ('stringValue' in value) return value.stringValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('booleanValue' in value) return value.booleanValue;
  if ('doubleValue' in value) return value.doubleValue;
  if ('nullValue' in value) return null;
  return null;
}

/** Flatten a document's `fields` map into a plain object. */
export function fields(doc) {
  const out = {};
  if (!doc || !doc.fields) return out;
  for (const [k, val] of Object.entries(doc.fields)) out[k] = plain(val);
  return out;
}

// ---- documents -----------------------------------------------------------
export async function getDoc(env, collection, id) {
  const res = await call(env, `/${collection}/${encodeURIComponent(id)}`, {
    method: 'GET',
  });
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`firestore get failed: ${res.status} ${await res.text()}`);
  return res.json();
}

/** Full replace (no updateMask) — the OTP doc is always written whole. */
export async function setDoc(env, collection, id, fieldMap) {
  const res = await call(env, `/${collection}/${encodeURIComponent(id)}`, {
    method: 'PATCH',
    body: JSON.stringify({ fields: fieldMap }),
  });
  if (!res.ok) throw new Error(`firestore set failed: ${res.status} ${await res.text()}`);
  return res.json();
}

export async function deleteDoc(env, collection, id) {
  const res = await call(env, `/${collection}/${encodeURIComponent(id)}`, {
    method: 'DELETE',
  });
  if (!res.ok && res.status !== 404) {
    throw new Error(`firestore delete failed: ${res.status} ${await res.text()}`);
  }
}

/**
 * Find a user by email.
 *
 * Case matters here: `createPlayerAccount` stores the email trimmed but NOT
 * lowercased, so an account can exist under either casing. One IN query covers
 * both candidates in a single round trip rather than guessing.
 */
export async function findUserByEmail(env, email) {
  const raw = email.trim();
  const lower = raw.toLowerCase();
  const candidates = raw === lower ? [raw] : [raw, lower];
  const token = await accessToken(env);
  const res = await fetch(`${base(env)}:runQuery`, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${token}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: 'users' }],
        where: {
          fieldFilter: {
            field: { fieldPath: 'email' },
            op: 'IN',
            value: { arrayValue: { values: candidates.map((c) => v.str(c)) } },
          },
        },
        limit: 1,
      },
    }),
  });
  if (!res.ok) {
    throw new Error(`firestore query failed: ${res.status} ${await res.text()}`);
  }
  const rows = await res.json();
  for (const row of rows) {
    if (row.document) {
      const f = fields(row.document);
      const name = row.document.name || '';
      return { uid: name.split('/').pop(), ...f };
    }
  }
  return null;
}

// ---- deletion ------------------------------------------------------------

/**
 * Delete every document in a subcollection, page by page.
 *
 * Firestore has no recursive delete over REST: deleting `users/{uid}` leaves
 * its subcollections behind as orphans that are still readable by anyone who
 * knows the path. For an account deletion that is precisely the data we are
 * meant to be removing, so it has to be walked explicitly.
 *
 * Best-effort by design: a page that fails is logged and skipped rather than
 * aborting the whole deletion half-way through.
 *
 * @returns {Promise<number>} how many documents were removed.
 */
export async function deleteSubcollection(env, parentPath, collectionId) {
  let removed = 0;
  for (let page = 0; page < 20; page++) { // hard stop; 20 x 300 is plenty
    const res = await call(
        env, `/${parentPath}/${collectionId}?pageSize=300`, { method: 'GET' });
    if (res.status === 404) break;
    if (!res.ok) {
      console.error(`list ${parentPath}/${collectionId} failed: ${res.status}`);
      break;
    }
    const body = await res.json();
    const docs = (body && body.documents) || [];
    if (docs.length === 0) break;

    for (const doc of docs) {
      // `doc.name` is the absolute resource path; we need it relative to the
      // documents root that `base()` already covers.
      const rel = String(doc.name).split('/documents/')[1];
      if (!rel) continue;
      const del = await call(env, `/${rel}`, { method: 'DELETE' });
      if (del.ok || del.status === 404) removed++;
      else console.error(`delete ${rel} failed: ${del.status}`);
    }
    if (docs.length < 300) break;
  }
  return removed;
}

// ---- atomic writes -------------------------------------------------------

/**
 * Commit several writes as one transaction.
 *
 * Needed because a guest join is three documents that must land together — the
 * player, the match's `playerUids` array, and the guest record. Written one at a
 * time, a failure half way leaves a player in a match who is in nobody's roster
 * array, or a guest record for a join that never happened.
 *
 * `writes` are raw REST write objects; use [serverTime] and [appendToArray] to
 * build the transforms.
 */
/**
 * The document path written more than once in `writes`, or null.
 *
 * Firestore's `:commit` allows **one write per document per request** and
 * rejects the whole batch otherwise. That is easy to trip the moment a second
 * feature wants a field on a document some other part of the join already
 * touches — `users/{uid}` carries both the profile write and the join-coin
 * increment, `matches/{id}` both `playerUids` and `awardedCoinUids` — and the
 * failure arrives as an opaque 400 with the join already refused. Two
 * transforms on one document belong in ONE write’s `fieldTransforms`; a
 * transform on a document this same commit is creating belongs in that
 * write's `updateTransforms`.
 */
export function duplicateWriteDocument(writes) {
  const seen = new Set();
  for (const w of writes || []) {
    const name = w?.update?.name ?? w?.transform?.document ?? w?.delete;
    if (!name) continue;
    if (seen.has(name)) return name;
    seen.add(name);
  }
  return null;
}

export async function commit(env, writes) {
  // Fail with the offending document name rather than Firestore’s 400, which
  // does not say which one.
  const dupe = duplicateWriteDocument(writes);
  if (dupe) {
    throw new Error(
        `firestore commit builds two writes for ${dupe} — merge them into one`
        + ` write (see duplicateWriteDocument)`);
  }
  const token = await accessToken(env);
  const res = await fetch(`${base(env)}:commit`, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${token}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify({ writes }),
  });
  if (!res.ok) {
    throw new Error(`firestore commit failed: ${res.status} ${await res.text()}`);
  }
  return res.json();
}

/** Absolute document path, as `:commit` requires. */
export function docPath(env, relative) {
  return `projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/${relative}`;
}

/** `FieldValue.serverTimestamp()` for a REST write. */
export const serverTime = (fieldPath) =>
    ({ fieldPath, setToServerValue: 'REQUEST_TIME' });

/** `FieldValue.arrayUnion([value])` for a REST write. */
export const appendToArray = (fieldPath, value) =>
    ({ fieldPath, appendMissingElements: { values: [value] } });

/** `FieldValue.increment(n)` for a REST write. */
export const incrementBy = (fieldPath, n) =>
    ({ fieldPath, increment: v.int(n) });

/**
 * One field of a raw document as a plain array of strings.
 *
 * `fields()` cannot do this: it flattens through `plain()`, which has no
 * `arrayValue` case and hands back null. Everything the worker read until now
 * was a scalar, so that was never felt — `awardedCoinUids` is the first array
 * it has to actually look inside.
 */
export function stringArray(doc, fieldPath) {
  const values = doc?.fields?.[fieldPath]?.arrayValue?.values;
  if (!Array.isArray(values)) return [];
  return values.map((x) => x?.stringValue).filter((x) => typeof x === 'string');
}

/** Resolve a match by join code, mirroring MatchRepository.findByCode. */
export async function findMatchByCode(env, rawCode) {
  const code = String(rawCode || '').trim().toUpperCase();
  if (!code) return null;
  const token = await accessToken(env);
  for (const field of ['code', 'codeA', 'codeB']) {
    const res = await fetch(`${base(env)}:runQuery`, {
      method: 'POST',
      headers: {
        authorization: `Bearer ${token}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        structuredQuery: {
          from: [{ collectionId: 'matches' }],
          where: {
            fieldFilter: {
              field: { fieldPath: field },
              op: 'EQUAL',
              value: v.str(code),
            },
          },
          limit: 1,
        },
      }),
    });
    if (!res.ok) {
      throw new Error(`match lookup failed: ${res.status} ${await res.text()}`);
    }
    const rows = await res.json();
    for (const row of rows) {
      if (row.document) {
        const f = fields(row.document);
        return { id: String(row.document.name).split('/').pop(), ...f };
      }
    }
  }
  return null;
}
