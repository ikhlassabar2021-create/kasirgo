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

const has = async (t) =>
  p.evaluate((needle) => {
    const nodes = [...document.querySelectorAll('flt-semantics')];
    return nodes.some((e) =>
      ((e.getAttribute('aria-label') || '') + ' ' + (e.textContent || '')).includes(needle));
  }, t);

const inputByLabel = async (label) => {
  const el = p.locator(`input[aria-label="${label}"], textarea[aria-label="${label}"]`).first();
  const bx = await el.boundingBox();
  if (!bx) return false;
  await p.mouse.click(bx.x + bx.width / 2, bx.y + bx.height / 2);
  await p.waitForTimeout(400);
  return true;
};

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
console.log('DOCTOR_OPEN', await has('Dokter Bisnis'));

await clickText('Menu Dokter');
await p.waitForTimeout(1500);
const opened = await clickText('Riwayat Kasus');
await p.waitForTimeout(6000);
console.log('CASES_OPEN', opened, await has('Riwayat Kasus'));
console.log('HAS_KNOWLEDGE_BTN', await has('Tambah Pengetahuan'));

const formOpen = await clickText('Tambah Pengetahuan');
await p.waitForTimeout(3000);
console.log('FORM_OPEN', formOpen, await has('Catatan ini akan diingat'));

const tOk = await inputByLabel('Judul');
await p.keyboard.type(QA_TITLE, { delay: 20 });
const cOk = await inputByLabel('Isi pengetahuan');
await p.keyboard.type('Pelanggan langganan gula pasir 1 kg tiap Sabtu pagi.', { delay: 15 });
console.log('FIELDS', tOk, cOk);

const saved = await clickText('Simpan Pengetahuan');
await p.waitForTimeout(1800);
const snack = await has('Pengetahuan disimpan');
await p.waitForTimeout(5000);
console.log('SAVED', saved, snack);
console.log('SECTION_KNOWLEDGE', await has('Pengetahuan Saya'));
console.log('ROW_TITLE', await has(QA_TITLE));

const rowCount = await p.evaluate(
  (needle) =>
    [...document.querySelectorAll('flt-semantics')].filter((e) =>
      (e.getAttribute('aria-label') || '').includes(needle)
    ).length,
  QA_TITLE
);
console.log('ROW_COUNT', rowCount);

console.log('ERRORS', errs.length, JSON.stringify(errs.slice(0, 3)));
await b.close();
