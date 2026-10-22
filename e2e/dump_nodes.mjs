import { chromium } from 'playwright';
const BASE = process.env.BASE || 'http://localhost:8099/kasirgo/';
const login = async (page, email) => {
  await page.goto(BASE + '?cb=' + Date.now(), { waitUntil: 'networkidle', timeout: 180000 });
  await page.waitForTimeout(6000);
  await page.locator('flt-semantics-placeholder').evaluate((el) => el.click());
  await page.waitForTimeout(2500);
  const clickText = async (t) => {
    const els = page.locator('flt-semantics', { hasText: t });
    const n = await els.count();
    for (let i = n - 1; i >= 0; i--) {
      const el = els.nth(i); const box = await el.boundingBox();
      if (!box || box.width === 0) continue;
      await page.mouse.click(box.x + box.width/2, box.y + box.height/2); return true;
    }
    return false;
  };
  await clickText('Saya Penjual'); await page.waitForTimeout(4000);
  const emailBox = await page.locator('input[aria-label="Email Bisnis / Owner"]').boundingBox();
  await page.mouse.click(emailBox.x + emailBox.width/2, emailBox.y + emailBox.height/2);
  await page.waitForTimeout(500);
  await page.keyboard.type(email, { delay: 25 }); await page.waitForTimeout(400);
  await page.keyboard.press('Tab'); await page.waitForTimeout(600);
  await page.keyboard.type('sabar2021', { delay: 40 }); await page.waitForTimeout(800);
  await clickText('MASUK KE KASIRGO'); await page.waitForTimeout(14000);
  return clickText;
};
const semText = (page) => page.evaluate(() => (document.querySelector('flt-semantics')?.textContent||''));
const browser = await chromium.launch({ args: ['--no-sandbox'] });
const ctx = await browser.newContext({ viewport: { width: 1280, height: 1500 }, serviceWorkers: 'block' });
const page = await ctx.newPage();
const clickText = await login(page, 'ikhlassabar2021@gmail.com');
let opened = await clickText('Dokter Bisnis AI');
if (!opened) { for (let i=0;i<8;i++){ await page.mouse.wheel(0,500); await page.waitForTimeout(800); if (await clickText('Dokter Bisnis AI')) { opened=true; break; } } }
await page.waitForTimeout(7000);
for (let i=0;i<14;i++){ if ((await semText(page)).includes('Delegasi Tugas')) break; await page.mouse.wheel(0,600); await page.waitForTimeout(900); }
await clickText('Delegasi Tugas'); await page.waitForTimeout(6000);
for (let i=0;i<12;i++){ if ((await semText(page)).includes('Laporan lengkap')) break; await page.mouse.wheel(0,500); await page.waitForTimeout(700); }
await clickText('Laporan lengkap'); await page.waitForTimeout(8000);
const nodes = await page.evaluate(() => {
  return [...document.querySelectorAll('flt-semantics')].map((el) => {
    const r = el.getBoundingClientRect();
    const label = el.getAttribute('aria-label');
    const own = [...el.childNodes].filter(n => n.nodeType === 3).map(n => n.textContent.trim()).join('');
    return { label, own, x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height), role: el.getAttribute('role') };
  }).filter(n => (n.label || n.own) && n.w > 0);
});
console.log(JSON.stringify(nodes, null, 0).slice(0, 8000));
console.log('COUNT', nodes.length);
await browser.close();
