#!/usr/bin/env python3
"""Generate the KasirGo user guide PDF (Bahasa Indonesia)."""
import os
from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT, TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    BaseDocTemplate, Frame, PageTemplate, Paragraph, Spacer, PageBreak,
    Table, TableStyle, KeepTogether, ListFlowable, ListItem, HRFlowable, Image,
)

PRIMARY = colors.HexColor('#0284C7')
PRIMARY_DARK = colors.HexColor('#075985')
ACCENT = colors.HexColor('#06B6D4')
INK = colors.HexColor('#0F172A')
MUTED = colors.HexColor('#64748B')
BORDER = colors.HexColor('#E2E8F0')
SOFT = colors.HexColor('#F1F5F9')
GREEN = colors.HexColor('#10B981')
AMBER = colors.HexColor('#F59E0B')

OUT = os.environ.get('GUIDE_OUT', '/tmp/opencode/panduan-kasirgo.pdf')
IMG_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'guide_images')

styles = getSampleStyleSheet()
S = {}
S['body'] = ParagraphStyle('body', parent=styles['BodyText'], fontName='Helvetica',
                           fontSize=9.8, leading=15, textColor=INK, spaceAfter=5,
                           alignment=TA_LEFT)
S['h1'] = ParagraphStyle('h1', parent=styles['Heading1'], fontName='Helvetica-Bold',
                         fontSize=20, leading=24, textColor=PRIMARY_DARK,
                         spaceBefore=2, spaceAfter=10)
S['h2'] = ParagraphStyle('h2', parent=styles['Heading2'], fontName='Helvetica-Bold',
                         fontSize=12.5, leading=16, textColor=PRIMARY,
                         spaceBefore=12, spaceAfter=5)
S['h3'] = ParagraphStyle('h3', parent=styles['Heading3'], fontName='Helvetica-Bold',
                         fontSize=10.5, leading=14, textColor=INK,
                         spaceBefore=8, spaceAfter=3)
S['bullet'] = ParagraphStyle('bullet', parent=S['body'], leftIndent=12,
                             bulletIndent=2, spaceAfter=3)
S['step'] = ParagraphStyle('step', parent=S['body'], leftIndent=16,
                           bulletIndent=2, spaceAfter=4)
S['note'] = ParagraphStyle('note', parent=S['body'], fontSize=9, leading=13,
                           textColor=PRIMARY_DARK, spaceAfter=0)
S['toc'] = ParagraphStyle('toc', parent=S['body'], fontSize=10.5, leading=18)
S['cover_title'] = ParagraphStyle('cover_title', parent=styles['Title'],
                                  fontName='Helvetica-Bold', fontSize=34, leading=40,
                                  textColor=colors.white, alignment=TA_LEFT)
S['cover_sub'] = ParagraphStyle('cover_sub', parent=S['body'], fontSize=12.5,
                                leading=19, textColor=colors.HexColor('#E0F2FE'))
S['cover_small'] = ParagraphStyle('cover_small', parent=S['body'], fontSize=9.5,
                                  textColor=colors.HexColor('#BAE6FD'))
S['table'] = ParagraphStyle('table', parent=S['body'], fontSize=8.8, leading=12,
                            spaceAfter=0)
S['table_h'] = ParagraphStyle('table_h', parent=S['table'], fontName='Helvetica-Bold',
                              textColor=colors.white)
S['caption'] = ParagraphStyle('caption', parent=S['body'], fontSize=8.4, leading=12,
                              textColor=MUTED, alignment=TA_CENTER, spaceAfter=2)


def footer(canvas, doc):
    canvas.saveState()
    w, h = A4
    canvas.setStrokeColor(BORDER)
    canvas.setLineWidth(0.7)
    canvas.line(20 * mm, 14 * mm, w - 20 * mm, 14 * mm)
    canvas.setFillColor(MUTED)
    canvas.setFont('Helvetica', 7.8)
    canvas.drawString(20 * mm, 9.5 * mm, 'KasirGo - Panduan Lengkap Penggunaan')
    canvas.drawRightString(w - 20 * mm, 9.5 * mm, f'Halaman {doc.page}')
    canvas.restoreState()


def cover(canvas, doc):
    w, h = A4
    canvas.saveState()
    canvas.setFillColor(PRIMARY_DARK)
    canvas.rect(0, 0, w, h, stroke=0, fill=1)
    canvas.setFillColor(colors.HexColor('#0C4A6E'))
    canvas.circle(w - 30 * mm, h - 40 * mm, 55 * mm, stroke=0, fill=1)
    canvas.setFillColor(ACCENT)
    canvas.setFillAlpha(0.25)
    canvas.circle(25 * mm, 40 * mm, 45 * mm, stroke=0, fill=1)
    canvas.setFillAlpha(1)
    canvas.setStrokeColor(ACCENT)
    canvas.setLineWidth(3)
    canvas.line(20 * mm, h - 62 * mm, 60 * mm, h - 62 * mm)
    canvas.restoreState()


def p(text, style='body'):
    return Paragraph(text, S[style])


def bullets(items, style='bullet'):
    return ListFlowable(
        [ListItem(p(i, style), leftIndent=12, value='circle') for i in items],
        bulletType='bullet', start='\u2022', leftIndent=12, bulletFontSize=8,
        spaceAfter=6,
    )


def steps(items):
    return ListFlowable(
        [ListItem(p(i, 'step'), leftIndent=18) for i in items],
        bulletType='1', leftIndent=18, bulletFontName='Helvetica-Bold',
        bulletFontSize=9.5, bulletColor=PRIMARY, spaceAfter=6,
    )


def callout(text, color=PRIMARY, bg=None):
    bg = bg or colors.HexColor('#EFF6FF')
    t = Table([[p(text, 'note')]], colWidths=[170 * mm])
    t.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), bg),
        ('BOX', (0, 0), (-1, -1), 0.6, color),
        ('LEFTPADDING', (0, 0), (-1, -1), 9),
        ('RIGHTPADDING', (0, 0), (-1, -1), 9),
        ('TOPPADDING', (0, 0), (-1, -1), 7),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 7),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
    ]))
    return KeepTogether([Spacer(1, 4), t, Spacer(1, 8)])


def table(rows, widths, header=True):
    data = []
    for r_i, row in enumerate(rows):
        data.append([p(c, 'table_h' if (header and r_i == 0) else 'table') for c in row])
    t = Table(data, colWidths=widths, repeatRows=1 if header else 0)
    style = [
        ('GRID', (0, 0), (-1, -1), 0.5, BORDER),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('RIGHTPADDING', (0, 0), (-1, -1), 6),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ('ROWBACKGROUNDS', (0, 1 if header else 0), (-1, -1), [colors.white, SOFT]),
    ]
    if header:
        style.append(('BACKGROUND', (0, 0), (-1, 0), PRIMARY))
    t.setStyle(TableStyle(style))
    return t


def shot(name, caption, width=78 * mm):
    path = os.path.join(IMG_DIR, name)
    if not os.path.exists(path):
        return []
    height = None
    try:
        from PIL import Image as PILImage
        with PILImage.open(path) as im:
            w, h = im.size
        height = width * h / w
    except Exception:
        height = None
    img = Image(path, width=width, height=height)
    img.hAlign = 'CENTER'
    return [KeepTogether([
        Spacer(1, 4), img, Spacer(1, 3),
        Paragraph(caption, S['caption']), Spacer(1, 8),
    ])]


