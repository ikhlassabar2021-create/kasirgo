import fs from 'fs';
import { chromium } from 'playwright';

const BASE = 'https://ikhlassabar2021-create.github.io/kasirgo/';
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

const run = async () => {
  const ins = await rest('doctor_delegations', {
    method: 'POST',
    headers: { Prefer: 'return=representation' },
    body: JSON.stringify({
      outlet_id: OUTLET,
      title: '__UI QA Staff__ Cek stok gula',
      body: 'Hitung sisa gula di gudang.',
      category: 'stok',
      priority: 'tinggi',
      assigned_user_id: CASHIER,
      assigned_name: 'Kasir Demo',
      assigned_role: 'cashier',
      due_at: new Date(Date.now() + 3600e3).toISOString(),
    }),
  });
  const id = ins.body?.[0]?.id;
  console.log('SEED', ins.status, id);

  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const ctx = await browser.newContext({
    viewport: { width: 1280, height: 1200 },
    serviceWorkers: 'block',
  });
  const page = await ctx.newPage();
  const errors = [];
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });

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
      return { x: b.x + b.width / 2, y: b.y + b.height / 2, label: el.getAttribute('aria-label') };
    }, t);
    if (!r) return false;
    await page.mouse.click(r.x, r.y);
    return true;
  };

  try {
    await page.goto(BASE + '?cb=' + Date.now(), { waitUntil: 'networkidle', timeout: 120000 });
    await page.waitForTimeout(5000);
    await page.locator('flt-semantics-placeholder').evaluate((el) => el.click());
    await page.waitForTimeout(2000);
    await clickLabel('Saya Penjual');
    await page.waitForTimeout(4000);
    const emailBox = await page.locator('input[aria-label="Email Bisnis / Owner"]').boundingBox();
    await page.mouse.click(emailBox.x + emailBox.width / 2, emailBox.y + emailBox.height / 2);
    await page.waitForTimeout(500);
    await page.keyboard.type('ikhlassabar2021+kasir@gmail.com', { delay: 25 });
    await page.waitForTimeout(400);
    await page.keyboard.press('Tab');
    await page.waitForTimeout(600);
    await page.keyboard.type('sabar2021', { delay: 40 });
    await page.waitForTimeout(800);
    await clickLabel('MASUK KE KASIRGO');
    await page.waitForTimeout(13000);

    const body = async () =>
      page.evaluate(() => document.body.innerText || document.querySelector('flt-semantics')?.textContent || '');
    const txt = await body();
    console.log('HOME_KASIR', txt.includes('Kasir'));
    console.log('HAS_STAFF_CARD', txt.includes('Tugas dari Owner'));
    console.log('HAS_TASK_TITLE', txt.includes('Cek stok gula'));
    console.log('HAS_PRIORITY', txt.includes('Penting'));

    console.log('CLICK_KERJAKAN', await clickLabel('Kerjakan'));
    await page.waitForTimeout(4000);
    const row = await rest(`doctor_delegations?id=eq.${id}&select=status,done_at`);
    console.log('AFTER_KERJAKAN', JSON.stringify(row.body));

    console.log('CLICK_SELESAI', await clickLabel('Selesai'));
    await page.waitForTimeout(4500);
    const row2 = await rest(`doctor_delegations?id=eq.${id}&select=status,done_at,done_note`);
    console.log('AFTER_SELESAI', JSON.stringify(row2.body));
    const prof = await rest(`doctor_outlet_profile?outlet_id=eq.${OUTLET}&select=xp,level`);
    console.log('XP', JSON.stringify(prof.body));

    await page.screenshot({ path: '/tmp/opencode/deleg_staff_card.png', fullPage: true });
  } finally {
    console.log('ERRORS', errors.length, JSON.stringify(errors.slice(0, 4)));
    if (id) {
      const del = await rest(`doctor_delegations?id=eq.${id}`, { method: 'DELETE' });
      console.log('CLEANUP', del.status);
    }
    await browser.close();
  }
};

run().catch((e) => { console.error('FAIL', e); process.exit(1); });
