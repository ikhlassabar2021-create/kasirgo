import { chromium } from 'playwright';

const BASE = process.env.BASE || 'http://localhost:8099/kasirgo/';
const EMAIL = 'ikhlassabar2021@gmail.com';

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

const clickSemantic = async (page, t) =>
  page.evaluate((label) => {
    const nodes = [...document.querySelectorAll('flt-semantics')];
    const hits = nodes.filter((e) => (e.textContent || '').trim() === label && e.getAttribute('role') === 'button');
    if (!hits.length) return false;
    hits[hits.length - 1].click();
    return true;
  }, t);

const login = async (page) => {
  await page.goto(BASE + '?cb=' + Date.now(), { waitUntil: 'networkidle', timeout: 180000 });
  await page.waitForTimeout(6000);
  await page.locator('flt-semantics-placeholder').evaluate((el) => el.click());
  await page.waitForTimeout(2500);
  await clickText(page, 'Saya Penjual');
  await page.waitForTimeout(4000);
  const emailBox = await page.locator('input[aria-label="Email Bisnis / Owner"]').boundingBox();
  await page.mouse.click(emailBox.x + emailBox.width / 2, emailBox.y + emailBox.height / 2);
  await page.waitForTimeout(500);
  await page.keyboard.type(EMAIL, { delay: 25 });
  await page.waitForTimeout(400);
  await page.keyboard.press('Tab');
  await page.waitForTimeout(600);
  await page.keyboard.type('sabar2021', { delay: 40 });
  await page.waitForTimeout(800);
  await clickText(page, 'MASUK KE KASIRGO');
  await page.waitForTimeout(22000);
};

const textOf = (page) =>
  page.evaluate(() =>
    [...document.querySelectorAll('flt-semantics')]
      .map((e) => (e.getAttribute('aria-label') || '') + ' ' + (e.textContent || ''))
      .join(' | ')
  );

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

  await login(page);
  await page.waitForTimeout(5000);

  await clickText(page, 'Dokter Bisnis AI');
  await page.waitForTimeout(12000);

  let text = await textOf(page);
  console.log('DOCTOR_OPEN:', /Dokter Bisnis/.test(text));

  const resultBox = await scrollTo(page, 'Lihat Hasil Diagnosa');
  console.log('RESULT_BTN_FOUND:', !!resultBox);
  if (resultBox) {
    await page.mouse.click(resultBox.x + resultBox.width / 2, resultBox.y + resultBox.height / 2);
  }
  const opened = !!resultBox;
  await page.waitForTimeout(5000);
  text = await textOf(page);
  console.log('RESULT_CLICK:', opened);
  console.log('HAS_HEADER:', /Hasil Pemeriksaan/.test(text));
  console.log('HAS_VERDICT:', /__SHARE_QA__ Stok Laris Sering Kosong/.test(text));
  console.log('HAS_BODY:', /uang belanja lari ke tempat lain/.test(text));
  console.log('HAS_SCORE42:', /42/.test(text));
  console.log('HAS_RECIPE:', /Peta Resep/.test(text));
  console.log('HAS_STEP2:', /Buat paket hemat sembako/.test(text));
  console.log('HAS_SHARE_BTN:', /Simpan \/ Bagikan/.test(text));
  await page.screenshot({ path: '/tmp/opencode/result_screen.png', fullPage: false });

  const shareClick = await clickText(page, 'Simpan / Bagikan');
  await page.waitForTimeout(3000);
  text = await textOf(page);
  console.log('SHARE_CLICK:', shareClick);
  console.log('SHEET_TITLE:', /Simpan \/ Bagikan Hasil/.test(text));
  console.log('SHEET_PDF:', /Simpan \/ Unduh PDF/.test(text));
  console.log('SHEET_WA:', /Kirim ke WhatsApp/.test(text));
  await page.screenshot({ path: '/tmp/opencode/result_share_sheet.png' });

  const dl = page.waitForEvent('download', { timeout: 30000 }).catch(() => null);
  await clickText(page, 'Simpan / Unduh PDF');
  const download = await dl;
  let saved = '';
  if (download) {
    saved = '/tmp/opencode/' + download.suggestedFilename();
    await download.saveAs(saved);
  }
  console.log('PDF_FILENAME:', download ? download.suggestedFilename() : 'NO_DOWNLOAD');
  let pdfText = '';
  if (saved) {
    const zlib = await import('node:zlib');
    const buf = await (await import('node:fs/promises')).readFile(saved);
    const s2 = buf.toString('latin1');
    const re = /stream\r?\n([\s\S]*?)endstream/g;
    let m;
    while ((m = re.exec(s2)) !== null) {
      try {
        pdfText += zlib.inflateSync(Buffer.from(m[1], 'latin1')).toString('latin1');
      } catch (_) {}
    }
  }
  const pdfPlain = [...pdfText.matchAll(/\[\((.*?)\)\]TJ/g)].map((x) => x[1]).join('').replace(/\s+/g, '');
  console.log('PDF_STORE:', /TokoTest/.test(pdfPlain));
  console.log('PDF_SCORE:', /42/.test(pdfPlain));
  console.log('PDF_VERDICT:', /__SHARE_QA__StokLarisSeringKosong/.test(pdfPlain));
  console.log('PDF_PATH:', saved);
  await page.waitForTimeout(2500);
  text = await textOf(page);
  console.log('PDF_SNACK:', /tersimpan sebagai PDF/.test(text));

  const waClick = await clickText(page, 'Simpan / Bagikan');
  await page.waitForTimeout(2500);
  const waBtnClick = await clickSemantic(page, 'Kirim ke WhatsApp');
  await page.waitForTimeout(2500);
  console.log('WA_SHEET_CLICK:', waClick, 'WA_BTN_CLICK:', waBtnClick);
  text = await textOf(page);
  const askPhone = /Nomor WhatsApp Bos/.test(text);
  console.log('WA_ASK_PHONE:', askPhone);
  const popupP = ctx.waitForEvent('page', { timeout: 15000 }).catch(() => null);
  let phoneSaved = false;
  if (askPhone) {
    const field = await page.locator('input[aria-label="08xxxxxxxxxx"]').boundingBox();
    await page.mouse.click(field.x + field.width / 2, field.y + field.height / 2);
    await page.waitForTimeout(400);
    await page.keyboard.type('081234567890', { delay: 30 });
    await page.waitForTimeout(500);
    phoneSaved = await clickSemantic(page, 'Simpan');
  }
  const popup = await popupP;
  await page.waitForTimeout(2500);
  console.log('WA_SAVE_PHONE:', phoneSaved);
  console.log('WA_POPUP:', popup ? popup.url().slice(0, 90) : 'NO_POPUP');
  text = await textOf(page);
  console.log('WA_SNACK_SAVED:', /Nomor Bos disimpan/.test(text));
  await page.screenshot({ path: '/tmp/opencode/result_wa_path.png' });
  console.log('ERRORS:', errors.length, errors.slice(0, 3));

  await browser.close();
  if (!download || !saved) process.exit(2);
};

run();
