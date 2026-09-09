# MonkeyCode Vibecoding Workflow -- KasirGo

> STATUS: Phase 0-1 SELESAI. Phase 2 SEDANG DIKERJAKAN. AGENTS.md sudah ada di root repo (memori proyek).

## Cara Kerja: Satu Session = Satu Phase

Alur per phase:
1. Buka session MonkeyCode baru (fresh environment)
2. Copy prompt Phase lalu paste (prompt sudah include perintah clone repo)
3. AI clone repo -> **otomatis baca AGENTS.md** (memori proyek) -> langsung paham konteks & progress tanpa perlu cerita ulang
4. AI kerjakan fitur phase, **push tiap 1-2 file selesai** (= save point)
5. Test live, pastikan tidak error
6. Update checklist "Progress Tracker" di AGENTS.md lalu commit + push
7. Selesai. Reset context / tutup session. Lanjut Phase berikutnya di session baru.

## AGENTS.md = Memori Permanen Proyek

- AGENTS.md di root repo berisi SEMUA konteks: stack, DB, roles, paket, AI, design, file structure, progress.
- Setiap session baru / reset context: AI auto-load AGENTS.md di awal -> langsung "ingat" proyek.
- Update hanya bagian **Progress Tracker** saat phase selesai (`- [ ]` -> `- [x]`). Jangan edit bagian lain tanpa perlu.
- Prompt Phase tetap membawa konteks 1-baris sbg cadangan (double safety).

## Aturan Push -- JANGAN tunggu akhir Phase!

Context window MonkeyCode bisa penuh sebelum Phase selesai. Solusi: **push setiap 1-2 file selesai.**

```
SETIAP kali selesai bikin 1-2 file:
  git add . && git commit -m "progress: [nama file]" && git push

JANGAN tunggu semua file selesai baru push.
```

Jika session mati sebelum push, code hilang. Push = save point.

## Kena Limit Context: Reset > Compact

| Kondisi | Aksi |
|---------|------|
| Ganti Phase / mulai fitur baru | **RESET context** (bukan task baru) - AGENTS.md auto-load lagi, langsung siap |
| Tengah debug satu bug rumit, detail history masih bernilai | **Compact** dulu, selesaikan, baru reset |
| Session mati sebelum sempat push | Code ter-push aman di GitHub; yang belum push HILANG -> ulangi dari commit terakhir |

Setelah reset: AI baca AGENTS.md + `git log --oneline` -> tahu posisi terakhir -> lanjut tanpa tanya ulang.
Jangan pakai Compact saat ganti phase - hasilnya lossy, bisa ada detail yang hilang.

## Awal Phase (Session Baru)

```
Copy prompt Phase berikutnya lalu paste. Prompt sudah include:
- Perintah clone repo
- Konteks 1-baris (cadangan, AGENTS.md tetap sumber utama)
- Perintah install dependency (hanya flutter pub get / npm install -- BUKAN install SDK)

Setelah clone: baca AGENTS.md dulu, lalu kerjakan sesuai prompt.
```

## Akhir Phase

```
git add . && git commit -m "Phase X: [nama]" && git push origin main
```

---

## PHASE 1: Supabase Setup + Auth

### Prompt:

