import { chromium } from 'playwright';

const BASE = 'https://ikhlassabar2021-create.github.io/kasirgo/';
const b = await chromium.launch({
  args: ['--no-sandbox', '--autoplay-policy=no-user-gesture-required'],
});
const c = await b.newContext({
  viewport: { width: 1280, height: 1200 },
  serviceWorkers: 'block',
});

await c.addInitScript(() => {
  window.__tts = [];
  const push = (o) => window.__tts.push({ t: Date.now(), ...o });
  const origPlay = HTMLMediaElement.prototype.play;
  HTMLMediaElement.prototype.play = function () {
    push({
      type: 'media-play',
      tag: this.tagName,
      src: (this.currentSrc || this.src || '').slice(0, 80),
      dur: this.duration,
    });
    return origPlay.call(this).catch((e) => {
      push({ type: 'media-play-err', err: String(e).slice(0, 160) });
      throw e;
    });
  };
  const origSpeak = window.speechSynthesis?.speak?.bind(window.speechSynthesis);
  if (origSpeak) {
    window.speechSynthesis.speak = function (u) {
      push({ type: 'synth-speak', text: String(u.text || '').slice(0, 80) });
      return origSpeak(u);
    };
  }
  window.__fetchLog = [];
  const origFetch = window.fetch;
  window.fetch = function (...a) {
    const url = typeof a[0] === 'string' ? a[0] : a[0]?.url || '';
    if (url.includes('tts_speak')) window.__fetchLog.push({ url: url.slice(0, 120) });
    return origFetch.apply(this, a);
  };
});

const p = await c.newPage();
const errs = [];
p.on('console', (m) => {
  if (m.type() === 'error') errs.push(m.text().slice(0, 200));
});
p.on('pageerror', (e) => errs.push('PAGEERR ' + String(e).slice(0, 200)));

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

const state = () =>
  p.evaluate(() => ({
    tts: window.__tts,
    fetch: window.__fetchLog,
    note: localStorage.getItem('flutter.kasirgo_doctor_voice_note'),
    aktif: localStorage.getItem('flutter.kasirgo_doctor_voice_note'),
  }));

const openSettings = async () => {
  await clickText('Pengaturan Dokter');
  await p.waitForTimeout(2500);
};

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
await p.waitForTimeout(8000);

const labels = await p.evaluate(() =>
  [...document.querySelectorAll('flt-semantics')]
    .map((e) => e.getAttribute('aria-label') || '')
    .filter((s) => s && s.length < 60)
    .slice(0, 60)
);
console.log('MENU_LABELS', JSON.stringify(labels));

const inp = await p.evaluate(() => {
  const el = [...document.querySelectorAll('input,textarea')].find((e) => {
    const h = e.getAttribute('placeholder') || e.getAttribute('aria-label') || '';
    return h.includes('pertanyaan') || h.includes('voice note');
  });
  if (!el) return null;
  const r = el.getBoundingClientRect();
  return { x: r.x, y: r.y, w: r.width, h: r.height };
});
console.log('INPUT', JSON.stringify(inp));

if (inp) {
  await p.mouse.click(inp.x + inp.w / 2, inp.y + inp.h / 2);
  await p.waitForTimeout(600);
  await p.keyboard.type('Berapa omzet saya minggu ini?', { delay: 20 });
  await p.waitForTimeout(600);
  await p.keyboard.press('Enter');
  await p.waitForTimeout(30000);
}

console.log('STATE', JSON.stringify(await state()));
console.log('ERRORS', errs.length, JSON.stringify(errs.slice(0, 6)));
await b.close();
