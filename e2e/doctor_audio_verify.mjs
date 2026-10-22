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

const profile = () =>
  rest(`doctor_outlet_profile?outlet_id=eq.${OUTLET}&select=outlet_id,preferred_tone,audio_prefs`);

const run = async () => {
  const before = await profile();
  console.log('BEFORE', JSON.stringify(before.body));

  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const ctx = await browser.newContext({
    viewport: { width: 1280, height: 1200 },
    serviceWorkers: 'block',
  });
  const page = await ctx.newPage();
  const errors = [];
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });

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
  const body = async () =>
    page.evaluate(() => document.body.innerText || document.querySelector('flt-semantics')?.textContent || '');
  const dumpSem = async (filter) =>
    page.evaluate((f) => [...document.querySelectorAll('flt-semantics')]
      .map((e) => ({
        label: e.getAttribute('aria-label') || '',
        role: e.getAttribute('role') || '',
        checked: e.getAttribute('aria-checked'),
        selected: e.getAttribute('aria-selected'),
        rect: (() => { const b = e.getBoundingClientRect(); return { x: b.x, y: b.y, w: b.width, h: b.height }; })(),
      }))
      .filter((n) => n.rect.w > 0 && (n.label.includes(f) || n.role === 'switch' || n.role === 'checkbox'))
      .slice(0, 40), filter);

  try {
    await page.goto(BASE + '?cb=' + Date.now(), { waitUntil: 'networkidle', timeout: 120000 });
    await page.waitForTimeout(5000);
    await page.locator('flt-semantics-placeholder').evaluate((el) => el.click());
    await page.waitForTimeout(2000);

    await clickText('Saya Penjual');
    await page.waitForTimeout(4000);
    const emailBox = await page.locator('input[aria-label="Email Bisnis / Owner"]').boundingBox();
    await page.mouse.click(emailBox.x + emailBox.width / 2, emailBox.y + emailBox.height / 2);
    await page.waitForTimeout(500);
    await page.keyboard.type('ikhlassabar2021@gmail.com', { delay: 25 });
    await page.waitForTimeout(400);
    await page.keyboard.press('Tab');
    await page.waitForTimeout(600);
    await page.keyboard.type('sabar2021', { delay: 40 });
    await page.waitForTimeout(800);
    await clickText('MASUK KE KASIRGO');
    await page.waitForTimeout(11000);
    console.log('HOME', (await body()).includes('Dashboard Owner'));

    const opened = await clickText('Dokter Bisnis AI');
    console.log('OPEN_DOCTOR', opened);
    await page.waitForTimeout(6000);

    const txt = await body();
    console.log('HAS_PERSONA', txt.includes('Persona Dokter'));
    console.log('HAS_AUDIO', txt.includes('Suara Interaktif'));
    console.log('HAS_SOUNDBOX', txt.includes('Soundbox POS'));
    console.log('HAS_TEGURAN', txt.includes('Teguran Resep'));
    console.log(
      'HAS_SUB_OPTIONS',
      JSON.stringify(
        ['Sapaan Awal', 'Full Voice Loop', 'Apel Pagi', 'Teguran Resep', 'Soundbox POS', 'Shop Floor'].map(
          (l) => [l, txt.includes(l)],
        ),
      ),
    );
    console.log('PERSONA_LIST', JSON.stringify(['Bos Tegas', 'Partner Santai', 'Analis Taktis'].map((p) => [p, txt.includes(p)])));

    const sem = await dumpSem('Suara');
    console.log('SEM', JSON.stringify(sem, null, 1));

    // Toggle master switch off via semantics role=switch first node
    const sw = await page.evaluate(() => {
      const el = [...document.querySelectorAll('flt-semantics')].find(
        (e) => e.getAttribute('role') === 'switch' && e.getBoundingClientRect().width > 0,
      );
      if (!el) return null;
      const b = el.getBoundingClientRect();
      return { x: b.x + b.width / 2, y: b.y + b.height / 2, label: el.getAttribute('aria-label'), checked: el.getAttribute('aria-checked') };
    });
    console.log('SWITCH', JSON.stringify(sw));
    if (sw) {
      await page.mouse.click(sw.x, sw.y);
      await page.waitForTimeout(3000);
      const after = await profile();
      console.log('AFTER_OFF', JSON.stringify(after.body));
      await page.mouse.click(sw.x, sw.y);
      await page.waitForTimeout(3000);
      const back = await profile();
      console.log('AFTER_ON', JSON.stringify(back.body));
    }

    // Persona: klik Partner Santai
    const pClick = await clickText('Partner Santai');
    await page.waitForTimeout(3000);
    const pAfter = await profile();
    console.log('PERSONA_CLICK', pClick, JSON.stringify(pAfter.body));

    const restoreTone = before.body?.[0]?.preferred_tone ?? 'bos_tegas';
    const restorePrefs = before.body?.[0]?.audio_prefs ?? {};
    const restored = await rest(`doctor_outlet_profile?outlet_id=eq.${OUTLET}`, {
      method: 'PATCH',
      headers: { Prefer: 'return=representation' },
      body: JSON.stringify({ preferred_tone: restoreTone, audio_prefs: restorePrefs }),
    });
    console.log('RESTORE', restored.status, JSON.stringify(restored.body));
    console.log('ERRORS', errors.length, JSON.stringify(errors.slice(0, 5)));
    await page.screenshot({ path: '/tmp/opencode/doctor_audio.png', fullPage: true });
  } finally {
    await browser.close();
  }
};

run().catch((e) => { console.error('FAIL', e); process.exit(1); });