```
=== KASIRGO: Aplikasi kasir UMKM (Flutter mobile + Supabase + React superadmin). 3 role: Owner (full), Admin (CRUD produk), Cashier (POS only). 3 paket: Gratis (500 tx/produk+iklan), 25rb (unlimited+barcode), 50rb (WA+social commerce+QR meja). AI Co-Pilot gratis local compute. Glassmorphism: #4F46E5 #7C3AED #06B6D4. Font Inter. Offline-first: SQLite lokal sync Supabase. 13 tabel DB+RLS. ===
Buat project Supabase baru untuk aplikasi kasir UMKM bernama "KasirGo".

Setup database schema berikut di Supabase SQL Editor:

-- ============================================
-- TABLES
-- ============================================

CREATE TABLE outlets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'warung',
  address TEXT,
  phone TEXT,
  subscription_tier TEXT NOT NULL DEFAULT 'free' CHECK (subscription_tier IN ('free', 'basic_25', 'pro_50')),
  subscription_expiry TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('admin', 'cashier')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, outlet_id)
);

CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  category TEXT DEFAULT 'Umum',
  barcode TEXT,
  cost_price DECIMAL(12,2) DEFAULT 0,
  base_price DECIMAL(12,2) NOT NULL DEFAULT 0,
  stock DECIMAL(12,2) DEFAULT 0,
  unit TEXT DEFAULT 'pcs',
  expired_date DATE,
  image_url TEXT,
  min_stock_alert DECIMAL(12,2) DEFAULT 5,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE product_prices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  channel TEXT NOT NULL CHECK (channel IN ('offline', 'tokopedia', 'shopee', 'blibli', 'gofood', 'grabfood', 'shopeefood')),
  price DECIMAL(12,2) NOT NULL,
  platform_fee_percent DECIMAL(5,2) DEFAULT 0
);

CREATE TABLE product_discounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  discount_percent DECIMAL(5,2),
  discount_amount DECIMAL(12,2),
  start_date TIMESTAMPTZ NOT NULL,
  end_date TIMESTAMPTZ NOT NULL,
  is_flash_sale BOOLEAN DEFAULT false
);

CREATE TABLE transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id),
  customer_id UUID,
  channel TEXT NOT NULL DEFAULT 'offline',
  payment_method TEXT NOT NULL DEFAULT 'cash' CHECK (payment_method IN ('cash', 'qris', 'bank_transfer')),
  total_amount DECIMAL(12,2) NOT NULL,
  total_discount DECIMAL(12,2) DEFAULT 0,
  final_amount DECIMAL(12,2) NOT NULL,
  status TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('completed', 'voided')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE transaction_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id UUID REFERENCES transactions(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id),
  product_name TEXT NOT NULL,
  quantity DECIMAL(12,2) NOT NULL,
  unit_price DECIMAL(12,2) NOT NULL,
  discount DECIMAL(12,2) DEFAULT 0,
  subtotal DECIMAL(12,2) NOT NULL
);

CREATE TABLE customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  phone_wa TEXT,
  total_spent DECIMAL(12,2) DEFAULT 0,
  loyalty_points INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE employees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id),
  check_in_time TIMESTAMPTZ,
  check_out_time TIMESTAMPTZ,
  shift TEXT DEFAULT 'pagi',
  date DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  tier TEXT NOT NULL CHECK (tier IN ('free', 'basic_25', 'pro_50')),
  start_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  end_date TIMESTAMPTZ NOT NULL,
  payment_method TEXT,
  payment_status TEXT DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'expired')),
  amount DECIMAL(12,2) NOT NULL DEFAULT 0
);

CREATE TABLE affiliates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  email TEXT UNIQUE,
  referral_code TEXT UNIQUE NOT NULL,
  commission_percent DECIMAL(5,2) DEFAULT 10,
  total_earned DECIMAL(12,2) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE affiliate_referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  affiliate_id UUID REFERENCES affiliates(id) ON DELETE CASCADE,
  outlet_id UUID REFERENCES outlets(id),
  subscription_tier TEXT NOT NULL,
  commission_amount DECIMAL(12,2) DEFAULT 0,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'paid')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE ai_insights (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  insight_type TEXT NOT NULL,
  data JSONB NOT NULL DEFAULT '{}',
  generated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- RLS POLICIES
-- ============================================

ALTER TABLE outlets ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_prices ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_discounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaction_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_insights ENABLE ROW LEVEL SECURITY;

-- Owner: full access to own outlet
CREATE POLICY owner_outlets ON outlets FOR ALL USING (owner_id = auth.uid());
CREATE POLICY owner_products ON products FOR ALL USING (outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid()));
CREATE POLICY owner_transactions ON transactions FOR ALL USING (outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid()));
CREATE POLICY owner_customers ON customers FOR ALL USING (outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid()));
CREATE POLICY owner_employees ON employees FOR ALL USING (outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid()));
CREATE POLICY owner_subscriptions ON subscriptions FOR ALL USING (outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid()));

-- Admin: CRUD products, read reports
CREATE POLICY admin_products ON products FOR ALL USING (outlet_id IN (SELECT outlet_id FROM user_roles WHERE user_id = auth.uid() AND role = 'admin'));
CREATE POLICY admin_transactions_read ON transactions FOR SELECT USING (outlet_id IN (SELECT outlet_id FROM user_roles WHERE user_id = auth.uid() AND role = 'admin'));

-- Cashier: read products, create transactions
CREATE POLICY cashier_products_read ON products FOR SELECT USING (outlet_id IN (SELECT outlet_id FROM user_roles WHERE user_id = auth.uid() AND role = 'cashier'));
CREATE POLICY cashier_transactions_insert ON transactions FOR INSERT WITH CHECK (outlet_id IN (SELECT outlet_id FROM user_roles WHERE user_id = auth.uid() AND role = 'cashier'));

-- ============================================
-- FUNCTIONS
-- ============================================

-- Auto-create outlet on user signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO outlets (owner_id, name, type)
  VALUES (NEW.id, NEW.raw_user_meta_data->>'business_name', COALESCE(NEW.raw_user_meta_data->>'business_type', 'warung'));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Auto-decrement stock on transaction
CREATE OR REPLACE FUNCTION decrement_stock()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE products SET stock = stock - NEW.quantity, updated_at = NOW()
  WHERE id = NEW.product_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_transaction_item_insert
  AFTER INSERT ON transaction_items
  FOR EACH ROW EXECUTE FUNCTION decrement_stock();

-- ============================================
-- INDEXES
-- ============================================

CREATE INDEX idx_products_outlet ON products(outlet_id);
CREATE INDEX idx_products_barcode ON products(barcode);
CREATE INDEX idx_transactions_outlet ON transactions(outlet_id);
CREATE INDEX idx_transactions_date ON transactions(created_at DESC);
CREATE INDEX idx_transaction_items_tx ON transaction_items(transaction_id);
CREATE INDEX idx_customers_outlet ON customers(outlet_id);
CREATE INDEX idx_employees_outlet_date ON employees(outlet_id, date);
CREATE INDEX idx_ai_insights_outlet ON ai_insights(outlet_id, insight_type);

Jalankan semua SQL di atas di Supabase SQL Editor. Pastikan tidak ada error. Setelah selesai, buat test user via Supabase Auth UI dan verifikasi trigger handle_new_user berjalan (outlet otomatis terbuat). Laporkan hasilnya.
```

### Test Check:
- [ ] Semua tabel terbuat tanpa error
- [ ] RLS policies aktif
- [ ] Trigger handle_new_user berfungsi (register user baru, outlet auto-create)
- [ ] Register + login berhasil

---

## PHASE 2: Flutter App Shell + Auth + Offline Engine

### Prompt:

