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
  const browser = await chromium.launch({
    args: ['--no-sandbox', '--use-fake-ui-for-media-stream'],
  });
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
    await page.waitForTimeout(8000);

    let txt = await semText(page);
    console.log('HAS_VOICE_HINT', txt.includes('Tulis atau ucapkan pertanyaan bisnis Anda'));
    console.log('HAS_MIC_LABEL', txt.includes('Bicara'));

    const mic = page.locator('flt-semantics', { hasText: 'Bicara' });
    const n = await mic.count();
    let box = null;
    for (let i = n - 1; i >= 0; i--) {
      const b = await mic.nth(i).boundingBox();
      if (b && b.width > 0 && b.height > 0 && b.y > 400) {
        box = b;
        break;
      }
    }
    console.log('MIC_BOX', !!box);
    if (box) {
      await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
      await page.waitForTimeout(6000);
      txt = await semText(page);
      const listening = txt.includes('Mendengarkan') || txt.includes('Mendengar:');
      const failed = txt.includes('Mikrofon') || txt.includes('Pengenal suara') || txt.includes('Izin mikrofon');
      console.log('LISTENING_OR_ERROR', listening, failed);
      console.log('STILL_ON_SCREEN', txt.includes('Dokter Bisnis') || txt.includes('Resep Aktif'));
    }
    await page.screenshot({ path: '/tmp/opencode/doctor_voice.png', fullPage: true });
    console.log('ERRORS', errors.length, errors.slice(0, 3).join(' | '));
  } finally {
    await browser.close();
  }
};

run().catch((e) => {
  console.error('FATAL', e);
  process.exit(1);
});
