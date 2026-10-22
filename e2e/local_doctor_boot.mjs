import { chromium } from 'playwright';

const BASE = 'http://127.0.0.1:8123/kasirgo/';

const browser = await chromium.launch({ args: ['--no-sandbox', '--use-fake-ui-for-media-stream'] });
const ctx = await browser.newContext({ viewport: { width: 1280, height: 1400 }, serviceWorkers: 'block' });
const page = await ctx.newPage();
const errors = [];
page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
page.on('pageerror', (e) => errors.push('PAGEERROR ' + e.message));

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

const semText = async () => page.evaluate(() =>
  Array.from(document.querySelectorAll('flt-semantics'))
    .map((el) => (el.getAttribute('aria-label') || '') + '\n' + (el.textContent || ''))
    .join('\n'));

await page.goto(BASE + '?cb=' + Date.now(), { waitUntil: 'networkidle', timeout: 120000 });
await page.waitForTimeout(5000);
await page.locator('flt-semantics-placeholder').evaluate((el) => el.click());
await page.waitForTimeout(2000);
console.log('SELLER', await clickText('Saya Penjual'));
await page.waitForTimeout(4000);
const emailBox = await page.locator('input[aria-label="Email Bisnis / Owner"]').boundingBox();
await page.mouse.click(emailBox.x + emailBox.width / 2, emailBox.y + emailBox.height / 2);
await page.waitForTimeout(400);
await page.keyboard.type('ikhlassabar2021@gmail.com', { delay: 20 });
await page.keyboard.press('Tab');
await page.waitForTimeout(500);
await page.keyboard.type('sabar2021', { delay: 30 });
await page.waitForTimeout(600);
console.log('LOGIN', await clickText('MASUK KE KASIRGO'));
await page.waitForTimeout(12000);
console.log('DOCTOR_OPEN', await clickText('Dokter Bisnis AI'));
await page.waitForTimeout(9000);

const txt = await semText();
console.log('HAS_CHAT', txt.includes('Tulis atau ucapkan pertanyaan bisnis'));
console.log('HAS_PERSONA', txt.includes('Persona Dokter'));
console.log('HAS_LEXICON_HINT', txt.includes('Suara aktif') || txt.includes('Bicara'));
console.log('ERRORS', errors.length);
if (errors.length) console.log(errors.slice(0, 6).join('\n'));
await page.screenshot({ path: '/tmp/opencode/local_doctor.png', fullPage: false });
await browser.close();
