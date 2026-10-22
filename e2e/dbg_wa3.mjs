import { chromium } from 'playwright';
const BASE='http://localhost:8099/kasirgo/';
const EMAIL='ikhlassabar2021@gmail.com';
const findBox = async (page, t) => {
  const els = page.locator('flt-semantics', { hasText: t });
  const n = await els.count();
  let best = null;
  for (let i = n - 1; i >= 0; i--) {
    const box = await els.nth(i).boundingBox();
    if (!box || box.width === 0 || box.height === 0) continue;
    if (box.y < 0 || box.y + box.height > 1500) continue;
    if (box.width > 1100) continue;
    const area = box.width * box.height;
    if (!best || area < best.area) best = { ...box, area };
  }
  return best;
};
const scrollTo = async (page, t, tries = 10) => {
  for (let i = 0; i < tries; i++) {
    const box = await findBox(page, t);
    if (box) return box;
    await page.mouse.move(640, 800);
    await page.mouse.wheel(0, 600);
    await page.waitForTimeout(900);
  }
  return null;
};
const clickText = async (page, t) => {
  const box = await findBox(page, t);
  if (!box) return false;
  await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
  return true;
};
const textOf = (page) => page.evaluate(() => [...document.querySelectorAll('flt-semantics')].map(e => (e.getAttribute('aria-label')||'') + ' ' + (e.textContent||'')).join(' | '));
const b = await chromium.launch({ args: ['--no-sandbox'] });
const ctx = await b.newContext({ viewport: { width: 1280, height: 1500 }, serviceWorkers: 'block', acceptDownloads: true });
const page = await ctx.newPage();
await page.goto(BASE + '?cb=' + Date.now(), { waitUntil: 'networkidle', timeout: 180000 });
await page.waitForTimeout(6000);
await page.locator('flt-semantics-placeholder').evaluate(el => el.click());
await page.waitForTimeout(2500);
await clickText(page, 'Saya Penjual');
await page.waitForTimeout(4000);
const eb = await page.locator('input[aria-label="Email Bisnis / Owner"]').boundingBox();
await page.mouse.click(eb.x + eb.width / 2, eb.y + eb.height / 2);
await page.waitForTimeout(500);
await page.keyboard.type(EMAIL, { delay: 25 });
await page.waitForTimeout(400); await page.keyboard.press('Tab'); await page.waitForTimeout(600);
await page.keyboard.type('sabar2021', { delay: 40 }); await page.waitForTimeout(800);
await clickText(page, 'MASUK KE KASIRGO');
await page.waitForTimeout(22000);
await clickText(page, 'Dokter Bisnis AI');
await page.waitForTimeout(12000);
const rb = await scrollTo(page, 'Lihat Hasil Diagnosa');
await page.mouse.click(rb.x + rb.width / 2, rb.y + rb.height / 2);
await page.waitForTimeout(5000);
await clickText(page, 'Simpan / Bagikan');
await page.waitForTimeout(2500);
const nodes = await page.evaluate(() => [...document.querySelectorAll('flt-semantics')].map(e => ({ t: (e.textContent||'').slice(0,40), r: e.getAttribute('role'), id: e.id, bb: e.getBoundingClientRect() })).filter(o => /WhatsApp|PDF|Tutup/.test(o.t)));
console.log(JSON.stringify(nodes.map(o => ({t:o.t, role:o.r, id:o.id, x:o.bb.x|0, y:o.bb.y|0, w:o.bb.width|0, h:o.bb.height|0})), null, 1));
await page.evaluate(() => { const e = document.getElementById('flt-semantic-node-219'); if (e) e.click(); });
await page.waitForTimeout(1500);
console.log('AFTER_JS_CLICK:', (await textOf(page)).slice(-900));
await page.waitForTimeout(3000);
console.log('AFTER_JS_CLICK_4s:', (await textOf(page)).slice(-900));
await b.close();
