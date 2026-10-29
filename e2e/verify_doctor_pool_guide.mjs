import { chromium } from 'playwright';

const BASE = 'https://ikhlassabar2021-create.github.io/kasirgo/';
const ADMIN = BASE + 'admin/';
const out = {};

const findBox = async (page, label) => {
  const nodes = await page.evaluate((t) => [...document.querySelectorAll('flt-semantics')]
    .map((e) => { const r = e.getBoundingClientRect(); return { aria: e.getAttribute('aria-label') || '', txt: (e.textContent || '').trim(), x: r.x, y: r.y, w: r.width, h: r.height }; })
    .filter((n) => (n.aria.includes(t) || n.txt.includes(t)) && n.w > 0 && n.h > 0), label);
  if (!nodes.length) return null;
  nodes.sort((a, b) => a.w * a.h - b.w * b.h);
  return nodes[0];
};
const click = async (page, label) => { const b = await findBox(page, label); if (!b) return false; await page.mouse.click(b.x + b.w / 2, b.y + b.h / 2); return true; };
const textOf = (page) => page.evaluate(() => [...document.querySelectorAll('flt-semantics')].map((e) => (e.getAttribute('aria-label') || '') + ' ' + (e.textContent || '')).join(' | '));
const enableSemantics = async (page) => { if (await page.locator('flt-semantics-placeholder').count()) { await page.locator('flt-semantics-placeholder').evaluate((el) => el.click()); await page.waitForTimeout(1500); } };

const loginOwner = async (page) => {
  await page.goto(BASE + '?cb=' + Date.now(), { waitUntil: 'networkidle', timeout: 180000 });
  await page.waitForTimeout(5000);
  await enableSemantics(page);
  await click(page, 'Saya Penjual');
  await page.waitForTimeout(4000);
  const eb = await page.locator('input[aria-label="Email Bisnis / Owner"]').boundingBox();
  await page.mouse.click(eb.x + eb.width / 2, eb.y + eb.height / 2);
  await page.keyboard.type('ikhlassabar2021@gmail.com', { delay: 12 });
  await page.keyboard.press('Tab');
  await page.waitForTimeout(250);
  await page.keyboard.type('sabar2021', { delay: 18 });
  await click(page, 'MASUK KE KASIRGO');
  await page.waitForTimeout(16000);
};

const browser = await chromium.launch({ headless: true });

// Admin: pool token AI card + 5 slot.
const actx = await browser.newContext({ viewport: { width: 1400, height: 1000 }, serviceWorkers: 'block' });
const apage = await actx.newPage();
const aerr = [];
apage.on('console', (m) => { if (m.type() === 'error') aerr.push(m.text().slice(0, 200)); });
await apage.goto(ADMIN + '?cb=' + Date.now(), { waitUntil: 'networkidle', timeout: 120000 });
await apage.waitForTimeout(2500);
await apage.fill('input[type=email]', 'superadmin@kasirgo.com');
await apage.fill('input[type=password]', 'sabar2021');
await apage.keyboard.press('Enter');
await apage.waitForTimeout(7000);
await apage.locator('a,button', { hasText: 'Control Plane' }).first().click();
await apage.waitForTimeout(4000);
await apage.locator('button', { hasText: 'Dokter Bisnis AI' }).first().click();
await apage.waitForTimeout(6000);
let body = await apage.locator('body').innerText();
out.poolCard = body.includes('Pool Token AI (maks 5 akun)');
out.poolCounter = /Terpakai \d+ \/ 5/.test(body);
out.slotInputs = await apage.locator('input[placeholder="mis. Akun Bos 1"]').count();
out.modelInputs = await apage.locator('input[placeholder="mercury-3"]').count();
out.apiKeyInputs = (await apage.locator('input[type=password]').count()) >= 5;
out.adminErrors = aerr.length;
await apage.screenshot({ path: '/tmp/opencode/admin_doctor_pool.png', fullPage: false });

// Owner: banner AI + panduan bergambar + tombol fitur.
const octx = await browser.newContext({ viewport: { width: 1280, height: 1000 }, serviceWorkers: 'block' });
const page = await octx.newPage();
const oerr = [];
page.on('console', (m) => { if (m.type() === 'error') oerr.push(m.text().slice(0, 200)); });
await loginOwner(page);
await click(page, 'Dokter Bisnis AI');
await page.waitForTimeout(9000);
let t = await textOf(page);
out.aiBanner = t.includes('AI global aktif') || t.includes('AI otomatis aktif') || t.includes('Token AI sudah maksimal');
out.doctorOpen = t.includes('Dokter Bisnis') && (t.includes('Tanya') || t.includes('Diagnosa') || t.includes('Cek Fisik'));
// Panduan (mobile): bottom nav Lainnya -> Panduan -> pusat bantuan bergambar.
const mctx = await browser.newContext({ viewport: { width: 390, height: 844 }, serviceWorkers: 'block', isMobile: true, hasTouch: true });
const mpage = await mctx.newPage();
const merr = [];
mpage.on('console', (m) => { if (m.type() === 'error') merr.push(m.text().slice(0, 200)); });
await loginOwner(mpage);
out.lainnyaClicked = await click(mpage, 'Lainnya');
await mpage.waitForTimeout(2500);
out.panduanClicked = await click(mpage, 'Panduan');
await mpage.waitForTimeout(5000);
let mt = await textOf(mpage);
out.guideBanner = mt.includes('Panduan Bergambar');
if (out.guideBanner) { await click(mpage, 'Panduan Bergambar'); await mpage.waitForTimeout(5000); }
mt = await textOf(mpage);
out.helpCenter = mt.includes('Panduan') && mt.includes('Tiket Support');
out.topics = ['Mulai & Atur Toko', 'Jualan di Kasir (POS)', 'Laporan & Performa'].every((x) => mt.includes(x));
if (mt.includes('Jualan di Kasir (POS)')) { await click(mpage, 'Jualan di Kasir (POS)'); await mpage.waitForTimeout(4000); }
const detail = await textOf(mpage);
out.mockImage = /Simulasi|Pratinjau|Tampilan|Keranjang|Omzet|Rp ?\d/.test(detail);
out.detailSnippet = detail.slice(0, 400);
out.stepButtons = (detail.match(/Buka Kasir|Coba di Kasir|Buka Produk|Buka Laporan|Buka Pengaturan|Buat \/ Buka Tiket/g) || []).length;
out.mobileErrors = merr.length;
await mpage.screenshot({ path: '/tmp/opencode/owner_guide_mobile.png' });

console.log(JSON.stringify(out, null, 2));
await browser.close();
