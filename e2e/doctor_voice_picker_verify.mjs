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

const semText = async (page) =>
  page.evaluate(() =>
    Array.from(document.querySelectorAll('flt-semantics'))
      .map((el) => (el.getAttribute('aria-label') || '') + '\n' + (el.textContent || ''))
      .join('\n'));

const run = async () => {
  const browser = await chromium.launch({ args: ['--no-sandbox', '--use-fake-ui-for-media-stream'] });
  const ctx = await browser.newContext({
    viewport: { width: 1280, height: 1200 },
    serviceWorkers: 'block',
  });
  const page = await ctx.newPage();
  const errors = [];
  page.on('console', (m) => {
    if (m.type() === 'error') errors.push(m.text());
  });

  try {
    const clickText = await login(page, 'ikhlassabar2021@gmail.com');
    console.log('OPEN_DOCTOR', await clickText('Dokter Bisnis AI'));
    await page.waitForTimeout(9000);

    let txt = await semText(page);
    console.log('HAS_PERSONA_BAR', txt.includes('Persona Dokter'));
    console.log('HAS_PICKER_BTN', txt.includes('Pilih Suara Perangkat'));
    const m = txt.match(/Suara aktif:\s*([^\n]+)/);
    console.log('ACTIVE_VOICE', m ? m[1].trim() : '(none)');

    console.log('OPEN_PICKER', await clickText('Pilih Suara Perangkat'));
    await page.waitForTimeout(4000);
    txt = await semText(page);
    console.log('PICKER_TITLE', txt.includes('Pilih Suara Dokter'));
    console.log('PICKER_AUTO_OPT', txt.includes('Pilih Otomatis'));
    const opts = (txt.match(/Wanita -|Pria -/g) || []).length;
    console.log('VOICE_OPTIONS', opts);
    console.log('EMPTY_HINT', txt.includes('tidak menyediakan suara Indonesia') || txt.includes('Belum ada suara Indonesia'));

    await page.screenshot({ path: '/tmp/opencode/doctor_voice_picker.png', fullPage: true });
    console.log('ERRORS', errors.length, errors.slice(0, 3).join(' | '));
  } finally {
    await browser.close();
  }
};

run().catch((e) => {
  console.error('FATAL', e);
  process.exit(1);
});
