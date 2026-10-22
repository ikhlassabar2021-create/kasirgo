import fs from 'fs';
import { chromium } from 'playwright';

const BASE = 'https://ikhlassabar2021-create.github.io/kasirgo/';
const SUPA = 'https://lmvjecdvfzsmrowwwpck.supabase.co';
const KEY = 'sb_publishable_8RJnG66i_37cih8GTG1sBA_0B91KOW_';
const OUTLET = '229c94d7-ce6d-4be1-98f5-448f600528cc';
const TOKEN = fs.readFileSync('/tmp/opencode/owner_token.txt', 'utf8').trim();
const CODE = 'ORD26101907777';
const PHONE = '089900000777';
const H = {
  apikey: KEY,
  Authorization: `Bearer ${TOKEN}`,
  'Content-Type': 'application/json',
};

const rest = async (path, opts = {}) => {
  const res = await fetch(`${SUPA}/rest/v1/${path}`, {
    ...opts,
    headers: { ...H, ...(opts.headers || {}) },
  });
  const text = await res.text();
  let body = null;
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    body = text;
  }
  return { status: res.status, body };
};

const rpc = (fn, args) =>
  rest(`rpc/${fn}`, { method: 'POST', body: JSON.stringify(args) });

const cleanupState = { productId: null, orderId: null, txId: null };

const cleanup = async () => {
  if (cleanupState.txId) {
    const r = await rpc('delete_transaction', { p_transaction: cleanupState.txId });
    console.log('CLEAN_TX', JSON.stringify(r.body));
    await rest(`stock_logs?ref_id=eq.${cleanupState.txId}`, { method: 'DELETE' });
  }
  if (cleanupState.orderId) {
    await rest(`order_items?order_id=eq.${cleanupState.orderId}`, { method: 'DELETE' });
    const r = await rest(`orders?id=eq.${cleanupState.orderId}`, { method: 'DELETE' });
    console.log('CLEAN_ORDER', r.status);
  }
  await rest(`customers?phone_wa=eq.${PHONE}`, { method: 'DELETE' });
  if (cleanupState.productId) {
    const r = await rest(`products?id=eq.${cleanupState.productId}`, { method: 'DELETE' });
    console.log('CLEAN_PRODUCT', r.status);
  }
};

const setup = async () => {
  await rest(`orders?code=eq.${CODE}`, { method: 'DELETE' });
  await rest(`products?name=eq.__QA_A11Y__`, { method: 'DELETE' });
  await rest(`customers?phone_wa=eq.${PHONE}`, { method: 'DELETE' });

  const prod = await rest('products', {
    method: 'POST',
    headers: { Prefer: 'return=representation' },
    body: JSON.stringify({
      outlet_id: OUTLET,
      name: '__QA_A11Y__',
      base_price: 5000,
      cost_price: 3000,
      stock: 10,
      unit: 'pcs',
      category: 'QA',
      is_published: true,
      is_service: false,
    }),
  });
  if (prod.status >= 300) throw new Error('product insert: ' + JSON.stringify(prod.body));
  cleanupState.productId = prod.body[0].id;

  const order = await rest('orders', {
    method: 'POST',
    headers: { Prefer: 'return=representation' },
    body: JSON.stringify({
      outlet_id: OUTLET,
      code: CODE,
      status: 'baru',
      payment_status: 'belum_konfirmasi',
      fulfillment: 'pickup',
      subtotal: 10000,
      delivery_fee: 0,
      total: 10000,
      buyer_name: 'QA A11y',
      buyer_phone: PHONE,
      note: 'uji a11y tombol selesai',
    }),
  });
  if (order.status >= 300) throw new Error('order insert: ' + JSON.stringify(order.body));
  cleanupState.orderId = order.body[0].id;

  const items = await rest('order_items', {
    method: 'POST',
    body: JSON.stringify([
      {
        order_id: cleanupState.orderId,
        product_id: cleanupState.productId,
        name_snapshot: '__QA_A11Y__',
        price_snapshot: 5000,
        qty: 2,
        line_total: 10000,
      },
    ]),
  });
  if (items.status >= 300) throw new Error('items insert: ' + JSON.stringify(items.body));

  const val = await rpc('validate_order_payment', {
    p_order: cleanupState.orderId,
    p_accept: true,
  });
  console.log('FIXTURE_VALIDATED', JSON.stringify(val.body));
};

