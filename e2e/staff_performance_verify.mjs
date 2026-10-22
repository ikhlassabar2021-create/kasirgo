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

const labels = (page) =>
  page.evaluate(() =>
    [...document.querySelectorAll('flt-semantics')]
      .map((el) => el.getAttribute('aria-label') || '')
      .filter(Boolean)
      .join('\n'));

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
  const failed = [];
  page.on('requestfailed', (r) => failed.push(r.url() + ' :: ' + r.failure()?.errorText));
  page.on('response', (r) => { if (r.status() >= 400) failed.push(r.status() + ' ' + r.url()); });

  const clickText = await login(page, 'ikhlassabar2021@gmail.com');
  console.log('OWNER_HOME', (await semText(page)).includes('Dashboard Owner'));

  let opened = await clickText('Dokter Bisnis AI');
  if (!opened) {
    for (let i = 0; i < 8; i++) {
      await page.mouse.wheel(0, 500);
      await page.waitForTimeout(800);
      if (await clickText('Dokter Bisnis AI')) { opened = true; break; }
    }
  }
  console.log('OPEN_DOCTOR', opened);
  await page.waitForTimeout(7000);

  let found = false;
  for (let i = 0; i < 14; i++) {
    if ((await semText(page)).includes('Delegasi Tugas')) { found = true; break; }
    await page.mouse.wheel(0, 600);
    await page.waitForTimeout(900);
  }
  console.log('HAS_DELEGATION_CARD', found);
  console.log('OPEN_BOARD', await clickText('Delegasi Tugas'));
  await page.waitForTimeout(6000);

  let hasBoard = false;
  for (let i = 0; i < 12; i++) {
    const l = await labels(page);
    if (l.includes('Papan Apresiasi Staf') && l.includes('30 hari terakhir')) { hasBoard = true; break; }
    await page.mouse.wheel(0, 500);
    await page.waitForTimeout(700);
  }
  console.log('BOARD_LEADERBOARD', hasBoard);
  console.log('OPEN_REPORT_LINK', await clickText('Laporan lengkap'));
  await page.waitForTimeout(8000);

  const txt = await semText(page);
  const lbl = await labels(page);
  console.log('REPORT_TITLE', txt.includes('Performa Staf') && lbl.includes('Performa Staf 30 Hari Terakhir'));
  console.log('HAS_SUMMARY', txt.includes('Tugas Selesai') && txt.includes('Tepat Waktu') && txt.includes('Total XP'));
  console.log('SUMMARY_VALUES', /5\s*Tugas Selesai/.test(txt.replace(/\n/g, ' ')), /80%\s*Tepat Waktu/.test(txt.replace(/\n/g, ' ')));
  console.log('HAS_STAFF_KASIR', lbl.includes('Kasir Demo'));
  console.log('HAS_STAFF_ADMIN', lbl.includes('admin cafe'));
  console.log('HAS_STAFF_KOKI', lbl.includes('Koki Test'));
  console.log('HAS_BADGE', lbl.includes('Juara') && lbl.includes('Pekerja Keras'));
  console.log('RANKING_SORTED', lbl.indexOf('Kasir Demo') < lbl.indexOf('admin cafe'));
  console.log('HAS_COUNTS', lbl.includes('3 selesai') && lbl.includes('2 selesai'));
  console.log('HAS_LATE', lbl.includes('1 terlambat'));

  await page.screenshot({ path: '/tmp/opencode/staff_performance.png', fullPage: true });

  console.log('CLICK_PERIOD_7', await clickLabel(page, '7 hari'));
  await page.waitForTimeout(5000);
  const txt7 = await semText(page);
  const lbl7 = await labels(page);
  console.log('PERIOD_7_ACTIVE', lbl7.includes('Performa Staf 7 Hari Terakhir'));
  console.log('PERIOD_7_HAS_DATA', lbl7.includes('Kasir Demo'));

  console.log('CLICK_STAFF', await clickLabel(page, 'Kasir Demo'));
  await page.waitForTimeout(4000);
  const sheet = await semText(page);
  const sheetLbl = await labels(page);
  console.log('DETAIL_OPEN', sheet.includes('Riwayat Tugas'));
  console.log('DETAIL_HAS_TASK', sheet.includes('__PERF_'));
  const sheetAll = sheet + '\n' + sheetLbl;
  console.log('DETAIL_HAS_METRIC', sheetAll.includes('Tepat waktu') && sheetAll.includes('Penyelesaian'));

  await page.screenshot({ path: '/tmp/opencode/staff_performance_detail.png', fullPage: false });

  await page.keyboard.press('Escape');
  await page.waitForTimeout(1500);

  const downloadPromise = page.waitForEvent('download', { timeout: 20000 }).catch(() => null);
  const clickedExport = (await clickLabel(page, 'Export Excel')) || (await clickText('Export Excel'));
  console.log('CLICK_EXPORT', clickedExport);
  const download = await downloadPromise;
  console.log('EXPORT_DOWNLOAD', !!download, download ? download.suggestedFilename() : 'none');
  if (download) {
    const path = '/tmp/opencode/' + download.suggestedFilename();
    await download.saveAs(path);
    console.log('EXPORT_SAVED', path);
  }
  await page.waitForTimeout(2500);

  console.log('ERRORS', errors.length, JSON.stringify(errors.slice(0, 3)));
  console.log('FAILED_REQ', failed.length, JSON.stringify(failed.slice(0, 5)));
  await browser.close();
};

run().catch((e) => {
  console.error('FATAL', e);
  process.exit(1);
});
