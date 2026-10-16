#!/usr/bin/env node
// Viễn Đông Infinite owner tool. The quest book lives in book.json (in git);
// plain answers live in secrets.json (git-ignored).
//
//   node firebase/infinite/infinite_book.mjs check      validate book + answers
//   node firebase/infinite/infinite_book.mjs hash ID CODE   print code_sha256
//   node firebase/infinite/infinite_book.mjs template   write book into remoteconfig.template.json
//   node firebase/infinite/infinite_book.mjs seed       write answers to Firestore infinite_secrets
//   node firebase/infinite/infinite_book.mjs live       where the LIVE config sends students (read-only)
//   node firebase/infinite/infinite_book.mjs publish [--place LAT,LNG --test]
//        merge the book into LIVE Remote Config (other keys untouched);
//        --place moves every at-school quest to a test spot
//
// Live change: check → seed → publish. Do not `firebase deploy --only
// remoteconfig` blindly: it replaces the whole live config with the template.
import { createHash } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..', '..');
const PROJECT = 'vido-student-beta';
const KINDS = new Set(['checkin', 'link', 'code', 'qr', 'quiz']);
const ID = /^[a-z0-9-]{1,40}$/;

const normalize = (s) => s.trim().toUpperCase().replace(/\s+/g, '');
const hash = (id, code) =>
  createHash('sha256').update(`${id}:${normalize(code)}`, 'utf8').digest('hex');
const readJson = (p) => JSON.parse(readFileSync(p, 'utf8'));

const book = () => readJson(join(here, 'book.json'));
const secrets = () => {
  const p = join(here, 'secrets.json');
  return existsSync(p) ? readJson(p) : null;
};

function builtInCosmeticIds() {
  const dart = readFileSync(join(root, 'lib/features/infinite/quest.dart'), 'utf8');
  const block = dart.split('const builtInCosmetics')[1].split('];')[0];
  return new Set([...block.matchAll(/Cosmetic\('([a-z0-9_]+)'/g)].map((m) => m[1]));
}

function check() {
  const b = book();
  const errors = [];
  const warn = [];
  if (typeof b.school?.lat !== 'number' || typeof b.school?.lng !== 'number') {
    errors.push('school.lat/lng missing');
  }
  const cosmetics = builtInCosmeticIds();
  for (const c of b.cosmetics ?? []) {
    if (!c.id || !c.name || !(c.frame || c.title)) errors.push(`bad cosmetic ${JSON.stringify(c)}`);
    else cosmetics.add(c.id);
  }
  const s = secrets();
  const seen = new Set();
  for (const q of b.quests ?? []) {
    const at = `quest ${q.id ?? '?'}`;
    if (!ID.test(q.id ?? '')) errors.push(`${at}: id must be a-z 0-9 - (max 40)`);
    if (seen.has(q.id)) errors.push(`${at}: duplicate id`);
    seen.add(q.id);
    if (!q.title) errors.push(`${at}: no title`);
    const kind = q.kind ?? 'checkin';
    if (!KINDS.has(kind)) warn.push(`${at}: kind "${kind}" is unknown to current apps (shows "update the app")`);
    if (kind === 'link' && !q.url) errors.push(`${at}: link quest needs url`);
    if (['code', 'qr', 'quiz'].includes(kind) && !q.code_sha256) errors.push(`${at}: needs code_sha256`);
    if (kind === 'quiz' && !(q.choices?.length >= 2)) errors.push(`${at}: quiz needs 2+ choices`);
    if (!q.spot) warn.push(`${at}: no map spot (list only)`);
    else if (!(q.spot.x >= 0 && q.spot.x <= 1 && q.spot.y >= 0 && q.spot.y <= 1)) errors.push(`${at}: spot x/y must be 0–1`);
    for (const r of q.rewards ?? []) if (!cosmetics.has(r)) errors.push(`${at}: unknown reward ${r}`);
    if (q.code_sha256) {
      const secret = s?.[q.id]?.code;
      if (!s) warn.push(`${at}: secrets.json missing, answer not verified`);
      else if (!secret) errors.push(`${at}: no answer in secrets.json`);
      else if (hash(q.id, secret) !== q.code_sha256) errors.push(`${at}: code_sha256 does not match secrets.json`);
      if (kind === 'quiz' && secret && !q.choices.some((c) => normalize(c) === normalize(secret))) {
        errors.push(`${at}: answer is not one of the choices`);
      }
    }
  }
  // The app's built-in copy must equal book.json so offline phones agree.
  const dart = readFileSync(join(root, 'lib/features/infinite/quest.dart'), 'utf8');
  const embedded = JSON.parse(dart.split("const defaultQuestsJson = '''")[1].split("''';")[0]);
  if (JSON.stringify(embedded) !== JSON.stringify(b)) {
    warn.push('book.json differs from the built-in defaultQuestsJson (fine for live changes; sync before an app build)');
  }
  for (const w of warn) console.log(`warn  ${w}`);
  for (const e of errors) console.log(`ERROR ${e}`);
  console.log(errors.length ? `✗ ${errors.length} error(s)` : `✓ book ok: ${b.quests.length} quests`);
  if (errors.length) process.exit(1);
}

function template() {
  check();
  const p = join(root, 'remoteconfig.template.json');
  const t = readJson(p);
  t.parameters.infinite_book_v2 = {
    defaultValue: { value: JSON.stringify(book()) },
    description:
      'Viễn Đông Infinite v2 book (builds after 6.0.6+6). Edit firebase/infinite/book.json, then run infinite_book.mjs template. Old builds read infinite_quests.',
    valueType: 'JSON',
  };
  writeFileSync(p, `${JSON.stringify(t, null, 2)}\n`);
  console.log('✓ remoteconfig.template.json updated');
}

async function accessToken() {
  const cfg = readJson(join(homedir(), '.config/configstore/firebase-tools.json'));
  const t = cfg.tokens ?? {};
  if (t.access_token && t.expires_at > Date.now() + 60_000) return t.access_token;
  // Same public OAuth client the Firebase CLI uses for its own refresh.
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'refresh_token',
      refresh_token: t.refresh_token,
      client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
      client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
    }),
  });
  if (!res.ok) throw new Error(`token refresh failed (${res.status}); run: firebase login --reauth`);
  return (await res.json()).access_token;
}