```
=== KASIRGO: Aplikasi kasir UMKM (Flutter mobile + Supabase + React superadmin). 3 role: Owner (full), Admin (CRUD produk), Cashier (POS only). 3 paket: Gratis (500 tx/produk+iklan), 25rb (unlimited+barcode), 50rb (WA+social commerce+QR meja). AI Co-Pilot gratis local compute. Glassmorphism: #4F46E5 #7C3AED #06B6D4. Font Inter. Offline-first: SQLite lokal sync Supabase. 13 tabel DB+RLS. ===
Clone repo [GITHUB_URL] lalu LANJUTKAN project Flutter kasirgo. Phase 1 selesai: Supabase DB + Auth. flutter pub get.
ATURAN: SETIAP selesai 1-2 file, langsung git add . && git commit -m "progress: [nama file]" && git push. JANGAN tunggu semua selesai.
SETELAH CLONE: baca file AGENTS.md di root repo untuk konteks lengkap proyek, lalu update checklist Progress Tracker di sana jika ada Phase yang selesai di session ini.

Buat project Flutter baru bernama "kasirgo" dengan struktur berikut.

Gunakan dependencies ini di pubspec.yaml:
- supabase_flutter: ^2.0.0
- drift: ^2.15.0
- sqlite3_flutter_libs: ^0.5.0
- path_provider: ^2.1.0
- go_router: ^13.0.0
- flutter_riverpod: ^2.4.0
- riverpod_annotation: ^2.3.0
- shared_preferences: ^2.2.0
- intl: ^0.19.0
- mobile_scanner: ^4.0.0
- qr_flutter: ^4.1.0
- barcode: ^2.2.0
- pdf: ^3.10.0
- printing: ^5.12.0
- excel: ^4.0.0
- url_launcher: ^6.2.0
- connectivity_plus: ^5.0.0
- google_fonts: ^6.1.0
- flutter_animate: ^4.3.0
- flutter_slidable: ^3.0.0
- fl_chart: ^0.66.0
- cached_network_image: ^3.3.0
- image_picker: ^1.0.0

BUAT STRUKTUR FOLDER:
lib/
  main.dart
  app.dart
  config/
    supabase_config.dart
    app_theme.dart
    constants.dart
  models/
    user.dart
    outlet.dart
    product.dart
    transaction.dart
    customer.dart
    employee.dart
  services/
    auth_service.dart
    sync_service.dart
    local_db_service.dart
    supabase_service.dart
  providers/
    auth_provider.dart
    outlet_provider.dart
    sync_provider.dart
  screens/
    auth/
      login_screen.dart
      register_screen.dart
    owner/
      owner_home_screen.dart
      product_list_screen.dart
      product_form_screen.dart
      pos_screen.dart
      report_screen.dart
      customer_list_screen.dart
      employee_screen.dart
      settings_screen.dart
    admin/
      admin_home_screen.dart
    cashier/
      cashier_home_screen.dart
      cashier_pos_screen.dart
    customer/
      customer_menu_screen.dart
  widgets/
    common/
      loading_widget.dart
      error_widget.dart
      empty_state_widget.dart
      app_drawer.dart
      search_bar.dart
    pos/
      cart_panel.dart
      product_grid.dart
      checkout_dialog.dart
  utils/
    offline_queue.dart
    ai_engine.dart
    formatters.dart
    validators.dart

BUAT KODE BERIKUT:

1. main.dart -- Entry point, init Supabase, run app
2. app.dart -- MaterialApp.router dengan GoRouter, theme glassmorphism
3. config/supabase_config.dart -- Supabase init dengan URL dan anon key (gunakan placeholder, user isi sendiri)
4. config/app_theme.dart -- Theme glassmorphism: background gradient biru-ungu, card dengan blur + border putih transparan, rounded corners, font Inter
5. config/constants.dart -- App name, version, channel list, payment methods
6. models/ -- Semua model class dengan fromJson/toJson, fromMap/toMap (untuk SQLite)
7. services/auth_service.dart -- Register, login, logout, getCurrentUser, getRole
8. services/local_db_service.dart -- SQLite dengan drift, simpan produk lokal, transaksi offline
9. services/sync_service.dart -- Cek koneksi, sync produk & transaksi ke Supabase saat online
10. services/supabase_service.dart -- CRUD wrapper untuk semua tabel Supabase
11. providers/auth_provider.dart -- Riverpod provider untuk auth state
12. screens/auth/login_screen.dart -- Email + password login, glassmorphism card style
13. screens/auth/register_screen.dart -- Register form dengan nama usaha + tipe usaha
14. Owner/Admin/Cashier screens -- Shell dengan bottom navigation sesuai role

DESIGN REQUIREMENTS:
- Glassmorphism: background gradient, card dengan backdropFilter blur, border putih semi-transparan
- Warna: primary biru (#4F46E5), secondary ungu (#7C3AED), accent cyan (#06B6D4)
- Gunakan Google Fonts Inter
- Semua screen harus responsive, bisa dipakai di HP ukuran 360dp width
- Button besar minimal 48dp tinggi (touch-friendly)
- Bottom navigation dengan icon yang jelas

ROLE FLOW:
- Setelah login, cek role user (owner/admin/cashier)
- Owner: 5 tab (Dashboard, Produk, Kasir, Laporan, Pengaturan)
- Admin: 2 tab (Produk, Laporan)
- Cashier: 1 screen (POS) + profile

OFFLINE ENGINE:
- local_db_service.dart: simpan produk ke SQLite, transaksi ke SQLite
- sync_service.dart: setiap 30 detik cek koneksi, jika online push data lokal ke Supabase
- Conflict resolution: last-write-wins dengan timestamp

PASTIKAN:
- flutter analyze tidak ada error
- flutter build apk --debug berhasil
- Test: login dengan user yang sudah dibuat di Supabase, pastikan redirect ke screen sesuai role

Laporkan hasil build dan test.
```

