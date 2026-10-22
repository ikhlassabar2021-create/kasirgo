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
  await page.waitForTimeout(4000);

  const cardBox = await scrollTo(page, 'Atur Harga & Diskon');
  console.log('CARD_FOUND:', !!cardBox);
  if (cardBox) {
    await page.mouse.click(cardBox.x + cardBox.w / 2, cardBox.y + cardBox.h / 2);
  }
  await page.waitForTimeout(8000);
  let text = await textOf(page);
  console.log('SCREEN_OPEN:', /Atur Harga & Diskon/.test(text));
  console.log('HAS_INTRO:', /saran harga|Harga & Diskon|AI/.test(text));
  console.log('HAS_SUMMARY:', /Perlu diskon/.test(text) && /Margin tipis/.test(text));
  console.log('HAS_DISCOUNT_CARD:', /Terapkan Diskon/.test(text));
  console.log('HAS_MARGIN_CARD:', /Naikkan ke Rp/.test(text));
  console.log('HAS_EMPTY:', /Harga Anda sudah sehat/.test(text));
  console.log('HAS_ERROR:', /Data produk belum bisa dimuat/.test(text));
  console.log('HAS_FOOTER:', /7 hari/.test(text));
  await page.screenshot({ path: '/tmp/opencode/dynpricing_screen.png' });

  const discountBtn = await findBox(page, 'Terapkan Diskon');
  if (discountBtn) {
    await page.mouse.click(discountBtn.x + discountBtn.w / 2, discountBtn.y + discountBtn.h / 2);
    await page.waitForTimeout(6000);
    text = await textOf(page);
    console.log('APPLY_SNACK:', /Diskon .*dipasang|diterapkan|berhasil/i.test(text));
    await page.screenshot({ path: '/tmp/opencode/dynpricing_applied.png' });
  } else {
    console.log('APPLY_SNACK: skipped (no discount card)');
  }

  const marginBtn = await findBox(page, 'Naikkan ke Rp');
  if (marginBtn) {
    await page.mouse.click(marginBtn.x + marginBtn.w / 2, marginBtn.y + marginBtn.h / 2);
    await page.waitForTimeout(6000);
    text = await textOf(page);
    console.log('PRICE_SNACK:', /Harga .*diperbarui|dinaikkan|berhasil/i.test(text));
    await page.screenshot({ path: '/tmp/opencode/dynpricing_price.png' });
  } else {
    console.log('PRICE_SNACK: skipped (no margin card)');
  }

  console.log('ERRORS', errors.length, errors.slice(0, 5));
  await browser.close();
};

run().catch((e) => { console.error('FAILED', e); process.exit(1); });
