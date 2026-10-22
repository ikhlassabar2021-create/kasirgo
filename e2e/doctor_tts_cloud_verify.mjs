import { chromium } from 'playwright';

const BASE = process.env.BASE_URL || 'http://127.0.0.1:8123/kasirgo/';
const browser = await chromium.launch({ args: ['--no-sandbox', '--autoplay-policy=no-user-gesture-required'] });
const ctx = await browser.newContext({ viewport: { width: 1280, height: 1400 }, serviceWorkers: 'block' });
const page = await ctx.newPage();
const errors = [];
const ttsCalls = [];
page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
page.on('pageerror', (e) => errors.push('PAGEERROR ' + e.message));
page.on('response', async (r) => {
  if (r.url().includes('/functions/v1/tts_speak')) {
    let size = 0;
    try { size = (await r.body()).length; } catch (_) {}
    ttsCalls.push({ status: r.status(), size, method: r.request().method() });
  }
});

const clickText = async (t) => {
  const els = page.locator('flt-semantics', { hasText: t });
  const n = await els.count();
  for (let i = n - 1; i >= 0; i--) {
    const box = await els.nth(i).boundingBox();
    if (!box || box.width === 0) continue;
    await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
    return true;
  }
  return false;
};

await page.goto(BASE + '?cb=' + Date.now(), { waitUntil: 'networkidle', timeout: 120000 });
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

const before = ttsCalls.length;
const played = await clickText('Dengar contoh suara');
await page.waitForTimeout(9000);
console.log('PREVIEW_CLICKED', played);
console.log('TTS_CALLS', ttsCalls.length - before);
console.log('TTS_DETAIL', JSON.stringify(ttsCalls.slice(-2)));
console.log('ERRORS', errors.length);
if (errors.length) console.log(errors.slice(0, 6).join('\n'));
await browser.close();