### Test Check:
- [ ] flutter analyze clean
- [ ] flutter build apk --debug berhasil
- [ ] Login screen muncul dengan glassmorphism design
- [ ] Register user baru, outlet auto-create
- [ ] Role detection berfungsi (owner/admin/cashier redirect berbeda)
- [ ] Offline sync: matikan internet, buat transaksi, nyalakan internet, data sync

---

## PHASE 3: Core Modules (Produk + POS + QRIS Manual)

### Prompt:

```
=== KASIRGO: Aplikasi kasir UMKM (Flutter mobile + Supabase + React superadmin). 3 role: Owner (full), Admin (CRUD produk), Cashier (POS only). 3 paket: Gratis (500 tx/produk+iklan), 25rb (unlimited+barcode), 50rb (WA+social commerce+QR meja). AI Co-Pilot gratis local compute. Glassmorphism: #4F46E5 #7C3AED #06B6D4. Font Inter. Offline-first: SQLite lokal sync Supabase. 13 tabel DB+RLS. ===
Clone repo [GITHUB_URL] lalu LANJUTKAN project Flutter kasirgo. Phase 1-2 selesai: DB + Auth + App shell + navigation. flutter pub get.
ATURAN: SETIAP selesai 1-2 file, langsung git add . && git commit -m "progress: [nama file]" && git push. JANGAN tunggu semua selesai.
SETELAH CLONE: baca file AGENTS.md di root repo untuk konteks lengkap proyek, lalu update checklist Progress Tracker di sana jika ada Phase yang selesai di session ini.

Lanjutkan project Flutter kasirgo. Tambahkan modul core berikut:

1. PRODUK MODULE (product_list_screen.dart, product_form_screen.dart)
   - List produk dengan search bar dan filter kategori
   - Grid/List view toggle
   - Swipe to delete
   - Fab button untuk tambah produk
   - Form produk: nama, kategori, harga modal, harga jual, stok, satuan, barcode, expired date, foto produk
   - Foto produk: ambil dari kamera/galeri, simpan lokal, upload ke Supabase Storage saat online
   - Tampilkan stok dengan warna: hijau (aman), kuning (menipis), merah (habis)
   - Scan barcode untuk input produk (pakai mobile_scanner)
   - Generate barcode dari text ke gambar (pakai library barcode)

2. POS MODULE (pos_screen.dart, cart_panel.dart, product_grid.dart, checkout_dialog.dart)
   - Mode: pilih channel (offline, tokopedia, shopee, dll)
   - Tampilan produk dalam grid, tap untuk tambah ke cart
   - Search bar untuk cari produk by nama/barcode
   - Cart panel di bawah: list item, qty +/-, total, tombol checkout
   - Checkout dialog: pilih payment method (cash, qris, bank_transfer)
   - QRIS Manual: tampilkan QR code statis, input nominal manual
   - Cash: input jumlah bayar, hitung kembalian
   - Setelah checkout: kurangi stok, simpan transaksi
   - Cetak struk (opsional, bisa share text)

3. Pembatasan Paket Gratis
   - Cek jumlah transaksi bulan ini, jika >= 500 tampilkan pesan upgrade
   - Cek jumlah produk, jika >= 500 disable tombol tambah
   - Tampilkan banner upgrade ke paket berbayar

4. AI CO-PILOT (utils/ai_engine.dart)
   - Prediksi Penjualan: moving average 7/14/30 hari dari histori transaksi
   - Deteksi Anomali: z-score > 2.0 pada transaksi harian
   - Rekomendasi Produk: "Pelanggan yang beli X juga beli Y" dari transaction_items
   - ABC Ranking: Pareto top 20% = A, next 30% = B, rest = C
   - Margin Alert: (harga jual - modal) / harga jual < threshold
   - Tampilkan insight di dashboard owner sebagai card

IMPLEMENTASI DETAIL:

product_list_screen.dart:
- AppBar dengan judul "Produk" dan tombol scan barcode
- Search bar di bawah AppBar
- Chip filter kategori horizontal scroll
- GridView produk 2 kolom, setiap card: foto, nama, harga, stok badge
- FAB untuk tambah produk
- Swipe left untuk delete (dengan konfirmasi)

pos_screen.dart:
- AppBar dengan channel selector dropdown
- Search bar produk
- GridView produk 3 kolom, compact
- Bottom sheet cart panel: list item, qty control, total
- Checkout button di bottom sheet
- Checkout dialog: payment method radio, nominal input, proses button

cart_panel.dart:
- DraggableScrollableSheet dari bawah
- List item cart dengan qty +/- dan subtotal
- Total section dengan diskon (jika ada)
- Tombol checkout

PASTIKAN:
- flutter analyze tidak error
- flutter build apk --debug berhasil
- Test: tambah 3 produk, buka POS, pilih produk, checkout dengan QRIS, cek stok berkurang
- Test: cek dashboard owner menampilkan AI insight

Laporkan hasil build dan test.
```

### Test Check:
- [ ] Tambah produk dengan foto berhasil
- [ ] Scan barcode berfungsi
- [ ] Generate barcode berfungsi
- [ ] POS: pilih produk, cart bertambah, checkout berhasil
- [ ] QRIS manual: tampil QR, input nominal, transaksi tersimpan
- [ ] Stok otomatis berkurang setelah transaksi
- [ ] Paket gratis: limit 500 dicek dan tampil pesan
- [ ] AI Co-Pilot insight muncul di dashboard
- [ ] Semua fitur offline-compatible

---

## PHASE 4: Laporan + Pelanggan + Karyawan

### Prompt:

