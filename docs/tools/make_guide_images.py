#!/usr/bin/env python3
"""Generate clean illustrative mockups of the KasirGo app (screens + buttons).

These are flat, color-accurate wireframes used inside the user guide PDF so
users can visually recognize each screen and button. They are NOT real
screenshots; the palette follows the "Centennial Modern Ocean White" design
system (see config/app_theme.dart).

Output: docs/tools/guide_images/*.png
"""
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'guide_images')
FONTS = '/usr/share/fonts/truetype'
LIB = os.path.join(FONTS, 'liberation2')
DEJA = os.path.join(FONTS, 'dejavu')


# Palette ---------------------------------------------------------------
def hexc(s):
    s = s.lstrip('#')
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


BG = hexc('F8FAFC')
SURFACE = hexc('FFFFFF')
BORDER = hexc('E2E8F0')
SOFT = hexc('F1F5F9')
PRIMARY = hexc('0284C7')
PRIMARY_DARK = hexc('075985')
TEAL = hexc('06B6D4')
INK = hexc('0F172A')
MUTED = hexc('64748B')
SUCCESS = hexc('10B981')
WARNING = hexc('F59E0B')
ERROR = hexc('EF4444')
INDIGO = hexc('4F46E5')
VIOLET = hexc('7C3AED')
PINK = hexc('DB2777')
TEAL_ACCENT = hexc('14B8A6')
ACCENT_BLUE = hexc('0EA5E9')
WHATSAPP = hexc('25D366')


def F(size, bold=False):
    p = os.path.join(LIB, 'LiberationSans-Bold.ttf' if bold else 'LiberationSans-Regular.ttf')
    return ImageFont.truetype(p, size)


def SF(size, bold=True):
    p = os.path.join(DEJA, 'DejaVuSans-Bold.ttf' if bold else 'DejaVuSans.ttf')
    return ImageFont.truetype(p, size)


PHONE_W, PHONE_H = 440, 860


def new_screen(w=PHONE_W, h=PHONE_H, bg=BG):
    img = Image.new('RGB', (w, h), bg)
    return img, ImageDraw.Draw(img)


def rrect(d, box, r, fill=None, outline=None, width=1):
    d.rounded_rectangle(box, radius=r, fill=fill, outline=outline, width=width)


def vgrad(d, box, c1, c2):
    (x0, y0, x1, y1) = box
    steps = max(2, y1 - y0)
    for i in range(steps):
        t = i / (steps - 1)
        c = tuple(int(c1[k] + (c2[k] - c1[k]) * t) for k in range(3))
        d.line([(x0, y0 + i), (x1, y0 + i)], fill=c)


def text(d, xy, s, font, fill, anchor='la'):
    d.text(xy, s, font=font, fill=fill, anchor=anchor)


def center_text(d, cx, s, font, fill, cy=None, box=None):
    if cy is None:
        cy = (box[1] + box[3]) // 2
    text(d, (cx, cy), s, font=font, fill=fill, anchor='mm')


# UI components ---------------------------------------------------------
def status_bar(d, w):
    text(d, (22, 26), '09:41', F(15, True), INK, anchor='lm')
    d.rounded_rectangle((w - 66, 14, w - 22, 34), radius=4, outline=INK, width=1)
    d.rectangle((w - 62, 18, w - 44, 30), fill=INK)
    d.rounded_rectangle((w - 40, 18, w - 26, 30), radius=2, fill=INK)


def app_bar(d, w, title, back=True):
    if back:
        d.line([(20, 56), (30, 48), (20, 40)], fill=PRIMARY, width=3, joint='curve')
    text(d, (54 if back else 22, 48), title, F(26, True), INK, anchor='lm')
    d.rounded_rectangle((w - 44, 42, w - 20, 54), radius=6, outline=BORDER, width=1)
    for i in range(3):
        d.ellipse((w - 40 + i * 8, 46, w - 36 + i * 8, 50), fill=MUTED)


def bottom_nav(d, w, h, active=2):
    d.rectangle((0, h - 86, w, h), fill=SURFACE, outline=BORDER)
    labels = ['Beranda', 'Produk', 'Kasir', 'Laporan', 'Lainnya']
    cx = [w * (i + 0.5) / 5 for i in range(5)]
    for i, lab in enumerate(labels):
        col = PRIMARY if i == active else MUTED
        if i == 2:
            d.ellipse((cx[i] - 26, h - 92, cx[i] + 26, h - 40), fill=TEAL)
            d.ellipse((cx[i] - 20, h - 86, cx[i] + 20, h - 46), fill=PRIMARY)
            icon_pos(d, cx[i], h - 64)
            d.text((cx[i], h - 28), lab, font=F(12, True), fill=PRIMARY, anchor='mm')
        else:
            d.text((cx[i], h - 58), '•', font=SF(20 if i == active else 16), fill=col, anchor='mm')
            d.text((cx[i], h - 28), lab, font=F(12, True if i == active else False), fill=col, anchor='mm')


