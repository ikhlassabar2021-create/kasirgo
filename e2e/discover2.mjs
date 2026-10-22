import { chromium } from 'playwright';
const base = 'https://ikhlassabar2021-create.github.io/kasirgo/';
const browser = await chromium.launch({ args: ['--no-sandbox'] });
const ctx = await browser.newContext({ viewport: { width: 1280, height: 1000 }, serviceWorkers: 'block' });
const page = await ctx.newPage();
await page.goto(base + '?cb=' + Date.now(), { waitUntil: 'networkidle', timeout: 120000 });
await page.waitForTimeout(5000);
await page.locator('flt-semantics-placeholder').evaluate(el => el.click());
await page.waitForTimeout(2500);
const clickText = async (t) => {
  const el = page.locator('flt-semantics', { hasText: t }).last();
  const box = await el.boundingBox();
  if (!box) return false;
  await page.mouse.click(box.x + box.width/2, box.y + box.height/2);
  return true;
};
console.log('seller click', await clickText('Saya Penjual'));
await page.waitForTimeout(4000);
const dump = await page.evaluate(() => {
  const out = [];
  document.querySelectorAll('flt-semantics').forEach(el => {
    const r = el.getBoundingClientRect();
    if (r.width === 0 || r.height === 0) return;
    out.push({ role: el.getAttribute('role'), label: el.getAttribute('aria-label'), text: (el.textContent||'').replace(/\n/g,' | ').slice(0,60), x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height) });
  });
  return out;
});
console.log(JSON.stringify(dump, null, 1).slice(0, 6000));
await page.screenshot({ path: '/tmp/opencode/discover2.png' });
await browser.close();
