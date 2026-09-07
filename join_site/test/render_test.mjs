// Headless smoke test for join_site/public/index.html.
//
// There is no DOM library available here, so this builds a stub DOM seeded with
// the real ids/attributes parsed out of the page. That makes it a genuine test
// of two things a syntax check cannot catch: every getElementById target really
// exists in the markup, and renderMatch produces the right state for each match
// status without throwing.
import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HTML = fs.readFileSync(path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'public', 'index.html'), 'utf8');
const SCRIPT = HTML.match(/<script>([\s\S]*?)<\/script>/)[1];

const IDS = [...HTML.matchAll(/\sid="([^"]+)"/g)].map((m) => m[1]);
const T_KEYS = [...HTML.matchAll(/data-t="([^"]+)"/g)].map((m) => m[1]);
const PH_KEYS = [...HTML.matchAll(/data-t-ph="([^"]+)"/g)].map((m) => m[1]);

// ---- fixtures ------------------------------------------------------------
const s = (v) => ({ stringValue: v });
const i = (v) => ({ integerValue: String(v) });
const arr = (n) => ({ arrayValue: { values: Array.from({ length: n }, () => s('u')) } });

const MATCHES = {
  LOBBY1: { name: 'matches/m1', fields: { code: s('LOBBY1'), codeA: s('LOBBY1'), codeB: s('SIDEB2'), status: s('lobby'), teamAName: s('Falcons'), teamBName: s('Eagles'), format: s('5v5'), durationMin: i(45), playerUids: arr(6), name: s('Friday Night') } },
  SIDEB2: null, // resolved through the codeB branch of the same doc
  LIVE01: { name: 'matches/m2', fields: { code: s('LIVE01'), status: s('live'), teamAName: s('Falcons'), teamBName: s('Eagles'), format: s('7v7'), scoreA: i(2), scoreB: i(1), playerUids: arr(14) } },
  ENDED1: { name: 'matches/m3', fields: { code: s('ENDED1'), status: s('ended'), teamAName: s('Falcons'), teamBName: s('Eagles'), scoreA: i(3), scoreB: i(3) } },
};

function fakeFetch(url, opts) {
  const body = JSON.parse(opts.body);
  const field = body.structuredQuery.where.fieldFilter.field.fieldPath;
  const code = body.structuredQuery.where.fieldFilter.value.stringValue;
  let doc = null;
  for (const m of Object.values(MATCHES)) {
    if (!m) continue;
    const f = m.fields[field];
    if (f && f.stringValue === code) { doc = m; break; }
  }
  return Promise.resolve({
    ok: true,
    json: () => Promise.resolve(doc ? [{ document: doc }] : [{ readTime: 'x' }]),
  });
}

// ---- stub DOM ------------------------------------------------------------
function makeDom() {
  const byId = new Map();
  const all = [];

  class El {
    constructor(tag, attrs = {}) {
      this.tag = tag; this.attrs = attrs; this._classes = new Set();
      this.textContent = ''; this.children = []; this.placeholder = '';
      this.handlers = {};
      const self = this;
      this.classList = {
        add: (c) => self._classes.add(c),
        remove: (c) => self._classes.delete(c),
        contains: (c) => self._classes.has(c),
      };
    }
    get className() { return [...this._classes].join(' '); }
    set className(v) { this._classes = new Set(String(v).split(/\s+/).filter(Boolean)); }
    set innerHTML(v) { if (v === '') this.children = []; }
    get innerHTML() { return ''; }
    appendChild(c) { this.children.push(c); return c; }
    removeChild(c) { this.children = this.children.filter((x) => x !== c); }
    setAttribute(k, v) { this.attrs[k] = v; }
    getAttribute(k) { return this.attrs[k] ?? null; }
    addEventListener(ev, fn) { this.handlers[ev] = fn; }
    select() {}
    get hidden() { return this._classes.has('hide'); }
  }

  // Seed from the real markup so a typo'd id fails loudly.
  for (const id of IDS) {
    const el = new El('div', {});
    el.attrs.id = id;
    const cls = HTML.match(new RegExp('class="([^"]*)"[^>]*id="' + id + '"')) ||
                HTML.match(new RegExp('id="' + id + '"[^>]*class="([^"]*)"'));
    if (cls) el.className = cls[1];
    const dt = HTML.match(new RegExp('id="' + id + '"[^>]*data-t="([^"]+)"'));
    if (dt) el.attrs['data-t'] = dt[1];
    byId.set(id, el); all.push(el);
  }
  // Elements carrying data-t / data-t-ph without an id still need to exist.
  for (const k of T_KEYS) { const e = new El('span', { 'data-t': k }); all.push(e); }
  for (const k of PH_KEYS) { const e = new El('input', { 'data-t-ph': k }); all.push(e); }

  const document = {
    documentElement: { lang: 'en', dir: 'ltr' },
    title: '',
    body: new El('body'),
    getElementById(id) {
      if (!byId.has(id)) throw new Error('getElementById("' + id + '") -> element not in markup');
      return byId.get(id);
    },
    querySelectorAll(sel) {
      if (sel === '[data-t]') return all.filter((e) => e.attrs['data-t']);
      if (sel === '[data-t-ph]') return all.filter((e) => e.attrs['data-t-ph']);
      return [];
    },
    createElement: (t) => new El(t),
    createTextNode: (t) => ({ textContent: t, isText: true }),
    execCommand: () => true,
  };
  return { document, byId, all, El };
}

