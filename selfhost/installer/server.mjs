import express from 'express';
import { readFile, writeFile, access, stat } from 'node:fs/promises';
import { constants } from 'node:fs';
import { join, normalize, resolve, extname, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

import { testConnection, restoreDatabase } from './lib/restore.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const BASE = resolve(__dirname, '..');
const DB_DIR = join(BASE, 'database');
const WEB_DIR = join(BASE, 'app', 'web');
const ADMIN_DIR = join(BASE, 'app', 'admin');
const STATE_FILE = join(BASE, 'state.json');

const PORT = Number(process.env.PORT) || 3000;

async function loadState() {
  try {
    return JSON.parse(await readFile(STATE_FILE, 'utf8'));
  } catch {
    return { restored: false };
  }
}

async function saveState(state) {
  await writeFile(STATE_FILE, JSON.stringify(state, null, 2));
}

function publicConfig(state) {
  return {
    restored: !!state.restored,
    appUrl: '',
    supabaseUrl: state.supabaseUrl || '',
    supabaseAnonKey: state.supabaseAnonKey || '',
  };
}

function injectConfig(html, config) {
  const payload = JSON.stringify({
    supabaseUrl: config.supabaseUrl || '',
    supabaseAnonKey: config.supabaseAnonKey || '',
  });
  const script =
    `<script>window.KASIRGO_CONFIG=${payload};` +
    `window.__KASIRGO_ADMIN_CONFIG__=${payload};</script>`;
  if (html.includes('</head>')) return html.replace('</head>', `${script}</head>`);
  if (html.includes('<head>')) return html.replace('<head>', `<head>${script}`);
  return script + html;
}

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.ttf': 'font/ttf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
};

async function fileExists(p) {
  try {
    await access(p, constants.F_OK);
    return true;
  } catch {
    return false;
  }
}

async function serveAppFile(res, dir, subPath, config) {
  let rel = (subPath || '').replace(/^\/+/, '');
  if (!rel) rel = 'index.html';
  let abs = normalize(join(dir, rel));

  const inDir = abs === resolve(dir) || abs.startsWith(resolve(dir) + '/');
  if (!inDir) {
    res.status(403).type('text/plain').send('Forbidden');
    return;
  }

  let exists = await fileExists(abs);
  if (exists) {
    const s = await stat(abs).catch(() => null);
    if (s && s.isDirectory()) {
      abs = join(abs, 'index.html');
      exists = await fileExists(abs);
    }
  }

  if (!exists) {
    // SPA fallback (deep-link / navigasi client-side).
    abs = join(dir, 'index.html');
    if (!(await fileExists(abs))) {
      res.status(404).type('text/plain').send('Not found');
      return;
    }
  }

  const ext = extname(abs).toLowerCase();
  if (ext === '.html') {
    let html = await readFile(abs, 'utf8');
    html = injectConfig(html, config);
    res.setHeader('Content-Type', MIME['.html']);
    res.send(html);
    return;
  }

  res.setHeader('Content-Type', MIME[ext] || 'application/octet-stream');
  res.send(await readFile(abs));
}

const app = express();
app.use(express.json({ limit: '2mb' }));
app.disable('x-powered-by');

async function restoreHandler(conn, supabaseUrl, supabaseAnonKey) {
  const report = { log: [] };
  const total = await restoreDatabase(conn, DB_DIR, (e) => {
    if (e.error) report.log.push(`${e.file}: ERROR ${e.error}`);
    else report.log.push(`${e.file}: ${e.ok} ok, ${e.failed} gagal`);
  });
  await saveState({
    restored: true,
    host: conn.host,
    port: conn.port,
    database: conn.database,
    user: conn.user,
    password: conn.password,
    supabaseUrl,
    supabaseAnonKey,
    restoredAt: new Date().toISOString(),
  });
  return { total: total.total, files: total.files, log: report.log };
}

app.get('/api/state', async (_req, res) => {
  const state = await loadState();
  res.json(publicConfig(state));
});

app.post('/api/test-db', async (req, res) => {
  try {
    const r = await testConnection(req.body || {});
    res.json(r);
  } catch (e) {
    res.json({ ok: false, error: String(e && e.message ? e.message : e) });
  }
});

app.post('/api/restore', async (req, res) => {
  try {
    const conn = req.body || {};
    const supabaseUrl = (req.body.supabaseUrl || '').trim();
    const supabaseAnonKey = (req.body.supabaseAnonKey || '').trim();
    const result = await restoreHandler(conn, supabaseUrl, supabaseAnonKey);
    res.json({ ok: true, ...result });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e && e.message ? e.message : e) });
  }
});

// Endpoint reset (opsional): hapus state & kembalikan ke wizard.
app.post('/api/reset', async (_req, res) => {
  try {
    await writeFile(STATE_FILE, JSON.stringify({ restored: false }));
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e) });
  }
});

// Aset wizard (app.css, app.js) — tanpa index agar routing utama yang menangani "/".
app.use(express.static(join(__dirname, 'public'), { index: false }));

// Routing utama: bila sudah restored, sajikan app & admin; bila belum, wizard.
app.use(async (req, res) => {
  if (req.method !== 'GET') return res.status(405).end();
  const path = req.path;
  if (path.startsWith('/api/')) return res.status(404).end();

  const state = await loadState();
  if (!state.restored) {
    // Selama belum restore, apa pun pathnya -> wizard.
    return res.sendFile(join(__dirname, 'public', 'index.html'));
  }

  const config = {
    supabaseUrl: state.supabaseUrl || `https://${req.hostname}`,
    supabaseAnonKey: state.supabaseAnonKey || '',
  };

  if (path === '/admin' || path.startsWith('/admin/')) {
    return serveAppFile(res, ADMIN_DIR, path.replace(/^\/admin\/?/, ''), config);
  }
  return serveAppFile(res, WEB_DIR, path, config);
});

app.listen(PORT, () => {
  console.log(`KasirGo self-host installer aktif di http://0.0.0.0:${PORT}`);
  console.log(`Database: ${DB_DIR}`);
  console.log(`Web app : ${WEB_DIR}`);
  console.log(`Admin   : ${ADMIN_DIR}`);
});