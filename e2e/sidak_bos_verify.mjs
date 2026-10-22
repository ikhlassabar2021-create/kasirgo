import { chromium } from 'playwright';

const BASE = process.env.BASE || 'http://localhost:8099/kasirgo/';
const EMAIL = 'ikhlassabar2021@gmail.com';

const findBox = async (page, t) => {
  const nodes = await page.evaluate((label) => {
    return [...document.querySelectorAll('flt-semantics')]
      .map((e) => {
        const r = e.getBoundingClientRect();
        return {
          role: e.getAttribute('role') || '',
          aria: e.getAttribute('aria-label') || '',
          txt: (e.textContent || '').trim(),
          x: r.x, y: r.y, w: r.width, h: r.height,
        };
      })
      .filter((n) => n.txt === label || n.aria === label || n.txt.includes(label));
  }, t);
  let best = null;
  for (const b of nodes) {
    if (!b.w || !b.h) continue;
    if (b.y < 0 || b.y + b.h > 1500) continue;
    if (b.w > 1260) continue;
    const area = b.w * b.h;
    if (!best || area < best.area) best = { ...b, area };
  }
  return best;
};

const scrollTo = async (page, t, tries = 12) => {
  for (let i = 0; i < tries; i++) {
    const box = await findBox(page, t);
    if (box) return box;
    await page.mouse.move(640, 800);
    await page.mouse.wheel(0, 500);
    await page.waitForTimeout(800);
  }
  return null;
};

