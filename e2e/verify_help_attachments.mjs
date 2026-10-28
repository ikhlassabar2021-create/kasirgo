import { chromium } from 'playwright';
import fs from 'fs';

const BASE = 'https://ikhlassabar2021-create.github.io/kasirgo/';
const ADMIN = BASE + 'admin/';
const SUPA = 'https://lmvjecdvfzsmrowwwpck.supabase.co';
const KEY = 'sb_publishable_8RJnG66i_37cih8GTG1sBA_0B91KOW_';
const SUBJECT = '__E2E_ATTACH__ QRIS tidak muncul';
const IMG = '/tmp/opencode/qa-attachment.png';

// PNG 2x2 biru
fs.writeFileSync(
  IMG,
  Buffer.from(
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAFElEQVR4nGP8z8Dwn4GBgYEBAwAAJgABn0k0sQAAAABJRU5ErkJggg==',
    'base64'
  )
);

const findBox = async (page, label, latest = false) => {
  const nodes = await page.evaluate((t) => {
    return [...document.querySelectorAll('flt-semantics')]
      .map((e) => {
        const r = e.getBoundingClientRect();
        return {
          aria: e.getAttribute('aria-label') || '',
          txt: (e.textContent || '').trim(),
          x: r.x, y: r.y, w: r.width, h: r.height,
        };
      })
      .filter((n) => (n.aria.includes(t) || n.txt.includes(t)) && n.w > 0 && n.h > 0);
  }, label);
  if (!nodes.length) return null;
  nodes.sort((a, b) => a.w * a.h - b.w * b.h);
  return latest ? nodes[nodes.length - 1] : nodes[0];
};

const click = async (page, label, latest) => {
  const box = await findBox(page, label, latest);
  if (!box) return false;
  await page.mouse.click(box.x + box.w / 2, box.y + box.h / 2);
  return true;
};

const textOf = (page) =>
  page.evaluate(() =>
    [...document.querySelectorAll('flt-semantics')]
      .map((e) => (e.getAttribute('aria-label') || '') + ' ' + (e.textContent || ''))
      .join(' | '));

const enableSemantics = async (page) => {
  if (await page.locator('flt-semantics-placeholder').count()) {
    await page.locator('flt-semantics-placeholder').evaluate((el) => el.click());
    await page.waitForTimeout(1500);
  }
};

const scrollDown = async (page, n = 5) => {
  for (let i = 0; i < n; i++) {
    await page.mouse.move(700, 900);
    await page.mouse.wheel(0, 600);
    await page.waitForTimeout(450);
  }
};

const loginOwner = async (page) => {
  await page.goto(BASE + '?cb=' + Date.now(), { waitUntil: 'networkidle', timeout: 180000 });
  await page.waitForTimeout(5000);
  await enableSemantics(page);
  await click(page, 'Saya Penjual');
  await page.waitForTimeout(4000);
  const emailBox = await page.locator('input[aria-label="Email Bisnis / Owner"]').boundingBox();
  await page.mouse.click(emailBox.x + emailBox.width / 2, emailBox.y + emailBox.height / 2);
  await page.keyboard.type('ikhlassabar2021@gmail.com', { delay: 12 });
  await page.keyboard.press('Tab');
  await page.waitForTimeout(250);
  await page.keyboard.type('sabar2021', { delay: 18 });
  await click(page, 'MASUK KE KASIRGO');
  await page.waitForTimeout(16000);
};

const openHelp = async (page) => {
  await page.reload({ waitUntil: 'networkidle' });
  await page.waitForTimeout(6000);
  await enableSemantics(page);
  await page.waitForTimeout(6000);
  await click(page, 'Pengaturan');
  await page.waitForTimeout(4000);
  await scrollDown(page, 5);
  const ok = await click(page, 'Bantuan & Tutorial');
  await page.waitForTimeout(4000);
  return ok;
};

