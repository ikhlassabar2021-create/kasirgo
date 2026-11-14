import { chromium } from 'playwright';
const run = async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1280, height: 1200 } });
  await page.goto('https://dokterbisnis.web.id/#/register?cb=' + Date.now(), { waitUntil: 'domcontentloaded', timeout: 180000 });
  await page.waitForTimeout(8000);
  if (await page.locator('flt-semantics-placeholder').count()) {
    await page.locator('flt-semantics-placeholder').evaluate((el) => el.click());
    await page.waitForTimeout(1500);
  }
  const nodes = await page.evaluate(() =>
    [...document.querySelectorAll('flt-semantics')]
      .map((e) => ({ a: e.getAttribute('aria-label') || '', t: (e.textContent || '').trim() }))
      .filter((n) => n.a || n.t));
  nodes.forEach((n) => console.log(JSON.stringify(n)));
  await browser.close();
};
run().catch((e) => { console.error('FATAL', e.message); process.exit(1); });