```
=== KASIRGO: Aplikasi kasir UMKM (Flutter mobile + Supabase + React superadmin). 3 role: Owner (full), Admin (CRUD produk), Cashier (POS only). 3 paket: Gratis (500 tx/produk+iklan), 25rb (unlimited+barcode), 50rb (WA+social commerce+QR meja). AI Co-Pilot gratis local compute. Glassmorphism: #4F46E5 #7C3AED #06B6D4. Font Inter. Offline-first: SQLite lokal sync Supabase. 13 tabel DB+RLS. ===
Clone repo [GITHUB_URL] lalu LANJUTKAN project Flutter kasirgo. Phase 1-3 selesai: DB + Auth + App shell + Produk + POS + AI. flutter pub get.
ATURAN: SETIAP selesai 1-2 file, langsung git add . && git commit -m "progress: [nama file]" && git push. JANGAN tunggu semua selesai.
SETELAH CLONE: baca file AGENTS.md di root repo untuk konteks lengkap proyek, lalu update checklist Progress Tracker di sana jika ada Phase yang selesai di session ini.

Lanjutkan project Flutter kasirgo. Tambahkan modul laporan, pelanggan, dan karyawan.

1. REPORT MODULE (report_screen.dart)
   - Tab: Ringkasan, Penjualan, Produk, Laba/Rugi
   - Filter periode: Hari ini, 7 hari, 30 hari, Bulan ini, Custom range
   - Ringkasan: total omzet, total untung, total transaksi, rata-rata transaksi
   - Grafik penjualan harian (fl_chart bar chart)
   - Top 10 produk terlaris (horizontal bar chart)
   - Laba/Rugi: pendapatan - HPP = laba kotor
   - Export ke Excel (pakai library excel)
   - Laporan Bank-Ready (paket basic+): format laporan keuangan standar bank
   - Kirim laporan via share (whatsapp, email)

2. CUSTOMER MODULE (customer_list_screen.dart)
   - List pelanggan dengan total belanja
   - Tambah pelanggan: nama, nomor WA
   - Detail pelanggan: riwayat transaksi, total belanja, loyalty points
   - Piutang/tempo tracking: pelanggan yang belum bayar

3. EMPLOYEE MODULE (employee_screen.dart)
   - List karyawan
   - Check-in / Check-out dengan tombol besar
   - Riwayat absensi per tanggal
   - Shift management: pagi/siang/malam

IMPLEMENTASI DETAIL:

report_screen.dart:
- AppBar dengan judul "Laporan"
- TabBar: Ringkasan | Penjualan | Produk
- Filter chip horizontal di bawah tab
- Ringkasan tab: 4 card metric (omzet, untung, transaksi, rata-rata)
- Penjualan tab: bar chart harian, list transaksi di bawah
- Produk tab: top 10 horizontal bar chart
- FAB export Excel

customer_list_screen.dart:
- Search bar
- List pelanggan dengan card: nama, WA, total belanja
- FAB tambah pelanggan
- Tap card untuk detail + riwayat transaksi

employee_screen.dart:
- Tanggal hari ini di header
- Tombol Check-in besar (hijau) / Check-out (merah)
- List absensi di bawah
- Shift info

PASTIKAN:
- flutter analyze tidak error
- flutter build apk --debug berhasil
- Test: generate laporan, export Excel, share
- Test: tambah pelanggan, lihat riwayat transaksi
- Test: check-in karyawan, check-out, lihat history

Laporkan hasil build dan test.
```

### Test Check:
- [ ] Laporan ringkasan menampilkan data akurat
- [ ] Grafik penjualan berfungsi
- [ ] Export Excel berhasil
- [ ] Laporan bank-ready menampilkan format yang benar
- [ ] Pelanggan list, tambah, detail, riwayat berfungsi
- [ ] Absensi check-in/check-out berfungsi
- [ ] History absensi tersimpan

---

## PHASE 5: Premium Features + Subscription Gate

### Prompt:

```
=== KASIRGO: Aplikasi kasir UMKM (Flutter mobile + Supabase + React superadmin). 3 role: Owner (full), Admin (CRUD produk), Cashier (POS only). 3 paket: Gratis (500 tx/produk+iklan), 25rb (unlimited+barcode), 50rb (WA+social commerce+QR meja). AI Co-Pilot gratis local compute. Glassmorphism: #4F46E5 #7C3AED #06B6D4. Font Inter. Offline-first: SQLite lokal sync Supabase. 13 tabel DB+RLS. ===
Clone repo [GITHUB_URL] lalu LANJUTKAN project Flutter kasirgo. Phase 1-4 selesai: DB + Auth + App + Produk + POS + AI + Laporan. flutter pub get.
ATURAN: SETIAP selesai 1-2 file, langsung git add . && git commit -m "progress: [nama file]" && git push. JANGAN tunggu semua selesai.
SETELAH CLONE: baca file AGENTS.md di root repo untuk konteks lengkap proyek, lalu update checklist Progress Tracker di sana jika ada Phase yang selesai di session ini.

Lanjutkan project Flutter kasirgo. Tambahkan fitur premium dan subscription gate.

1. SUBSCRIPTION GATE
   - Halaman settings: tampilkan tier saat ini, expiry date
   - Tombol upgrade ke basic_25 atau pro_50
   - Payment simulation (karena belum ada payment gateway, gunakan dummy flow: tap upgrade -> konfirmasi -> langsung aktif)
   - Cek tier di setiap fitur premium: jika tidak eligible, tampilkan dialog upgrade
   - Free tier: tampilkan iklan banner di bagian bawah screen (simulasi Adstera)

2. MULTI-CHANNEL PRICING (product_form_screen.dart tambahan)
   - Di form produk, tambahkan section "Harga per Channel"
   - List channel: offline, tokopedia, shopee, blibli, gofood, grabfood, shopeefood
   - Setiap channel: input harga + input platform fee %
   - Auto-hitung margin per channel

3. DISCOUNT & PROMO (product_form_screen.dart tambahan)
   - Tambahkan section "Diskon & Promo"
   - Input diskon % atau nominal
   - Tanggal mulai dan selesai
   - Toggle "Flash Sale"
   - Di POS screen: jika produk ada diskon aktif, tampilkan badge diskon dan harga coret

4. NOTIFICATION (Edge Function + Local)
   - Buat Supabase Edge Function untuk cron job:
     - Cek stok menipis (stock < min_stock_alert)
     - Cek produk expired dalam 7 hari
   - Di Flutter: tampilkan badge notifikasi di dashboard
   - List notifikasi: stok menipis, expired, insight harian

5. FLASH SALE AUTO-SUGGEST
   - utils/ai_engine.dart: deteksi produk dengan stok tidak berubah > 30 hari
   - Tampilkan card "Stok Menumpuk" di dashboard dengan saran diskon

IMPLEMENTASI DETAIL:

settings_screen.dart:
- Card subscription tier saat ini dengan warna (free: abu, basic: biru, pro: ungu)
- List fitur yang tersedia di tier saat ini
- Tombol upgrade
- Iklan banner (jika free tier, simulasi)

BUAT SUPABASE EDGE FUNCTION (stock_alert):
- Buka Supabase Dashboard > Edge Functions > New Function "stock_alert"
- Kode:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const { data: products } = await supabase
    .from("products")
    .select("id, outlet_id, name, stock, min_stock_alert, expired_date");

  const alerts = [];
  for (const p of products || []) {
    if (p.stock <= p.min_stock_alert) {
      alerts.push({ product_id: p.id, outlet_id: p.outlet_id, type: "low_stock", message: `Stok ${p.name} menipis: ${p.stock}` });
    }
    if (p.expired_date) {
      const daysUntilExpiry = Math.ceil((new Date(p.expired_date).getTime() - Date.now()) / (1000 * 60 * 60 * 24));
      if (daysUntilExpiry <= 7 && daysUntilExpiry > 0) {
        alerts.push({ product_id: p.id, outlet_id: p.outlet_id, type: "expiring", message: `${p.name} kadaluarsa dalam ${daysUntilExpiry} hari` });
      }
    }
  }

  for (const alert of alerts) {
    await supabase.from("ai_insights").insert({
      outlet_id: alert.outlet_id,
      insight_type: alert.type,
      data: alert
    });
  }

  return new Response(JSON.stringify({ alerts_count: alerts.length }), {
    headers: { "Content-Type": "application/json" },
  });
});
```

PASTIKAN:
- flutter analyze tidak error
- flutter build apk --debug berhasil
- Test: upgrade tier, cek fitur premium terbuka
- Test: multi-channel pricing di form produk
- Test: diskon muncul di POS
- Test: notifikasi stok menipis
- Test: flash sale auto-suggest di dashboard

Laporkan hasil build dan test.
```

### Test Check:
- [ ] Subscription gate berfungsi (free -> basic -> pro)
- [ ] Multi-channel pricing tersimpan dan muncul di POS
- [ ] Diskon produk muncul di POS dengan badge
- [ ] Notifikasi stok menipis dan expired muncul
- [ ] Flash sale auto-suggest berfungsi
- [ ] Iklan muncul di free tier, hilang di berbayar

---

## PHASE 6: WhatsApp + Social Commerce + Toko Online + QR Meja

### Prompt:

```
=== KASIRGO: Aplikasi kasir UMKM (Flutter mobile + Supabase + React superadmin). 3 role: Owner (full), Admin (CRUD produk), Cashier (POS only). 3 paket: Gratis (500 tx/produk+iklan), 25rb (unlimited+barcode), 50rb (WA+social commerce+QR meja). AI Co-Pilot gratis local compute. Glassmorphism: #4F46E5 #7C3AED #06B6D4. Font Inter. Offline-first: SQLite lokal sync Supabase. 13 tabel DB+RLS. ===
Clone repo [GITHUB_URL] lalu LANJUTKAN project Flutter kasirgo. Phase 1-5 selesai. flutter pub get.
ATURAN: SETIAP selesai 1-2 file, langsung git add . && git commit -m "progress: [nama file]" && git push. JANGAN tunggu semua selesai.
SETELAH CLONE: baca file AGENTS.md di root repo untuk konteks lengkap proyek, lalu update checklist Progress Tracker di sana jika ada Phase yang selesai di session ini.

Lanjutkan project Flutter kasirgo. Tambahkan integrasi dan fitur premium lanjutan.

1. WHATSAPP INTEGRATION
   - Kirim struk digital via WhatsApp: gunakan url_launcher dengan format wa.me
   - Format struk: nama toko, tanggal, item, total, terima kasih
   - Broadcast promosi: pilih pelanggan, tulis pesan, kirim via WA (buka intent WA)
   - WA CRM Auto-Retensi (pro tier): deteksi pelanggan tidak transaksi > 30 hari, tampilkan saran kirim WA

2. SOCIAL COMMERCE SYNC (simulasi dashboard)
   - Halaman "Social Commerce": card per channel (Shopee, Tokopedia, GoFood, dll)
   - Setiap card: input transaksi manual dari channel tersebut
   - Form: nama produk, qty, harga, platform fee, tanggal
   - Transaksi tersimpan dengan channel tag, stok auto-kurang
   - Laporan per channel di report screen