function run({ search = '', pathname = '/', lang = null } = {}) {
  const { document, byId, all } = makeDom();
  const store = new Map();
  if (lang !== null) store.set('yno_lang', String(lang));

  const sandbox = {
    document,
    fetch: fakeFetch,
    console,
    setTimeout,
    URLSearchParams,
    navigator: { language: 'en-GB', clipboard: null },
    location: { search, pathname },
    localStorage: {
      getItem: (k) => (store.has(k) ? store.get(k) : null),
      setItem: (k, v) => store.set(k, v),
    },
    window: {},
    history: { replaceState: () => {} },
  };
  sandbox.window = sandbox;
  vm.createContext(sandbox);
  vm.runInContext(SCRIPT, sandbox, { filename: 'index.html<script>' });
  return { document, byId, all };
}

const tick = () => new Promise((r) => setImmediate(r));

// ---- assertions ----------------------------------------------------------
let pass = 0, fail = 0;
function check(label, cond, detail) {
  if (cond) { pass++; console.log('  PASS  ' + label); }
  else { fail++; console.log('  FAIL  ' + label + (detail ? '  -> ' + detail : '')); }
}

console.log('markup: ' + IDS.length + ' ids, ' + T_KEYS.length + ' data-t, ' + PH_KEYS.length + ' data-t-ph\n');

// 1. lobby match via the shared code
{
  const { byId } = run({ search: '?code=LOBBY1' });
  await tick(); await tick(); await tick();
  console.log('lobby match (?code=LOBBY1)');
  check('match section shown', !byId.get('s-match').hidden);
  check('find section hidden', byId.get('s-find').hidden);
  check('loader hidden', byId.get('s-loading').hidden);
  check('status = Lobby open', byId.get('statusText').textContent === 'Lobby open', byId.get('statusText').textContent);
  check('pill styled as lobby', byId.get('statusPill').classList.contains('lobby'));
  check('code shown', byId.get('codeOut').textContent === 'LOBBY1');
  check('match name shown', byId.get('matchName').textContent === 'Friday Night' && !byId.get('matchName').hidden);
  check('teams rendered', byId.get('teamA').textContent === 'Falcons' && byId.get('teamB').textContent === 'Eagles');
  check('vs (not a score) before kickoff', byId.get('vsOrScore').textContent === 'vs');
  check('3 meta chips (format, duration, players)', byId.get('meta').children.length === 3, String(byId.get('meta').children.length));
  const note = byId.get('sideNote');
  check('side note names Team A', !note.hidden && note.children.some((c) => c.textContent === 'Falcons'));
  check('no warning before kickoff', byId.get('warnNote').hidden);
  check('how-to-join shown', !byId.get('howCard').hidden);
}