def module_card(d, x0, y0, w, hh, title, sub, color, glyph):
    rrect(d, (x0, y0, x0 + w, y0 + hh), 16, fill=SURFACE, outline=BORDER, width=1)
    chip = 36
    rrect(d, (x0 + 14, y0 + 14, x0 + 14 + chip, y0 + 14 + chip), 12, fill=color)
    center_text(d, x0 + 14 + chip // 2, glyph, SF(20), SURFACE, cy=y0 + 14 + 8)
    text(d, (x0 + 14, y0 + 56), title, F(15, True), INK)
    text(d, (x0 + 14, y0 + 74), sub, F(12), MUTED)


def btn(d, box, label, fill=PRIMARY, txt=SURFACE, bold=True, r=14, size=16):
    rrect(d, box, r, fill=fill)
    center_text(d, (box[0] + box[2]) // 2, label, F(size, bold), txt, box=box)


# QR code (deterministic fake) -----------------------------------------
def icon_pos(d, cx, cy, color=SURFACE):
    rrect(d, (cx - 13, cy - 15, cx + 13, cy + 3), 3, fill=color)
    d.line([(cx, cy + 3), (cx, cy + 12)], fill=color, width=3)
    d.line([(cx - 11, cy + 12), (cx + 11, cy + 12)], fill=color, width=3)
    rrect(d, (cx + 5, cy - 11, cx + 18, cy - 2), 2, fill=SURFACE, outline=INK, width=1)
    d.line([(cx + 7, cy - 8), (cx + 16, cy - 8)], fill=INK, width=1)
    d.line([(cx + 7, cy - 5), (cx + 16, cy - 5)], fill=INK, width=1)


def icon_camera(d, cx, cy, color=MUTED):
    rrect(d, (cx - 18, cy - 9, cx + 18, cy + 13), 5, outline=color, width=3)
    d.ellipse((cx - 8, cy - 5, cx + 8, cy + 11), outline=color, width=3)


def icon_eye(d, cx, cy, color=MUTED):
    d.ellipse((cx - 13, cy - 6, cx + 13, cy + 6), outline=color, width=2)
    d.ellipse((cx - 3, cy - 3, cx + 3, cy + 3), fill=color)


def draw_qr(d, box, seed=7):
    import random
    rnd = random.Random(seed)
    x0, y0, x1, y1 = box
    rrect(d, box, 0, fill=SURFACE, outline=BORDER)
    n = 21
    cell = (x1 - x0) / n
    for r in range(n):
        for c in range(n):
            if rnd.random() < 0.44:
                d.rectangle((x0 + c * cell, y0 + r * cell, x0 + (c + 1) * cell, y0 + (r + 1) * cell), fill=INK)
    for (fx, fy) in [(0, 0), (n - 7, 0), (0, n - 7)]:
        d.rectangle((x0 + fx * cell - 2, y0 + fy * cell - 2, x0 + (fx + 7) * cell + 2, y0 + (fy + 7) * cell + 2), fill=SURFACE, outline=INK, width=3)
        d.rectangle((x0 + fx * cell + cell, y0 + fy * cell + cell, x0 + (fx + 6) * cell - cell, y0 + (fy + 6) * cell - cell), fill=INK)


# Screens ---------------------------------------------------------------
def screen_dashboard():
    img, d = new_screen()
    status_bar(d, PHONE_W)
    app_bar(d, PHONE_W, 'Beranda')
    y = 72
    # Omzet card
    card = (18, y, PHONE_W - 18, y + 130)
    d.rounded_rectangle(card, 20, fill=PRIMARY)
    text(d, (36, y + 26), 'OMZET HARI INI', F(13, True), hexc('E0F2FE'))
    text(d, (36, y + 58), 'Rp1.250.000', F(34, True), SURFACE)
    text(d, (36, y + 100), '+8% dari kemarin   •   42 transaksi', F(14), hexc('E0F2FE'))
    y += 150
    # Section header
    text(d, (20, y), 'Modul Bisnis KasirGo', F(19, True), INK, anchor='la')
    y += 30
    gw = (PHONE_W - 18 - 18 - 12) / 2
    gh = 108
    mods = [
        ('Dokter Bisnis AI', 'Diagnosa & resep', INDIGO, '+'),
        ('Sidak Stok & Kas', 'Audit internal', INDIGO, '✓'),
        ('Atur Harga & Diskon', 'Saran dari AI', VIOLET, '%'),
        ('Laporan & Progres', 'Tren usaha Anda', INDIGO, '↗'),
        ('Katalog Online', 'Web katalog WA', PRIMARY, '▦'),
        ('Afiliasi', 'Komisi referral', TEAL_ACCENT, '↗'),
    ]
    for i, (t, s, c, g) in enumerate(mods):
        r, col = divmod(i, 2)
        x0 = 18 + col * (gw + 12)
        y0 = y + r * (gh + 12)
        module_card(d, x0, y0, gw, gh, t, s, c, g)
    bottom_nav(d, PHONE_W, PHONE_H, active=0)
    return img


def screen_pos():
    img, d = new_screen()
    status_bar(d, PHONE_W)
    app_bar(d, PHONE_W, 'Kasir (POS)')
    y = 64
    # search
    rrect(d, (18, y, PHONE_W - 18, y + 44), 14, fill=SURFACE, outline=BORDER)
    d.ellipse((30, y + 13, 46, y + 29), outline=MUTED, width=2)
    d.line([(48, y + 31), (54, y + 37)], fill=MUTED, width=2)
    text(d, (62, y + 22), 'Cari produk atau pindai…', F(15), MUTED)
    y += 60
    # product grid (2 cols)
    gw = (PHONE_W - 18 - 18 - 12) / 2
    gh = 150
    prods = [('Beras 5 kg', 'Rp65.000', SUCCESS, 'Aman'),
             ('Minyak 1L', 'Rp18.000', SUCCESS, 'Aman'),
             ('Gula Pasir', 'Rp15.000', WARNING, 'Stok: 6'),
             ('Telur Ayam', 'Rp28.000', ERROR, 'Habis')]
    for i, (nm, pr, col, tag) in enumerate(prods):
        r, coln = divmod(i, 2)
        x0 = 18 + coln * (gw + 12)
        y0 = y + r * (gh + 12)
        rrect(d, (x0, y0, x0 + gw, y0 + gh), 12, fill=SURFACE, outline=BORDER)
        rrect(d, (x0 + 8, y0 + 8, x0 + gw - 8, y0 + 74), 8, fill=SOFT)
        text(d, (x0 + gw // 2, y0 + 41), '□', SF(34), MUTED, anchor='mm')
        text(d, (x0 + 12, y0 + 84), nm, F(14, True), INK)
        text(d, (x0 + 12, y0 + 104), pr, F(14, True), PRIMARY)
        rrect(d, (x0 + 12, y0 + 124, x0 + 74, y0 + 142), 8, fill=col)
        text(d, (x0 + 43, y0 + 133), tag, F(9, True), SURFACE, anchor='mm')
    # cart panel
    cy = PHONE_H - 250
    rrect(d, (18, cy, PHONE_W - 18, cy + 150), 16, fill=SURFACE, outline=PRIMARY, width=2)
    text(d, (34, cy + 24), 'Keranjang  (3 item)', F(17, True), INK)
    text(d, (34, cy + 50), 'Total', F(13), MUTED)
    text(d, (34, cy + 74), 'Rp108.000', F(26, True), PRIMARY)
    btn(d, (PHONE_W - 180, cy + 30, PHONE_W - 34, cy + 110), 'Bayar', PRIMARY, r=14, size=20)
    bottom_nav(d, PHONE_W, PHONE_H, active=2)
    return img


def screen_payment():
    img, d = new_screen()
    status_bar(d, PHONE_W)
    app_bar(d, PHONE_W, 'Pembayaran')
    y = 64
    # total card
    rrect(d, (18, y, PHONE_W - 18, y + 96), 16, fill=SURFACE, outline=BORDER)
    text(d, (34, y + 30), 'Total belanja', F(14), MUTED)
    text(d, (34, y + 62), 'Rp108.000', F(30, True), INK)
    y += 112
    # methods
    text(d, (20, y), 'Metode pembayaran', F(18, True), INK)
    y += 30
    methods = [('QRIS', 'Scan untuk bayar', PRIMARY, True),
               ('Tunai', 'Bayar di kasir', SUCCESS, False),
               ('Transfer', 'Bank transfer', MUTED, False)]
    for i, (nm, sub, c, sel) in enumerate(methods):
        rrect(d, (18, y, PHONE_W - 18, y + 64), 14, fill=SURFACE if not sel else hexc('E0F2FE'), outline=PRIMARY if sel else BORDER, width=2 if sel else 1)
        d.ellipse((34, y + 19, 48, y + 33), outline=c if not sel else PRIMARY, width=3)
        if sel:
            d.ellipse((38, y + 23, 44, y + 29), fill=PRIMARY)
        text(d, (62, y + 18), nm, F(16, True), INK)
        text(d, (62, y + 40), sub, F(12), MUTED)
        y += 76
    y += 8
    # QR pane
    qr = 150
    qx = (PHONE_W - qr) // 2
    rrect(d, (qx - 16, y - 16, qx + qr + 16, y + qr + 16), 16, fill=SURFACE, outline=BORDER)
    draw_qr(d, (qx, y, qx + qr, y + qr), seed=11)
    y += qr + 40
    text(d, (PHONE_W // 2, y), 'Arahkan kamera pembeli ke QR di atas', F(13), MUTED, anchor='mm')
    y += 30
    btn(d, (18, y, PHONE_W - 18, y + 58), 'Konfirmasi Pembayaran', PRIMARY, size=18)
    bottom_nav(d, PHONE_W, PHONE_H, active=2)
    return img


def screen_product_form():
    img, d = new_screen()
    status_bar(d, PHONE_W)
    app_bar(d, PHONE_W, 'Tambah Produk')
    y = 64
    fields = [('Nama Produk', 'Beras 5 kg'), ('Harga Jual', 'Rp65.000'),
              ('Stok Awal', '120'), ('Kategori', 'Sembako ▾')]
    for lbl, val in fields:
        rrect(d, (18, y, PHONE_W - 18, y + 62), 14, fill=SURFACE, outline=BORDER)
        text(d, (32, y + 20), lbl, F(13), MUTED)
        text(d, (32, y + 44), val, F(18, True), INK)
        y += 74
    # toggle jasa
    rrect(d, (18, y, PHONE_W - 18, y + 62), 14, fill=SURFACE, outline=BORDER)
    text(d, (32, y + 20), 'Produk Jasa / Layanan', F(15, True), INK)
    text(d, (32, y + 42), 'Tidak menghitung stok', F(12), MUTED)
    togg = (PHONE_W - 80, y + 16, PHONE_W - 34, y + 46)
    rrect(d, togg, 15, fill=SOFT)
    d.ellipse((togg[0] + 4, togg[1] + 4, togg[0] + 26, togg[3] - 4), fill=MUTED)
    y += 82
    # image picker
    rrect(d, (18, y, PHONE_W - 18, y + 110), 14, fill=SURFACE, outline=BORDER)
    icon_camera(d, PHONE_W // 2, y + 38)
    text(d, (PHONE_W // 2, y + 78), 'Tambah foto produk', F(13), MUTED, anchor='mm')
    y += 130
    btn(d, (18, y, PHONE_W - 18, y + 60), 'Simpan Produk', PRIMARY, size=18)
    return img


def screen_login():
    img, d = new_screen(bg=SURFACE)
    d.rectangle((0, 0, PHONE_W, PHONE_H), fill=SURFACE)
    y = 130
    text(d, (PHONE_W // 2, y), 'KasirGo', F(40, True), PRIMARY, anchor='mm')
    text(d, (PHONE_W // 2, y + 40), 'Masuk ke akun Anda', F(16), MUTED, anchor='mm')
    y += 100
    for lbl, val, secret in [('Email', 'nama@email.com', False), ('Kata Sandi', '••••••••', True)]:
        rrect(d, (30, y, PHONE_W - 30, y + 66), 14, fill=SOFT, outline=BORDER)
        text(d, (46, y + 22), lbl, F(13), MUTED)
        text(d, (46, y + 46), val, F(17, True), INK)
        if secret:
            icon_eye(d, PHONE_W - 58, y + 45)
        y += 84
    btn(d, (30, y, PHONE_W - 30, y + 62), 'Masuk', PRIMARY, size=18)
    y += 84
    text(d, (PHONE_W // 2, y), 'Belum punya akun?  Daftar', F(15, True), PRIMARY, anchor='mm')
    y += 40
    d.line([(30, y), (PHONE_W - 30, y)], fill=BORDER, width=1)
    text(d, (PHONE_W // 2, y + 30), 'atau lanjutkan dengan', F(13), MUTED, anchor='mm')
    return img


def screen_orders():
    img, d = new_screen()
    status_bar(d, PHONE_W)
    app_bar(d, PHONE_W, 'Pesanan Masuk')
    # tabs
    y = 60
    rrect(d, (18, y, PHONE_W - 18, y + 46), 12, fill=SOFT)
    for i, lab in enumerate(['Dine-in', 'Online']):
        tx = 18 + (PHONE_W - 36) / 4 + i * (PHONE_W - 36) / 2
        if i == 0:
            rrect(d, (tx - 78, y + 5, tx + 78, y + 41), 10, fill=SURFACE)
            text(d, (tx, y + 23), lab, F(15, True), INK, anchor='mm')
        else:
            text(d, (tx, y + 23), lab, F(15, True), MUTED, anchor='mm')
    y += 62
    orders = [('Meja 1', 'Nasi Goreng x2, Es Teh x2', 'Menunggu Bayar', WARNING),
              ('Meja 3', 'Ayam Bakar x1, Jeruk x1', 'Menunggu Bayar', WARNING),
              ('Online #104', 'Beras 5kg x1', 'Diproses', PRIMARY)]
    for i, (ttl, det, st, c) in enumerate(orders):
        hh = 96
        rrect(d, (18, y, PHONE_W - 18, y + hh), 14, fill=SURFACE, outline=BORDER)
        text(d, (34, y + 22), ttl, F(16, True), INK)
        text(d, (34, y + 46), det, F(13), MUTED)
        rrect(d, (PHONE_W - 148, y + 18, PHONE_W - 34, y + 42), 10, fill=c)
        text(d, (PHONE_W - 91, y + 30), st, F(11, True), SURFACE, anchor='mm')
        btn(d, (PHONE_W - 148, y + 50, PHONE_W - 34, y + 78), 'Konfirmasi', PRIMARY, r=10, size=13)
        y += hh + 12
    text(d, (PHONE_W // 2, y + 10), 'Pesanan belum dibayar tidak masuk dapur', F(12), MUTED, anchor='mm')
    bottom_nav(d, PHONE_W, PHONE_H, active=3)
    return img


def screen_buttons():
    img, d = new_screen(w=560, h=300, bg=BG)
    rrect(d, (0, 0, 560, 300), 0, fill=BG)
    # primary button
    text(d, (30, 34), 'Tombol aksi utama', F(17, True), INK)
    btn(d, (30, 60, 330, 118), 'Simpan Produk', PRIMARY, size=20)
    # secondary / outline
    text(d, (30, 150), 'Tombol sekunder', F(17, True), INK)
    rrect(d, (30, 176, 330, 234), 14, outline=PRIMARY, width=2)
    center_text(d, 180, 'Batal', F(20, True), PRIMARY, box=(30, 176, 330, 234))
    # chips / badge
    text(d, (360, 34), 'Badge status', F(17, True), INK)
    rrect(d, (360, 70, 470, 100), 12, fill=SUCCESS)
    center_text(d, 415, 'Aman', F(15, True), SURFACE, box=(360, 70, 470, 100))
    rrect(d, (360, 116, 470, 146), 12, fill=WARNING)
    center_text(d, 415, 'Menipis', F(15, True), SURFACE, box=(360, 116, 470, 146))
    rrect(d, (360, 162, 470, 192), 12, fill=ERROR)
    center_text(d, 415, 'Habis', F(15, True), SURFACE, box=(360, 162, 470, 192))
    # chip
    text(d, (360, 210), 'Chip pilihan', F(17, True), INK)
    rrect(d, (360, 240, 470, 272), 16, fill=hexc('E0F2FE'), outline=PRIMARY)
    center_text(d, 415, 'QRIS', F(15, True), PRIMARY, box=(360, 240, 470, 272))
    return img


SCREENS = {
    'dashboard.png': screen_dashboard,
    'pos.png': screen_pos,
    'pembayaran.png': screen_payment,
    'produk.png': screen_product_form,
    'login.png': screen_login,
    'pesanan.png': screen_orders,
    'tombol.png': screen_buttons,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in SCREENS.items():
        img = fn()
        img.save(os.path.join(OUT, name))
        print('OK', name, img.size)


if __name__ == '__main__':
    main()