import { chromium } from 'playwright';
import { readFileSync } from 'node:fs';

const BASE = process.env.BASE || 'http://localhost:8099/kasirgo/';
const EMAIL = 'ikhlassabar2021@gmail.com';
const SUPA = 'https://lmvjecdvfzsmrowwwpck.supabase.co';
const KEY = 'sb_publishable_8RJnG66i_37cih8GTG1sBA_0B91KOW_';
const TOKEN = readFileSync('/tmp/opencode/owner_token.txt', 'utf8').trim();

const rest = async (path, init = {}) => {
  const res = await fetch(SUPA + '/rest/v1/' + path, {
    ...init,
    headers: {
      apikey: KEY,
      Authorization: 'Bearer ' + TOKEN,
      'Content-Type': 'application/json',
      ...(init.headers || {}),
    },
  });
  const text = await res.text();
  let body = null;
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    body = text;
  }
  return { status: res.status, body };
};

const listProgress = () =>
  rest(
    'doctor_action_logs?select=id,action_type,description,outcome,status,result,created_at' +
      '&action_type=eq.progress_tracker&order=created_at.desc&limit=10'
  );

const findBox = async (page, t) => {
  const nodes = await page.evaluate((label) => {
    return [...document.querySelectorAll('flt-semantics')]
      .map((e) => {
        const r = e.getBoundingClientRect();
        return {
          role: e.getAttribute('role') || '',
          aria: e.getAttribute('aria-label') || '',
          txt: (e.textContent || '').trim(),
          x: r.x, y: r.y, w: r.width, h: r.height,
        };
      })
      .filter((n) => n.txt === label || n.aria === label || n.txt.includes(label));
  }, t);
  let best = null;
  for (const b of nodes) {
    if (!b.w || !b.h) continue;
    if (b.y < 0 || b.y + b.h > 1500) continue;
    if (b.w > 1260) continue;
    const area = b.w * b.h;
    if (!best || area < best.area) best = { ...b, area };
  }
  return best;
};

const scrollTo = async (page, t, tries = 12) => {
  for (let i = 0; i < tries; i++) {
    const box = await findBox(page, t);
    if (box) return box;
    await page.mouse.move(640, 800);
    await page.mouse.wheel(0, 500);
    await page.waitForTimeout(800);
  }
  return null;
};

const clickText = async (page, t) => {
  const box = await findBox(page, t);
  if (!box) return false;
  await page.mouse.click(box.x + box.w / 2, box.y + box.h / 2);
  return true;
};

const login = async (page) => {
  await page.goto(BASE + '?cb=' + Date.now(), { waitUntil: 'networkidle', timeout: 180000 });
  await page.waitForTimeout(6000);
  await page.locator('flt-semantics-placeholder').evaluate((el) => el.click());
  await page.waitForTimeout(2500);
  await clickText(page, 'Saya Penjual');
  await page.waitForTimeout(4000);
  const emailBox = await page.locator('input[aria-label="Email Bisnis / Owner"]').boundingBox();
  await page.mouse.click(emailBox.x + emailBox.width / 2, emailBox.y + emailBox.height / 2);
  await page.waitForTimeout(500);
  await page.keyboard.type(EMAIL, { delay: 25 });
  await page.waitForTimeout(400);
  await page.keyboard.press('Tab');
  await page.waitForTimeout(600);
  await page.keyboard.type('sabar2021', { delay: 40 });
  await page.waitForTimeout(800);
  await clickText(page, 'MASUK KE KASIRGO');
  await page.waitForTimeout(22000);
};

const textOf = (page) =>
  page.evaluate(() =>
    [...document.querySelectorAll('flt-semantics')]
      .map((e) => (e.getAttribute('aria-label') || '') + ' ' + (e.textContent || ''))
      .join(' | ')
  );

