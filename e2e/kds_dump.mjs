import { chromium } from 'playwright';
const base = 'https://ikhlassabar2021-create.github.io/kasirgo/';
const browser = await chromium.launch({ args: ['--no-sandbox'] });
const ctx = await browser.newContext({ viewport: { width: 1280, height: 1000 }, serviceWorkers: 'block' });
const page = await ctx.newPage();
const clickText = async (t) => {
  const els = page.locator('flt-semantics', { hasText: t });
  const n = await els.count();
  for (let i = n - 1; i >= 0; i--) {
    const el = els.nth(i);
    const box = await el.boundingBox();
    if (!box || box.width === 0) continue;
    await page.mouse.click(box.x + box.width/2, box.y + box.height/2);
    return true;
  }
  return false;
};
await page.goto(base + '?cb=' + Date.now(), { waitUntil: 'networkidle', timeout: 120000 });
await page.waitForTimeout(5000);
await page.locator('flt-semantics-placeholder').evaluate(el => el.click());
await page.waitForTimeout(2000);
await clickText('Saya Penjual'); await page.waitForTimeout(3500);
await page.mouse.click(640, 455); await page.waitForTimeout(700);
await page.keyboard.type('ikhlassabar2021@gmail.com', { delay: 20 });
await page.keyboard.press('Tab'); await page.waitForTimeout(400);
await page.keyboard.type('sabar2021', { delay: 20 });
await page.waitForTimeout(500);
await clickText('MASUK KE KASIRGO'); await page.waitForTimeout(9000);
await clickText('Kitchen (KDS)'); await page.waitForTimeout(7000);
const dump = await page.evaluate(() => {
  const out = [];
  document.querySelectorAll('flt-semantics').forEach(el => {
    const r = el.getBoundingClientRect();
    if (r.width === 0 || r.height === 0) return;
    out.push({ role: el.getAttribute('role'), label: el.getAttribute('aria-label'), text: (el.textContent||'').replace(/\n/g,' | ').slice(0,120), x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height) });
  });
  return out;
});
console.log(JSON.stringify(dump, null, 1));
await browser.close();
