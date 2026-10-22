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

const ownerFlow = async (browser) => {
  const ctx = await browser.newContext({
    viewport: { width: 1280, height: 1400 },
    serviceWorkers: 'block',
  });
  const page = await ctx.newPage();
  const errors = [];
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
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

  const txt = await semText(page);
  console.log('BOARD_TITLE', txt.includes('Delegasi Tugas'));
  console.log('HAS_LEADERBOARD_HEADER', txt.includes('Papan Apresiasi Staf'));
  console.log('HAS_PERIOD', /30 hari terakhir/.test(txt));
  console.log('HAS_XP_HINT', /8 XP per tugas selesai/.test(txt));
  console.log('HAS_TOP_STAFF', txt.includes('Kasir Demo'));
  console.log('HAS_RANK2_STAFF', txt.includes('admin cafe'));
  console.log('HAS_DONE_COUNT', /3 selesai/.test(txt));
  console.log('HAS_BADGE_JUARA', txt.includes('Juara'));
  console.log('HAS_STAFF_TOTAL', /\d+ staf/.test(txt));

  const shot = '/tmp/opencode/leaderboard_owner.png';
  await page.screenshot({ path: shot, fullPage: true });
  console.log('SHOT', shot);
  console.log('OWNER_ERRORS', errors.length, JSON.stringify(errors.slice(0, 3)));
  await ctx.close();
};

const staffFlow = async (browser) => {
  const ctx = await browser.newContext({
    viewport: { width: 900, height: 1400 },
    serviceWorkers: 'block',
  });
  const page = await ctx.newPage();
  const errors = [];
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  const clickText = await login(page, 'ikhlassabar2021+kasir@gmail.com');

  const home = await semText(page);
  console.log('STAFF_HOME', /Kasir|Beranda/.test(home));

  let txt = home;
  for (let i = 0; i < 12; i++) {
    if (txt.includes('Peringkat')) break;
    await page.mouse.wheel(0, 500);
    await page.waitForTimeout(900);
    txt = await semText(page);
  }
  console.log('HAS_TASK_CARD', txt.includes('Tugas'));
  console.log('HAS_RANK_STRIP', txt.includes('Peringkat 1 - Terbaik!'));
  console.log('HAS_XP_BADGE', /\d+ XP/.test(txt));
  console.log('HAS_PERIOD_LABEL', /30 hari terakhir/.test(txt));
  console.log('HAS_BADGE_CHIP', txt.includes('Juara'));
  console.log('HAS_DONE_TEXT', /tugas selesai/.test(txt));

  const shot = '/tmp/opencode/leaderboard_staff.png';
  await page.screenshot({ path: shot, fullPage: true });
  console.log('SHOT', shot);
  console.log('STAFF_ERRORS', errors.length, JSON.stringify(errors.slice(0, 3)));
  await ctx.close();
};

const run = async () => {
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  try {
    await ownerFlow(browser);
    await staffFlow(browser);
  } finally {
    await browser.close();
  }
};

run().catch((e) => { console.error('FAIL', e); process.exit(1); });
