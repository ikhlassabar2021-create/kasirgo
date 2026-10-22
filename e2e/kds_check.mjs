import { chromium } from 'playwright';

const OUT = process.env.OUT || '229c94d7-ce6d-4be1-98f5-448f600528cc';
const base = 'https://ikhlassabar2021-create.github.io/kasirgo/';
const browser = await chromium.launch({ args: ['--no-sandbox'] });
const ctx = await browser.newContext({ viewport: { width: 1280, height: 1000 }, serviceWorkers: 'block' });
const page = await ctx.newPage();
const errors = [];
page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
page.on('requestfailed', r => errors.push('REQFAIL ' + r.url()));

await page.goto(base + '?cb=' + Date.now(), { waitUntil: 'networkidle', timeout: 120000 });
await page.waitForTimeout(4000);

// login
const email = page.locator('input[type="email"], input').first();
await email.click();
await email.fill('ikhlassabar2021@gmail.com');
await page.keyboard.press('Tab');
await page.keyboard.type('sabar2021');
await page.waitForTimeout(500);
const loginBtn = page.getByText(/^Masuk$/).first();
await loginBtn.click();
await page.waitForTimeout(8000);
await page.screenshot({ path: '/tmp/opencode/kds_home.png', fullPage: false });

const bodyText = await page.locator('body').innerText();
console.log('LOGIN_OK', bodyText.includes('Kitchen (KDS)') || bodyText.includes('KasirGo'));
console.log('HAS_KDS_CARD', bodyText.includes('Kitchen (KDS)'));

// open KDS
const kds = page.getByText('Kitchen (KDS)').first();
if (await kds.count()) {
  await kds.click();
  await page.waitForTimeout(6000);
}
await page.screenshot({ path: '/tmp/opencode/kds_screen.png', fullPage: false });
const kdsText = await page.locator('body').innerText();
console.log('KDS_HAS_ORDER', kdsText.includes('ORD26101909999'));
console.log('KDS_HAS_ONLINE_BADGE', kdsText.includes('ONLINE'));
console.log('KDS_HAS_BUTTON', kdsText.includes('TANDAI SIAP SAJI'));
console.log('ERRORS', errors.length, errors.slice(0, 5).join(' | '));
console.log('---KDS_TEXT---');
console.log(kdsText.slice(0, 1500));
await browser.close();
