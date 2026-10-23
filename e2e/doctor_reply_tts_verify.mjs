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
      src: (this.currentSrc || this.src || '').slice(0, 40),
      dur: Math.round((this.duration || 0) * 1000) / 1000,
    });
    return origPlay.call(this).catch((e) => {
      push({ type: 'media-play-err', err: String(e).slice(0, 140) });
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
    if (url.includes('tts_speak')) {
      window.__fetchLog.push({ t: Date.now(), url: url.slice(0, 100) });
    }
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

const mark = () => p.evaluate(() => (window.__mark = Date.now()));

const state = () =>
  p.evaluate(() => {
    const m = window.__mark || 0;
    return {
      note: localStorage.getItem('flutter.kasirgo_doctor_voice_note'),
      mark: m,
      tts: window.__tts.map((e) => ({ ...e, dt: m ? e.t - m : null })),
      fetch: window.__fetchLog.map((e) => ({ ...e, dt: m ? e.t - m : null })),
    };
  });

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

// buka menu Dokter
const menuOk = await p.evaluate(() => {
  const btns = [...document.querySelectorAll('flt-semantics')].filter((e) => {
    const r = e.getBoundingClientRect();
    const lbl = e.getAttribute('aria-label') || '';
    return r.width > 20 && r.height > 20 && r.y < 120 && /menu|pengaturan/i.test(lbl);
  });
  if (!btns.length) return null;
  const r = btns[0].getBoundingClientRect();
  return { x: r.x + r.width / 2, y: r.y + r.height / 2, label: btns[0].getAttribute('aria-label') };
});
console.log('MENU_BTN', JSON.stringify(menuOk));
if (menuOk) {
  await p.mouse.click(menuOk.x, menuOk.y);
  await p.waitForTimeout(1500);
}
console.log('MENU_OPENED', await clickText('Persona & Suara'));
await p.waitForTimeout(2500);

// cari switch "Mode Voice Note" lewat label + switch terdekat
const switchHit = await p.evaluate(() => {
  const all = [...document.querySelectorAll('flt-semantics')];
  const label = all.find((e) => (e.getAttribute('aria-label') || '').includes('Mode Voice Note'));
  if (!label) return null;
  const lr = label.getBoundingClientRect();
  const switches = all
    .filter((e) => (e.getAttribute('role') || '') === 'switch')
    .map((e) => ({ e, r: e.getBoundingClientRect() }))
    .filter((o) => o.r.width > 0);
  let best = null;
  for (const o of switches) {
    const d = Math.abs(o.r.y + o.r.height / 2 - (lr.y + lr.height / 2));
    if (!best || d < best.d) best = { d, r: o.r };
  }
  if (!best || best.d > 40) return { labelY: lr.y, switchCount: switches.length, best: best?.d };
  return {
    x: best.r.x + best.r.width / 2,
    y: best.r.y + best.r.height / 2,
    labelY: lr.y,
    switchCount: switches.length,
    best: best.d,
  };
});
console.log('SWITCH_HIT', JSON.stringify(switchHit));
if (switchHit && switchHit.x) {
  await p.mouse.click(switchHit.x, switchHit.y);
  await p.waitForTimeout(1200);
}
console.log('NOTE_PREF', await p.evaluate(() => localStorage.getItem('flutter.kasirgo_doctor_voice_note')));
await p.keyboard.press('Escape');
await p.waitForTimeout(1500);

const inp = await p.evaluate(() => {
  const el = [...document.querySelectorAll('input,textarea')].find((e) => {
    const h = e.getAttribute('placeholder') || e.getAttribute('aria-label') || '';
    return h.includes('pertanyaan') || h.includes('voice note') || h.includes('Dokter');
  });
  if (!el) return null;
  const r = el.getBoundingClientRect();
  return { x: r.x, y: r.y, w: r.width, h: r.height, hint: el.getAttribute('placeholder') || el.getAttribute('aria-label') };
});
console.log('INPUT', JSON.stringify(inp));

if (inp) {
  await p.mouse.click(inp.x + inp.w / 2, inp.y + inp.h / 2);
  await p.waitForTimeout(500);
  await p.keyboard.type('Berapa omzet saya minggu ini?', { delay: 20 });
  await p.waitForTimeout(500);
  await mark();
  await p.keyboard.press('Enter');
  await p.waitForTimeout(45000);
}

const st = await state();
console.log('NOTE_PREF_AFTER', st.note);
console.log('TTS', JSON.stringify(st.tts));
console.log('FETCH', JSON.stringify(st.fetch));
console.log('ERRORS', errs.length, JSON.stringify(errs.slice(0, 6)));
await b.close();
