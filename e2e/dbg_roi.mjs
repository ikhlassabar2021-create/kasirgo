import { chromium } from 'playwright';
const BASE = 'https://ikhlassabar2021-create.github.io/kasirgo/';
const login = async (page, email) => {
  await page.goto(BASE + '?cb=' + Date.now(), { waitUntil: 'networkidle', timeout: 120000 });
  await page.waitForTimeout(5000);
  await page.locator('flt-semantics-placeholder').evaluate((el) => el.click());
  await page.waitForTimeout(2000);
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
  await clickText('Saya Penjual');
  await page.waitForTimeout(4000);
  const b = await page.locator('input[aria-label="Email Bisnis / Owner"]').boundingBox();
  await page.mouse.click(b.x + b.width / 2, b.y + b.height / 2);
  await page.waitForTimeout(500);
  await page.keyboard.type(email, { delay: 25 });
  await page.keyboard.press('Tab');
  await page.waitForTimeout(600);
  await page.keyboard.type('sabar2021', { delay: 40 });
  await page.waitForTimeout(800);
  await clickText('MASUK KE KASIRGO');
  await page.waitForTimeout(12000);
  return clickText;
};
const run = async () => {
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 1200 }, serviceWorkers: 'block' });
  const page = await ctx.newPage();
  const sem = async () => page.evaluate(() => Array.from(document.querySelectorAll('flt-semantics')).map(e => (e.getAttribute('aria-label')||'') + ' ' + (e.textContent||'')).join('\n'));
  const clickText = await login(page, 'ikhlassabar2021@gmail.com');
  console.log('OPEN', await clickText('Dokter Bisnis AI'));
  await page.waitForTimeout(9000);
  for (let i = 0; i < 12; i++) {
    if ((await sem()).includes('Rapor ROI Promosi')) break;
    await page.mouse.move(640, 700);
    await page.mouse.wheel(0, 500);
    await page.waitForTimeout(700);
  }
  console.log('FOUND_CTA', (await sem()).includes('Rapor ROI Promosi'));
  const els = page.locator('flt-semantics', { hasText: 'Rapor ROI Promosi' });
  const n = await els.count();
  console.log('N', n);
  for (let i = 0; i < n; i++) {
    const box = await els.nth(i).boundingBox();
    console.log('BOX', i, JSON.stringify(box));
  }
  console.log('CLICK', await clickText('Rapor ROI Promosi'));
  await page.waitForTimeout(8000);
  const t = (await sem()).replace(/\s+/g, ' ');
  console.log('AFTER', t.slice(0, 700));
  await page.screenshot({ path: '/tmp/opencode/doctor_roi2.png' });
  await browser.close();
};
run().catch(e => { console.error(e); process.exit(1); });
