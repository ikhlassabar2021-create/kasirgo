import { chromium } from 'playwright';

const BASE = 'https://dokterbisnis.web.id/';

const enableSemantics = async (page) => {
  if (await page.locator('flt-semantics-placeholder').count()) {
    await page.locator('flt-semantics-placeholder').evaluate((el) => el.click());
    await page.waitForTimeout(1500);
  }
};

const dump = async (page) => page.evaluate(() =>
  [...document.querySelectorAll('flt-semantics')]
    .map((e) => {
      const r = e.getBoundingClientRect();
      return {
        aria: e.getAttribute('aria-label') || '',
        txt: (e.textContent || '').trim(),
        x: r.x, y: r.y, w: r.width, h: r.height,
      };
    })
    .filter((n) => n.w > 0 && n.h > 0));

const run = async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1280, height: 1200 } });
  const errors = [];
  page.on('console', (m) => {
    if (m.type() === 'error') errors.push(m.text().slice(0, 200));
  });

  await page.goto(BASE + '#/register?cb=' + Date.now(), { waitUntil: 'domcontentloaded', timeout: 180000 });
  await page.waitForTimeout(8000);
  await enableSemantics(page);

  const nodes = await dump(page);
  const text = nodes.map((n) => n.txt).join('\n');

  console.log('HAS_NIK_LABEL', /NIK \(16 digit\)/i.test(text));
  console.log('HAS_DATA_KYC', /Data KYC Wajib/i.test(text));
  console.log('HAS_NOTE_KTP', /sesuai KTP/i.test(text));
  console.log('HAS_NIK_HP_NOTE', /NIK dan nomor HP dilengkapi/i.test(text));
  console.log('HAS_PHONE_LABEL', /Nomor Telepon/i.test(text));
  console.log('INPUT_COUNT', await page.locator('input').count());

  console.log('ERRORS', errors.length, JSON.stringify(errors.slice(0, 3)));
  await browser.close();
};

run().catch((e) => {
  console.error('FATAL', e.message);
  process.exit(1);
});