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
    Table, TableStyle, KeepTogether, ListFlowable, ListItem, HRFlowable,
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
    story.append(Paragraph('Versi 3.0 &bull; Edisi Oktober 2026', S['cover_small']))
    story.append(Paragraph('ikhlassabar2021-create.github.io/kasirgo', S['cover_small']))
    story.append(PageBreak())

    # ------------------------------------------------------------ DAFTAR ISI
    story.append(Paragraph('Daftar Isi', S['h1']))
    story.append(HRFlowable(width='100%', thickness=2, color=ACCENT, spaceAfter=10))
    toc = [
        '1.  Tentang KasirGo & Cara Masuk',
        '2.  Peran Pengguna & Hak Akses',
        '3.  Menyiapkan Toko Pertama Kali',
        '4.  Mengelola Produk, Stok & Resep',
        '5.  Transaksi di Kasir (POS)',
        '6.  Pesanan Masuk, QR Meja & Dapur (KDS)',
        '7.  Katalog Online & Pemasaran WhatsApp',
        '8.  Pelanggan, Kasbon & Loyalitas',
        '9.  Laporan & Pembukuan',
        '10. Karyawan, Shift & Delegasi Tugas',
        '11. Dokter Bisnis AI & Fitur Penumbuh Usaha',
        '12. Marketplace Hyper-Local (Mode Pembeli)',
        '13. Bundling, Referral & Afiliasi',
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
    story += section('1', 'Tentang KasirGo & Cara Masuk',
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
        'Buka aplikasi KasirGo atau alamat <b>ikhlassabar2021-create.github.io/kasirgo</b> di browser.',
        'Pilih <b>Masuk</b> bila sudah punya akun, atau <b>Daftar</b> untuk membuat akun baru.',
        'Isi email dan kata sandi. Gunakan email aktif karena tautan konfirmasi dikirim ke email tersebut.',
        'Bila muncul pesan "Email harus dikonfirmasi", buka kotak masuk atau folder spam lalu klik tautan konfirmasi.',
        'Setelah masuk, pilih mode <b>Penjual</b> (mengelola toko) atau <b>Pembeli</b> (berbelanja di toko sekitar).',
    ]))
    story.append(callout(
        '<b>Lupa kata sandi?</b> Hubungi admin KasirGo atau gunakan menu ubah kata sandi '
        'di Pengaturan. Untuk akun staf, owner dapat meminta reset kepada tim KasirGo.'))
    story.append(sub('1.3 Mengenal tampilan'))
    story.append(bullets([
        '<b>Beranda</b> - ringkasan penjualan hari ini, pesanan masuk, dan tombol cepat.',
        '<b>Menu samping (garis tiga)</b> - produk, pelanggan, karyawan, laporan, pengaturan, bantuan.',
        '<b>Navigasi bawah</b> - berpindah antar tab utama sesuai peran.',
    ]))

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
    story.append(sub('3.1 Lengkapi profil & verifikasi (KYC)'))
    story.append(steps([
        'Buka <b>Pengaturan</b> lalu lengkapi nama toko, nomor WhatsApp, dan alamat.',
        'Buka <b>Verifikasi KYC</b>: isi nama sesuai KTP, unggah foto KTP dan selfie.',
        'Pastikan tulisan NIK pada KTP terlihat jelas dan tidak terpotong.',
        'Setelah lolos verifikasi, fitur premium dan pencairan dana dapat digunakan.',
    ]))
    story.append(sub('3.2 Pilih tipe usaha'))
    story.append(bullets([
        'Tipe usaha menentukan modul otomatis: cafe/restoran mendapat QR Meja & Dapur (KDS); '
        'warung/kelontong mendapat fokus produk & stok; jasa mendapat produk layanan tanpa stok.',
        'Ubah tipe usaha kapan saja di Pengaturan. Data lama tidak hilang.',
    ]))
    story.append(sub('3.3 Siapkan pembayaran'))
    story.append(steps([
        'Unggah gambar <b>QRIS statis</b> milik toko di Pengaturan > QRIS Toko.',
        'QRIS statis dipakai untuk pembayaran manual: kasir memeriksa dana masuk, lalu menandai lunas.',
        'Untuk QRIS otomatis (dana terverifikasi sendiri), aktifkan lewat Program Pendukung.',
    ]))
    story.append(sub('3.4 Atur pengiriman & jam buka'))
    story.append(bullets([
        'Aktifkan <b>Diantar</b> bila menerima pesanan antar, lalu tentukan radius layanan.',
        'Isi jam buka agar pembeli tahu kapan toko menerima pesanan.',
        'Untuk usaha dengan beberapa cabang, tambahkan outlet lewat menu <b>Multi Outlet</b> '
        '(butuh Program Pendukung).',
    ]))

    # ------------------------------------------------------------------ 4
    story.append(PageBreak())
    story += section('4', 'Mengelola Produk, Stok & Resep',
                     'Produk adalah inti jualan. Masukkan produk dengan benar agar '
                     'laporan dan stok akurat.')
    story.append(sub('4.1 Menambah produk'))
    story.append(steps([
        'Buka menu <b>Produk</b> lalu tekan tombol <b>Tambah Produk</b>.',
        'Isi nama produk, harga jual, dan stok awal.',
        'Isi <b>HPP / harga modal</b> agar laporan laba dan saran harga bekerja.',
        'Pilih kategori dan unggah foto produk. Foto disimpan di perangkat Anda (tidak diunggah ke server).',
        'Tekan <b>Simpan</b>. Produk langsung muncul di kasir.',
    ]))
    story.append(sub('4.2 Produk jasa / layanan'))
    story.append(bullets([
        'Aktifkan saklar <b>Produk Jasa / Layanan</b> untuk jasa seperti potong rambut, '
        'servis, atau cuci sepatu.',
        'Produk jasa tidak menghitung stok dan tetap bisa dijual walau stok nol.',
    ]))
    story.append(sub('4.3 Barcode & pencarian cepat'))
    story.append(bullets([
        'Isi kolom barcode bila produk memiliki barcode. Di kasir, tombol pindai dapat '
        'langsung mencari produk tersebut.',
        'Gunakan kolom pencarian di kasir untuk menemukan produk berdasarkan nama.',
    ]))
    story.append(sub('4.4 Stok masuk, stok opname & resep'))
    story.append(bullets([
        '<b>Riwayat stok</b> mencatat setiap penambahan dan pengurangan stok.',
        '<b>Sidak Stok & Kas</b> (menu Dokter Bisnis) membantu menghitung fisik stok dan uang '
        'kas, lalu menampilkan selisih beserta nilai rupiahnya.',
        'Untuk cafe/resto, gunakan <b>Resep (BOM)</b>: tentukan bahan per porsi agar stok bahan '
        'berkurang otomatis saat produk terjual.',
    ]))
    story.append(callout(
        '<b>Kartu stok berwarna:</b> hijau berarti stok aman (di atas 10), kuning berarti '
        'menipis (1-10), merah berarti habis. Segera lakukan kulakan saat muncul kuning/merah.'))

    # ------------------------------------------------------------------ 5
    story.append(PageBreak())
    story += section('5', 'Transaksi di Kasir (POS)',
                     'Alur menjual produk ke pelanggan di toko.')
    story.append(sub('5.1 Membuat transaksi'))
    story.append(steps([
        'Buka <b>Kasir</b> (POS). Cari atau pindai produk yang dibeli.',
        'Tekan produk untuk menambahkan ke keranjang. Ubah jumlah dengan tombol + / -.',
        'Periksa total. Bila perlu, isi nama dan nomor WhatsApp pelanggan agar struk bisa dikirim.',
        'Pilih metode bayar: <b>Tunai</b>, <b>QRIS</b>, atau <b>Transfer</b> sesuai kebutuhan.',
        'Tekan <b>Bayar</b>, masukkan uang diterima bila tunai, lalu selesaikan transaksi.',
    ]))
    story.append(sub('5.2 Struk & kirim ke WhatsApp'))
    story.append(bullets([
        'Setelah transaksi, muncul dialog sukses dengan tombol <b>Struk PDF</b>.',
        'Pilih <b>Kirim Struk Teks ke WA</b> atau <b>Kirim Struk PDF ke WA</b> bila nomor pelanggan diisi.',
        'Logo struk dapat diganti dari Pengaturan (tersimpan di perangkat).',
    ]))
    story.append(sub('5.3 Diskon, bundling & saran tambahan'))
    story.append(bullets([
        'Diskon produk diatur pada menu produk atau lewat fitur <b>Atur Harga & Diskon</b>.',
        'Bundling (paket hemat) tampil sebagai satu item di keranjang.',
        'Kasir menampilkan saran tambahan (cross-sell) dari kebiasaan belanja pelanggan.',
    ]))
    story.append(sub('5.4 Shift kasir & tip'))
    story.append(steps([
        'Di beranda kasir, tekan <b>Buka Shift</b> dan masukkan kas modal awal.',
        'Saat selesai, tekan <b>Tutup Shift</b> lalu hitung uang fisik. Selisih kas tercatat.',
        'Catat tip pelanggan lewat tombol <b>Input Tip</b> agar laporan tip rapi.',
    ]))

    # ------------------------------------------------------------------ 6
    story.append(PageBreak())
    story += section('6', 'Pesanan Masuk, QR Meja & Dapur (KDS)',
                     'Pesanan dari pelanggan bisa datang lewat QR meja, katalog online, '
                     'atau marketplace. Semua masuk ke daftar Pesanan Masuk.')
    story.append(sub('6.1 Membuka daftar pesanan'))
    story.append(bullets([
        'Owner: tombol <b>Pesanan Masuk</b> di beranda.',
        'Kasir: kartu <b>Pesanan Masuk</b> di Beranda Kasir (ada angka notifikasi merah).',
        'Admin: tab <b>Pesanan</b> di posisi paling kiri.',
        'Daftar dibagi dua tab: <b>Dine-in</b> (pesanan QR meja) dan <b>Online</b> (katalog/pembeli).',
    ]))
    story.append(sub('6.2 Konfirmasi pembayaran'))
    story.append(steps([
        'Buka pesanan berlabel <b>Menunggu Bayar</b>.',
        'Periksa dana: uang tunai diterima, atau saldo QRIS/transfer sudah masuk ke rekening.',
        'Tekan <b>Konfirmasi Bayar</b>. Pesanan otomatis berstatus dibayar dan diteruskan ke Dapur.',
        'Bila pembayaran tidak ditemukan, gunakan aksi tolak/batalkan sesuai pesanan.',
    ]))
    story.append(callout(
        '<b>Penting:</b> pesanan baru tidak masuk antrean masak sebelum kasir menekan '
        'Konfirmasi Bayar. Ini mencegah masakan dibuat untuk pesanan yang belum dibayar.'))
    story.append(sub('6.3 Layar Dapur (KDS)'))
    story.append(bullets([
        'Koki melihat tiket pesanan yang sudah dibayar. Banner kuning menunjukkan jumlah '
        'pesanan yang masih menunggu konfirmasi kasir.',
        'Alur status: <b>Menunggu</b> -> <b>Dimasak</b> -> <b>Siap</b> -> <b>Selesai</b>.',
        'Gunakan filter di atas untuk melihat antrean tertentu. Layar memperbarui otomatis.',
    ]))

    # ------------------------------------------------------------------ 7
    story.append(PageBreak())
    story += section('7', 'Katalog Online & Pemasaran WhatsApp',
                     'Jualan tidak berhenti di toko. Bagikan katalog digital ke pelanggan.')
    story.append(sub('7.1 Menerbitkan katalog online'))
    story.append(steps([
        'Buka menu <b>Katalog Online</b> (owner).',
        'Aktifkan produk yang ingin ditampilkan ke publik.',
        'Bagikan tautan katalog ke pelanggan. Pelanggan dapat melihat produk, memesan, '
        'dan memilih ambil sendiri atau diantar.',
        'Pesanan dari katalog muncul di <b>Pesanan Masuk > Online</b>.',
    ]))
    story.append(sub('7.2 QR Meja untuk cafe & resto'))
    story.append(steps([
        'Buka menu <b>QR Meja</b>, tambahkan meja (mis. "Meja 1").',
        'Cetak atau tempel QR di meja. Pelanggan memindai QR, memilih menu, lalu mengirim pesanan.',
        'Pesanan masuk ke kasir dengan status Menunggu Bayar. Setelah dikonfirmasi, '
        'pesanan tampil di Dapur.',
    ]))
    story.append(sub('7.3 Broadcast WhatsApp'))
    story.append(bullets([
        'Gunakan menu <b>WA Marketing</b> untuk menyusun pesan promosi.',
        'Pilih sasaran dari daftar pelanggan yang sudah tersimpan.',
        'Pesan dibuka melalui WhatsApp Anda, sehingga tetap terasa personal.',
    ]))

    # ------------------------------------------------------------------ 8
    story.append(PageBreak())
    story += section('8', 'Pelanggan, Kasbon & Loyalitas',
                     'Kenali pelanggan agar bisa menagih piutang dan menjaga mereka kembali.')
    story.append(bullets([
        'Menu <b>Pelanggan</b> menyimpan nama, nomor WhatsApp, dan catatan pelanggan.',
        'Nama pelanggan otomatis tersimpan saat kasir mengisi nomor WhatsApp di pembayaran.',
        'Kasbon (utang pelanggan) dicatat agar tidak lupa ditagih.',
        'Gunakan riwayat belanja untuk menawarkan produk yang biasa dibeli pelanggan.',
        'Nomor WhatsApp dapat langsung dipakai untuk pengingat atau promo.',
    ]))

    # ------------------------------------------------------------------ 9
    story.append(PageBreak())
    story += section('9', 'Laporan & Pembukuan',
                     'Angka yang benar membuat keputusan lebih tenang.')
    story.append(sub('9.1 Laporan harian'))
    story.append(bullets([
        'Menu <b>Laporan</b> menampilkan omzet, jumlah transaksi, produk terlaris, dan metode bayar.',
        'Pilih rentang tanggal untuk melihat periode tertentu.',
    ]))
    story.append(sub('9.2 Unduh Excel & PDF'))
    story.append(steps([
        'Di layar laporan, tekan <b>Excel</b> untuk membuka berkas spreadsheet.',
        'Tekan <b>PDF</b> untuk laporan siap cetak dengan format pembukuan sederhana (SAK EMKM).',
        'Berkas tersimpan di perangkat atau terunduh melalui browser.',
    ]))
    story.append(sub('9.3 Laporan ke bos & laporan otomatis'))
    story.append(bullets([
        'Isi nomor WhatsApp bos di pengaturan Dokter Bisnis agar laporan bisa dikirim otomatis.',
        'Laporan otomatis berisi ringkasan omzet, produk terlaris, dan catatan penting.',
    ]))
    story.append(sub('9.4 Laporan & Progres (skor usaha)'))
    story.append(bullets([
        'Fitur <b>Laporan & Progres</b> memberi skor 0-100 dari tren omzet, target, dan '
        'langkah resep yang dijalankan.',
        'Tekan <b>Catat Progres Hari Ini</b> untuk menyimpan capaian harian.',
    ]))

    # ----------------------------------------------------------------- 10
    story.append(PageBreak())
    story += section('10', 'Karyawan, Shift & Delegasi Tugas',
                     'Bagi tugas dengan akun terpisah agar riwayat tetap jelas.')
    story.append(sub('10.1 Menambah akun karyawan'))
    story.append(steps([
        'Buka menu <b>Karyawan</b> (hanya owner).',
        'Tekan <b>Tambah Karyawan</b>, pilih peran: Admin, Kasir, atau Koki (khusus usaha makanan).',
        'Isi nama, email, dan kata sandi awal. Sampaikan kata sandi kepada karyawan.',
        'Karyawan masuk memakai email tersebut dan langsung melihat menu sesuai perannya.',
    ]))
    story.append(callout(
        '<b>Kuota gratis:</b> 1 akun Admin dan 1 akun Kasir per outlet. Menambah lebih banyak '
        'akun membutuhkan Program Pendukung.'))
    story.append(sub('10.2 Shift & tip'))
    story.append(bullets([
        'Kasir membuka shift saat mulai bekerja dan menutupnya saat pulang.',
        'Sistem mencatat kas awal, penjualan tunai, dan selisih kas.',
        'Tip pelanggan dicatat per shift agar pembagiannya adil.',
    ]))
    story.append(sub('10.3 Delegasi tugas'))
    story.append(bullets([
        'Owner dapat memberi tugas berbatas waktu kepada staf.',
        'Tugas yang terlambat muncul sebagai pengingat di beranda staf dan owner.',
        'Tandai tugas selesai agar rekap kinerja staf akurat.',
    ]))

    # ----------------------------------------------------------------- 11
    story.append(PageBreak())
    story += section('11', 'Dokter Bisnis AI & Fitur Penumbuh Usaha',
                     'Asisten digital yang membantu mendiagnosis usaha dan menyusun '
                     'langkah perbaikan. Semua fitur ini bagian dari Program Pendukung.')
    story.append(sub('11.1 Mulai konsultasi'))
    story.append(steps([
        'Buka kartu <b>Dokter Bisnis AI</b> di beranda owner.',
        'Pilih topik cepat: Diagnosa Usaha, Kenapa Omzet Turun, Saran Promosi, atau Cek Stok & Kas.',
        'Isi "Cek Fisik Toko" (3 langkah sederhana) agar saran lebih tepat.',
        'Ketik pertanyaan seperti bertanya kepada konsultan. Dokter akan menjawab dengan '
        'kartu ringkasan dan rencana kerja.',
    ]))
    story.append(sub('11.2 Membaca hasil & resep'))
    story.append(bullets([
        'Hasil diagnosa menampilkan skor usaha 0-100, vonis, dan peta resep berisi langkah perbaikan.',
        'Setiap langkah punya tombol <b>Jalankan</b> untuk langsung membuka fitur terkait, '
        'atau <b>Tandai Selesai</b> bila sudah dilakukan di luar aplikasi.',
        'Simpan atau bagikan hasil sebagai PDF dan kirim ke WhatsApp.',
        'Buka <b>Riwayat Kasus</b> untuk melanjutkan konsultasi lama atau menghapus riwayat.',
    ]))
    story.append(sub('11.3 Fitur penumbuh usaha'))
    story.append(table([
        ['Fitur', 'Kegunaan'],
        ['Sidak Stok & Kas', 'Menghitung stok fisik dan uang kas, menampilkan selisih bernilai rupiah.'],
        ['Atur Harga & Diskon', 'Saran diskon dan kenaikan harga yang tetap aman di atas modal.'],
        ['Laporan & Progres', 'Skor kemajuan usaha serta capaian target omzet.'],
        ['Bos Virtual', 'Analitik penjualan, peluang cross-sell, dan pengingat tindakan.'],
        ['Squad Digital Marketing', 'Membuat materi desain, jadwal promosi, dan draf iklan.'],
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
    story.append(bullets([
        'Di halaman awal, pilih <b>Pembeli</b>. Bila belum punya akun, daftar singkat diperlukan.',
        'Izinkan akses lokasi agar radar menampilkan toko terdekat.',
        'Pilih radius 3, 5, atau 10 km sesuai kebutuhan.',
    ]))
    story.append(sub('12.2 Memesan'))
    story.append(steps([
        'Pilih toko, lalu buka katalog produknya.',
        'Tambahkan produk ke keranjang. Satu pesanan hanya untuk satu toko.',
        'Buka keranjang, lalu tekan <b>Lanjut ke Checkout</b>.',
        'Isi nama, nomor WhatsApp, dan alamat bila memilih diantar.',
        'Tekan <b>Buat Pesanan</b>, lalu ikuti instruksi pembayaran yang muncul.',
    ]))
    story.append(sub('12.3 Melacak pesanan'))
    story.append(bullets([
        'Status pesanan dapat dilihat di aplikasi: menunggu konfirmasi, diproses, diantar, selesai.',
        'Simpan bukti transfer di perangkat bila memilih transfer manual.',
        'Hubungi toko lewat tombol WhatsApp bila ada perubahan pesanan.',
    ]))

    # ----------------------------------------------------------------- 13
    story.append(PageBreak())
    story += section('13', 'Bundling, Referral & Afiliasi',
                     'Tiga cara menambah omzet tanpa menambah biaya iklan.')
    story.append(sub('13.1 Paket bundling'))
    story.append(steps([
        'Buka menu <b>Bundling</b>, lalu buat paket (mis. Sembako Hemat).',
        'Pilih produk dan atur harga paket lebih murah dari harga satuan.',
        'Paket muncul di kasir dan katalog pelanggan sebagai satu item.',
    ]))
    story.append(sub('13.2 Kode referral pelanggan'))
    story.append(bullets([
        'Buat kode referral (mis. HEMAT10) beserta aturan potongannya.',
        'Bagikan kode kepada pelanggan. Setiap pemakaian tercatat.',
        'Gunakan catatan referral untuk melihat kode mana yang paling efektif.',
    ]))
    story.append(sub('13.3 Afiliasi untuk owner'))
    story.append(bullets([
        'Setiap outlet otomatis memiliki kode afiliasi (contoh KGO-XXXXXX).',
        'Bagikan kode/link kepada calon pengguna KasirGo.',
        'Komisi dari pengguna yang bergabung tercatat di menu <b>Afiliasi</b>.',
        'Lengkapi data rekening agar komisi dapat dicairkan.',
    ]))

    # ----------------------------------------------------------------- 14
    story.append(PageBreak())
    story += section('14', 'Program Pendukung (Langganan)',
                     'Fitur inti KasirGo gratis selamanya. Program Pendukung membuka '
                     'fitur bonus dan membantu pengembangan aplikasi.')
    story.append(bullets([
        'Harga: <b>Rp50.000 per bulan</b> untuk semua fitur bonus (satu harga, tanpa tingkatan).',
        'Pembayaran melalui QRIS. Status aktif otomatis setelah pembayaran terverifikasi.',
        'Bila masa aktif habis, fitur inti tetap bisa dipakai. Fitur bonus terkunci sampai diperpanjang.',
    ]))
    story.append(sub('Fitur bonus utama'))
    story.append(table([
        ['Kategori', 'Contoh fitur'],
        ['Pesanan & layanan', 'QRIS dinamis otomatis, QR Meja, katalog online, dapur (KDS)'],
        ['Penumbuh usaha', 'Dokter Bisnis AI, Sidak Bos, Atur Harga & Diskon, Laporan & Progres'],
        ['Pemasaran', 'WA Marketing, bundling, referral, laporan otomatis ke bos, bebas iklan'],
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
    story.append(bullets([
        'Buka menu <b>Panduan</b> dari beranda atau Pengaturan.',
        'Gunakan kolom pencarian dan filter kategori/peran untuk menemukan panduan.',
        'Panduan PDF dapat diunduh agar tetap terbaca saat offline.',
    ]))
    story.append(sub('15.2 Membuat tiket bantuan'))
    story.append(steps([
        'Buka <b>Bantuan & Tutorial</b> (menu samping) atau <b>Tiket Bantuan</b> di Pengaturan.',
        'Tekan <b>Tiket Baru</b>, tulis judul singkat dan penjelasan kendala.',
        'Sertakan nama menu, pesan error, dan waktu kejadian agar cepat ditangani.',
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
        'Untuk owner, tayangkan toko lewat Lapak Live agar muncul di radar pembeli.',
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
        'QRIS dinamis memerlukan Program Pendukung aktif.',
        'QRIS statis tetap dapat dipakai: unggah gambar QRIS toko di Pengaturan.',
        'Bila QRIS dinamis tampil kosong, tutup lalu buka kembali layar pembayaran.',
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