async function seed() {
  check();
  const s = secrets();
  if (!s) throw new Error('secrets.json missing');
  const token = await accessToken();
  const base = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/infinite_secrets`;
  for (const q of book().quests) {
    const entry = s[q.id];
    if (!entry?.code && !q.from && !q.to) continue;
    const fields = {};
    if (entry?.code) fields.code = { stringValue: normalize(entry.code) };
    // Dates are Vietnam days: open from 00:00 on `from` until 24:00 on `to`.
    if (q.from) fields.from = { timestampValue: new Date(`${q.from}T00:00:00+07:00`).toISOString() };
    if (q.to) fields.to = { timestampValue: new Date(new Date(`${q.to}T00:00:00+07:00`).getTime() + 86_400_000).toISOString() };
    const res = await fetch(`${base}/${q.id}`, {
      method: 'PATCH',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      body: JSON.stringify({ fields }),
    });
    if (!res.ok) throw new Error(`${q.id}: ${res.status} ${await res.text()}`);
    console.log(`✓ secret ${q.id}`);
  }
}

// Metres between two points (haversine).
function metres(a, b) {
  const r = (x) => (x * Math.PI) / 180;
  const h = Math.sin(r(b.lat - a.lat) / 2) ** 2
    + Math.cos(r(a.lat)) * Math.cos(r(b.lat)) * Math.sin(r(b.lng - a.lng) / 2) ** 2;
  return 2 * 6371000 * Math.asin(Math.sqrt(h));
}

// Every point a key sends students to: the school, map and each quest's place.
function pointsOf(value) {
  let v; try { v = JSON.parse(value ?? ''); } catch { return null; }
  const out = [];
  const walk = (o, path) => {
    if (!o || typeof o !== 'object') return;
    if (typeof o.lat === 'number' && typeof o.lng === 'number') out.push({ path, lat: o.lat, lng: o.lng });
    for (const [k, x] of Object.entries(o)) walk(x, path ? `${path}.${k}` : k);
  };
  walk(v, '');
  return out;
}

const SCHOOL_KEYS = ['infinite_book_v2', 'infinite_quests'];
const MAX_FROM_SCHOOL_M = 2000;

// Read-only: where does the LIVE config send students?
async function live({ quiet = false } = {}) {
  const school = book().school;
  const token = await accessToken();
  const res = await fetch(`https://firebaseremoteconfig.googleapis.com/v1/projects/${PROJECT}/remoteConfig`,
    { headers: { authorization: `Bearer ${token}` } });
  if (!res.ok) throw new Error(`read live config: ${res.status}`);
  const cfg = await res.json();
  let bad = 0;
  for (const key of SCHOOL_KEYS) {
    const pts = pointsOf(cfg.parameters?.[key]?.defaultValue?.value);
    if (!pts) { console.log(`- ${key}: missing or not JSON`); continue; }
    for (const p of pts) {
      const d = Math.round(metres(school, p));
      if (d > MAX_FROM_SCHOOL_M) bad += 1;
      if (!quiet || d > MAX_FROM_SCHOOL_M) console.log(`${d > MAX_FROM_SCHOOL_M ? '✗' : '✓'} ${key} ${p.path || '(root)'} ${p.lat},${p.lng} — ${d} m from Viễn Đông`);
    }
  }
  console.log(bad ? `✗ ${bad} point(s) are NOT at Viễn Đông (live version ${cfg.version?.versionNumber})`
    : `✓ every point is at Viễn Đông (live version ${cfg.version?.versionNumber})`);
  return bad;
}

