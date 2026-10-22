import { chromium } from 'playwright';

const BASE = 'https://ikhlassabar2021-create.github.io/kasirgo/';

const login = async (page, email) => {
  await page.goto(BASE + '?cb=' + Date.now(), { waitUntil: 'networkidle', timeout: 120000 });
  await page.waitForTimeout(5000);
  await page.locator('flt-semantics-placeholder').evaluate((el) => el.click());
  await page.waitForTimeout(2000);
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
  await page.waitForTimeout(12000);
  return clickText;
};

const run = async () => {
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const ctx = await browser.newContext({
    viewport: { width: 1280, height: 1200 },
    serviceWorkers: 'block',
  });
  const page = await ctx.newPage();
  const errors = [];
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });

  try {
    const clickText = await login(page, 'ikhlassabar2021@gmail.com');
    const body = async () =>
      page.evaluate(() => document.body.innerText || document.querySelector('flt-semantics')?.textContent || '');

    console.log('OPEN_DOCTOR', await clickText('Dokter Bisnis AI'));
    await page.waitForTimeout(7000);

    const semText = async () =>
      page.evaluate(() =>
        Array.from(document.querySelectorAll('flt-semantics'))
          .map((el) => (el.getAttribute('aria-label') || '') + '\n' + (el.textContent || ''))
          .join('\n'));
    let txt = await semText();
    for (let i = 0; i < 6 && !txt.includes('Kartu Identitas Bisnis'); i++) {
      await page.mouse.wheel(0, 400);
      await page.waitForTimeout(800);
      txt = await semText();
    }
    console.log('HAS_IDENTITY', txt.includes('Kartu Identitas Bisnis'));
    console.log('HAS_LEVEL', txt.includes('Level 1'));
    console.log('HAS_XP', txt.includes('45 / 100 XP menuju level 2'));
    console.log('HAS_STREAK', txt.includes('Streak'));
    await page.screenshot({ path: '/tmp/opencode/doctor_gamification.png', fullPage: true });

    let roiFound = false;
    for (let i = 0; i < 16; i++) {
      const els = page.locator('flt-semantics', { hasText: 'Rapor ROI Promosi' });
      const n = await els.count();
      let visible = null;
      for (let j = n - 1; j >= 0; j--) {
        const box = await els.nth(j).boundingBox();
        if (box && box.width > 0 && box.y > 60 && box.y + box.height < 1180) {
          visible = box;
          break;
        }
      }
      if (visible) { roiFound = true; break; }
      await page.mouse.move(640, 700);
      await page.mouse.wheel(0, 400);
      await page.waitForTimeout(700);
    }
    console.log('HAS_ROI_CTA', roiFound);
    console.log('OPEN_ROI', await clickText('Rapor ROI Promosi'));
    await page.waitForTimeout(5000);
    const roiTxt = await semText();
    console.log('ROI_TITLE', roiTxt.includes('Rapor ROI Promosi'));
    console.log('ROI_PERIOD', roiTxt.includes('30 Hari'));
    console.log('ROI_EMPTY_OR_DATA', roiTxt.includes('Belum ada') || roiTxt.includes('Hasil Promosi'));
    console.log('ROI_SNIP', roiTxt.replace(/\s+/g, ' ').slice(0, 500));
    await page.screenshot({ path: '/tmp/opencode/doctor_roi.png', fullPage: true });
  } finally {
    console.log('ERRORS', errors.length, JSON.stringify(errors.slice(0, 4)));
    await browser.close();
  }
};

run().catch((e) => { console.error('FAIL', e); process.exit(1); });