const run = async () => {
  const before = await listProgress();
  const beforeIds = new Set((before.body || []).map((r) => r.id));
  console.log('ROWS_BEFORE:', beforeIds.size);

  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const ctx = await browser.newContext({
    viewport: { width: 1280, height: 1500 },
    serviceWorkers: 'block',
  });
  const page = await ctx.newPage();
  const errors = [];
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });

  await login(page);
  await page.waitForTimeout(4000);

  const cardBox = await scrollTo(page, 'Laporan & Progres');
  console.log('CARD_FOUND:', !!cardBox);
  if (cardBox) {
    await page.mouse.click(cardBox.x + cardBox.w / 2, cardBox.y + cardBox.h / 2);
  }
  await page.waitForTimeout(8000);

  let text = await textOf(page);
  console.log('SCREEN_OPEN:', /Laporan & Progres/.test(text));
  console.log('HAS_HERO:', /Progres Usaha Anda/.test(text));
  console.log('HAS_SCORE:', /Skor \d+/.test(text));
  console.log('HAS_TREND_CHIP:', /Tren (membaik|masih sama|menurun)/.test(text));
  console.log('HAS_TREND_TEXT:', /Omzet 7 hari terakhir/.test(text));
  console.log('HAS_SECTION:', /Resep & Target/.test(text));
  console.log('HAS_PRESCRIPTION_CARD:', /Langkah Resep Dokter/.test(text));
  console.log('HAS_TARGET_CARD:', /Target Omzet/.test(text));
  console.log('HAS_CHART:', /Omzet 7 Hari Terakhir/.test(text));
  console.log('HAS_ACTIONS_CARD:', /Aksi Perbaikan/.test(text));
  console.log('HAS_EMPTY:', /Belum ada data untuk diukur/.test(text));
  console.log('HAS_ERROR:', /Data progres belum bisa dimuat/.test(text));
  console.log('HAS_BUTTON:', /Catat Progres Hari Ini/.test(text));
  await page.screenshot({ path: '/tmp/opencode/progress_tracker_screen.png', fullPage: false });

  const btn = await findBox(page, 'Catat Progres Hari Ini');
  if (btn) {
    await page.mouse.click(btn.x + btn.w / 2, btn.y + btn.h / 2);
    await page.waitForTimeout(1200);
    text = await textOf(page);
    console.log('SNACK_SAVED:', /tersimpan di catatan Dokter Bisnis/.test(text));
    await page.waitForTimeout(5000);
    text = await textOf(page);
    console.log('BUTTON_CHANGED:', /Progres hari ini sudah dicatat/.test(text));
    await page.screenshot({ path: '/tmp/opencode/progress_tracker_logged.png' });
  } else {
    console.log('SNACK_SAVED: skipped (button not found)');
  }

  await page.waitForTimeout(1500);
  const after = await listProgress();
  const created = (after.body || []).filter((r) => !beforeIds.has(r.id));
  console.log('ROWS_CREATED:', created.length);
  if (created.length > 0) {
    const row = created[0];
    console.log('ROW_TYPE:', row.action_type);
    console.log('ROW_STATUS:', row.status);
    console.log('ROW_OUTCOME:', row.outcome);
    console.log('ROW_DESC:', row.description);
    console.log('ROW_HAS_SCORE:', typeof row.result?.score === 'number');
    console.log('ROW_TREND:', row.result?.trend);
    console.log('ROW_SALES_7D:', row.result?.sales_7d);
    console.log('ROW_TARGET_PERCENT:', row.result?.target_percent);
    console.log('ROW_PRESCRIPTION:', `${row.result?.prescription_done}/${row.result?.prescription_total}`);
    console.log('ROW_ACTIONS:', `${row.result?.actions_done}/${row.result?.actions_total}`);
    const del = await rest('doctor_action_logs?id=eq.' + row.id, { method: 'DELETE' });
    console.log('CLEANUP_STATUS:', del.status);
  }

  const left = await listProgress();
  console.log('ROWS_AFTER_CLEANUP:', (left.body || []).length);
  console.log('ERRORS', errors.length, errors.slice(0, 5));
  await browser.close();
};

run().catch((e) => { console.error('FAILED', e); process.exit(1); });
