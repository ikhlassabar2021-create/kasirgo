import { chromium } from 'playwright';
const base = 'https://ikhlassabar2021-create.github.io/kasirgo/';
const CODE = 'ORD26101908888';
const browser = await chromium.launch({ args: ['--no-sandbox'] });
const ctx = await browser.newContext({ viewport: { width: 1280, height: 1000 }, serviceWorkers: 'block' });
const page = await ctx.newPage();
const errors = [];
page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
const body = async () => page.evaluate(() => document.body.innerText || '');
const clickText = async (t) => {
  const els = page.locator('flt-semantics', { hasText: t });
  const n = await els.count();
  for (let i = n - 1; i >= 0; i--) {
    const bx = await els.nth(i).boundingBox();
    if (!bx || bx.width === 0) continue;
    await page.mouse.click(bx.x + bx.width / 2, bx.y + bx.height / 2);
    return true;
  }
  return false;
};
const clickLabel = async (t) => {
  const r = await page.evaluate((t) => {
    const els = [...document.querySelectorAll('flt-semantics')];
    const hit = els.find((e) => (e.getAttribute('aria-label') || '').includes(t) && e.getBoundingClientRect().width > 0);
    if (!hit) return null;
    const b = hit.getBoundingClientRect();
    return { x: b.x + b.width / 2, y: b.y + b.height / 2 };
  }, t);
  if (!r) return false;
  await page.mouse.click(r.x, r.y);
  return true;
};
await page.goto(base + '?cb=' + Date.now(), { waitUntil: 'networkidle', timeout: 120000 });
await page.waitForTimeout(5000);
await page.locator('flt-semantics-placeholder').evaluate((el) => el.click());
await page.waitForTimeout(2000);
await clickText('Saya Penjual');
await page.waitForTimeout(3500);
await page.mouse.click(640, 455);
await page.waitForTimeout(700);
await page.keyboard.type('ikhlassabar2021@gmail.com', { delay: 20 });
await page.keyboard.press('Tab');
await page.waitForTimeout(400);
await page.keyboard.type('sabar2021', { delay: 20 });
await page.waitForTimeout(500);
await clickText('MASUK KE KASIRGO');
await page.waitForTimeout(11000);
console.log('HOME_LOADED', (await body()).includes('Dashboard Owner'));
await clickText('Pesanan Masuk');
await page.waitForTimeout(2500);
await clickText('Pesanan Online');
await page.waitForTimeout(3000);
console.log('CLICK_AKTIF', await clickLabel('Aktif'));
await page.waitForTimeout(3500);
const card = await page.evaluate((code) => {
  const els = [...document.querySelectorAll('flt-semantics')];
  const cand = els
    .filter((e) => (e.textContent || '').includes(code))
    .map((e) => e.getBoundingClientRect())
    .filter((b) => b.width > 500 && b.height > 100 && b.height < 500);
  if (!cand.length) return null;
  const b = cand[cand.length - 1];
  return { x: b.x, y: b.y, w: b.width, h: b.height };
}, CODE);
console.log('CARD', JSON.stringify(card));
if (card) {
  const cx = card.x + card.w / 2;
  const cy = card.y + card.h - 14 - 22;
  await page.mouse.click(cx, cy);
  console.log('CLICKED_AT', Math.round(cx), Math.round(cy));
  await page.waitForTimeout(5000);
  const b = await body();
  console.log('SNACK_DONE', b.includes('Pesanan selesai'));
  console.log('CARD_STILL_THERE', b.includes(CODE));
  await page.screenshot({ path: '/tmp/opencode/cashier_4_done.png' });
}
console.log('ERRORS', errors.length, errors.slice(0, 3).join(' || '));
await browser.close();
