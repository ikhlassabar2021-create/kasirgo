import { chromium } from 'playwright';

const BASE = 'https://ikhlassabar2021-create.github.io/kasirgo/';
const ADMIN = BASE + 'admin/';
const SUPA = 'https://lmvjecdvfzsmrowwwpck.supabase.co';
const KEY = 'sb_publishable_8RJnG66i_37cih8GTG1sBA_0B91KOW_';

const findBox = async (page, label, latest = false) => {
  const nodes = await page.evaluate((t) => {
    return [...document.querySelectorAll('flt-semantics')]
      .map((e) => {
        const r = e.getBoundingClientRect();
        return {
          aria: e.getAttribute('aria-label') || '',
          txt: (e.textContent || '').trim(),
          x: r.x, y: r.y, w: r.width, h: r.height,
        };
      })
      .filter((n) => (n.aria.includes(t) || n.txt.includes(t)) && n.w > 0 && n.h > 0);
  }, label);
  if (!nodes.length) return null;
  nodes.sort((a, b) => a.w * a.h - b.w * b.h);
  return latest ? nodes[nodes.length - 1] : nodes[0];
};

const click = async (page, label, latest) => {
  const box = await findBox(page, label, latest);
  if (!box) return false;
  await page.mouse.click(box.x + box.w / 2, box.y + box.h / 2);
  return true;
};

const textOf = (page) =>
  page.evaluate(() =>
    [...document.querySelectorAll('flt-semantics')]
      .map((e) => (e.getAttribute('aria-label') || '') + ' ' + (e.textContent || ''))
      .join(' | '));

const enableSemantics = async (page) => {
  const ph = p => p.locator('flt-semantics-placeholder').count();
  if (await ph(page)) {
    await page.locator('flt-semantics-placeholder').evaluate((el) => el.click());
    await page.waitForTimeout(1500);
  }
};

const scrollDown = async (page, n = 5) => {
  for (let i = 0; i < n; i++) {
    await page.mouse.move(700, 900);
    await page.mouse.wheel(0, 600);
    await page.waitForTimeout(500);
  }
};

const loginOwner = async (page) => {
  await page.goto(BASE + '?cb=' + Date.now(), { waitUntil: 'networkidle', timeout: 180000 });
  await page.waitForTimeout(5000);
  await enableSemantics(page);
  await click(page, 'Saya Penjual');
  await page.waitForTimeout(4000);
  const emailBox = await page.locator('input[aria-label="Email Bisnis / Owner"]').boundingBox();
  await page.mouse.click(emailBox.x + emailBox.width / 2, emailBox.y + emailBox.height / 2);
  await page.keyboard.type('ikhlassabar2021@gmail.com', { delay: 15 });
  await page.keyboard.press('Tab');
  await page.waitForTimeout(300);
  await page.keyboard.type('sabar2021', { delay: 20 });
  await click(page, 'MASUK KE KASIRGO');
  await page.waitForTimeout(16000);
};

const openSettings = async (page) => {
  await page.reload({ waitUntil: 'networkidle' });
  await page.waitForTimeout(6000);
  await enableSemantics(page);
  await page.waitForTimeout(7000);
  await click(page, 'Pengaturan');
  await page.waitForTimeout(4500);
};

const run = async () => {
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const ctx = await browser.newContext({
    viewport: { width: 1280, height: 1600 },
    serviceWorkers: 'block',
  });
  const page = await ctx.newPage();
  const errors = [];
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text().slice(0, 200)); });
  const out = {};

  try {
    await loginOwner(page);
    let txt = await textOf(page);
    out.ownerHome = txt.includes('Pesanan Masuk');

    await click(page, 'Pesanan Masuk', true);
    await page.waitForTimeout(4000);
    txt = await textOf(page);
    if (!(txt.includes('Dine-in') && txt.includes('Online'))) {
      await click(page, 'Pesanan Masuk');
      await page.waitForTimeout(4000);
      txt = await textOf(page);
    }
    out.ordersScreen = txt.includes('Dine-in') && txt.includes('Online');
    out.ordersHeader = /Pantau pesanan/i.test(txt);

    await openSettings(page);
    await scrollDown(page, 5);
    out.settingsLoaded = (await textOf(page)).includes('Akun & Bantuan');
    out.ticketRow = await click(page, 'Tiket Bantuan');
    await page.waitForTimeout(4000);
    txt = await textOf(page);
    out.ticketsScreen = txt.includes('Tiket Bantuan') && txt.includes('Tiket Baru');

    const opened = await click(page, 'Tiket Baru');
    await page.waitForTimeout(2000);
    if (opened) {
      await page.locator('[aria-label="Judul / topik"]').first().fill('__E2E_TICKET__ Tombol struk tidak muncul');
      await page.locator('[aria-label="Jelaskan kendala (opsional)"]').first().fill('Uji otomatis Playwright, abaikan.');
      await page.waitForTimeout(500);
      out.submitClicked = await click(page, 'Kirim Tiket');
      await page.waitForTimeout(5000);
      txt = await textOf(page);
      out.ticketCreated = txt.includes('__E2E_TICKET__');
    }

    await click(page, 'Back');
    await page.waitForTimeout(2500);
    const pdfRes = await ctx.request.get(BASE + 'panduan/panduan-kasirgo.pdf');
    out.guidePdfStatus = pdfRes.status();
    out.guidePdfBytes = (await pdfRes.body()).length;

    const apage = await ctx.newPage();
    const aerr = [];
    apage.on('console', (m) => { if (m.type() === 'error') aerr.push(m.text().slice(0, 200)); });
    await apage.goto(ADMIN + '?cb=' + Date.now(), { waitUntil: 'networkidle', timeout: 120000 });
    await apage.waitForTimeout(2500);
    await apage.fill('input[type=email]', 'superadmin@kasirgo.com');
    await apage.fill('input[type=password]', 'sabar2021');
    await apage.keyboard.press('Enter');
    await apage.waitForTimeout(7000);
    out.adminLoggedIn = !apage.url().includes('/login');
    await apage.goto(ADMIN + '#/support', { waitUntil: 'networkidle' });
    await apage.waitForTimeout(5000);
    const bodyText = await apage.locator('body').innerText();
    out.adminSupportPage = bodyText.includes('Tiket Support');
    out.adminSeesTicket = bodyText.includes('__E2E_TICKET__');
    out.adminErrors = aerr.length;
    await apage.screenshot({ path: '/tmp/opencode/admin_support.png' });
  } catch (e) {
    out.exception = String(e).slice(0, 400);
  }

  out.consoleErrors = errors.length;
  out.errorSamples = errors.slice(0, 5);
  console.log(JSON.stringify(out, null, 2));
  await browser.close();
};

run();
