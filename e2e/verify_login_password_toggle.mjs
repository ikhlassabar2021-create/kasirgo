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
        role: e.getAttribute('role') || '',
        txt: (e.textContent || '').trim(),
        x: r.x, y: r.y, w: r.width, h: r.height,
      };
    })
    .filter((n) => n.w > 0 && n.h > 0));

const smallest = (nodes, text) =>
  nodes.filter((n) => n.aria.includes(text) || n.txt.includes(text))
    .sort((a, b) => a.w * a.h - b.w * b.h)[0];

const run = async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1280, height: 1000 } });
  const errors = [];
  page.on('console', (m) => {
    if (m.type() === 'error') errors.push(m.text().slice(0, 200));
  });

  await page.goto(BASE + '?cb=' + Date.now(), { waitUntil: 'domcontentloaded', timeout: 180000 });
  await page.waitForTimeout(7000);
  await enableSemantics(page);

  let nodes = await dump(page);
  const seller = smallest(nodes, 'Saya Penjual');
  if (seller) {
    await page.mouse.click(seller.x + seller.w / 2, seller.y + seller.h / 2);
    await page.waitForTimeout(4000);
    await enableSemantics(page);
  }

  nodes = await dump(page);
  const toggleBefore = nodes.filter((n) => /tampilkan password/i.test(n.aria + n.txt));
  console.log('TOGGLE_TAMPILKAN_COUNT', toggleBefore.length);

  const inputs = () => page.evaluate(() =>
    [...document.querySelectorAll('input')].map((i) => ({ type: i.type, value: i.value ? '***' : '' })));
  console.log('INPUTS_INITIAL', JSON.stringify(await inputs()));

  const pwdInput = page.locator('input[type="password"]');
  const hasPwdInput = await pwdInput.count();
  console.log('PASSWORD_INPUT_COUNT', hasPwdInput);

  if (hasPwdInput) {
    await pwdInput.first().click({ force: true });
    await page.keyboard.type('rahasia123');
    await page.waitForTimeout(600);
    console.log('PASSWORD_VALUE_LEN', (await pwdInput.first().inputValue()).length);
  } else if (toggleBefore.length) {
    const t = smallest(nodes, 'Tampilkan password');
    await page.mouse.click(t.x + t.w / 2, t.y + t.h / 2);
    await page.waitForTimeout(600);
    console.log('CLICKED_WITHOUT_INPUT');
  }

  if (!toggleBefore.length) {
    console.log('SKIP_TOGGLE_NO_LABEL');
  } else {
    const t = smallest(nodes, 'Tampilkan password');
    await page.mouse.click(t.x + t.w / 2, t.y + t.h / 2);
    await page.waitForTimeout(900);
    const hiddenInputs = await page.evaluate(() =>
      [...document.querySelectorAll('input')].map((i) => i.type));
    console.log('INPUT_TYPES_AFTER_SHOW', JSON.stringify(hiddenInputs));
    nodes = await dump(page);
    const toggleAfter = nodes.filter((n) => /sembunyikan password/i.test(n.aria + n.txt));
    console.log('TOGGLE_SEMBUNYIKAN_COUNT', toggleAfter.length);

    if (toggleAfter.length) {
      const t2 = smallest(nodes, 'Sembunyikan password');
      await page.mouse.click(t2.x + t2.w / 2, t2.y + t2.h / 2);
      await page.waitForTimeout(900);
      const back = await page.evaluate(() =>
        [...document.querySelectorAll('input')].map((i) => i.type));
      console.log('INPUT_TYPES_AFTER_HIDE', JSON.stringify(back));
      nodes = await dump(page);
      console.log('TOGGLE_TAMPILKAN_AGAIN',
        nodes.filter((n) => /tampilkan password/i.test(n.aria + n.txt)).length);
    }
  }

  console.log('ERRORS', errors.length, JSON.stringify(errors.slice(0, 3)));
  await browser.close();
};

run().catch((e) => {
  console.error('FATAL', e.message);
  process.exit(1);
});
