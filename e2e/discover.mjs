import { chromium } from 'playwright';
const base = 'https://ikhlassabar2021-create.github.io/kasirgo/';
const browser = await chromium.launch({ args: ['--no-sandbox'] });
const ctx = await browser.newContext({ viewport: { width: 1280, height: 1000 }, serviceWorkers: 'block' });
const page = await ctx.newPage();
await page.goto(base + '?cb=' + Date.now(), { waitUntil: 'networkidle', timeout: 120000 });
await page.waitForTimeout(5000);
console.log('placeholder count', await page.locator('flt-semantics-placeholder').count());
const ph = page.locator('flt-semantics-placeholder');
if (await ph.count()) { await ph.evaluate(el => el.click()); console.log('clicked placeholder'); }
await page.waitForTimeout(3000);
const sem = await page.evaluate(() => {
  const out = [];
  document.querySelectorAll('flt-semantics, [role]').forEach(el => {
    const r = el.getBoundingClientRect();
    out.push({ tag: el.tagName, role: el.getAttribute('role'), label: el.getAttribute('aria-label'), text: (el.textContent||'').slice(0,40), x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height) });
  });
  return out.filter(o => o.label || o.text).slice(0, 60);
});
console.log(JSON.stringify(sem, null, 1));
await page.screenshot({ path: '/tmp/opencode/discover.png' });
await browser.close();