const run = async () => {
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const ctx = await browser.newContext({
    viewport: { width: 1280, height: 1600 },
    serviceWorkers: 'block',
  });
  const page = await ctx.newPage();
  const errors = [];
  page.on('console', (m) => {
    if (m.type() === 'error') errors.push(m.text().slice(0, 220));
  });
  const out = {};

  try {
    await loginOwner(page);
    out.helpOpened = await openHelp(page);
    let txt = await textOf(page);
    out.tabs = txt.includes('Panduan') && txt.includes('Tiket Support');
    out.hero = txt.includes('Panduan Bergambar');
    out.topics =
      txt.includes('Mulai & Atur Toko') &&
      txt.includes('Jualan di Kasir') &&
      txt.includes('Pesanan Online') &&
      txt.includes('Laporan & Performa') &&
      txt.includes('Karyawan & Hak Akses') &&
      txt.includes('Bantuan, AI & Lampiran');
    await page.screenshot({ path: '/tmp/opencode/help_center.png' });

    out.topicOpen = await click(page, 'Jualan di Kasir');
    await page.waitForTimeout(2500);
    txt = await textOf(page);
    out.topicSteps =
      txt.includes('Pilih produk') &&
      txt.includes('Atur keranjang') &&
      txt.includes('Selesaikan pembayaran');
    out.mockRendered = txt.includes('Beras') && txt.includes('Total');
    out.actionButton = txt.includes('Buka Kasir');
    await page.screenshot({ path: '/tmp/opencode/help_topic.png' });
    await click(page, 'Back');
    await page.waitForTimeout(2000);

    out.ticketTab = await click(page, 'Tiket Support');
    await page.waitForTimeout(3000);
    txt = await textOf(page);
    out.ticketsScreen = txt.includes('Tiket Baru');

    const opened = await click(page, 'Tiket Baru');
    await page.waitForTimeout(2000);
    if (opened) {
      await page.locator('[aria-label="Judul / topik"]').first().fill(SUBJECT);
      await page.locator('[aria-label="Jelaskan kendala (opsional)"]').first().fill(
        'Uji otomatis lampiran gambar. Abaikan.'
      );
      const [chooser] = await Promise.all([
        page.waitForEvent('filechooser', { timeout: 10000 }).catch(() => null),
        click(page, 'Lampiran'),
      ]);
      out.pickerOpened = !!chooser;
      if (chooser) {
        await chooser.setFiles(IMG);
        await page.waitForTimeout(2000);
      }
      txt = await textOf(page);
      out.fileChip = txt.includes('qa-attachment.png');
      out.submitClicked = await click(page, 'Kirim Tiket');
      await page.waitForTimeout(8000);
      txt = await textOf(page);
      out.ticketDetail = txt.includes(SUBJECT) && txt.includes('Tim KasirGo');
      await page.screenshot({ path: '/tmp/opencode/ticket_detail.png' });
    }

    // Verifikasi lampiran via REST memakai sesi owner di localStorage.
    const info = await page.evaluate(async ({ supa, key, subject }) => {
      const k = Object.keys(localStorage).find((x) => x.includes('auth-token'));
      if (!k) return { error: 'no session' };
      const tok = JSON.parse(localStorage.getItem(k) || '{}')?.access_token;
      if (!tok) return { error: 'no token' };
      const h = { apikey: key, Authorization: 'Bearer ' + tok };
      const t = await fetch(
        `${supa}/rest/v1/support_tickets?subject=eq.${encodeURIComponent(subject)}&select=id`,
        { headers: h }
      ).then((r) => r.json());
      if (!t?.length) return { error: 'ticket not found' };
      const id = t[0].id;
      const atts = await fetch(
        `${supa}/rest/v1/support_ticket_attachments?ticket_id=eq.${id}&select=id,file_name,mime_type,size_bytes,storage_path,reply_id`,
        { headers: h }
      ).then((r) => r.json());
      return { ticketId: id, attachments: atts };
    }, { supa: SUPA, key: KEY, subject: SUBJECT });
    out.rest = info;

    // Admin melihat lampiran (React -> <img alt="...">).
    const apage = await ctx.newPage();
    const aerr = [];
    apage.on('console', (m) => {
      if (m.type() === 'error') aerr.push(m.text().slice(0, 200));
    });
    await apage.goto(ADMIN + '?cb=' + Date.now(), { waitUntil: 'networkidle', timeout: 120000 });
    await apage.waitForTimeout(2500);
    await apage.fill('input[type=email]', 'superadmin@kasirgo.com');
    await apage.fill('input[type=password]', 'sabar2021');
    await apage.keyboard.press('Enter');
    await apage.waitForTimeout(7000);
    await apage.goto(ADMIN + '#/support', { waitUntil: 'networkidle' });
    await apage.waitForTimeout(4000);
    const body = await apage.locator('body').innerText();
    out.adminSeesTicket = body.includes(SUBJECT);
    const row = apage.locator('button', { hasText: SUBJECT }).first();
    if (await row.count()) {
      await row.click();
      await apage.waitForTimeout(4000);
    }
    out.adminImage = (await apage.locator('img[alt="qa-attachment.png"]').count()) > 0;
    out.adminErrors = aerr.length;
    await apage.screenshot({ path: '/tmp/opencode/admin_ticket_attach.png' });

    // Mobile: pusat bantuan + form tiket tidak overflow.
    const mctx = await browser.newContext({
      viewport: { width: 390, height: 844 },
      serviceWorkers: 'block',
      isMobile: true,
      hasTouch: true,
    });
    const mpage = await mctx.newPage();
    const merr = [];
    mpage.on('console', (m) => {
      if (m.type() === 'error') merr.push(m.text().slice(0, 200));
    });
    await loginOwner(mpage);
    await mpage.locator('flt-semantics-placeholder').count();
    out.mobileHelp = await openHelp(mpage);
    await mpage.waitForTimeout(2000);
    await mpage.screenshot({ path: '/tmp/opencode/mobile_help.png' });
    out.mobileErrors = merr.length;
    await mctx.close();

    // Bersihkan data uji (superadmin): storage + tiket (cascade lampiran).
    if (info?.ticketId) {
      const at = await ctx.request.post(`${SUPA}/auth/v1/token?grant_type=password`, {
        headers: { apikey: KEY, 'Content-Type': 'application/json' },
        data: { email: 'superadmin@kasirgo.com', password: 'sabar2021' },
      });
      const adminTok = (await at.json()).access_token;
      for (const a of info.attachments ?? []) {
        await ctx.request.delete(
          `${SUPA}/storage/v1/object/support-attachments/${a.storage_path}`,
          { headers: { apikey: KEY, Authorization: 'Bearer ' + adminTok } }
        );
      }
      const del = await ctx.request.delete(
        `${SUPA}/rest/v1/support_tickets?id=eq.${info.ticketId}`,
        { headers: { apikey: KEY, Authorization: 'Bearer ' + adminTok, Prefer: 'return=minimal' } }
      );
      out.cleanupStatus = del.status();
    }
  } catch (e) {
    out.exception = String(e).slice(0, 500);
  }

  out.consoleErrors = errors.length;
  out.errorSamples = errors.slice(0, 5);
  console.log(JSON.stringify(out, null, 2));
  await browser.close();
};

run();