import { chromium } from 'playwright';

const base = 'https://ikhlassabar2021-create.github.io/kasirgo/';
const CODE = 'ORD26101908888';

const browser = await chromium.launch({ args: ['--no-sandbox'] });
const ctx = await browser.newContext({
  viewport: { width: 1280, height: 1000 },
  serviceWorkers: 'block',
});
const page = await ctx.newPage();
const errors = [];
page.on('console', (m) => {
  if (m.type() === 'error') errors.push(m.text());
});

const clickText = async (t) => {
  const els = page.locator('flt-semantics', { hasText: t });
  const n = await els.count();
  for (let i = n - 1; i >= 0; i--) {
    const el = els.nth(i);
    const box = await el.boundingBox();
    if (!box || box.width === 0) continue;
    await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
    return true;
  }
  return false;
};

const body = async () =>
  page.evaluate(() => document.body.innerText || document.querySelector('flt-semantics')?.textContent || '');

const cardLabels = async () =>
  page.evaluate(() =>
    [...document.querySelectorAll('flt-semantics')]
      .map((e) => e.getAttribute('aria-label') || '')
      .filter((t) => t.includes('ORD'))
  );

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

console.log('CLICK_PESANAN_MASUK', await clickText('Pesanan Masuk'));
await page.waitForTimeout(2500);
console.log('CLICK_PESANAN_ONLINE', await clickText('Pesanan Online'));
await page.waitForTimeout(3500);
console.log('ORDERS_LABELS', JSON.stringify(await cardLabels()));
await page.screenshot({ path: '/tmp/opencode/cashier_1_list.png' });

const clickLabel = async (t) => {
  const r = await page.evaluate((t) => {
    const els = [...document.querySelectorAll('flt-semantics')];
    const hit = els.find((e) => {
      const l = e.getAttribute('aria-label') || '';
      const b = e.getBoundingClientRect();
      return l.includes(t) && b.width > 0;
    });
    if (!hit) return null;
    const b = hit.getBoundingClientRect();
    return { x: b.x + b.width / 2, y: b.y + b.height / 2 };
  }, t);
  if (!r) return false;
  await page.mouse.click(r.x, r.y);
  return true;
};

const clickButtonInCard = async (code, label) => {
  const r = await page.evaluate(({ code, label }) => {
    const els = [...document.querySelectorAll('flt-semantics')];
    const card = els.find((e) => (e.getAttribute('aria-label') || '').includes(code));
    if (!card) return { err: 'card not found' };
    const c = card.getBoundingClientRect();
    const btn = els.find((e) => {
      const b = e.getBoundingClientRect();
      return (
        e.getAttribute('role') === 'button' &&
        (e.textContent || '').trim() === label &&
        b.y >= c.y &&
        b.y <= c.y + c.height &&
        b.width > 0
      );
    });
    if (!btn) return { err: 'button not found' };
    const b = btn.getBoundingClientRect();
    return { x: b.x + b.width / 2, y: b.y + b.height / 2 };
  }, { code, label });
  if (r.err) return r;
  await page.mouse.click(r.x, r.y);
  return true;
};

console.log('CLICK_VALID', await clickButtonInCard(CODE, 'Pembayaran Valid & Proses'));
await page.waitForTimeout(4000);
console.log('AFTER_VALID', JSON.stringify(await cardLabels()));
console.log('SNACK', (await body()).includes('Pembayaran valid'));
await page.screenshot({ path: '/tmp/opencode/cashier_2_valid.png' });

console.log('CLICK_AKTIF', await clickLabel('Aktif'));
await page.waitForTimeout(2500);
console.log('AKTIF_LABELS', JSON.stringify(await cardLabels()));
console.log('BTN_LABELS', JSON.stringify(await page.evaluate(() =>
  [...document.querySelectorAll('flt-semantics[role="button"]')]
    .map((e) => (e.getAttribute('aria-label') || '').trim())
    .filter((t) => t && !t.includes('ORD')))));
await page.screenshot({ path: '/tmp/opencode/cashier_2b_aktif.png' });
console.log('CLICK_SELESAI', await clickButtonInCard(CODE, 'Selesai'));
await page.waitForTimeout(5000);
console.log('AFTER_COMPLETE_BODY', (await body()).slice(0, 400));
console.log('SNACK_DONE', (await body()).includes('Pesanan selesai'));
await page.screenshot({ path: '/tmp/opencode/cashier_3_done.png' });

console.log('ERRORS', errors.length, errors.slice(0, 3).join(' || '));
await browser.close();
