import { chromium } from 'playwright';
const BASE = 'https://ikhlassabar2021-create.github.io/kasirgo/';
const b = await chromium.launch({ args: ['--no-sandbox', '--use-fake-ui-for-media-stream'] });
const ctx = await b.newContext({ viewport: { width: 1280, height: 1200 }, serviceWorkers: 'block', permissions: ['microphone'] });
const page = await ctx.newPage();
await page.goto(BASE + '?cb=' + Date.now(), { waitUntil: 'networkidle', timeout: 120000 });
await page.waitForTimeout(5000);
await page.locator('flt-semantics-placeholder').evaluate((el) => el.click());
await page.waitForTimeout(2000);
const clickText = async (t) => {
  const els = page.locator('flt-semantics', { hasText: t });
  for (let i = (await els.count()) - 1; i >= 0; i--) {
    const box = await els.nth(i).boundingBox();
    if (!box || box.width === 0) continue;
    await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
    return true;
  }
  return false;
};
await clickText('Saya Penjual');
await page.waitForTimeout(4000);
const emailBox = await page.locator('input[aria-label="Email Bisnis / Owner"]').boundingBox();
await page.mouse.click(emailBox.x + emailBox.width / 2, emailBox.y + emailBox.height / 2);
await page.keyboard.type('ikhlassabar2021@gmail.com', { delay: 20 });
await page.keyboard.press('Tab');
await page.waitForTimeout(500);
await page.keyboard.type('sabar2021', { delay: 30 });
await clickText('MASUK KE KASIRGO');
await page.waitForTimeout(12000);
await clickText('Dokter Bisnis AI');
await page.waitForTimeout(8000);
const inputs = await page.evaluate(() => Array.from(document.querySelectorAll('input,textarea')).map(el => ({ label: el.getAttribute('aria-label'), ph: el.getAttribute('placeholder'), val: el.value })));
console.log('INPUTS', JSON.stringify(inputs));
const sem = await page.evaluate(() => Array.from(document.querySelectorAll('flt-semantics')).map(el => (el.getAttribute('aria-label')||'')+' | '+(el.textContent||'')).filter(s => /mikrofon|ucapkan|Tulis|Bicara|dengarkan/i.test(s)));
console.log('SEM', JSON.stringify(sem, null, 1));
await b.close();
