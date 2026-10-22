import { chromium } from 'playwright';
const base = 'https://ikhlassabar2021-create.github.io/kasirgo/';
const browser = await chromium.launch({ args: ['--no-sandbox'] });
const ctx = await browser.newContext({ viewport: { width: 1280, height: 1000 }, serviceWorkers: 'block' });
const page = await ctx.newPage();
const errors = [];
page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
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
await page.keyboard.type('ikhlassabar2021+kokitest@gmail.com', { delay: 20 });
await page.keyboard.press('Tab'); await page.waitForTimeout(400);
await page.keyboard.type('sabar2021', { delay: 20 });
await page.waitForTimeout(500);
await clickText('MASUK KE KASIRGO'); await page.waitForTimeout(10000);
const label = await page.evaluate(() => {
  const el = [...document.querySelectorAll('flt-semantics[role="button"]')].find(e => (e.getAttribute('aria-label')||'').includes('ORD26101909999'));
  return el ? el.getAttribute('aria-label') : null;
});
const body = await page.evaluate(() => document.querySelector('flt-semantics')?.textContent || '');
console.log('KITCHEN_LANDS_KDS', body.includes('Kitchen Display (KDS)') || body.includes('Semua Antrean'));
console.log('KITCHEN_CARD', JSON.stringify(label));
console.log('ERRORS', errors.length, errors.slice(0,3).join(' || '));
await page.screenshot({ path: '/tmp/opencode/kds_kitchen.png' });
await browser.close();
