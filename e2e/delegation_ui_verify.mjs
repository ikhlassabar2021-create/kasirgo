import fs from 'fs';
import { chromium } from 'playwright';

const BASE = 'https://ikhlassabar2021-create.github.io/kasirgo/';
const SUPA = 'https://lmvjecdvfzsmrowwwpck.supabase.co';
const KEY = 'sb_publishable_8RJnG66i_37cih8GTG1sBA_0B91KOW_';
const OUTLET = '229c94d7-ce6d-4be1-98f5-448f600528cc';
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
  await page.goto(BASE + '?cb=' + Date.now(), { waitUntil: 'networkidle', timeout: 120000 });
  await page.waitForTimeout(5000);
  await page.locator('flt-semantics-placeholder').evaluate((el) => el.click());
  await page.waitForTimeout(2000);
  const clickText = async (t) => {
    const els = page.locator('flt-semantics', { hasText: t });
    const n = await els.count();
    for (let i = n - 1; i >= 0; i--) {
      const el = els.nth(i);
      const box = await el.boundingBox();
      if (!box || box.width === 0) continue;
      await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
      return true;
    }
    return false;
  };
  await clickText('Saya Penjual');
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
  await clickText('MASUK KE KASIRGO');
  await page.waitForTimeout(12000);
  return clickText;
};

const run = async () => {
  const before = await rest(`doctor_delegations?outlet_id=eq.${OUTLET}&select=id,title,status`);
  console.log('BEFORE_ROWS', JSON.stringify(before.body));

  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const ctx = await browser.newContext({
    viewport: { width: 1280, height: 1200 },
    serviceWorkers: 'block',
  });
  const page = await ctx.newPage();
  const errors = [];
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });

  let createdId = null;
  try {
    const clickText = await login(page, 'ikhlassabar2021@gmail.com');
    const body = async () =>
      page.evaluate(() => document.body.innerText || document.querySelector('flt-semantics')?.textContent || '');

    console.log('HOME', (await body()).includes('Dashboard Owner'));

    const opened = await clickText('Dokter Bisnis AI');
    console.log('OPEN_DOCTOR', opened);
    await page.waitForTimeout(6000);

    // scroll cari kartu Delegasi Tugas
    let found = false;
    for (let i = 0; i < 12; i++) {
      if ((await body()).includes('Delegasi Tugas')) { found = true; break; }
      await page.mouse.wheel(0, 600);
      await page.waitForTimeout(900);
    }
    console.log('HAS_CARD', found);
    const cardClick = await clickText('Delegasi Tugas');
    console.log('OPEN_BOARD', cardClick);
    await page.waitForTimeout(5000);
    const boardTxt = await body();
    console.log('BOARD_TITLE', boardTxt.includes('Delegasi Tugas'));
    console.log('HAS_FAB', boardTxt.includes('Tugas Baru'));
    console.log('HAS_SUMMARY', boardTxt.includes('Aktif'));

    await clickText('Tugas Baru');
    await page.waitForTimeout(2500);
    const titleBox = await page.locator('input[aria-label="Judul tugas"]').boundingBox();
    await page.mouse.click(titleBox.x + titleBox.width / 2, titleBox.y + titleBox.height / 2);
    await page.waitForTimeout(400);
    await page.keyboard.type('__UI QA__ Cek stok gula', { delay: 20 });
    await page.waitForTimeout(500);
    console.log('CAT_STOK', await clickText('Stok'));
    await page.waitForTimeout(400);
    console.log('PRIO_TINGGI', await clickText('Tinggi'));
    await page.waitForTimeout(400);
    console.log('ASSIGN_OPEN', await clickText('Tugaskan ke'));
    await page.waitForTimeout(1500);
    console.log('ASSIGN_PICK', await clickText('Kasir Demo'));
    await page.waitForTimeout(800);
    console.log('DUE_TODAY', await clickText('Hari ini'));
    await page.waitForTimeout(400);
    console.log('SAVE', await clickText('Buat Tugas'));
    await page.waitForTimeout(5000);

    const after = await rest(`doctor_delegations?outlet_id=eq.${OUTLET}&select=id,title,status,assigned_name,priority,category,due_at&title=like.__UI%20QA__*`);
    console.log('AFTER_ROWS', JSON.stringify(after.body));
    createdId = after.body?.[0]?.id ?? null;
    const shot1 = '/tmp/opencode/deleg_board_owner.png';
    await page.screenshot({ path: shot1, fullPage: true });
    console.log('SHOT', shot1);
  } finally {
    console.log('ERRORS', errors.length, JSON.stringify(errors.slice(0, 4)));
    if (createdId) {
      const del = await rest(`doctor_delegations?id=eq.${createdId}`, { method: 'DELETE' });
      console.log('CLEANUP', del.status);
    }
    await browser.close();
  }
};

run().catch((e) => { console.error('FAIL', e); process.exit(1); });
