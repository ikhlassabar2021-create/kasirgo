import { chromium } from 'playwright';

const BASE = process.env.KASIRGO_BASE || 'https://ikhlassabar2021-create.github.io/kasirgo/';
const EMAIL = 'ikhlassabar2021@gmail.com';
const PASS = 'sabar2021';

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

const hasBtn = async (label) =>
  (await p.locator('flt-semantics[role="button"]').filter({ hasText: new RegExp('^' + label + '$') }).count()) > 0;

const clickBtn = async (label) => {
  const el = p
    .locator('flt-semantics[role="button"]')
    .filter({ hasText: new RegExp('^' + label.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '$') })
    .first();
  if ((await el.count()) === 0) return false;
  const bx = await el.boundingBox();
  if (!bx) return false;
  await p.mouse.click(bx.x + bx.width / 2, bx.y + bx.height / 2);
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
await p.keyboard.type(EMAIL, { delay: 25 });
await p.keyboard.press('Tab');
await p.waitForTimeout(600);
await p.keyboard.type(PASS, { delay: 40 });
await p.waitForTimeout(800);
await clickText('MASUK KE KASIRGO');
await p.waitForTimeout(13000);
console.log('LOGIN', await has('Dokter Bisnis AI'));

await clickText('Dokter Bisnis AI');
await p.waitForTimeout(8000);
console.log('CHAT_OPEN', await has('Dokter Bisnis'));
console.log('CHAT_INPUT', await hasBtn('Bicara'));
console.log('NO_CARD_IDENTITY', !(await has('Identitas Bisnis')));

const menuOpen = await clickBtn('Menu Dokter');
await p.waitForTimeout(1800);
console.log('MENU_OPEN', menuOpen, await has('Menu Dokter Bisnis'));
console.log('ENTRY_OVERVIEW', await has('Ringkasan Bisnis'));
console.log('ENTRY_TASKS', await has('Tugas & Delegasi'));
console.log('ENTRY_VOICE', await has('Persona & Suara'));
console.log('ENTRY_CASES', await has('Riwayat Kasus'));
console.log('ENTRY_REPORT', await has('Lapor ke Bos'));

const panes = ['Ringkasan Bisnis', 'Tugas & Delegasi', 'Persona & Suara'];

for (const entry of panes) {
  await clickBtn('Menu Dokter');
  await p.waitForTimeout(1200);
  const opened = await clickText(entry);
  await p.waitForTimeout(2200);
  const menuClosed = !(await has('Menu Dokter Bisnis'));
  const titleOk = await has(entry);
  const chatHidden = !(await hasBtn('Bicara'));
  const backOk = await clickBtn('Kembali ke chat');
  await p.waitForTimeout(1800);
  console.log(`PANE ${entry}`, opened, menuClosed, titleOk, chatHidden, backOk, await hasBtn('Bicara'));
}

await clickBtn('Menu Dokter');
await p.waitForTimeout(1200);
await clickText('Riwayat Kasus');
await p.waitForTimeout(6000);
console.log('CASES_OPEN', await has('Riwayat Kasus'), await has('Tambah Pengetahuan'));
await clickBtn('Back');
await p.waitForTimeout(4000);
console.log('BACK_TO_CHAT', await hasBtn('Bicara'));

console.log('ERRORS', errs.length, errs.slice(0, 3));
await b.close();
