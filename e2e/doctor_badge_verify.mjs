import { chromium } from 'playwright';

const BASE = process.env.BASE || 'http://localhost:8099/kasirgo/';
const EMAIL = 'ikhlassabar2021@gmail.com';

const login = async (page) => {
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
  await page.keyboard.type(EMAIL, { delay: 25 });
  await page.waitForTimeout(400);
  await page.keyboard.press('Tab');
  await page.waitForTimeout(600);
  await page.keyboard.type('sabar2021', { delay: 40 });
  await page.waitForTimeout(800);
  await clickText('MASUK KE KASIRGO');
  await page.waitForTimeout(22000);
};

const dump = (page) =>
  page.evaluate(() => {
    const els = [...document.querySelectorAll('flt-semantics')];
    return {
      labels: els.map((e) => e.getAttribute('aria-label') || '').filter(Boolean),
      text: els.map((e) => (e.getAttribute('aria-label') || '') + ' ' + (e.textContent || '')).join(' | '),
    };
  });

const run = async () => {
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const ctx = await browser.newContext({
    viewport: { width: 1280, height: 1500 },
    serviceWorkers: 'block',
  });
  const page = await ctx.newPage();
  const errors = [];
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });

  await login(page);
  await page.waitForTimeout(6000);

  const { labels, text } = await dump(page);
  const badgeLabel = /Dokter Bisnis AI\s*Perlu perhatian \(\d+\)/.exec(text) || '';
  const subtitle = /Perlu perhatian \((\d+)\)/.exec(text);
  const hasCard = /Dokter Bisnis AI/.test(text);

  console.log('LEN:', text.length, 'LABELS:', labels.length);
  await (await import('node:fs/promises')).writeFile('/tmp/opencode/badge_text.txt', text);
  console.log('BADGE_LABEL:', JSON.stringify(badgeLabel && badgeLabel[0]));
  console.log('SUBTITLE:', subtitle ? subtitle[0] : 'NOT_FOUND');
  console.log('HAS_CARD:', hasCard);
  console.log('ERRORS:', errors.length);

  await browser.close();
  if (!badgeLabel || !subtitle) process.exit(2);
};

run();