3. TOKO ONLINE KATALOG (PWA ringan)
   - Halaman "Toko Online" di settings: generate link katalog
   - Katalog web ringan: daftar produk, foto, harga, tombol order via WA
   - Buat sebagai Flutter Web build terpisah atau halaman statis
   - Untuk simplifikasi: gunakan halaman Flutter yang menampilkan produk dalam format katalog

4. QR MEJA (Cafe/Restoran)
   - Generate QR code per meja (pakai qr_flutter)
   - QR berisi deep link ke halaman menu
   - Customer scan QR -> buka halaman menu -> pilih item -> submit order
   - Order muncul di screen owner/admin sebagai notifikasi

5. HEALTH SCORE DASHBOARD
   - Dashboard owner tambahan: health score card
   - Health score (0-100) dihitung dari:
     - Revenue trend (30 hari vs 30 hari sebelumnya): 30%
     - Customer retention: 25%
     - Inventory turnover: 20%
     - Margin health: 15%
     - Transaction growth: 10%
   - Cashflow projection: piutang - tagihan + tren 7 hari
   - Tampilkan dengan gauge chart dan card metric

IMPLEMENTASI DETAIL:

Buat screen baru:
- screens/owner/social_commerce_screen.dart
- screens/owner/health_score_screen.dart
- screens/owner/whatsapp_broadcast_screen.dart
- screens/owner/qr_table_screen.dart
- screens/owner/online_catalog_screen.dart
- screens/customer/customer_order_screen.dart

Tambahkan ke navigation owner.

PASTIKAN:
- flutter analyze tidak error
- flutter build apk --debug berhasil
- Test: kirim struk via WA, buka intent WA
- Test: input transaksi social commerce, cek stok berkurang
- Test: generate QR meja, scan, order
- Test: health score dashboard menampilkan data
- Test: katalog online tampil

Laporkan hasil build dan test.
```

### Test Check:
- [ ] Struk WhatsApp terkirim (intent terbuka)
- [ ] Broadcast promosi ke pelanggan terpilih
- [ ] Social commerce: input transaksi, stok berkurang
- [ ] QR meja: generate, scan, order muncul
- [ ] Health score dashboard akurat
- [ ] Katalog online bisa diakses

---

## PHASE 7: Superadmin Web (React.js + Vercel)

### Prompt:

```
=== KASIRGO: Aplikasi kasir UMKM (Flutter mobile + Supabase + React superadmin). 3 role: Owner (full), Admin (CRUD produk), Cashier (POS only). 3 paket: Gratis (500 tx/produk+iklan), 25rb (unlimited+barcode), 50rb (WA+social commerce+QR meja). AI Co-Pilot gratis local compute. Glassmorphism: #4F46E5 #7C3AED #06B6D4. Font Inter. Offline-first: SQLite lokal sync Supabase. 13 tabel DB+RLS. ===
Clone repo [GITHUB_URL] lalu LANJUTKAN project React kasirgo-admin. Phase 1-6 selesai (Flutter app). npm install.
ATURAN: SETIAP selesai 1-2 file, langsung git add . && git commit -m "progress: [nama file]" && git push. JANGAN tunggu semua selesai.
SETELAH CLONE: baca file AGENTS.md di root repo untuk konteks lengkap proyek, lalu update checklist Progress Tracker di sana jika ada Phase yang selesai di session ini.

Buat project React.js baru untuk superadmin dashboard KasirGo. Deploy ke Vercel.

Buat dengan Vite + React + TypeScript + Tailwind CSS:

npm create vite@latest kasirgo-admin -- --template react-ts
cd kasirgo-admin
npm install @supabase/supabase-js react-router-dom recharts lucide-react
npm install -D tailwindcss @tailwindcss/vite

STRUKTUR FOLDER:
src/
  main.tsx
  App.tsx
  config/
    supabase.ts
  components/
    Layout.tsx
    Sidebar.tsx
    StatCard.tsx
  pages/
    Login.tsx
    Dashboard.tsx
    Users.tsx
    UserDetail.tsx
    Affiliates.tsx
    Backup.tsx
    Revenue.tsx

FITUR:

1. Login (pages/Login.tsx)
   - Email + password login
   - Hanya user dengan role superadmin yang bisa akses
   - Redirect ke dashboard setelah login

2. Dashboard (pages/Dashboard.tsx)
   - Total users, active subscriptions, revenue bulan ini, total affiliates
   - Grafik pie: distribusi tier (free/basic/pro)
   - Grafik line: revenue per bulan

3. User Management (pages/Users.tsx)
   - Table semua users dengan: nama, email, outlet, tier, status
   - Search dan filter
   - Tombol "Masuk sebagai Owner" (impersonate)
   - Tombol suspend/activate

4. User Detail (pages/UserDetail.tsx)
   - Detail outlet, subscription history
   - Product count, transaction count
   - Tombol impersonate
   - Tombol backup data outlet ini

5. Affiliate Management (pages/Affiliates.tsx)
   - Table affiliates: nama, email, referral code, commission, total earned
   - Tambah affiliate form
   - Track referrals per affiliate

6. Backup & Restore (pages/Backup.tsx)
   - List backup per outlet
   - Tombol create backup (export data outlet ke JSON)
   - Tombol restore (upload JSON)

7. Revenue (pages/Revenue.tsx)
   - Total revenue per bulan
   - Revenue by tier
   - Pending payments
   - Affiliate commission summary

DESIGN:
- Dark theme admin panel
- Sidebar navigation
- Tabel dengan sorting dan pagination
- Responsive design

SUPABASE SETUP:
- Tambahkan kolom role ke auth.users metadata: role = 'superadmin' untuk superadmin
- Buat user superadmin pertama manual via Supabase dashboard

