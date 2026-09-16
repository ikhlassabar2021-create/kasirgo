# KASIRGO - PAKET PROMPT PHASE 4 (Hemat Token)

Fase: Laporan + Pelanggan + Karyawan.
Status saat ini: ST1-ST7 `[x]`, tinggal ST8.

Cara pakai:
1. Setelah reset/compact: tempel **SATU PROMPT RESET-RESUME** (bagian 0).
2. Kerjakan per sub-task: tempel **PROMPT PEMBUKA** (bagian 1) lalu blok ST (bagian 3).
3. Setiap 1-2 file selesai: `git add . && git commit -m "progress: [file]" && git push`.
4. Kalau error: tempel **ERROR PLAYBOOK** (bagian 2) + 1 baris error saja.
5. Sesudah ST8: tempel **PROMPT LIVE TEST** (bagian 4).

---

## 0. SATU PROMPT RESET-RESUME (paste setelah reset)

```text
=== KASIRGO: super-app kasir UMKM (Flutter mobile + Supabase + React superadmin).
Role: Owner (full access), Admin (CRUD produk + laporan), Cashier (POS), Customer (QR meja), Superadmin (web).
Paket: free / basic_25 / pro_50. AI Co-Pilot gratis (local compute, Rp0).
Design: glassmorphism dark #4F46E5 #7C3AED #06B6D4, font Inter, min touch 56dp.
DB Supabase 13 tabel + RLS; offline-first SQLite (drift) sync 30 detik.
ATURAN: tanpa install / pub get / build APK. Baca HANYA PROGRESS-PHASE4.md. Perintah panjang redirect ke file. 1 task per pesan.
Selesai 1-2 file: git add . && git commit -m "progress: [file]" && git push. JANGAN tunggu semua selesai.
Error: kirim hanya 1 baris file:baris:pesan, bukan stack trace. Error sama >2x -> STOP+push+BLOCKER.
===
Lanjutkan Phase 4 dari commit terakhir. Jalankan: git log --oneline -5 dan baca PROGRESS-PHASE4.md.
Laporkan singkat: ST yang sudah [x], ST yang belum, file terakhir. JANGAN coding dulu sampai saya kirim blok ST.
```

---

## 1. PROMPT PEMBUKA (tempel di setiap ST)

```text
=== Lanjutan Phase 4 KASIRGO. Role: Owner/Admin/Cashier/Customer/Superadmin.
Baca HANYA PROGRESS-PHASE4.md. Tanpa install/pub get/build APK. Perintah panjang redirect ke file.
Edit targeted, jangan rewrite. Output hanya kode/diff.
Analyze 1 file: export PATH="$PATH:/opt/flutter/bin" && dart analyze <file> 2>&1 | tail -20.
1 error per percobaan, kirim hanya file:baris:pesan. Error sama >2x -> STOP+push+BLOCKER.
Selesai: git add . && git commit -m "progress: [file]" && git push, STOP.
===
```

---

## 2. ERROR PLAYBOOK (hemat token)

```text
Error tak tahu lokasi -> urutan murah, berhenti di temuan pertama:
1. export PATH="$PATH:/opt/flutter/bin" && dart analyze lib 2>&1 | grep -i error | head -20
2. grep -nE "Error|Exception|Failed" /tmp/run.log | head -15
3. Layar blank -> kirim HANYA 1 baris pertama console browser (F12).
4. Persempit: buka 1 screen langsung, jangan alur panjang.
5. Isolasi tab: Ringkasan -> Penjualan -> Produk.
Kirim hanya 1 baris error. Jangan paste log/stack trace penuh.
Stop-loss: error sama >2x -> STOP, push, tulis BLOCKER:, minta Compact/Reset.
```

Template perbaikan 1 error:

```text
=== PERBAIKAN ===
File: [path]
Error: [1 baris]
Perbaiki HANYA baris/fungsi ini. Jangan baca file lain, jangan refactor, jangan rewrite.
Output hanya diff. dart analyze file itu. STOP.
```

---

## 3. SUB-TASK PROMPTS

Tempel PROMPT PEMBUKA (bagian 1), lalu tempel salah satu blok di bawah.

### ST1 - Report Screen (dashboard laporan)

```text
ST1: Buat lib/screens/owner/report_screen.dart (dipakai Owner + Admin).
- AppBar "Laporan"; TabBar: Ringkasan | Penjualan | Produk.
- Filter periode chip: Hari ini, 7 hari, 30 hari, Bulan ini, Custom range.
- Tab Ringkasan: 4 metric card (omzet, untung, jumlah transaksi, rata-rata).
- Query tabel transactions & products di Supabase sesuai periode.
Analyze file itu.
```

### ST2 - Detail Laporan + Export

