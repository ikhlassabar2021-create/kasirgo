import { chromium } from 'playwright';

const BASE = process.env.BASE_URL || 'https://ikhlassabar2021-create.github.io/kasirgo/';
const browser = await chromium.launch({
  args: ['--no-sandbox', '--autoplay-policy=no-user-gesture-required'],
});
const ctx = await browser.newContext({
  viewport: { width: 1280, height: 1400 },
  serviceWorkers: 'block',
});
const page = await ctx.newPage();
const errors = [];
const tts = [];
page.on('console', (m) => {
  if (m.type() === 'error') errors.push(m.text());
});
page.on('pageerror', (e) => errors.push('PAGEERROR ' + e.message));
page.on('response', async (r) => {
  if (!r.url().includes('/functions/v1/tts_speak')) return;
  let body = null;
  try {
    body = await r.json();
  } catch (_) {}
  tts.push({ status: r.status(), body });
});

const clickText = async (t, maxW = 0) => {
  const els = page.locator('flt-semantics', { hasText: t });
  const n = await els.count();
  for (let i = n - 1; i >= 0; i--) {
    const el = els.nth(i);
    const box = await el.boundingBox();
    if (!box || box.width === 0) continue;
    if (maxW && box.width > maxW) continue;
    await el.scrollIntoViewIfNeeded().catch(() => {});
    await el.evaluate((e) => e.click()).catch(() => {});
    return { ok: true, x: Math.round(box.x), y: Math.round(box.y) };
  }
  return { ok: false };
};

const speaking = () =>
  page.locator('flt-semantics', { hasText: 'Dokter sedang berbicara' }).count();

const waitSilent = async (limitMs) => {
  const t0 = Date.now();
  for (let i = 0; i < limitMs / 250; i++) {
    if ((await speaking()) === 0) return Date.now() - t0;
    await page.waitForTimeout(250);
  }
  return -1;
};

const decodeDurations = (segments) =>
  page.evaluate(async (segs) => {
    const ctx = new AudioContext();
    const out = [];
    for (const s of segs) {
      const bin = atob(s.audio);
      const u8 = new Uint8Array(bin.length);
      for (let i = 0; i < bin.length; i++) u8[i] = bin.charCodeAt(i);
      try {
        const buf = await ctx.decodeAudioData(u8.buffer);
        out.push({ dur: buf.duration, pause: s.pause_ms, bytes: u8.length });
      } catch (e) {
        out.push({ dur: -1, pause: s.pause_ms, bytes: u8.length });
      }
    }
    return out;
  }, segments);

await page.goto(BASE + '?cb=' + Date.now(), {
  waitUntil: 'networkidle',
  timeout: 120000,
});
await page.waitForTimeout(5000);
await page.locator('flt-semantics-placeholder').evaluate((el) => el.click());
await page.waitForTimeout(2000);
await clickText('Saya Penjual');
await page.waitForTimeout(4000);
const box = await page.locator('input[aria-label="Email Bisnis / Owner"]').boundingBox();
await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
await page.keyboard.type('ikhlassabar2021@gmail.com', { delay: 20 });
await page.keyboard.press('Tab');
await page.waitForTimeout(400);
await page.keyboard.type('sabar2021', { delay: 30 });
await page.waitForTimeout(600);
await clickText('MASUK KE KASIRGO');
await page.waitForTimeout(12000);
await clickText('Dokter Bisnis AI');
await page.waitForTimeout(8000);

// ---- 1. Putar contoh suara penuh, ukur jeda antar kalimat ----
const before = tts.length;
const clicked = await clickText('Dengar contoh suara');
await page.waitForTimeout(1500);
const seenSpeaking = (await speaking()) > 0;
const played = await waitSilent(60000);
const last = tts.length > before ? tts[tts.length - 1] : null;
const body = last?.body ?? {};
const segs = Array.isArray(body.segments) ? body.segments : [];
const decoded = segs.length ? await decodeDurations(segs) : [];
const audioTotal = decoded.reduce((a, s) => a + Math.max(0, s.dur), 0);
const pauseTotal = decoded.reduce((a, s) => a + s.pause, 0) / 1000;
const rate = body.playback_rate ?? 1;
const expectedMs = Math.round((audioTotal / rate + pauseTotal) * 1000);

console.log('PREVIEW_CLICKED', clicked);
console.log('HTTP', last?.status, 'PROVIDER', body.provider);
console.log('PERSONA', body.persona, 'RATE', rate);
console.log('SEGMENTS', segs.length, 'DURATIONS', decoded.map((d) => d.dur.toFixed(2)).join(','));
console.log('PAUSES_MS', decoded.map((d) => d.pause).join(','));
console.log('AUDIO_S', audioTotal.toFixed(2), 'PAUSE_S', pauseTotal.toFixed(2));
console.log('SPEAKING_SEEN', seenSpeaking);
console.log('PLAYED_MS', played, 'EXPECTED_MS', expectedMs);
console.log(
  'PLAYBACK_RATIO',
  expectedMs > 0 && played > 0 ? (played / expectedMs).toFixed(2) : 'n/a',
);

// ---- 2. Hentikan saat sedang bicara -> audio harus langsung berhenti ----
const before2 = tts.length;
const clicked2 = await clickText('Dengar contoh suara');
let sawSecond = false;
for (let i = 0; i < 20; i++) {
  if (tts.length > before2) { sawSecond = true; break; }
  await page.waitForTimeout(250);
}
const speakingBeforeStop = (await speaking()) > 0;
const stopClicked = await clickText('Bicara', 90);
const stopLatency = await waitSilent(15000);
console.log('STOP_TEST_CLICKED', JSON.stringify(clicked2), 'REQ', sawSecond);
console.log('STOP_SPEAKING_BEFORE', speakingBeforeStop);
console.log('STOP_CLICKED', stopClicked);
console.log('STOP_LATENCY_MS', stopLatency);
console.log('STOP_CALLS', tts.length - before2);

console.log('ERRORS', errors.length);
if (errors.length) console.log(errors.slice(0, 6).join('\n'));
await browser.close();
