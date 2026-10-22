import { chromium } from 'playwright';

const BASE = process.env.BASE || 'https://ikhlassabar2021-create.github.io/kasirgo/';

const login = async (page, email) => {
  await page.goto(BASE + '?cb=' + Date.now(), { waitUntil: 'networkidle', timeout: 180000 });
  await page.waitForTimeout(6000);
  await page.locator('flt-semantics-placeholder').evaluate((el) => el.click());
  await page.waitForTimeout(2500);
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
  const emailBox = await page.locator('input[aria-label="Email Bisnis / Owner"]').boundingBox();
  await page.mouse.click(emailBox.x + emailBox.width / 2, emailBox.y + emailBox.height / 2);
  await page.waitForTimeout(500);
  await page.keyboard.type(email, { delay: 25 });
  await page.waitForTimeout(400);
  await page.keyboard.press('Tab');
  await page.waitForTimeout(600);
  await page.keyboard.type('sabar2021', { delay: 40 });
  await page.waitForTimeout(800);
  await clickText('MASUK KE KASIRGO');
  await page.waitForTimeout(14000);
  return clickText;
};

const semText = (page) =>
  page.evaluate(() => {
    const root = document.querySelector('flt-semantics');
    return (root?.textContent || '') + ' | ' + document.body.innerText;
  });

const clickLabel = async (page, needle) => {
  const box = await page.evaluate((n) => {
    const el = [...document.querySelectorAll('flt-semantics')].find((e) => {
      const label = e.getAttribute('aria-label') || '';
      const own = [...e.childNodes]
        .filter((c) => c.nodeType === 3)
        .map((c) => c.textContent.trim())
        .join(' ');
      return label.includes(n) || own.includes(n);
    });
    if (!el) return null;
    const r = el.getBoundingClientRect();
    return { x: r.x, y: r.y, w: r.width, h: r.height };
  }, needle);
  if (!box || box.w === 0) return false;
  await page.mouse.click(box.x + box.w / 2, box.y + box.h / 2);
  return true;
};

const run = async () => {
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const ctx = await browser.newContext({
    viewport: { width: 1280, height: 1500 },
    serviceWorkers: 'block',
    acceptDownloads: true,
  });
  const page = await ctx.newPage();
  const errors = [];
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });

  const clickText = await login(page, 'ikhlassabar2021@gmail.com');
  console.log('OWNER_HOME', (await semText(page)).includes('Dashboard Owner'));

  console.log('OPEN_REPORT_NAV', await clickText('Laporan'));
  await page.waitForTimeout(7000);
  const t = await semText(page);
  console.log('REPORT_SCREEN', t.includes('Laporan Penjualan') || t.includes('Ringkasan'));

  const downloadPromise = page.waitForEvent('download', { timeout: 25000 }).catch(() => null);
  const clicked = (await clickLabel(page, 'Export Excel')) || (await clickText('Export Excel')) || (await clickText('Excel'));
  console.log('CLICK_EXPORT', clicked);
  const download = await downloadPromise;
  console.log('DOWNLOAD', !!download, download ? download.suggestedFilename() : 'none');
  if (download) {
    const path = '/tmp/opencode/' + download.suggestedFilename();
    await download.saveAs(path);
    console.log('SAVED', path);
  }
  await page.waitForTimeout(2500);
  console.log('ERRORS', errors.length, JSON.stringify(errors.slice(0, 3)));
  await browser.close();
};

run().catch((e) => {
  console.error('FATAL', e);
  process.exit(1);
});