```text
ST2: Lengkapi report_screen.dart.
- Tab Penjualan: bar chart harian (fl_chart) + list transaksi.
- Tab Produk: top 10 produk horizontal bar chart.
- Export Excel (library excel).
- Laporan bank-ready (pendapatan - HPP = laba kotor) via PDF (pdf + printing).
- Share via WhatsApp/email (url_launcher).
Analyze file itu.
```

### ST3 - Manajemen Pelanggan

```text
ST3: Buat lib/screens/owner/customer_list_screen.dart.
- Search bar; list card (nama, no WA, total belanja).
- FAB tambah pelanggan (dialog: nama + nomor WA), simpan ke tabel customers.
- Persist via Supabase (RLS outlet).
Analyze file itu.
```

### ST4 - Manajemen Karyawan

```text
ST4: Buat lib/screens/owner/employee_screen.dart + update lib/services/supabase_service.dart.
- List karyawan.
- Tambah karyawan + role assignment memakai updateEmployeeRole di supabase_service.dart.
- Tabel employees: user_id, outlet_id, role.
Analyze tiap file.
```

### ST5 - Detail Pelanggan

```text
ST5: Tambah detail pelanggan di customer_list_screen.dart (modal bottom sheet).
- Riwayat transaksi, total belanja, loyalty points.
- Piutang/tempo: daftar pelanggan yang belum bayar.
Analyze file itu.
```

### ST6 - Absensi Karyawan

```text
ST6: Tambah TabBar (Absensi | Daftar Staf) di employee_screen.dart + method absensi di supabase_service.dart.
- Header tanggal hari ini; ChoiceChip shift pagi/siang/malam.
- Tombol Check-in (hijau) / Check-out (merah).
- History absensi dari tabel employees (check_in_time, check_out_time, shift, date, user_id, outlet_id).
Analyze tiap file.
```

### ST7 - Integrasi Tab Owner & Admin

```text
ST7: Integrasi navigasi.
- lib/screens/owner/owner_home_screen.dart: pakai IndexedStack berisi Dashboard, Produk, Kasir, Laporan, Pengaturan, Pelanggan, Karyawan; bottom nav pakai setState.
- lib/screens/admin/admin_home_screen.dart: tab Laporan menampilkan ReportScreen.
Analyze tiap file.
```

### ST8 - Analyze + Live Test + Tutup Phase

```text
ST8: Tutup Phase 4.
1. export PATH="$PATH:/opt/flutter/bin" && flutter analyze 2>&1 | tail -30
2. flutter run -d web-server --web-renderer html --web-hostname 0.0.0.0 --web-port 8080 > /tmp/run.log 2>&1 &
3. grep -nE "Error|Exception|Failed" /tmp/run.log | head -15
4. Minta URL preview port 8080.
5. Uji live via klik: laporan + grafik (Owner & Admin), export Excel, tambah pelanggan + detail, check-in/out karyawan.
6. Update AGENTS.md: tandai [x] Phase 4.
7. git add . && git commit -m "docs: phase 4 selesai" && git push
Laporkan: URL preview + yang diklik + hasil + error. JANGAN build APK.
```

---

## 4. PROMPT LIVE TEST (detail klik yang diuji)

```text
Uji live di web preview (tanpa build APK). Buka berurutan dan laporkan hasil tiap langkah:
1. Login Owner -> tab Laporan: Ringkasan (metric card akurat) -> Penjualan (grafik tampil) -> Produk (top 10).
2. Ganti filter periode, pastikan angka berubah.
3. FAB export Excel -> file terunduh.
4. Tab Pelanggan: tambah 1 pelanggan -> buka detail -> cek riwayat + total belanja + piutang.
5. Tab Karyawan: check-in -> check-out -> cek history absensi.
6. Login Admin -> tab Laporan: pastikan ReportScreen yang sama tampil.
Laporkan: URL preview + langkah yang diklik + hasil + error (1 baris).
Catatan: kamera/barcode/SQLite native tidak jalan di web.
```

---

## 5. TEST CHECKLIST Phase 4

- [ ] Ringkasan akurat (Owner & Admin)
- [ ] Grafik penjualan berfungsi
- [ ] Export Excel berhasil
- [ ] Bank-ready format benar
- [ ] Pelanggan list/tambah/detail/riwayat/piutang
- [ ] Absensi check-in/out + history

## 6. Catatan

- Laporan butuh data: kalau Supabase kosong, buat 3-5 transaksi via POS dulu.
- Semua fitur Phase 4 bisa diuji di web (tidak ada fitur native).
- Alur reset: PUSH dulu -> Compact -> memory check. Reset hanya kalau Compact ngawur. Setelah reset, tempel bagian 0.