DEPLOY:
- Push ke GitHub
- Deploy ke Vercel (connect repo)
- Set environment variables: VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY

PASTIKAN:
- npm run build tidak error
- Deploy ke Vercel berhasil
- Test: login superadmin, lihat dashboard, impersonate owner, manage affiliates, backup

Laporkan hasil deploy.
```

### Test Check:
- [ ] Login superadmin berfungsi
- [ ] Dashboard menampilkan stats
- [ ] User list, search, filter berfungsi
- [ ] Impersonate owner berfungsi
- [ ] Affiliate CRUD berfungsi
- [ ] Backup/restore berfungsi
- [ ] Revenue dashboard akurat
- [ ] Deploy Vercel sukses

---

## PHASE 8: Polish, Testing, Final Deploy

### Prompt:

```
=== KASIRGO: Aplikasi kasir UMKM (Flutter mobile + Supabase + React superadmin). 3 role: Owner (full), Admin (CRUD produk), Cashier (POS only). 3 paket: Gratis (500 tx/produk+iklan), 25rb (unlimited+barcode), 50rb (WA+social commerce+QR meja). AI Co-Pilot gratis local compute. Glassmorphism: #4F46E5 #7C3AED #06B6D4. Font Inter. Offline-first: SQLite lokal sync Supabase. 13 tabel DB+RLS. ===
Clone repo [GITHUB_URL] lalu LANJUTKAN project. Phase 1-7 selesai: Flutter app + React admin. flutter pub get && npm install.
ATURAN: SETIAP selesai 1-2 file, langsung git add . && git commit -m "progress: [nama file]" && git push. JANGAN tunggu semua selesai.
SETELAH CLONE: baca file AGENTS.md di root repo untuk konteks lengkap proyek, lalu update checklist Progress Tracker di sana jika ada Phase yang selesai di session ini.

Lakukan finalisasi project KasirGo:

1. UI POLISH (Flutter)
   - Cek semua screen: pastikan glassmorphism theme konsisten
   - Add loading states, error states, empty states di semua screen
   - Add pull-to-refresh di semua list screen
   - Add haptic feedback di tombol-tombol penting
   - Animasi transisi antar screen (slide, fade)
   - Splash screen dengan logo KasirGo

2. PWA SETUP (Flutter Web untuk katalog)
   - Build Flutter web untuk katalog online
   - Tambahkan manifest.json dan service worker
   - Deploy ke Vercel sebagai static site

3. ADSTERA INTEGRATION (Free Tier)
   - Tambahkan banner ad di bagian bawah screen untuk free tier
   - Simulasi: gunakan container dengan teks "Iklan" dan warna abu-abu

4. FINAL TESTING
   - Test flow lengkap: register -> buat produk -> transaksi -> laporan
   - Test semua role: owner, admin, cashier
   - Test offline: matikan internet, transaksi, nyalakan internet, sync
   - Test upgrade: free -> basic -> pro
   - Test semua fitur premium

5. GITHUB SETUP
   - Buat repo GitHub: kasirgo-app (Flutter) dan kasirgo-admin (React)
   - Push semua kode
   - Tambahkan README dengan setup instructions

6. VERCEL DEPLOY
   - Deploy React admin ke Vercel
   - Deploy Flutter web katalog ke Vercel (jika ada)

7. APK BUILD
   - flutter build apk --release
   - Upload APK sebagai GitHub release

PASTIKAN:
- Tidak ada error di flutter analyze
- Tidak ada error di npm run build (React)
- Semua flow berjalan lancar
- APK release bisa diinstall dan berfungsi

Laporkan semua hasil final.
```

### Test Check:
- [ ] UI konsisten di semua screen
- [ ] Loading/error/empty states ada
- [ ] Pull-to-refresh berfungsi
- [ ] Animasi transisi halus
- [ ] Splash screen muncul
- [ ] PWA katalog berfungsi
- [ ] Iklan muncul di free tier
- [ ] Full flow test: register -> produk -> transaksi -> laporan
- [ ] Role test: owner, admin, cashier
- [ ] Offline test: transaksi offline -> sync online
- [ ] Upgrade test: semua tier
- [ ] GitHub repo terisi kode
- [ ] Vercel deploy sukses
- [ ] APK release berfungsi

---

## RINGKASAN WORKFLOW

### Per Phase:
```
AKHIR session lama:  Update checklist di AGENTS.md, lalu git add . && git commit -m "Phase X: [nama]" && git push
AWAL session baru:   Reset context (BUKAN task baru), lalu copy prompt Phase berikutnya
                     Prompt sudah include: clone repo + perintah baca AGENTS.md + install dependency
SETELAH clone:       AI baca AGENTS.md -> paham konteks & progress -> kerjakan phase
PUSH:                tiap 1-2 file selesai (save point), jangan tunggu akhir phase
KENA LIMIT:          Reset context > Compact. Compact hanya saat di tengah debug 1 bug rumit.
```

### Alur Satu Phase (ringkas):
```
1. Session baru  ->  2. Paste prompt phase  ->  3. AI clone + baca AGENTS.md
4. AI kerjakan + push tiap 1-2 file  ->  5. Test live
6. Update Progress Tracker AGENTS.md + commit + push  ->  7. Selesai
```

### Tools per Phase:
| Phase | Tools | Perintah install |
|-------|-------|-----------------|
| 1 | None (Supabase web) | - |
| 2-6 | Flutter SDK | `flutter pub get` |
| 7 | Node.js | `npm install` |
| 8 | Flutter + Node.js | `flutter pub get && npm install` |

Setelah semua 8 Phase selesai: push ke GitHub, deploy Vercel, build APK release.