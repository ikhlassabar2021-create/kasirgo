import fs from 'fs';
import { chromium } from 'playwright';

const BASE = 'https://ikhlassabar2021-create.github.io/kasirgo/';
const SUPA = 'https://lmvjecdvfzsmrowwwpck.supabase.co';
const KEY = 'sb_publishable_8RJnG66i_37cih8GTG1sBA_0B91KOW_';
const OUTLET = '229c94d7-ce6d-4be1-98f5-448f600528cc';
const TOKEN = fs.readFileSync('/tmp/opencode/owner_token.txt', 'utf8').trim();
const CODE = 'ORD26101907777';
const PHONE = '089900000777';
const H = { apikey: KEY, Authorization: `Bearer ${TOKEN}`, 'Content-Type': 'application/json' };

const rest = async (path, opts = {}) => {
  const res = await fetch(`${SUPA}/rest/v1/${path}`, { ...opts, headers: { ...H, ...(opts.headers || {}) } });
  const t = await res.text();
  let body = null;
  try { body = t ? JSON.parse(t) : null; } catch { body = t; }
  return { status: res.status, body };
};
const rpc = (fn, args) => rest(`rpc/${fn}`, { method: 'POST', body: JSON.stringify(args) });
const state = { productId: null, orderId: null };

const setup = async () => {
  await rest(`orders?code=eq.${CODE}`, { method: 'DELETE' });
  await rest('products?name=eq.__QA_A11Y__', { method: 'DELETE' });
  const p = await rest('products', {
    method: 'POST',
    headers: { Prefer: 'return=representation' },
    body: JSON.stringify({ outlet_id: OUTLET, name: '__QA_A11Y__', base_price: 5000, cost_price: 3000, stock: 10, unit: 'pcs', category: 'QA', is_published: true, is_service: false }),
  });
  state.productId = p.body[0].id;
  const o = await rest('orders', {
    method: 'POST',
    headers: { Prefer: 'return=representation' },
    body: JSON.stringify({ outlet_id: OUTLET, code: CODE, status: 'baru', payment_status: 'belum_konfirmasi', fulfillment: 'pickup', subtotal: 10000, delivery_fee: 0, total: 10000, buyer_name: 'QA A11y', buyer_phone: PHONE, note: 'uji a11y' }),
  });
  state.orderId = o.body[0].id;
  await rest('order_items', {
    method: 'POST',
    body: JSON.stringify([{ order_id: state.orderId, product_id: state.productId, name_snapshot: '__QA_A11Y__', price_snapshot: 5000, qty: 2, line_total: 10000 }]),
  });
  await rpc('validate_order_payment', { p_order: state.orderId, p_accept: true });
};

const cleanup = async () => {
  if (state.orderId) {
    await rest(`order_items?order_id=eq.${state.orderId}`, { method: 'DELETE' });
    await rest(`orders?id=eq.${state.orderId}`, { method: 'DELETE' });
  }
  await rest(`customers?phone_wa=eq.${PHONE}`, { method: 'DELETE' });
  if (state.productId) await rest(`products?id=eq.${state.productId}`, { method: 'DELETE' });
};

const run = async () => {
  await setup();
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 1000 }, serviceWorkers: 'block' });
  const page = await ctx.newPage();
  const clickText = async (t) => {
    const els = page.locator('flt-semantics', { hasText: t });
    const n = await els.count();
    for (let i = n - 1; i >= 0; i--) {
      const b = await els.nth(i).boundingBox();
      if (!b || b.width === 0) continue;
      await page.mouse.click(b.x + b.width / 2, b.y + b.height / 2);
      return true;
    }
    return false;
  };
  try {
    await page.goto(BASE + '?cb=' + Date.now(), { waitUntil: 'networkidle', timeout: 120000 });
    await page.waitForTimeout(5000);
    await page.locator('flt-semantics-placeholder').evaluate((el) => el.click());
    await page.waitForTimeout(2000);
    await clickText('Saya Penjual');
    await page.waitForTimeout(3500);
    await page.mouse.click(640, 455);
    await page.waitForTimeout(700);
    await page.keyboard.type('ikhlassabar2021@gmail.com', { delay: 20 });
    await page.keyboard.press('Tab');
    await page.waitForTimeout(400);
    await page.keyboard.type('sabar2021', { delay: 20 });
    await page.waitForTimeout(500);
    await clickText('MASUK KE KASIRGO');
    await page.waitForTimeout(11000);
    await clickText('Pesanan Masuk');
    await page.waitForTimeout(2500);
    await clickText('Pesanan Online');
    await page.waitForTimeout(4000);

    const dump = await page.evaluate(() => {
      const out = [];
      for (const e of document.querySelectorAll('flt-semantics')) {
        const b = e.getBoundingClientRect();
        if (b.width === 0) continue;
        out.push({
          role: e.getAttribute('role'),
          aria: (e.getAttribute('aria-label') || '').slice(0, 80),
          text: (e.textContent || '').replace(/\s+/g, ' ').trim().slice(0, 100),
          x: Math.round(b.x), y: Math.round(b.y), w: Math.round(b.width), h: Math.round(b.height),
          depth: (() => { let d = 0, p = e.parentElement; while (p) { if (p.tagName === 'FLT-SEMANTICS') d++; p = p.parentElement; } return d; })(),
        });
      }
      return out;
    });
    console.log('NODES', dump.length);
    const near = dump.filter((n) => n.text.includes('QA A11y') || n.text.includes('ORD26101907777') || n.aria.includes('QA A11y') || n.aria.includes('ORD26101907777'));
    console.log('MATCH_CODE', JSON.stringify(near, null, 1));
    const btns = dump.filter((n) => n.role === 'button');
    console.log('BUTTONS', JSON.stringify(btns, null, 1));
    fs.writeFileSync('/tmp/opencode/a11y_nodes.json', JSON.stringify(dump, null, 1));
  } finally {
    await browser.close();
  }
};

try { await run(); } catch (e) { console.log('FATAL', e.message); } finally { await cleanup(); console.log('CLEANED'); }