async function publish(args) {
  check();
  const b = book();
  const i = args.indexOf('--place');
  const testPlace = i >= 0;
  if (testPlace) {
    // A test spot sends EVERY student's at-school quest elsewhere (10-16: Melbourne
    // stayed live). Only with an explicit --test, and the verify below will shout.
    if (!args.includes('--test')) throw new Error('--place moves every at-school quest; add --test if this is really a test publish');
    const [lat, lng] = (args[i + 1] ?? '').split(',').map(Number);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) throw new Error('--place LAT,LNG');
    for (const q of b.quests) if (q.at_school !== false) q.place = { lat, lng, radius_m: 150 };
    console.log(`⚠ TEST spot ${lat},${lng} on at-school quests — republish WITHOUT --place before students play`);
  }
  const token = await accessToken();
  const url = `https://firebaseremoteconfig.googleapis.com/v1/projects/${PROJECT}/remoteConfig`;
  const res = await fetch(url, { headers: { authorization: `Bearer ${token}` } });
  if (!res.ok) throw new Error(`read live config: ${res.status}`);
  const etag = res.headers.get('etag');
  const live = await res.json();
  live.parameters ??= {};
  live.parameters.infinite_book_v2 = {
    defaultValue: { value: JSON.stringify(b) },
    description: 'Viễn Đông Infinite v2 book (builds after 6.0.6+6). Source: firebase/infinite/book.json.',
    valueType: 'JSON',
  };
  // Builds up to 6.0.6+6 still read infinite_quests. A normal publish restores it
  // from the template (the school point), so old phones are not left elsewhere.
  if (!testPlace) {
    const tpl = readJson(join(root, 'remoteconfig.template.json'));
    const old = tpl.parameters?.infinite_quests;
    if (!old) throw new Error('remoteconfig.template.json has no infinite_quests');
    live.parameters.infinite_quests = old;
  }
  delete live.version;
  const put = await fetch(url, {
    method: 'PUT',
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json; UTF-8', 'if-match': etag },
    body: JSON.stringify(live),
  });
  if (!put.ok) throw new Error(`publish: ${put.status} ${await put.text()}`);
  const v = (await put.json()).version?.versionNumber;
  console.log(`✓ published Remote Config version ${v} (kept: ${Object.keys(live.parameters).join(', ')})`);
  const bad = await live_check();
  if (bad && !testPlace) process.exitCode = 1;
}

const live_check = () => live({ quiet: true });

const [cmd, ...args] = process.argv.slice(2);
try {
  if (cmd === 'check') check();
  else if (cmd === 'template') template();
  else if (cmd === 'seed') await seed();
  else if (cmd === 'publish') await publish(args);
  else if (cmd === 'live') { if (await live()) process.exitCode = 1; }
  else if (cmd === 'hash') console.log(hash(args[0], args.slice(1).join(' ')));
  else {
    console.log('usage: infinite_book.mjs check | hash ID CODE | template | seed | live | publish [--place LAT,LNG --test]');
    process.exit(2);
  }
} catch (e) {
  console.error(`✗ ${e.message}`);
  process.exit(1);
}