const run = async () => {
  await setup();

  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const ctx = await browser.newContext({
    viewport: { width: 1280, height: 1000 },
    serviceWorkers: 'block',
  });
  const page = await ctx.newPage();
  const errors = [];
  page.on('console', (m) => {
    if (m.type() === 'error') errors.push(m.text());
  });

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
  const clickLabel = async (t) => {
    const r = await page.evaluate((t) => {
      const els = [...document.querySelectorAll('flt-semantics')];
      const hit = els.find((e) => {
        const l = e.getAttribute('aria-label') || '';
        const b = e.getBoundingClientRect();
        return l.includes(t) && b.width > 0;
      });
      if (!hit) return null;
      const b = hit.getBoundingClientRect();
      return { x: b.x + b.width / 2, y: b.y + b.height / 2 };
    }, t);
    if (!r) return false;
    await page.mouse.click(r.x, r.y);
    return true;
  };
  const body = async () =>
    page.evaluate(
      () =>
        document.body.innerText ||
        document.querySelector('flt-semantics')?.textContent ||
        '',
    );

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

    console.log('HOME', (await body()).includes('Dashboard Owner'));
    console.log('NAV_MASUK', await clickText('Pesanan Masuk'));
    await page.waitForTimeout(2500);
    console.log('NAV_ONLINE', await clickText('Pesanan Online'));
    await page.waitForTimeout(3500);
    console.log('CHIP_AKTIF', await clickLabel('Aktif'));
    await page.waitForTimeout(3000);

    const sem = await page.evaluate((code) => {
      const els = [...document.querySelectorAll('flt-semantics')];
      const vis = (e) => {
        const b = e.getBoundingClientRect();
        return b.width > 0 && b.height > 0;
      };
      const card = els.find(
        (e) => vis(e) && (e.getAttribute('aria-label') || '').includes(code),
      );
      const cb = card ? card.getBoundingClientRect() : null;
      const buttons = els
        .filter((e) => vis(e) && e.getAttribute('role') === 'button')
        .map((e) => {
          const b = e.getBoundingClientRect();
          return {
            text: (e.textContent || '').replace(/\s+/g, ' ').trim(),
            x: Math.round(b.x),
            y: Math.round(b.y),
            w: Math.round(b.width),
            h: Math.round(b.height),
            inCard: !!cb && b.x >= cb.x - 2 && b.x + b.width <= cb.x + cb.width + 2 && b.y >= cb.y - 2 && b.y + b.height <= cb.y + cb.height + 2,
          };
        });
      return {
        cardFound: !!card,
        cardRole: card ? card.getAttribute('role') : null,
        cardLabel: card ? (card.getAttribute('aria-label') || '').replace(/\s+/g, ' ').trim().slice(0, 120) : null,
        cardRect: cb ? { x: Math.round(cb.x), y: Math.round(cb.y), w: Math.round(cb.width), h: Math.round(cb.height) } : null,
        cardButtons: buttons.filter((b) => b.inCard),
      };
    }, CODE);

    console.log('CARD_FOUND', sem.cardFound);
    console.log('CARD_ROLE', sem.cardRole);
    console.log('CARD_LABEL', sem.cardLabel);
    console.log('CARD_RECT', JSON.stringify(sem.cardRect));
    console.log('CARD_BUTTONS', JSON.stringify(sem.cardButtons));
    const selesai = sem.cardButtons.filter((b) => b.text === 'Selesai');
    console.log('SELESAI_SEPARATE', selesai.length === 1 && sem.cardRole !== 'button');
    console.log('CARD_NOT_BUTTON', sem.cardRole !== 'button');

    if (selesai.length === 1) {
      const b = selesai[0];
      await page.mouse.click(b.x + b.w / 2, b.y + b.h / 2);
      console.log('CLICK_SELESAI', true);
    } else {
      console.log('CLICK_SELESAI', 'button not found');
    }
    await page.waitForTimeout(6000);
    console.log('SNACK_SELESAI', (await body()).includes('Pesanan selesai'));
    console.log(
      'CARD_GONE',
      !(await page.evaluate((code) => {
        const els = [...document.querySelectorAll('flt-semantics')];
        return els.some(
          (e) => (e.textContent || '').includes(code) && e.getBoundingClientRect().width > 0,
        );
      }, CODE)),
    );
    await page.screenshot({ path: '/tmp/opencode/a11y_selesai.png' });

    const ord = await rest(
      `orders?id=eq.${cleanupState.orderId}&select=status,payment_status,transaction_id`,
    );
    const row = ord.body?.[0] || {};
    console.log('DB_ORDER', JSON.stringify(row));
    if (row.transaction_id) {
      cleanupState.txId = row.transaction_id;
      const tx = await rest(
        `transactions?id=eq.${row.transaction_id}&select=id,total_amount,final_amount,status,channel,customer_id`,
      );
      console.log('DB_TX', JSON.stringify(tx.body?.[0] || null));
    }
    console.log('ERRORS', errors.length, errors.slice(0, 3).join(' || '));
  } finally {
    await browser.close();
  }
};

try {
  await run();
} catch (e) {
  console.log('FATAL', e.message);
} finally {
  await cleanup();
  const left = await rest(
    `orders?select=id&or=(code.eq.${CODE},buyer_phone.eq.${PHONE})`,
  );
  console.log('RESIDUE_ORDERS', JSON.stringify(left.body));
  const prods = await rest('products?select=id&name=eq.__QA_A11Y__');
  console.log('RESIDUE_PRODUCTS', JSON.stringify(prods.body));
  const cust = await rest(`customers?select=id&phone_wa=eq.${PHONE}`);
  console.log('RESIDUE_CUSTOMERS', JSON.stringify(cust.body));
}