def section(number, title, intro=None):
    flow = [Spacer(1, 2)]
    flow.append(Paragraph(f'{number}. {title}', S['h1']))
    flow.append(HRFlowable(width='100%', thickness=2, color=ACCENT, spaceAfter=8))
    if intro:
        flow.append(p(intro))
    return flow


def sub(title):
    return p(title, 'h2')


def build():
    story = []

    # ---------------------------------------------------------------- COVER
    story.append(Spacer(1, 52 * mm))
    story.append(Paragraph('PANDUAN LENGKAP', S['cover_small']))
    story.append(Spacer(1, 3))
    story.append(Paragraph('KasirGo', S['cover_title']))
    story.append(Spacer(1, 4))
    story.append(Paragraph('Aplikasi Kasir & Penumbuh Usaha UMKM Indonesia', S['cover_sub']))
    story.append(Spacer(1, 16 * mm))
    story.append(Paragraph(
        'Panduan langkah demi langkah untuk Owner, Admin, Kasir, Koki, '
        'dan Pembeli. Ditulis sederhana agar langsung bisa dipraktikkan.', S['cover_sub']))
    story.append(Spacer(1, 30 * mm))
    story.append(Paragraph('Versi 3.1 &bull; Edisi November 2026', S['cover_small']))
    story.append(Paragraph('dokterbisnis.web.id', S['cover_small']))
    story.append(PageBreak())

    # ------------------------------------------------------------ DAFTAR ISI
    story.append(Paragraph('Daftar Isi', S['h1']))
    story.append(HRFlowable(width='100%', thickness=2, color=ACCENT, spaceAfter=10))
    toc = [
        '1.  Tentang KasirGo, Cara Masuk & Langkah Awal',
        '2.  Peran Pengguna & Hak Akses',
        '3.  Menyiapkan Toko Pertama Kali',
        '4.  Mengelola Produk & Stok',
        '5.  Transaksi di Kasir (POS)',
        '6.  Pesanan Masuk, QR Meja & Dapur (KDS)',
        '7.  Katalog Online & Pemasaran WhatsApp',
        '8.  Pelanggan, Kasbon & Loyalitas',
        '9.  Laporan & Pembukuan',
        '10. Karyawan, Shift & Delegasi Tugas',
        '11. Dokter Bisnis AI & Fitur Penumbuh Usaha',
        '12. Marketplace Hyper-Local (Mode Pembeli)',
        '13. Bundling & Afiliasi',
        '14. Program Pendukung (Langganan)',
        '15. Panduan & Tiket Bantuan',
        '16. Tips, Perbaikan Masalah & FAQ',
    ]
    for item in toc:
        story.append(Paragraph(item, S['toc']))
    story.append(Spacer(1, 10))
    story.append(callout(
        '<b>Tips membaca:</b> ikuti nomor bagian sesuai kebutuhan. Bagian 1-3 wajib '
        'dibaca saat pertama kali memakai KasirGo. Bagian lain bisa dibaca sambil bekerja.'))
    story.append(PageBreak())

    # ------------------------------------------------------------------ 1
    story += section('1', 'Tentang KasirGo, Cara Masuk & Langkah Awal',
                     'KasirGo adalah aplikasi kasir untuk warung, kelontong, retail, '
                     'cafe, restoran, dan usaha jasa. Satu aplikasi, banyak peran: '
                     'owner, admin, kasir, koki, dan pembeli.')
    story.append(sub('1.1 Satu aplikasi untuk semua peran'))
    story.append(bullets([
        'Aplikasi yang sama dipakai semua orang. Menu yang muncul menyesuaikan peran akun.',
        'Data tersimpan di cloud sehingga aman bila ponsel hilang atau ganti perangkat.',
        'Tetap bisa berjualan saat internet putus: transaksi disimpan di perangkat lalu dikirim otomatis saat online kembali.',
    ]))
    story.append(sub('1.2 Masuk ke aplikasi'))
    story.append(steps([
        'Buka aplikasi KasirGo atau alamat <b>dokterbisnis.web.id</b> di browser.',
        'Pilih <b>Masuk</b> bila sudah punya akun, atau <b>Daftar</b> untuk membuat akun baru.',
        'Isi email dan kata sandi. Gunakan email aktif karena tautan konfirmasi dikirim ke email tersebut.',
        'Bila muncul pesan "Email harus dikonfirmasi", buka kotak masuk atau folder spam lalu klik tautan konfirmasi.',
        'Setelah masuk, pilih mode <b>Penjual</b> (mengelola toko) atau <b>Pembeli</b> (berbelanja di toko sekitar).',
    ]))
    story += shot('login.png', 'Tampilan layar masuk KasirGo: isi email dan kata sandi, lalu tekan Masuk.')
    story.append(callout(
        '<b>Lupa kata sandi?</b> Hubungi admin KasirGo atau gunakan menu ubah kata sandi '
        'di Pengaturan. Untuk akun staf, owner dapat meminta reset kepada tim KasirGo.'))
    story.append(sub('1.3 Mengenal tampilan'))
    story.append(bullets([
        '<b>Beranda</b> - kartu omzet hari ini, jumlah transaksi, grafik 7 hari terakhir, pesanan masuk, dan tombol cepat.',
        '<b>Menu samping (ikon garis tiga)</b> - Produk, Pelanggan, Karyawan, Laporan, Pengaturan, Panduan, dan Bantuan. Di layar lebar (web/tablet) menu tampil sebagai sidebar tetap.',
        '<b>Navigasi bawah</b> - berpindah antar tab utama sesuai peran. Semua tombol penting diberi jarak aman dari area navigasi HP agar tidak terhalang.',
        '<b>Ikon profil / keluar</b> berada di pojok kanan atas panel atau bawah sidebar.',
    ]))
    story += shot('dashboard.png', 'Beranda owner: kartu omzet, statistik, dan tombol modul bisnis.')
    story += shot('tombol.png', 'Gaya tombol dan label status yang dipakai aplikasi: tombol utama, sekunder, serta badge.',
                   width=150 * mm)
    story.append(sub('1.4 Beralih antara mode Penjual dan Pembeli'))
    story.append(steps([
        'Setelah masuk, aplikasi bisa dipakai dalam dua mode. Di halaman awal pilih '
        'kartu <b>Penjual</b> (mengelola toko) atau <b>Pembeli</b> (berbelanja di warung sekitar).',
        'Mode Penjual menampilkan beranda sesuai peran akun (owner/admin/kasir/koki).',
        'Mode Pembeli membuka radar toko terdekat, katalog, keranjang, dan pelacakan pesanan.',
        'Untuk kembali antar mode, gunakan menu profil atau keluar lalu masuk kembali sesuai kebutuhan.',
    ]))
    story.append(sub('1.5 Kesiapan saat ini (onboarding cepat)'))
    story.append(bullets([
        'Outlet baru otomatis diberi beberapa <b>produk contoh</b> berkategori "Contoh" untuk latihan.',
        'Di beranda owner muncul kartu <b>"Langkah Awal Berjualan"</b> berisi 3 langkah cepat: '
        'Pilih Tipe Usaha, Kelola Produk, dan Coba Transaksi Pertama - dengan bilah kemajuan (mis. 1/3).',
        'Setelah ketiga langkah selesai, kartu berubah menjadi "Tokomu siap. Selamat berjualan!" dan bisa ditutup (tombol X).',
        'Bila tidak ingin produk contoh, tekan <b>Hapus contoh</b> pada kartu tersebut. Produk contoh ikut hilang.',
    ]))
    story.append(callout(
        '<b>Ingin mulai bersih?</b> Anda boleh langsung menambah produk asli tanpa menghapus '
        'produk contoh. Produk contoh hanya alat bantu latihan dan bisa dihapus kapan saja.'))

    # ------------------------------------------------------------------ 2
    story.append(PageBreak())
    story += section('2', 'Peran Pengguna & Hak Akses',
                     'Setiap akun memiliki satu peran. Peran menentukan menu dan '
                     'tindakan yang boleh dilakukan.')
    story.append(table([
        ['Peran', 'Bisa melakukan', 'Platform'],
        ['Owner', 'Semua fitur: produk (termasuk hapus), laporan, karyawan, '
                  'pengaturan, dokter bisnis, afiliasi', 'Aplikasi (HP/Web)'],
        ['Admin', 'Tambah/edit produk, laporan standar, lihat pesanan & dapur. '
                  'Tidak bisa menghapus produk', 'Aplikasi'],
        ['Kasir', 'Transaksi POS, QRIS manual, pesanan masuk, shift, tip', 'Aplikasi'],
        ['Koki', 'Hanya layar Dapur (KDS): memproses status masakan', 'Aplikasi'],
        ['Pembeli', 'Radar toko, katalog, keranjang, pesanan, lacak pesanan', 'Aplikasi'],
        ['Superadmin', 'Kelola seluruh platform, tiket support, kontrol integrasi', 'Web admin'],
    ], [24 * mm, 108 * mm, 38 * mm]))
    story.append(Spacer(1, 6))
    story.append(callout(
        '<b>Ganti peran?</b> Satu email hanya punya satu peran. Untuk kasir yang juga '
        'pemilik, gunakan akun owner. Untuk menambah admin/kasir/koki, buka '
        '<b>Karyawan</b> di akun owner.', color=AMBER, bg=colors.HexColor('#FFFBEB')))

    # ------------------------------------------------------------------ 3
    story.append(PageBreak())
    story += section('3', 'Menyiapkan Toko Pertama Kali',
                     'Ikuti urutan ini agar toko siap dipakai berjualan.')
    story.append(p('Setelah mendaftar, Anda tidak langsung "dilepas". Ikuti urutan '
                   'berikut agar toko benar-benar siap dipakai. Cek daftar ini satu per satu.'))
    story.append(sub('3.1 Lengkapi profil & verifikasi (KYC)'))
    story.append(steps([
        'Buka <b>Pengaturan</b> dari menu samping. Isi <b>Nama Toko</b>, <b>Nomor WhatsApp</b> aktif, dan <b>Alamat</b> toko.',
        'Buka <b>Verifikasi KYC</b>. Isi nama sesuai KTP, lalu tekan tombol unggah untuk <b>Foto KTP</b>.',
        'Ambil foto KTP di tempat terang, permukaan rata, dan pastikan seluruh tulisan (khususnya 16 digit NIK) terlihat jelas dan tidak terpotong.',
        'Unggah <b>Selfie memegang KTP</b>: wajah dan KTP harus terlihat jelas dalam satu foto.',
        'Aplikasi memproses verifikasi otomatis. Bila lolos, status berubah menjadi <b>Terverifikasi</b>.',
        'Bila ditolak, muncul alasan (mis. NIK tidak terbaca atau foto blur). Perbaiki lalu kirim ulang.',
    ]))
    story.append(callout(
        '<b>Penting:</b> selama belum terverifikasi, hanya layar KYC, bantuan, dan keluar yang '
        'bisa dipakai. POS, produk, dan transaksi terkunci sampai verifikasi selesai. '
        'Foto KTP/selfie disimpan di perangkat Anda, bukan diunggah ke server.'))
    story.append(sub('3.2 Pilih tipe usaha'))
    story.append(steps([
        'Di kartu <b>"Langkah Awal Berjualan"</b> tekan <b>Pilih</b> pada baris "Pilih Tipe Usaha", '
        'atau buka <b>Pengaturan > Tipe Usaha</b>.',
        'Pilih tipe lewat daftar dropdown yang muncul. Contoh pilihan: Warung Sembako, Warung Madura, '
        'Kelontong, Retail, Cafe, Restoran, Kedai Kopi, Minimarket, Toko Baju, Apotek, Gerobak, Jasa, Lainnya.',
        'Tipe usaha menentukan fitur yang aktif: cafe/restoran memunculkan QR Meja & Dapur (KDS); '
        'warung/kelontong fokus ke produk & stok; Jasa memunculkan opsi produk layanan tanpa stok.',
        'Ubah tipe usaha kapan saja. Data lama tidak hilang.',
    ]))
    story.append(sub('3.3 Siapkan pembayaran (QRIS)'))
    story.append(steps([
        'Buka <b>Pengaturan > QRIS Toko</b>, lalu unggah gambar <b>QRIS statis</b> milik toko.',
        'QRIS statis dipakai untuk pembayaran manual: kasir menampilkan gambar, memeriksa dana masuk, lalu menandai lunas.',
        'Untuk penagihan dengan nominal bebas, pastikan QRIS yang diunggah adalah QRIS milik rekening toko Anda.',
    ]))
    story.append(sub('3.4 Atur pengiriman, jam buka & cabang'))
    story.append(bullets([
        'Aktifkan opsi <b>Diantar</b> bila menerima pesanan antar, lalu tentukan radius layanan (mis. 3/5/10 km).',
        'Isi jam buka agar pembeli tahu kapan toko menerima pesanan.',
        'Untuk beberapa cabang, tambahkan outlet lewat menu <b>Multi Outlet</b> (butuh Program Pendukung).',
        'Aktifkan lokasi toko pada pengaturan agar muncul di radar pembeli di sekitar Anda.',
    ]))
    story.append(sub('3.5 Daftar periksa kesiapan toko'))
    story.append(table([
        ['Cek', 'Cara memastikan'],
        ['Profil lengkap', 'Pengaturan: nama toko, WA, alamat terisi'],
        ['KYC verifikasi', 'Status KYC = Terverifikasi (hijau)'],
        ['Tipe usaha', 'Sudah dipilih sesuai jenis usaha'],
        ['Produk siap', 'Minimal 1 produk asli terdaftar (produk contoh boleh dihapus)'],
        ['QRIS', 'Gambar QRIS toko terunggah (opsional, untuk bayar QRIS)'],
        ['Lokasi (opsional)', 'Lokasi toko aktif bila ingin muncul di radar pembeli'],
    ], [40 * mm, 130 * mm]))

    # ------------------------------------------------------------------ 4
    story.append(PageBreak())
    story += section('4', 'Mengelola Produk & Stok',
                     'Produk adalah inti jualan. Masukkan produk dengan benar agar '
                     'laporan dan stok akurat.')
    story.append(sub('4.1 Menambah produk (klik per klik)'))
    story.append(steps([
        'Buka menu <b>Produk</b> (menu samping). Bila kartu "Langkah Awal" muncul, bisa juga tekan <b>Tambah</b> pada baris "Kelola Produk".',
        'Tekan tombol <b>+ / Tambah Produk</b> di pojok kanan bawah.',
        'Isi <b>Nama Produk</b>, lalu <b>Harga Jual</b>.',
        'Isi <b>Stok Awal</b> (jumlah barang yang ada saat ini).',
        'Pilih <b>Kategori</b> produk (mis. Makanan, Minuman, Sembako).',
        'Unggah <b>Foto Produk</b> bila ada. Foto disimpan di perangkat Anda (tidak diunggah ke server).',
        'Isi <b>Barcode</b> bila produk memiliki barcode (opsional).',
        'Tekan <b>Simpan</b>. Produk langsung muncul di daftar dan bisa dijual di kasir.',
    ]))
    story += shot('produk.png', 'Form tambah produk: nama, harga jual, stok awal, kategori, dan foto produk.')
    story.append(sub('4.2 Mengubah, mencari & menghapus produk'))
    story.append(bullets([
        '<b>Mengubah:</b> ketuk produk pada daftar untuk membuka form, ubah datanya, lalu tekan Simpan.',
        '<b>Mencari:</b> gunakan kolom pencarian di atas daftar produk, atau pindai barcode.',
        '<b>Ubah harga jual:</b> buka produk lalu perbarui Harga Jual.',
        '<b>Menghapus produk (khusus Owner):</b> ketuk dan tahan atau buka menu produk, pilih Hapus, lalu konfirmasi. '
        'Admin & Kasir tidak dapat menghapus produk.',
        'Produk yang sudah pernah terjual tetap aman: riwayat transaksi lama tidak ikut hilang saat produk dihapus.',
    ]))
    story.append(sub('4.3 Produk jasa / layanan'))
    story.append(steps([
        'Saat menambah/mengedit produk, aktifkan saklar <b>Produk Jasa / Layanan</b>.',
        'Kolom stok akan dinonaktifkan karena layanan tidak menghitung stok.',
        'Contoh: potong rambut, servis AC, cuci sepatu, les privat.',
        'Produk layanan tetap muncul di kasir dan katalog walau stok nol, dengan badge "Layanan".',
    ]))
    story.append(sub('4.4 Barcode & pencarian cepat'))
    story.append(bullets([
        'Isi kolom barcode bila produk memiliki barcode. Di kasir, tombol pindai dapat '
        'langsung mencari dan menambahkan produk tersebut ke keranjang.',
        'Gunakan kolom pencarian di kasir untuk menemukan produk berdasarkan nama.',
        'Badge stok pada kartu produk membantu memantau ketersediaan sekilas.',
    ]))
    story.append(sub('4.5 Stok masuk & stok opname'))
    story.append(steps([
        'Saat menerima barang dari pemasok, buka produk dan tambah stok (stok masuk).',
        'Setiap penambahan & pengurangan stok tercatat di <b>Riwayat Stok</b>.',
        'Untuk memeriksa fisik barang, gunakan <b>Sidak Stok & Kas</b> (menu Dokter Bisnis): hitung '
        'stok fisik dan uang kas, lalu aplikasi menampilkan selisih beserta nilai rupiahnya.',
    ]))
    story.append(callout(
        '<b>Kartu stok berwarna:</b> hijau berarti stok aman (di atas 10), kuning berarti '
        'menipis (1-10), merah berarti habis. Segera lakukan kulakan saat muncul kuning/merah.'))
    story.append(callout(
        '<b>Produk contoh:</b> outlet baru otomatis punya beberapa produk kategori "Contoh". '
        'Produk ini bisa dipakai berlatih atau dihapus lewat tombol <b>Hapus contoh</b> di kartu '
        '"Langkah Awal Berjualan".', color=ACCENT, bg=colors.HexColor('#ECFEFF')))

    # ------------------------------------------------------------------ 5
    story.append(PageBreak())
    story += section('5', 'Transaksi di Kasir (POS)',
                     'Alur menjual produk ke pelanggan di toko.')
    story.append(sub('5.1 Membuat transaksi (klik per klik)'))
    story.append(steps([
        'Buka menu <b>Kasir</b> (POS) dari menu samping atau tombol <b>BUKA KASIR (POS)</b> di beranda kasir.',
        'Cari produk lewat kolom pencarian, atau tekan tombol <b>pindai barcode</b> lalu arahkan kamera.',
        'Ketuk kartu produk untuk menambahkan ke keranjang. Ulangi untuk produk lain.',
        'Di keranjang, ubah jumlah dengan tombol + / -. Untuk menghapus item gunakan ikon tempat sampah.',
        'Periksa total di panel keranjang.',
        'Bila pelanggan ingin struk dikirim, isi <b>Nama Pelanggan</b> dan <b>Nomor WhatsApp</b>. '
        'Nama pelanggan otomatis tersimpan bila nomor WA diisi.',
        'Tekan <b>Bayar</b>, lalu pilih metode: <b>Tunai</b>, <b>QRIS</b>, atau <b>Transfer</b>.',
        'Untuk Tunai: masukkan jumlah uang diterima; kembalian dihitung otomatis.',
        'Tekan tombol konfirmasi untuk menyelesaikan transaksi.',
    ]))
    story.append(callout(
        '<b>Jual offline tetap jalan:</b> bila internet putus, transaksi disimpan di perangkat '
        'dan dikirim otomatis saat online kembali. Jangan hapus aplikasi/data sebelum sinkronisasi selesai.'))
    story += shot('pos.png', 'Layar Kasir (POS): cari produk, keranjang, dan panel total bayar.')
    story += shot('pembayaran.png', 'Layar pembayaran: pilih metode Tunai, QRIS, atau Transfer.')
    story.append(sub('5.2 Pembayaran QRIS'))
    story.append(bullets([
        '<b>QRIS statis:</b> gambar QRIS toko ditampilkan; kasir memeriksa dana masuk di aplikasi '
        'bank/e-wallet, lalu menandai transaksi lunas. Tersedia gratis.',
    ]))
    story.append(sub('5.3 Struk & kirim ke WhatsApp'))
    story.append(steps([
        'Setelah transaksi berhasil, muncul dialog sukses.',
        'Tekan <b>Struk PDF</b> untuk menyimpan/mencetak struk.',
        'Tekan <b>Kirim Struk Teks ke WA</b> atau <b>Kirim Struk PDF ke WA</b> bila nomor pelanggan diisi.',
        'Logo struk dapat diganti dari Pengaturan (tersimpan di perangkat).',
    ]))
    story.append(sub('5.4 Diskon, bundling & saran tambahan'))
    story.append(bullets([
        'Diskon produk diatur pada menu produk atau lewat fitur <b>Atur Harga & Diskon</b> (saran dari AI).',
        'Bundling (paket hemat) tampil sebagai satu item di keranjang dengan satu harga.',
        'Kasir menampilkan saran tambahan (cross-sell) dari kebiasaan belanja pelanggan.',
    ]))
    story.append(sub('5.5 Shift kasir & tip'))
    story.append(steps([
        'Di beranda kasir, tekan <b>Buka Shift</b>. Masukkan <b>Kas Modal Awal</b> (uang di laci saat mulai), lalu tekan <b>Mulai Shift</b>.',
        'Status di hero berubah menjadi "Shift Aktif".',
        'Saat selesai, tekan <b>Tutup Shift</b>. Isi <b>Total Kas Akhir (uang fisik di laci)</b>, lalu tekan <b>Tutup & Selesai</b>.',
        'Aplikasi menghitung selisih kas. Bila pas muncul "Kas pas!"; bila ada selisih, ditampilkan nilainya.',
        'Catat tip pelanggan lewat kartu <b>Input Tip</b> agar laporan tip rapi dan pembagiannya adil.',
    ]))
    story.append(sub('5.6 Jika stok kurang'))
    story.append(bullets([
        'Produk dengan stok merah (habis) tidak bisa ditambahkan sampai stok diisi.',
        'Produk layanan (jasa) tetap bisa dijual walau stok nol.',
        'Kelola stok dari menu Produk, atau gunakan Sidak Stok & Kas untuk memeriksa fisik.',
    ]))

    # ------------------------------------------------------------------ 6
    story.append(PageBreak())
    story += section('6', 'Pesanan Masuk, QR Meja & Dapur (KDS)',
                     'Pesanan dari pelanggan bisa datang lewat QR meja, katalog online, '
                     'atau marketplace. Semua masuk ke daftar Pesanan Masuk.')
    story.append(sub('6.1 Membuka daftar pesanan'))
    story.append(bullets([
        'Owner: tekan tombol <b>Pesanan Masuk</b> di beranda.',
        'Kasir: tekan kartu <b>Pesanan Masuk</b> di Beranda Kasir (ada angka notifikasi merah).',
        'Admin: buka tab <b>Pesanan</b> di posisi paling kiri.',
        'Daftar dibagi dua tab: <b>Dine-in</b> (pesanan QR meja) dan <b>Online</b> (katalog/pembeli).',
        'Pesanan baru ditandai <b>Menunggu Bayar</b>. Layar memperbarui otomatis saat ada pesanan baru.',
    ]))
    story += shot('pesanan.png', 'Daftar Pesanan Masuk terbagi tab Dine-in dan Online.')
    story.append(sub('6.2 Konfirmasi pembayaran'))
    story.append(steps([
        'Buka pesanan berlabel <b>Menunggu Bayar</b> untuk melihat rincian.',
        'Periksa dana: uang tunai diterima, atau saldo QRIS/transfer sudah masuk ke rekening.',
        'Bila pembayaran sudah benar, tekan <b>Konfirmasi Bayar</b>. Pesanan otomatis berstatus dibayar dan diteruskan ke Dapur.',
        'Bila pembayaran tidak ditemukan, gunakan aksi tolak/batalkan sesuai pesanan.',
        'Setelah selesai, daftar akan memperbarui dan badge notifikasi berkurang.',
    ]))
    story.append(callout(
        '<b>Penting:</b> pesanan baru tidak masuk antrean masak sebelum kasir menekan '
        'Konfirmasi Bayar. Ini mencegah masakan dibuat untuk pesanan yang belum dibayar.'))
    story.append(sub('6.3 Layer Dapur / KDS (untuk Koki & usaha makanan)'))
    story.append(steps([
        'Login sebagai Koki membuka layar Dapur secara langsung. Admin usaha makanan juga punya tab <b>Dapur (KDS)</b>.',
        'Tiket berisi pesanan yang sudah dibayar. Banner kuning di atas menunjukkan jumlah pesanan yang masih menunggu konfirmasi kasir.',
        'Ubah status tiket berurutan: <b>Dimasak</b> -> <b>Siap</b> -> <b>Selesai</b> sesuai progres di dapur.',
        'Gunakan filter di atas untuk fokus pada antrean tertentu. Layar memperbarui otomatis tanpa muat ulang.',
    ]))
    story.append(sub('6.4 QR Meja (khusus cafe & restoran)'))
    story.append(steps([
        'Buka menu <b>QR Meja Dine-in</b>.',
        'Tekan tombol tambah, isi nama meja (mis. "Meja 1"), lalu simpan.',
        'Cetak atau tempel QR di meja. Pelanggan memindai QR, memilih menu, dan mengirim pesanan.',
        'Pesanan masuk ke kasir sebagai <b>Menunggu Bayar</b>; setelah dikonfirmasi, tampil di Dapur.',
    ]))
    story.append(sub('6.5 Pesanan macet / tidak muncul'))
    story.append(bullets([
        'Pastikan Anda membuka <b>Pesanan Masuk</b>, bukan hanya tab POS.',
        'Pastikan akun berada pada outlet yang benar (bukan cabang lain).',
        'Tarik layar ke bawah untuk memuat ulang daftar.',
        'Pesanan berstatus Menunggu Bayar memang belum masuk Dapur sampai dikonfirmasi.',
    ]))

    # ------------------------------------------------------------------ 7
    story.append(PageBreak())
    story += section('7', 'Katalog Online & Pemasaran WhatsApp',
                     'Jualan tidak berhenti di toko. Bagikan katalog digital ke pelanggan.')
    story.append(sub('7.1 Menerbitkan katalog online'))
    story.append(steps([
        'Buka menu <b>Katalog Online</b> (owner).',
        'Aktifkan saklar publikasi pada tiap produk yang ingin tampil ke publik. '
        'Produk yang tidak dipublikasikan tetap hanya terlihat di kasir.',
        'Tekan <b>Salin Tautan</b> atau <b>Bagikan</b> untuk mengirim link katalog '
        'lewat WhatsApp/media sosial.',
        'Pelanggan membuka tautan, melihat daftar produk, lalu memesan dengan pembayaran '
        'QRIS atau Tunai (transfer bank tidak lagi dipakai di sisi pelanggan).',
        'Pesanan dari katalog muncul di <b>Pesanan Masuk > Online</b> untuk dikonfirmasi '
        'kasir sebelum diproses.',
    ]))
    story.append(sub('7.2 QR Meja untuk cafe & resto'))
    story.append(steps([
        'Buka menu <b>QR Meja</b>, lalu tekan <b>Tambah Meja</b> dan isi nama (mis. "Meja 1").',
        'Tab "Daftar Meja" menampilkan semua meja. Tekan ikon QR pada sebuah meja untuk '
        'menampilkan/menyimpan/cetak kode QR-nya.',
        'Tempel QR di meja. Pelanggan memindai QR, memilih menu, dan mengirim pesanan '
        'langsung ke kasir.',
        'Pesanan masuk dengan status Menunggu Bayar. Setelah kasir konfirmasi, pesanan '
        'diteruskan ke layar Dapur (KDS).',
    ]))
    story.append(sub('7.3 Broadcast WhatsApp'))
    story.append(steps([
        'Buka menu <b>WA Marketing</b> untuk menyusun pesan promosi.',
        'Tulis pesan, sisipkan variabel nama pelanggan bila tersedia, lalu pilih sasaran '
        'dari daftar pelanggan.',
        'Tekan kirim. Pesan dibuka lewat aplikasi WhatsApp Anda, sehingga tetap terasa '
        'personal dan bukan nomor asing.',
    ]))

    # ------------------------------------------------------------------ 8
    story.append(PageBreak())
    story += section('8', 'Pelanggan, Kasbon & Loyalitas',
                     'Kenali pelanggan agar bisa menagih piutang dan menjaga mereka kembali.')
    story.append(sub('8.1 Menambah & menyimpan pelanggan'))
    story.append(steps([
        'Buka menu <b>Pelanggan</b>. Tekan <b>Tambah Pelanggan</b> untuk memasukkan nama, '
        'nomor WhatsApp, dan catatan.',
        'Nama pelanggan otomatis tersimpan saat kasir mengetik nomor WhatsApp di layar '
        'pembayaran (POS) lalu menyelesaikan transaksi.',
        'Nomor ditulis dengan format 08xx atau 62xx; aplikasi menyamakan format agar tidak ganda.',
    ]))
    story.append(sub('8.2 Kasbon (piutang)'))
    story.append(steps([
        'Saat pelanggan berutang di kasir, catat sebagai kasbon berserta nominalnya.',
        'Buka <b>Pelanggan</b> untuk melihat sisa piutang tiap pelanggan agar mudah ditagih.',
        'Tandai pelunasan saat pelanggan membayar utangnya.',
    ]))
    story.append(sub('8.3 Menggunakan riwayat belanja'))
    story.append(bullets([
        'Riwayat belanja dipakai menawarkan produk yang biasa dibeli pelanggan.',
        'Nomor WhatsApp pelanggan dipakai untuk pengingat kasbon atau broadcast promo.',
        'Hapus pelanggan lewat menu titik-tiga, setelah konfirmasi.',
    ]))

    # ------------------------------------------------------------------ 9
    story.append(PageBreak())
    story += section('9', 'Laporan & Pembukuan',
                     'Angka yang benar membuat keputusan lebih tenang.')
    story.append(sub('9.1 Laporan harian (klik per klik)'))
    story.append(steps([
        'Buka menu <b>Laporan</b> (menu samping atau navigasi bawah).',
        'Pilih periode: 7 hari, 30 hari, atau rentang tanggal sendiri.',
        'Ringkasan menampilkan <b>omzet</b>, <b>laba kotor</b>, jumlah transaksi, produk terlaris, dan rincian metode bayar.',
        'Gulir ke bawah untuk melihat daftar transaksi beserta nama produk dan jumlahnya.',
    ]))
    story.append(sub('9.2 Unduh Excel & PDF'))
    story.append(steps([
        'Di layar laporan, tekan tombol <b>Excel</b>. Berkas xlsx dibuat dengan sheet Ringkasan, Penjualan, dan Per Produk.',
        'Tekan tombol <b>PDF</b> untuk laporan siap cetak berformat pembukuan sederhana (SAK EMKM): Identitas Usaha, Laba Rugi, Penerimaan per metode, dan tanda tangan.',
        'Di HP berkas tersimpan di penyimpanan; di web berkas langsung terunduh melalui browser.',
    ]))
    story.append(sub('9.3 Laporan ke bos & laporan otomatis'))
    story.append(steps([
        'Isi nomor <b>WhatsApp bos</b> pada pengaturan Dokter Bisnis.',
        'Aktifkan laporan otomatis (bagian Program Pendukung) agar ringkasan dikirim berkala.',
        'Laporan otomatis berisi ringkasan omzet, produk terlaris, dan catatan penting.',
    ]))
    story.append(sub('9.4 Laporan & Progres (skor usaha)'))
    story.append(steps([
        'Buka fitur <b>Laporan & Progres</b> dari beranda atau dari langkah resep Dokter Bisnis.',
        'Lihat skor usaha 0-100, tren omzet 7 hari terakhir, dan bar chart penjualan harian.',
        'Periksa kartu "Langkah Resep Dokter" dan "Target Omzet".',
        'Tekan <b>Catat Progres Hari Ini</b> untuk menyimpan capaian; muncul konfirmasi "Progres hari ini sudah dicatat".',
    ]))

    # ----------------------------------------------------------------- 10
    story.append(PageBreak())
    story += section('10', 'Karyawan, Shift & Delegasi Tugas',
                     'Bagi tugas dengan akun terpisah agar riwayat tetap jelas.')
    story.append(sub('10.1 Menambah akun karyawan (klik per klik)'))
    story.append(steps([
        'Buka menu <b>Karyawan</b> (hanya owner).',
        'Tekan <b>Tambah Karyawan</b>, lalu pilih peran: <b>Admin</b>, <b>Kasir</b>, atau '
        '<b>Koki (KDS Dapur Saja)</b> khusus usaha makanan.',
        'Isi <b>Nama</b>, <b>Email</b>, dan <b>Kata Sandi awal</b>.',
        'Tekan Simpan. Sampaikan email & kata sandi kepada karyawan.',
        'Karyawan masuk memakai email tersebut dan langsung melihat menu sesuai perannya '
        '(Koki langsung ke layar Dapur).',
    ]))
    story.append(callout(
        '<b>Kuota gratis:</b> 1 akun Admin dan 1 akun Kasir per outlet. Menambah lebih banyak '
        'akun membutuhkan Program Pendukung. Saat Program Pendukung/trial aktif, jumlah staf menjadi tanpa batas.'))
    story.append(sub('10.2 Mengubah peran & mengatur ulang kata sandi'))
    story.append(bullets([
        'Buka data karyawan pada daftar untuk mengubah perannya.',
        'Bila staf lupa kata sandi, minta owner/admin mengatur ulang melalui menu Karyawan, '
        'atau hubungi tim KasirGo.',
        'Jangan bagikan akun owner kepada staf. Buat akun terpisah agar riwayat tugas tetap jelas.',
    ]))
    story.append(sub('10.3 Shift & tip'))
    story.append(bullets([
        'Kasir membuka shift saat mulai bekerja dan menutupnya saat pulang.',
        'Sistem mencatat kas awal, penjualan tunai, dan selisih kas (pas / lebih / kurang).',
        'Tip pelanggan dicatat per shift agar pembagiannya adil.',
        'Owner dapat melihat laporan kinerja staf lewat menu Performa Staf.',
    ]))
    story.append(sub('10.4 Delegasi tugas & pengingat'))
    story.append(steps([
        'Owner memberi tugas berbatas waktu kepada staf dari menu delegasi.',
        'Tugas tampil sebagai kartu di beranda staf dan owner.',
        'Tugas yang mendekati/melewati tenggat memunculkan notifikasi pengingat di perangkat.',
        'Staf menandai tugas selesai; owner melihat rekap keterlambatan.',
    ]))

    # ----------------------------------------------------------------- 11
    story.append(PageBreak())
    story += section('11', 'Dokter Bisnis AI & Fitur Penumbuh Usaha',
                     'Asisten digital yang membantu mendiagnosis usaha dan menyusun '
                     'langkah perbaikan. Semua fitur ini bagian dari Program Pendukung.')
    story.append(sub('11.1 Mulai konsultasi'))
    story.append(steps([
        'Buka kartu <b>Dokter Bisnis AI</b> di beranda owner (kartu ini terkunci bila Program Pendukung belum aktif).',
        'Pilih salah satu tombol topik cepat: <b>Diagnosa Usaha</b>, <b>Kenapa Omzet Turun</b>, '
        '<b>Saran Promosi</b>, atau <b>Cek Stok & Kas</b>.',
        'Isi <b>"Cek Fisik Toko"</b>: 3 langkah bergambar (kondisi fisik, tampilan, dan perilaku usaha). '
        'Setelah selesai, tombol ini berubah menjadi permanen di atas chat agar bisa diisi ulang kapan saja.',
        'Ketik pertanyaan seperti berbicara ke konsultan. Selama menunggu, muncul "... sedang menganalisa".',
        'Dokter menjawab dengan teks ringkas + kartu (card/gauge/checklist) sesuai kebutuhan.',
    ]))
    story.append(sub('11.2 Membaca hasil & menjalankan resep'))
    story.append(steps([
        'Setelah konsultasi fase diagnosa, tekan tombol <b>Lihat Hasil Diagnosa</b>.',
        'Layar hasil menampilkan skor usaha 0-100 (gauge), vonis berwarna, dan <b>Peta Resep</b> berisi langkah bernomor.',
        'Pada setiap langkah resep tersedia dua tombol: <b>Jalankan</b> (membuka fitur terkait di aplikasi) '
        'dan <b>Tandai Selesai</b> (bila sudah dikerjakan di luar aplikasi).',
        'Kartu <b>Resep Aktif</b> di atas chat menampilkan masa target. Bila lewat target, muncul peringatan.',
        'Bila semua langkah ditandai selesai, resep otomatis berstatus selesai (achieved).',
        'Tekan <b>Simpan / Bagikan</b> untuk menyimpan hasil sebagai PDF atau mengirim ke WhatsApp bos.',
        'Buka <b>Riwayat Kasus</b> dari ikon di kanan atas untuk melanjutkan konsultasi lama atau menghapus riwayat.',
    ]))
    story.append(callout(
        '<b>Tombol Evaluasi Resep:</b> pada fase resep/evaluasi, tekan "Berhasil" atau "Belum Berhasil". '
        'Bila belum berhasil, Dokter memperbaiki resep dan menaikkan tingkat penanganan.'))
    story.append(sub('11.3 Fitur penumbuh usaha'))
    story.append(table([
        ['Fitur', 'Kegunaan'],
        ['Sidak Stok & Kas', 'Menghitung stok fisik dan uang kas, menampilkan selisih bernilai rupiah.'],
        ['Atur Harga & Diskon', 'Saran diskon dan kenaikan harga yang tetap aman di atas modal.'],
        ['Laporan & Progres', 'Skor kemajuan usaha serta capaian target omzet.'],
        ['Bos Virtual', 'Analitik penjualan, peluang cross-sell, dan pengingat tindakan.'],
        ['Laporan Mingguan', 'Ringkasan otomatis setiap pekan beserta saran tindak lanjut.'],
    ], [42 * mm, 128 * mm]))
    story.append(Spacer(1, 6))
    story.append(callout(
        '<b>Perlu persetujuan:</b> saran yang mengubah data (mis. menjalankan promosi) '
        'muncul sebagai kartu persetujuan. Anda memutuskan Setujui atau Tolak.'))

    # ----------------------------------------------------------------- 12
    story.append(PageBreak())
    story += section('12', 'Marketplace Hyper-Local (Mode Pembeli)',
                     'Pembeli dapat menemukan toko di sekitar dan memesan langsung.')
    story.append(sub('12.1 Beralih ke mode Pembeli'))
    story.append(steps([
        'Di halaman awal, pilih kartu <b>Pembeli</b>. Bila belum punya akun, ikuti pendaftaran singkat '
        '(email sudah terdaftar otomatis diarahkan ke mode Masuk).',
        'Izinkan akses lokasi agar radar menampilkan toko terdekat ("Lokasi aktif" muncul di atas daftar).',
        'Pilih radius <b>3, 5, atau 10 km</b> lewat chip di bagian atas.',
    ]))
    story.append(sub('12.2 Memesan (klik per klik)'))
    story.append(steps([
        'Pilih toko dari daftar "Toko Terdekat", lalu buka katalog produknya.',
        'Cari produk lewat kolom pencarian bila daftarnya panjang.',
        'Ketuk <b>Tambah</b> pada produk untuk memasukkannya ke keranjang. Satu keranjang hanya untuk satu toko.',
        'Buka keranjang, periksa jumlah, lalu tekan <b>Lanjut ke Checkout</b>.',
        'Isi <b>Nama</b>, <b>Nomor WhatsApp</b>, dan <b>Alamat</b> bila memilih diantar (pilih ambil sendiri bila mengambil di toko).',
        'Tekan <b>Buat Pesanan</b>. Muncul kartu "Pesanan Dibuat" berisi kode pesanan dan total.',
        'Ikuti instruksi pembayaran yang muncul (tunai / QRIS saat pesanan diterima).',
    ]))
    story.append(sub('12.3 Melacak pesanan'))
    story.append(bullets([
        'Buka tab <b>Pesanan</b> untuk melihat semua pesanan Anda.',
        'Status bergerak: Dibuat -> Diproses -> Siap / Diantar -> Selesai.',
        'Simpan bukti transfer di perangkat bila memilih transfer manual.',
        'Hubungi toko lewat tombol WhatsApp bila ada perubahan pesanan.',
    ]))

    # ----------------------------------------------------------------- 13
    story.append(PageBreak())
    story += section('13', 'Bundling & Afiliasi',
                     'Dua cara menambah omzet tanpa menambah biaya iklan.')
    story.append(sub('13.1 Paket bundling'))
    story.append(steps([
        'Buka menu <b>Bundling</b>, lalu buat paket (mis. Sembako Hemat).',
        'Pilih produk dan atur harga paket lebih murah dari harga satuan.',
        'Paket muncul di kasir dan katalog pelanggan sebagai satu item.',
    ]))
    story.append(sub('13.2 Afiliasi untuk owner'))
    story.append(steps([
        'Setiap outlet otomatis memiliki kode afiliasi (contoh KGO-XXXXXX). Buka menu <b>Afiliasi</b> untuk melihatnya.',
        'Tekan <b>Salin</b> untuk menyalin kode/link, lalu bagikan kepada calon pengguna KasirGo.',
        'Komisi dari pengguna yang bergabung tercatat di menu <b>Afiliasi</b> (ringkasan + riwayat closing).',
        'Lengkapi data rekening agar komisi dapat dicairkan.',
    ]))

    # ----------------------------------------------------------------- 14
    story.append(PageBreak())
    story += section('14', 'Program Pendukung (Langganan)',
                     'Fitur inti KasirGo gratis selamanya. Program Pendukung membuka '
                     'fitur bonus dan membantu pengembangan aplikasi.')
    story.append(sub('14.1 Cara berlangganan (klik per klik)'))
    story.append(steps([
        'Buka kartu <b>Dukung KasirGo</b> di beranda, atau menu <b>Program Pendukung</b> '
        'di Pengaturan.',
        'Bila belum punya langganan, tekan <b>Beli Sekarang</b> atau gunakan <b>Coba Trial '
        'Gratis</b> bila tersedia.',
        'Pilih paket <b>Pendukung</b> seharga <b>Rp50.000 per bulan</b> (satu harga, tanpa tingkatan).',
        'Pilih <b>QRIS Dinamis</b> untuk pembayaran otomatis. Pindai QR yang muncul dan '
        'bayar; status aktif terverifikasi sendiri dalam beberapa detik.',
        'Untuk pembayaran QRIS statis/manual, ikuti petunjuk pada layar, lalu tunggu '
        'konfirmasi dari sistem.',
    ]))
    story.append(sub('14.2 Memeriksa status langganan'))
    story.append(steps([
        'Buka <b>Program Pendukung</b> untuk melihat status, masa berlaku, dan daftar manfaat.',
        'Bila masa aktif habis, fitur inti tetap bisa dipakai; fitur bonus terkunci sampai diperpanjang.',
        'Tekan <b>Perpanjang Sekarang</b> untuk memperpanjang sebelum masa berakhir.',
    ]))
    story.append(sub('Fitur bonus utama'))
    story.append(table([
        ['Kategori', 'Contoh fitur'],
        ['Pesanan & layanan', 'QR Meja, katalog online, dapur (KDS)'],
        ['Penumbuh usaha', 'Dokter Bisnis AI, Sidak Bos, Atur Harga & Diskon, Laporan & Progres'],
        ['Pemasaran', 'WA Marketing, bundling, laporan otomatis ke bos, bebas iklan'],
        ['Operasional', 'Multi outlet, kuota staf tambahan, struk dengan logo sendiri'],
    ], [42 * mm, 128 * mm]))
    story.append(Spacer(1, 6))
    story.append(callout(
        '<b>Cara berlangganan:</b> buka kartu Program Pendukung di beranda atau Pengaturan, '
        'pilih paket, lalu pindai QRIS yang muncul. Tunggu beberapa detik sampai status berubah aktif.'))

    # ----------------------------------------------------------------- 15
    story.append(PageBreak())
    story += section('15', 'Panduan & Tiket Bantuan',
                     'Bila ada kendala, Anda tidak perlu menebak. Kirim tiket dan '
                     'tim KasirGo akan membalas di aplikasi.')
    story.append(sub('15.1 Membuka Panduan'))
    story.append(steps([
        'Buka menu <b>Panduan</b> dari beranda, atau <b>Bantuan & Tutorial</b> dari menu samping.',
        'Pilih tab <b>Panduan</b> untuk melihat panduan bergambar (simulasi langkah satu per satu).',
        'Gunakan kolom pencarian dan filter kategori/peran untuk menemukan panduan.',
        'Panduan PDF dapat diunduh agar tetap terbaca saat offline.',
    ]))
    story.append(sub('15.2 Membuat tiket bantuan'))
    story.append(steps([
        'Buka <b>Bantuan & Tutorial</b> (menu samping) atau <b>Tiket Bantuan</b> di Pengaturan, '
        'lalu pilih tab <b>Tiket Support</b>.',
        'Tekan <b>Tiket Baru</b>, tulis judul singkat dan penjelasan kendala.',
        'Sertakan nama menu, pesan error, dan waktu kejadian agar cepat ditangani.',
        'Opsional: tekan <b>Lampiran</b> untuk menambah sampai 3 file (maks 10 MB) '
        'berupa screenshot atau dokumen.',
        'Tekan <b>Kirim Tiket</b>. Tiket muncul di daftar dengan status Menunggu.',
    ]))
    story.append(sub('15.3 Status tiket'))
    story.append(table([
        ['Status', 'Arti'],
        ['Menunggu', 'Tiket sudah masuk dan menunggu dibaca tim KasirGo.'],
        ['Diproses', 'Tim KasirGo sudah membalas atau sedang menangani.'],
        ['Selesai', 'Masalah selesai dan tiket ditutup oleh owner.'],
    ], [30 * mm, 140 * mm]))
    story.append(Spacer(1, 6))
    story.append(bullets([
        'Balas tiket di kolom pesan. Balasan owner otomatis membuka kembali tiket yang sudah selesai.',
        'Hanya owner yang dapat menutup tiket. Staf tetap bisa membalas.',
        'Superadmin melihat semua tiket dari seluruh outlet dan dapat membalas, mengubah status, atau menghapus tiket.',
    ]))

    # ----------------------------------------------------------------- 16
    story.append(PageBreak())
    story += section('16', 'Tips, Perbaikan Masalah & FAQ',
                     'Solusi cepat untuk kendala yang paling sering terjadi.')
    story.append(sub('16.1 Tidak bisa masuk'))
    story.append(bullets([
        'Pastikan email dan kata sandi benar (perhatikan huruf besar/kecil).',
        'Bila muncul "Email harus dikonfirmasi", cek kotak masuk dan folder spam untuk tautan konfirmasi.',
        'Bila akun staf lupa kata sandi, minta owner atau tim KasirGo melakukan reset.',
        'Keluar dahulu sebelum masuk dengan akun lain agar sesi tidak tertukar.',
    ]))
    story.append(sub('16.2 Tombol tertutup navigasi ponsel'))
    story.append(bullets([
        'Pastikan aplikasi versi terbaru sudah terpasang.',
        'Pada ponsel dengan navigasi gestur, area bawah layar kini otomatis diberi jarak aman '
        'sehingga tombol tidak tertutup.',
        'Bila masih terpotong, tutup aplikasi dari daftar aplikasi lalu buka kembali.',
    ]))
    story.append(sub('16.3 Lokasi & radar tidak muncul'))
    story.append(bullets([
        'Aktifkan GPS dan izinkan akses lokasi untuk KasirGo.',
        'Untuk owner, pastikan lokasi toko aktif agar muncul di radar pembeli.',
        'Pastikan radius yang dipilih cukup besar (mis. 10 km).',
    ]))
    story.append(sub('16.4 Pesanan tidak muncul di kasir/koki'))
    story.append(bullets([
        'Periksa menu <b>Pesanan Masuk</b> pada peran kasir atau admin.',
        'Pesanan baru berstatus Menunggu Bayar. Konfirmasi pembayaran agar masuk Dapur.',
        'Bila daftar kosong, tarik layar ke bawah untuk memuat ulang.',
        'Pastikan akun berada pada outlet yang benar (bukan cabang lain).',
    ]))
    story.append(sub('16.5 QRIS tidak muncul'))
    story.append(bullets([
        'QRIS statis dipakai di kasir: unggah gambar QRIS toko lebih dulu di Pengaturan > QRIS Toko.',
        'Bila gambar QRIS belum diunggah, tombol QRIS tidak menampilkan apa pun.',
        'Bila gambar sudah diunggah tetapi tidak muncul, tutup lalu buka kembali layar pembayaran.',
    ]))
    story.append(sub('16.6 Internet putus'))
    story.append(bullets([
        'Transaksi tetap tersimpan di perangkat dan dikirim otomatis saat internet kembali.',
        'Hindari menghapus aplikasi/data sebelum sinkronisasi selesai.',
        'Periksa ikon status sinkronisasi di aplikasi.',
    ]))
    story.append(sub('16.7 Pertanyaan umum'))
    story.append(bullets([
        '<b>Apakah data aman?</b> Data disimpan di server dengan hak akses per outlet. '
        'Foto produk tetap di perangkat Anda.',
        '<b>Bisa dipakai tanpa internet?</b> Bisa untuk transaksi. Sinkronisasi berjalan saat online.',
        '<b>Bisa ganti nomor WhatsApp?</b> Bisa, ubah di Pengaturan.',
        '<b>Bisa punya lebih dari satu toko?</b> Bisa melalui Multi Outlet (Program Pendukung).',
        '<b>Bagaimana menambah staf?</b> Menu Karyawan di akun owner.',
    ]))
    story.append(Spacer(1, 8))
    story.append(HRFlowable(width='100%', thickness=1, color=BORDER, spaceAfter=8))
    story.append(p('<b>Butuh bantuan lain?</b> Buka menu <b>Tiket Bantuan</b> di aplikasi. '
                   'Tim KasirGo akan membalas di tiket yang sama.', 'body'))
    story.append(p('KasirGo - membantu UMKM Indonesia berjualan lebih rapi dan bertumbuh.', 'note'))

    doc = BaseDocTemplate(
        OUT, pagesize=A4,
        leftMargin=20 * mm, rightMargin=20 * mm,
        topMargin=18 * mm, bottomMargin=20 * mm,
        title='Panduan Lengkap KasirGo', author='KasirGo',
        subject='Panduan penggunaan aplikasi KasirGo',
    )
    frame = Frame(doc.leftMargin, doc.bottomMargin, doc.width, doc.height, id='normal')
    doc.addPageTemplates([
        PageTemplate(id='cover', frames=[frame], onPage=cover),
        PageTemplate(id='body', frames=[frame], onPage=footer),
    ])

    from reportlab.platypus import NextPageTemplate as _NPT
    story.insert(1, _NPT('body'))
    doc.build(story)
    print('PDF written:', OUT, os.path.getsize(OUT), 'bytes')


if __name__ == '__main__':
    build()