const clickText = async (page, t) => {
  const box = await findBox(page, t);
  if (!box) return false;
  await page.mouse.click(box.x + box.w / 2, box.y + box.h / 2);
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

const typeInto = async (page, label, value) => {
  const box = await page.locator(`input[aria-label="${label}"]`).boundingBox();
  if (!box) return false;
  await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
  await page.waitForTimeout(400);
  await page.keyboard.press('Control+A');
  await page.keyboard.press('Backspace');
  await page.waitForTimeout(200);
  await page.keyboard.type(String(value), { delay: 40 });
  await page.waitForTimeout(600);
  return true;
};

const pdfPlain = async (path) => {
  const zlib = await import('node:zlib');
  const fs = await import('node:fs/promises');
  const buf = await fs.readFile(path);
  const s2 = buf.toString('latin1');
  const re = /stream\r?\n([\s\S]*?)endstream/g;
  let txt = '';
  let m;
  while ((m = re.exec(s2)) !== null) {
    try {
      txt += zlib.inflateSync(Buffer.from(m[1], 'latin1')).toString('latin1');
    } catch (_) {}
  }
  return [...txt.matchAll(/\[\((.*?)\)\]TJ/g)].map((x) => x[1]).join('').replace(/\s+/g, '');
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

  await login(page);
  await page.waitForTimeout(4000);

  const cardBox = await scrollTo(page, 'Sidak Stok & Kas');
  console.log('CARD_FOUND:', !!cardBox);
  if (cardBox) {
    await page.mouse.click(cardBox.x + cardBox.w / 2, cardBox.y + cardBox.h / 2);
  }
  await page.waitForTimeout(8000);
  let text = await textOf(page);
  console.log('SCREEN_OPEN:', /Sidak Bos/.test(text));
  console.log('HAS_TABS:', /Sidak Baru/.test(text) && /Riwayat/.test(text));
  console.log('HAS_CASH_CARD:', /Kas Laci|Uang laci/.test(text));
  console.log('HAS_STOCK_CARD:', /Mulai Hitung Stok/.test(text));
  console.log('HAS_FINDINGS:', /Temuan/.test(text));
  await page.screenshot({ path: '/tmp/opencode/sidak_screen.png' });

  const openOk = await typeInto(page, 'Uang laci saat mulai (modal awal)', '100000');
  const actOk = await typeInto(page, 'Uang laci hasil hitung', '150000');
  console.log('FILL_CASH:', openOk, actOk);
  text = await textOf(page);
  console.log('CASH_DIFF_SHOWN:', /Selisih kas/.test(text) && /Rp\s?40\.000/.test(text));

  const countBtn = await scrollTo(page, 'Mulai Hitung Stok');
  console.log('COUNT_BTN:', countBtn);
  const countClick = countBtn ? (await page.mouse.click(countBtn.x + countBtn.w / 2, countBtn.y + countBtn.h / 2), true) : false;
  await page.waitForTimeout(4000);
  text = await textOf(page);
  console.log('COUNT_OPEN:', countClick, /Hitung Stok Fisik/.test(text));

  let physicalFilled = false;
  const rowInput = page.locator('input[aria-label*="Roti Bakar"]').first();
  if ((await rowInput.count()) > 0) {
    const box = await rowInput.boundingBox();
    if (box && box.width > 0) {
      await page.mouse.click(box.x + box.width - 46, box.y + box.height / 2);
      await page.waitForTimeout(400);
      await page.keyboard.press('Control+A');
      await page.keyboard.press('Backspace');
      await page.waitForTimeout(200);
      await page.keyboard.type('40', { delay: 60 });
      await page.waitForTimeout(900);
      physicalFilled = true;
    }
  }
  console.log('PHYSICAL_FILLED:', physicalFilled);
  text = await textOf(page);
  console.log('COUNT_DIFF_VISIBLE:', /Selisih/.test(text));
  await page.screenshot({ path: '/tmp/opencode/sidak_count.png' });

  const doneClick = await clickText(page, 'Selesai Menghitung');
  await page.waitForTimeout(4000);
  text = await textOf(page);
  console.log('BACK_TO_SIDAK:', doneClick, /Sidak Bos/.test(text));
  console.log('STOCK_DIFF_SHOWN:', /Produk berselisih/.test(text));

  const saveBox = await scrollTo(page, 'Simpan Hasil Sidak');
  console.log('SAVE_BTN_FOUND:', !!saveBox);
  if (saveBox) {
    await page.mouse.click(saveBox.x + saveBox.w / 2, saveBox.y + saveBox.h / 2);
  }
  await page.waitForTimeout(7000);
  text = await textOf(page);
  console.log('SAVED_DIALOG:', /Sidak Tersimpan/.test(text));
  console.log('DIALOG_VERDICT:', /Hasil:/.test(text));
  console.log('DIALOG_PDF_BTN:', /PDF/.test(text));
  await page.screenshot({ path: '/tmp/opencode/sidak_saved.png' });

  const dl = page.waitForEvent('download', { timeout: 30000 }).catch(() => null);
  const pdfClick = await clickSemantic(page, 'PDF');
  const download = await dl;
  let saved = '';
  if (download) {
    saved = '/tmp/opencode/' + download.suggestedFilename();
    await download.saveAs(saved);
  }
  console.log('PDF_CLICK:', pdfClick, 'PDF_FILENAME:', download ? download.suggestedFilename() : 'NO_DOWNLOAD');
  if (saved) {
    const plain = (await pdfPlain(saved)).replace(/\|/g, '');
    console.log('PDF_STORE:', /TokoTest/.test(plain));
    console.log('PDF_VERDICT:', /SIDAK|ADASELISIH/.test(plain));
    console.log('PDF_KAS:', /KasLaci|Kasfisik|Selisih/.test(plain));
  }

  await page.waitForTimeout(2000);
  const closeClick = await clickSemantic(page, 'Tutup');
  await page.waitForTimeout(2500);
  text = await textOf(page);
  console.log('DIALOG_CLOSED:', closeClick, !/Sidak Tersimpan/.test(text));

  const histClick = await clickText(page, 'Riwayat');
  await page.waitForTimeout(5000);
  text = await textOf(page);
  console.log('HISTORY_OPEN:', histClick);
  console.log('HISTORY_HAS_ROW:', /Kas Rp|Stok Rp|Sidak /.test(text));
  await page.screenshot({ path: '/tmp/opencode/sidak_history.png' });

  console.log('ERRORS:', errors.length, errors.slice(0, 3));
  await browser.close();
};

run();
