import { chromium } from 'playwright';
const base = 'https://ikhlassabar2021-create.github.io/kasirgo/';
const browser = await chromium.launch({ args: ['--no-sandbox'] });
const ctx = await browser.newContext({ viewport: { width: 1280, height: 1000 }, serviceWorkers: 'block' });
const page = await ctx.newPage();
const errors = [];
page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });

const semText = () => page.evaluate(() => document.querySelector('flt-semantics')?.textContent || '');
const clickText = async (t, opts = {}) => {
  const els = page.locator('flt-semantics', { hasText: t });
  const n = await els.count();
  for (let i = n - 1; i >= 0; i--) {
    const el = els.nth(i);
    const box = await el.boundingBox();
    if (!box || box.width === 0) continue;
    if (opts.exact && (await el.textContent()).trim() !== t) continue;
    await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
    return true;
  }
  return false;
};

await page.goto(base + '?cb=' + Date.now(), { waitUntil: 'networkidle', timeout: 120000 });
await page.waitForTimeout(5000);
await page.locator('flt-semantics-placeholder').evaluate(el => el.click());
await page.waitForTimeout(2000);
console.log('STEP seller', await clickText('Saya Penjual'));
await page.waitForTimeout(3500);

await page.mouse.click(455 + 185, 431 + 24);
await page.waitForTimeout(700);
await page.keyboard.type('ikhlassabar2021@gmail.com', { delay: 25 });
await page.keyboard.press('Tab');
await page.waitForTimeout(400);
await page.keyboard.type('sabar2021', { delay: 25 });
await page.waitForTimeout(600);
console.log('STEP login', await clickText('MASUK KE KASIRGO'));
await page.waitForTimeout(9000);
let t = await semText();
console.log('HOME_HAS_KDS', t.includes('Kitchen (KDS)'));
await page.screenshot({ path: '/tmp/opencode/kds_home.png', fullPage: false });

console.log('STEP open kds', await clickText('Kitchen (KDS)'));
await page.waitForTimeout(7000);
t = await semText();
console.log('KDS_HAS_ORDER', t.includes('ORD26101909999'));
console.log('KDS_HAS_ONLINE', t.includes('ONLINE'));
console.log('KDS_HAS_ACTION', t.includes('TANDAI SIAP SAJI'));
await page.screenshot({ path: '/tmp/opencode/kds_screen.png', fullPage: false });
console.log('KDS_TEXT_SNIPPET', t.slice(0, 700).replace(/\n/g, ' | '));

console.log('STEP mark ready', await clickText('TANDAI SIAP SAJI'));
await page.waitForTimeout(5000);
t = await semText();
console.log('AFTER_HAS_WAIT_CASHIER', t.includes('SIAP - TUNGGU KASIR'));
await page.screenshot({ path: '/tmp/opencode/kds_ready.png', fullPage: false });
console.log('ERRORS', errors.length, errors.slice(0, 4).join(' || '));
await browser.close();
