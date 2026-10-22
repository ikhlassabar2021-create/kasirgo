import { chromium } from 'playwright';

const BASE = 'https://ikhlassabar2021-create.github.io/kasirgo/';
const b = await chromium.launch({ args: ['--no-sandbox'] });
const c = await b.newContext({
  viewport: { width: 1280, height: 1200 },
  serviceWorkers: 'block',
});
const p = await c.newPage();
const errs = [];
p.on('console', (m) => {
  if (m.type() === 'error') errs.push(m.text().slice(0, 160));
});

const clickText = async (t) => {
  const els = p.locator('flt-semantics', { hasText: t });
  const n = await els.count();
  for (let i = n - 1; i >= 0; i--) {
    const el = els.nth(i);
    const bx = await el.boundingBox();
    if (!bx || bx.width === 0) continue;
    await p.mouse.click(bx.x + bx.width / 2, bx.y + bx.height / 2);
    return true;
  }
  return false;
};

const pref = () =>
  p.evaluate(() => ({
    note: localStorage.getItem('flutter.kasirgo_doctor_voice_note'),
    transcript: localStorage.getItem('flutter.kasirgo_doctor_voice_transcript'),
  }));

const labels = () =>
  p.evaluate(() =>
    [...document.querySelectorAll('flt-semantics')]
      .map((e) => e.getAttribute('aria-label') || '')
      .filter((s) => s.includes('voice note') || s.includes('Voice Note') || s.includes('Teks Suara'))
  );

await p.goto(BASE + '?cb=' + Date.now(), { waitUntil: 'networkidle', timeout: 120000 });
await p.waitForTimeout(6000);
await p.locator('flt-semantics-placeholder').evaluate((el) => el.click());
await p.waitForTimeout(2500);
await clickText('Saya Penjual');
await p.waitForTimeout(4000);

const eb = await p.locator('input[aria-label="Email Bisnis / Owner"]').boundingBox();
await p.mouse.click(eb.x + eb.width / 2, eb.y + eb.height / 2);
await p.waitForTimeout(500);
await p.keyboard.type('ikhlassabar2021@gmail.com', { delay: 25 });
await p.keyboard.press('Tab');
await p.waitForTimeout(600);
await p.keyboard.type('sabar2021', { delay: 40 });
await p.waitForTimeout(800);
await clickText('MASUK KE KASIRGO');
await p.waitForTimeout(12000);
await clickText('Dokter Bisnis AI');
await p.waitForTimeout(7000);

console.log('PREF_AWAL', JSON.stringify(await pref()));
console.log('LABELS_AWAL', JSON.stringify(await labels()));

const switchBox = async (i) => {
  const boxes = await p.evaluate(() =>
    [...document.querySelectorAll('flt-semantics[role="switch"]')].map((e) => {
      const r = e.getBoundingClientRect();
      return { x: r.x, y: r.y, w: r.width, h: r.height };
    })
  );
  return boxes[i];
};

const clickSwitch = async (i) => {
  const bx = await switchBox(i);
  if (!bx) return false;
  await p.mouse.click(bx.x + bx.w / 2, bx.y + bx.h / 2);
  return true;
};

const hint = () =>
  p.evaluate(() => {
    const el = [...document.querySelectorAll('flt-semantics')].find((e) =>
      (e.getAttribute('aria-label') || '').includes('voice note')
    );
    if (el) return el.getAttribute('aria-label');
    const inputs = [...document.querySelectorAll('input,textarea')].map(
      (e) => e.getAttribute('placeholder') || e.getAttribute('aria-label') || ''
    );
    return inputs.filter((s) => s.toLowerCase().includes('bicara'));
  });

const on = await clickSwitch(1);
await p.waitForTimeout(2500);
console.log('TOGGLE_ON_CLICK', on, JSON.stringify(await pref()));
console.log('HINT_ON', JSON.stringify(await hint()));

const onTranscript = await clickSwitch(2);
await p.waitForTimeout(2500);
console.log('TRANSCRIPT_ON_CLICK', onTranscript, JSON.stringify(await pref()));

const offTranscript = await clickSwitch(2);
await p.waitForTimeout(1500);
const off = await clickSwitch(1);
await p.waitForTimeout(2500);
console.log('TOGGLE_OFF_CLICK', off, JSON.stringify(await pref()));
console.log('HINT_OFF', JSON.stringify(await hint()));

console.log('ERRORS', errs.length, JSON.stringify(errs.slice(0, 3)));
await b.close();
