// Verifies the join page's code-resolution path against the live database:
// the REST contract, the three-field fallback, and the side (A/B) derivation.
const PROJECT = 'yno-app-e96f5';
const KEY = 'AIzaSyAC0lgsD_K86fhmpwaZWpEoFE6rVjMLafU';
const ENDPOINT = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents:runQuery?key=${KEY}`;

const val = (f) => !f ? null
  : ('stringValue' in f ? f.stringValue
  : ('arrayValue' in f ? (f.arrayValue.values || []) : null));

async function runQuery(body) {
  const r = await fetch(ENDPOINT, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!r.ok) throw new Error('http ' + r.status);
  return r.json();
}

async function queryByField(field, code) {
  const rows = await runQuery({
    structuredQuery: {
      from: [{ collectionId: 'matches' }],
      where: { fieldFilter: { field: { fieldPath: field }, op: 'EQUAL', value: { stringValue: code } } },
      limit: 1,
    },
  });
  for (const row of rows) if (row.document) return row.document;
  return null;
}

async function findByCode(code) {
  for (const f of ['code', 'codeA', 'codeB']) {
    const d = await queryByField(f, code);
    if (d) return d;
  }
  return null;
}

const mask = (s) => s ? s.slice(0, 2) + '*'.repeat(Math.max(0, s.length - 2)) : s;

const rows = (await runQuery({ structuredQuery: { from: [{ collectionId: 'matches' }], limit: 6 } }))
  .filter((x) => x.document);
console.log('sample matches pulled:', rows.length, '\n');

let pass = 0, fail = 0;
for (const row of rows) {
  const f = row.document.fields;
  const id = row.document.name.split('/').pop();
  for (const [key, label] of [['code', 'shared'], ['codeA', 'sideA'], ['codeB', 'sideB']]) {
    const c = val(f[key]);
    if (!c) continue;
    const found = await findByCode(c);
    const hit = found && found.name.split('/').pop() === id;
    const ff = found ? found.fields : {};
    let side = null;
    if (found) { if (val(ff.codeB) === c) side = 'b'; else if (val(ff.codeA) === c) side = 'a'; }
    // What the page should conclude, derived independently from the source doc.
    const expect = val(f.codeB) === c ? 'b' : (val(f.codeA) === c ? 'a' : null);
    const ok = hit && side === expect;
    ok ? pass++ : fail++;
    console.log(`  ${ok ? 'PASS' : 'FAIL'}  ${label.padEnd(6)} ${mask(c)} -> side ${String(side).padEnd(4)} (expected ${String(expect).padEnd(4)}) status=${val(f.status)}`);
  }
}

const none = await findByCode('ZZZZ99');
console.log(`  ${none === null ? 'PASS' : 'FAIL'}  unknown code -> ${none === null ? 'null' : 'UNEXPECTED HIT'}`);
none === null ? pass++ : fail++;

console.log(`\nresolved ${pass}, failures ${fail}`);
process.exit(fail ? 1 : 0);