// 2. side-B code on the same match
{
  const { byId } = run({ search: '?code=SIDEB2' });
  await tick(); await tick(); await tick();
  console.log('\nside-B code (?code=SIDEB2)');
  check('resolved via codeB', byId.get('codeOut').textContent === 'SIDEB2');
  check('side note names Team B', byId.get('sideNote').children.some((c) => c.textContent === 'Eagles'));
}

// 3. live match
{
  const { byId } = run({ search: '?code=LIVE01' });
  await tick(); await tick(); await tick();
  console.log('\nlive match (?code=LIVE01)');
  check('pill styled as live', byId.get('statusPill').classList.contains('live'));
  check('status = LIVE', byId.get('statusText').textContent === 'LIVE');
  check('score shown instead of vs', byId.get('vsOrScore').textContent === '2 - 1');
  check('score styling applied', byId.get('vsOrScore').className === 'score');
  check('approval warning shown', !byId.get('warnNote').hidden && /admin approves/.test(byId.get('warnNote').textContent));
  check('code still offered', !byId.get('codeCard').hidden);
}

// 4. ended match
{
  const { byId } = run({ search: '?code=ENDED1' });
  await tick(); await tick(); await tick();
  console.log('\nended match (?code=ENDED1)');
  check('final score shown', byId.get('vsOrScore').textContent === '3 - 3');
  check('code card hidden', byId.get('codeCard').hidden);
  check('how-to-join hidden', byId.get('howCard').hidden);
  check('side note hidden', byId.get('sideNote').hidden);
  check('over warning shown', !byId.get('warnNote').hidden && /nothing left to join/.test(byId.get('warnNote').textContent));
}

// 5. unknown code
{
  const { byId } = run({ search: '?code=NOPE99' });
  await tick(); await tick(); await tick();
  console.log('\nunknown code (?code=NOPE99)');
  check('falls back to the find form', !byId.get('s-find').hidden && byId.get('s-match').hidden);
  check('error message shown', byId.get('findErr').textContent === 'No match found for that code.', byId.get('findErr').textContent);
  check('code kept in the input for editing', byId.get('codeInput').value === 'NOPE99' || byId.get('codeInput').value === undefined);
}

// 6. bare visit (the referral link target)
{
  const { byId } = run({ search: '', pathname: '/' });
  await tick(); await tick();
  console.log('\nbare visit (referral link)');
  check('landing form shown', !byId.get('s-find').hidden);
  check('no error on a clean visit', byId.get('findErr').hidden);
  check('match section hidden', byId.get('s-match').hidden);
  check('store note visible (no STORE_URL set)', !byId.get('storeNote').hidden);
  check('store button hidden', byId.get('storeLink').hidden);
}

// 7. bare code in the path
{
  const { byId } = run({ search: '', pathname: '/LOBBY1' });
  await tick(); await tick(); await tick();
  console.log('\ncode as a path segment (/LOBBY1)');
  check('resolves like ?code=', byId.get('codeOut').textContent === 'LOBBY1');
}

// 8. Arabic
{
  const { document, byId, all } = run({ search: '?code=LOBBY1', lang: 1 });
  await tick(); await tick(); await tick();
  console.log('\nArabic (localStorage yno_lang=1)');
  check('dir = rtl', document.documentElement.dir === 'rtl');
  check('lang = ar', document.documentElement.lang === 'ar');
  check('title translated', /مباراة/.test(document.title), document.title);
  check('status translated', byId.get('statusText').textContent === 'اللوبي مفتوح', byId.get('statusText').textContent);
  check('toggle offers English', byId.get('langBtn').textContent === 'English');
  const empties = all.filter((e) => e.attrs['data-t'] && !e.textContent);
  check('every data-t string has Arabic copy', empties.length === 0,
        empties.map((e) => e.attrs['data-t']).join(', '));
  const phEmpty = all.filter((e) => e.attrs['data-t-ph'] && !e.placeholder);
  check('every placeholder has Arabic copy', phEmpty.length === 0);
}

console.log('\n' + pass + ' passed, ' + fail + ' failed');
process.exit(fail ? 1 : 0);
