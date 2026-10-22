import fs from 'fs';
import { chromium } from 'playwright';

const BASE = process.env.BASE || 'https://ikhlassabar2021-create.github.io/kasirgo/';
const SUPA = 'https://lmvjecdvfzsmrowwwpck.supabase.co';
const KEY = 'sb_publishable_8RJnG66i_37cih8GTG1sBA_0B91KOW_';
const OUTLET = '229c94d7-ce6d-4be1-98f5-448f600528cc';
const CASHIER = '0f3c7d79-a157-4ae5-aaff-e12da41ab59d';
const TOKEN = fs.readFileSync('/tmp/opencode/owner_token.txt', 'utf8').trim();
const H = { apikey: KEY, Authorization: `Bearer ${TOKEN}`, 'Content-Type': 'application/json' };

const rest = async (path, opts = {}) => {
  const res = await fetch(`${SUPA}/rest/v1/${path}`, {
    ...opts,
    headers: { ...H, ...(opts.headers || {}) },
  });
  const text = await res.text();
  let body = null;
  try { body = text ? JSON.parse(text) : null; } catch { body = text; }
  return { status: res.status, body };
};

const login = async (page, email) => {
  await page.goto(BASE + '?cb=' + Date.now(), { waitUntil: 'networkidle', timeout: 180000 });
  await page.waitForTimeout(6000);
  await page.locator('flt-semantics-placeholder').evaluate((el) => el.click());
  await page.waitForTimeout(2500);
  const clickLabel = async (t) => {
    const r = await page.evaluate((label) => {
      const els = [...document.querySelectorAll('flt-semantics')].filter((e) => {
        const b = e.getBoundingClientRect();
        if (b.width === 0 || b.height === 0) return false;
        const aria = e.getAttribute('aria-label') || '';
        return aria.includes(label) || (e.textContent || '').includes(label);
      });
      if (!els.length) return null;
      const el = els[els.length - 1];
      const b = el.getBoundingClientRect();
      return { x: b.x + b.width / 2, y: b.y + b.height / 2 };
    }, t);
    if (!r) return false;
    await page.mouse.click(r.x, r.y);
    return true;
  };
  await clickLabel('Saya Penjual');
  await page.waitForTimeout(4000);
  const emailBox = await page.locator('input[aria-label="Email Bisnis / Owner"]').boundingBox();
  await page.mouse.click(emailBox.x + emailBox.width / 2, emailBox.y + emailBox.height / 2);
  await page.waitForTimeout(500);
  await page.keyboard.type(email, { delay: 25 });
  await page.waitForTimeout(400);
  await page.keyboard.press('Tab');
  await page.waitForTimeout(600);
  await page.keyboard.type('sabar2021', { delay: 40 });
  await page.waitForTimeout(800);
  await clickLabel('MASUK KE KASIRGO');
  await page.waitForTimeout(16000);
  return clickLabel;
};

const run = async () => {
  const overdue = new Date(Date.now() - 2 * 86400e3).toISOString();
  const insTask = await rest('doctor_delegations', {
    method: 'POST',
    headers: { Prefer: 'return=representation' },
    body: JSON.stringify({
      outlet_id: OUTLET,
      title: '__ALERT_QA__ Hitung stok gula',
      body: 'Cek sisa gula di gudang.',
      category: 'stok',
      priority: 'tinggi',
      assigned_user_id: CASHIER,
      assigned_name: 'Kasir Demo',
      assigned_role: 'cashier',
      due_at: overdue,
    }),
  });
  const taskId = insTask.body?.[0]?.id;
  console.log('SEED_TASK', insTask.status, taskId);

  const insRep = await rest('doctor_memory', {
    method: 'POST',
    headers: { Prefer: 'return=representation' },
    body: JSON.stringify({
      outlet_id: OUTLET,
      kind: 'reprimand',
      title: '__ALERT_QA__ Teguran',
      content: 'Resep kemarin belum dijalankan. Kerjakan hari ini.',
      status: 'open',
      data: { level: 2 },
    }),
  });
  const repId = insRep.body?.[0]?.id;
  console.log('SEED_REPRIMAND', insRep.status, repId);

  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const results = {};
  for (const [label, email] of [
    ['owner', 'ikhlassabar2021@gmail.com'],
    ['cashier', 'ikhlassabar2021+kasir@gmail.com'],
  ]) {
    const ctx = await browser.newContext({
      viewport: { width: 1280, height: 1200 },
      serviceWorkers: 'block',
    });
    const page = await ctx.newPage();
    const errors = [];
    const logs = [];
    page.on('console', (m) => {
      if (m.type() === 'error') errors.push(m.text());
      if (m.text().includes('[DoctorAlert]')) logs.push(m.text());
    });
    page.on('pageerror', (e) => errors.push(`pageerror: ${e.message}`));
    await login(page, email);
    await page.waitForTimeout(9000);
    const text = await page.evaluate(() => document.body.innerText || '');
    const semantics = await page.evaluate(() =>
      [...document.querySelectorAll('flt-semantics')]
        .map((e) => e.getAttribute('aria-label') || e.textContent || '')
        .join(' | '));
    results[label] = {
      errors: errors.slice(0, 5),
      alertLogs: logs,
      hasHome: /Kasir|Beranda|Dashboard|Tugas|Produk/i.test(text + semantics),
      hasTaskCard: semantics.includes('__ALERT_QA__') || semantics.includes('Tugas dari Owner'),
      hasReprimandBanner: semantics.includes('Teguran'),
    };
    await page.screenshot({ path: `/tmp/opencode/alert_${label}.png` });
    await ctx.close();
  }
  console.log(JSON.stringify(results, null, 2));

  if (taskId) {
    const del = await rest(`doctor_delegations?id=eq.${taskId}`, { method: 'DELETE' });
    console.log('CLEAN_TASK', del.status);
  }
  if (repId) {
    const del = await rest(`doctor_memory?id=eq.${repId}`, { method: 'DELETE' });
    console.log('CLEAN_REPRIMAND', del.status);
  }
  await browser.close();
};

run().catch((e) => { console.error('FATAL', e); process.exit(1); });
