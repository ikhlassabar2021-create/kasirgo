import { chromium } from 'playwright';

const BASE = process.env.KASIRGO_BASE || 'https://ikhlassabar2021-create.github.io/kasirgo/';
const QA_TITLE = '__QA_UI__ Pelanggan suka gula 1 kg';

const b = await chromium.launch({ args: ['--no-sandbox'] });
const c = await b.newContext({
  viewport: { width: 1280, height: 1200 },
  serviceWorkers: 'block',
});
const p = await c.newPage();
const errs = [];
p.on('console', (m) => {
  if (m.type() === 'error') errs.push(m.text().slice(0, 160));
});

const clickText = async (t) => {
  const els = p.locator('flt-semantics', { hasText: t });
  const n = await els.count();
  for (let i = n - 1; i >= 0; i--) {
    const el = els.nth(i);
    const bx = await el.boundingBox();
    if (!bx || bx.width === 0) continue;
    await p.mouse.click(bx.x + bx.width / 2, bx.y + bx.height / 2);
    return true;
  }
  return false;
};

const dump = (needle) =>
  p.evaluate((n) => {
    const out = [];
    for (const e of document.querySelectorAll('flt-semantics')) {
      const l = e.getAttribute('aria-label') || '';
      if (l.includes(n)) {
        const r = e.getBoundingClientRect();
        out.push({ l: l.slice(0, 90), x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height) });
      }
    }
    return out;
  }, needle);

await p.goto(BASE + '?cb=' + Date.now(), { waitUntil: 'networkidle', timeout: 120000 });
await p.waitForTimeout(6000);
await p.locator('flt-semantics-placeholder').evaluate((el) => el.click());
await p.waitForTimeout(2500);
await clickText('Saya Penjual');
await p.waitForTimeout(4000);

const eb = await p.locator('input[aria-label="Email Bisnis / Owner"]').boundingBox();
await p.mouse.click(eb.x + eb.width / 2, eb.y + eb.height / 2);
await p.waitForTimeout(500);
await p.keyboard.type('ikhlassabar2021@gmail.com', { delay: 25 });
await p.keyboard.press('Tab');
await p.waitForTimeout(600);
await p.keyboard.type('sabar2021', { delay: 40 });
await p.waitForTimeout(800);
await clickText('MASUK KE KASIRGO');
await p.waitForTimeout(12000);

await clickText('Dokter Bisnis AI');
await p.waitForTimeout(7000);
await clickText('Menu Dokter');
await p.waitForTimeout(1500);
await clickText('Riwayat Kasus');
await p.waitForTimeout(6000);

console.log('PENGETAHUAN_NODES', JSON.stringify(await dump('Pengetahu')));
console.log('ROW_NODES', JSON.stringify(await dump(QA_TITLE)));

const row = (await dump(QA_TITLE))[0];
console.log('ROW', JSON.stringify(row));
await p.mouse.click(row.x + row.w - 20, row.y + 20);
await p.waitForTimeout(2500);
const del = await p.evaluate(() => {
  const e = [...document.querySelectorAll('flt-semantics')].find((n) =>
    (n.getAttribute('aria-label') || '') === 'Hapus'
  );
  if (!e) return null;
  const r = e.getBoundingClientRect();
  return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
});
console.log('DEL_ITEM', JSON.stringify(del));
if (del) {
  await p.mouse.click(del.x, del.y);
  await p.waitForTimeout(3000);
  const ok = await clickText('Hapus');
  await p.waitForTimeout(6000);
  console.log('CONFIRM', ok);
  console.log('ROW_GONE', (await dump(QA_TITLE)).length === 0);
}

console.log('ERRORS', errs.length, JSON.stringify(errs.slice(0, 3)));
await b.close();
