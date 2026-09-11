# KASIRGO -- WORKFLOW LENGKAP (Copy-Paste ke MonkeyCode)

> Copy prompt Phase yang ingin dikerjakan, paste ke session MonkeyCode baru. Satu session = satu Phase.
> Sebelum memulai: pastikan repo sudah di-push ke GitHub dan `AGENTS.md` ada di root.

---

## MASTER CHECKLIST

| Phase | Nama | Status | Session |
|-------|------|--------|---------|
| 0 | Design docs + PRD + workflow | [x] SELESAI | - |
| 1 | Supabase DB + Auth | [x] SELESAI | - |
| 2 | Flutter App Shell + Auth + Offline Engine | [ ] SEDANG | Session 2 |
| 3 | Produk + POS + QRIS + AI Co-Pilot | [ ] | Session 3 |
| 4 | Laporan + Pelanggan + Karyawan | [ ] | Session 4 |
| 5 | Premium Features + Subscription Gate | [ ] | Session 5 |
| 6 | WhatsApp + Social Commerce + QR Meja + Health Score | [ ] | Session 6 |
| 7 | Superadmin Web (React + Cloudflare Pages) | [ ] | Session 7 |
| 8 | Polish + Testing + Final Deploy | [ ] | Session 8 |

---

## ATURAN UMUM (BACA SEKALI)

1. **Satu session = satu Phase.** Jangan kerjakan 2 Phase dalam 1 session.
2. **Push tiap 1-2 file selesai.** Jangan tunggu semua selesai baru push.
3. **Baca AGENTS.md dulu.** Itu sumber konteks proyek.
4. **Update Progress Tracker** di AGENTS.md saat phase selesai.
5. **Testing: HTML renderer.** `flutter run -d web-server --web-renderer html --web-hostname 0.0.0.0 --web-port 8080`
6. **APK target <10MB per ABI.** `flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/debug-info`
7. **Foto produk = LOKAL** (`image_local_path`). Tidak upload ke Supabase.
8. **Jika kena limit context: push -> Compact -> AI baca AGENTS.md + git log -> lanjut.** Lihat bagian "CONTEXT WINDOW RECOVERY".
9. **Ganti Phase: push -> Compact -> memory check -> baru lanjut.** Compact hemat token tapi tetap ingat ringkasan; `AGENTS.md` = jaring pengaman. Pakai RESET hanya kalau hasil Compact ngawur.
10. **Hemat token:** lihat bagian "HEMAT TOKEN (WAJIB)" di bawah -- satu task per pesan, jangan baca file tidak relevan, error sama >3x = reset.
11. **Test LIVE setiap Phase selesai.** Jalankan dev server, minta URL preview, uji pakai klik -- jangan hanya percaya "build sukses". Lihat bagian "TEST LIVE PER PHASE".

---

---

## PHASE 1: Supabase DB + Auth

### FILE LAMPIRAN
| File | Status | Dibuat di Phase |
|------|--------|-----------------|
| `kasirgo/` (project Flutter) | BELUM | Phase 2 |
| `kasirgo-admin/` (project React) | BELUM | Phase 7 |
| `docs/KASIRGO-WORKFLOW-LENGKAP.md` | SUDAH | Phase 0 |
| `docs/STRATEGI-KASIRGO.md` | SUDAH | Phase 0 |
| `docs/PRD-KasirGo.md` | SUDAH | Phase 0 |
| `AGENTS.md` | SUDAH | Phase 0 |

> Phase 1 dikerjakan di Supabase Dashboard (web). Tidak ada kode Flutter/React yang dibuat.

### PROMPT (Copy-Paste)

```
=== KASIRGO: Aplikasi kasir UMKM (Flutter mobile + Supabase + React superadmin). 3 role: Owner (full), Admin (CRUD produk), Cashier (POS only). 3 paket: Gratis (500 tx/produk+iklan), 25rb (unlimited+barcode), 50rb (WA+social commerce+QR meja). AI Co-Pilot gratis local compute. Glassmorphism: #4F46E5 #7C3AED #06B6D4. Font Inter. Offline-first: SQLite lokal sync Supabase. 13 tabel DB+RLS. ===
Buat project Supabase baru untuk aplikasi kasir UMKM bernama "KasirGo".

ATURAN: SETIAP selesai 1 langkah (tabel, trigger, RLS, verifikasi) atau update file docs/AGENTS.md, langsung git add . && git commit -m "progress: [nama langkah]" && git push. JANGAN tunggu semua selesai.
SETELAH PHASE SELESAI: tulis section "Handoff Phase 1" di AGENTS.md (status, schema, hasil verifikasi, sisa pekerjaan), lalu commit + push.

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
  image_local_path TEXT NOT NULL DEFAULT '',
  thumb_key TEXT,
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
  referred_user_id UUID REFERENCES auth.users(id),
  outlet_id UUID REFERENCES outlets(id),
  commission_amount DECIMAL(12,2) DEFAULT 0,
  status TEXT DEFAULT 'active',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE ai_insights (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  insight_type TEXT NOT NULL,
  data JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- TRIGGERS
-- ============================================

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO outlets (owner_id, name, type)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'business_name', 'Toko Baru'), COALESCE(NEW.raw_user_meta_data->>'business_type', 'warung'));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

CREATE OR REPLACE FUNCTION decrement_stock()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE products SET stock = stock - NEW.quantity WHERE id = NEW.product_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER tr_decrement_stock
  AFTER INSERT ON transaction_items
  FOR EACH ROW EXECUTE FUNCTION decrement_stock();

-- ============================================
-- RLS POLICIES
-- ============================================

-- outlets: owner full access
ALTER TABLE outlets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner can manage own outlet" ON outlets FOR ALL USING (owner_id = auth.uid());
CREATE POLICY "Admin/Cashier can view own outlet" ON outlets FOR SELECT USING (
  EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND outlet_id = outlets.id)
);

-- user_roles: owner full access
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner can manage roles" ON user_roles FOR ALL USING (
  EXISTS (SELECT 1 FROM outlets WHERE id = user_roles.outlet_id AND owner_id = auth.uid())
);

-- products: owner/admin CRUD, cashier read
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner/Admin can manage products" ON products FOR ALL USING (
  EXISTS (SELECT 1 FROM outlets WHERE id = products.outlet_id AND owner_id = auth.uid())
  OR EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND outlet_id = products.outlet_id AND role = 'admin')
);
CREATE POLICY "Cashier can view products" ON products FOR SELECT USING (
  EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND outlet_id = products.outlet_id AND role = 'cashier')
);

-- product_prices: same as products
ALTER TABLE product_prices ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner/Admin can manage prices" ON product_prices FOR ALL USING (
  EXISTS (SELECT 1 FROM products p JOIN outlets o ON p.outlet_id = o.id WHERE p.id = product_prices.product_id AND o.owner_id = auth.uid())
  OR EXISTS (SELECT 1 FROM products p JOIN user_roles r ON p.outlet_id = r.outlet_id WHERE p.id = product_prices.product_id AND r.user_id = auth.uid() AND r.role = 'admin')
);
CREATE POLICY "Cashier can view prices" ON product_prices FOR SELECT USING (
  EXISTS (SELECT 1 FROM products p JOIN user_roles r ON p.outlet_id = r.outlet_id WHERE p.id = product_prices.product_id AND r.user_id = auth.uid() AND r.role = 'cashier')
);

-- product_discounts
ALTER TABLE product_discounts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner/Admin can manage discounts" ON product_discounts FOR ALL USING (
  EXISTS (SELECT 1 FROM products p JOIN outlets o ON p.outlet_id = o.id WHERE p.id = product_discounts.product_id AND o.owner_id = auth.uid())
  OR EXISTS (SELECT 1 FROM products p JOIN user_roles r ON p.outlet_id = r.outlet_id WHERE p.id = product_discounts.product_id AND r.user_id = auth.uid() AND r.role = 'admin')
);

-- transactions: owner/admin read, cashier insert
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner/Admin can view transactions" ON transactions FOR SELECT USING (
  EXISTS (SELECT 1 FROM outlets WHERE id = transactions.outlet_id AND owner_id = auth.uid())
  OR EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND outlet_id = transactions.outlet_id AND role IN ('admin', 'cashier'))
);
CREATE POLICY "Any role can insert transactions" ON transactions FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM outlets WHERE id = transactions.outlet_id AND owner_id = auth.uid())
  OR EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND outlet_id = transactions.outlet_id)
);

-- transaction_items
ALTER TABLE transaction_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "View transaction items" ON transaction_items FOR SELECT USING (
  EXISTS (SELECT 1 FROM transactions t JOIN outlets o ON t.outlet_id = o.id WHERE t.id = transaction_items.transaction_id AND o.owner_id = auth.uid())
  OR EXISTS (SELECT 1 FROM transactions t JOIN user_roles r ON t.outlet_id = r.outlet_id WHERE t.id = transaction_items.transaction_id AND r.user_id = auth.uid())
);
CREATE POLICY "Insert transaction items" ON transaction_items FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM transactions t JOIN outlets o ON t.outlet_id = o.id WHERE t.id = transaction_items.transaction_id AND o.owner_id = auth.uid())
  OR EXISTS (SELECT 1 FROM transactions t JOIN user_roles r ON t.outlet_id = r.outlet_id WHERE t.id = transaction_items.transaction_id AND r.user_id = auth.uid())
);

-- customers
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Manage customers" ON customers FOR ALL USING (
  EXISTS (SELECT 1 FROM outlets WHERE id = customers.outlet_id AND owner_id = auth.uid())
  OR EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND outlet_id = customers.outlet_id AND role IN ('admin', 'cashier'))
);

-- employees
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Manage employees" ON employees FOR ALL USING (
  EXISTS (SELECT 1 FROM outlets WHERE id = employees.outlet_id AND owner_id = auth.uid())
  OR (EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND outlet_id = employees.outlet_id) AND employees.user_id = auth.uid())
);

-- subscriptions
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "View own subscriptions" ON subscriptions FOR SELECT USING (
  EXISTS (SELECT 1 FROM outlets WHERE id = subscriptions.outlet_id AND owner_id = auth.uid())
);

-- affiliates (superadmin only via service key)
ALTER TABLE affiliates ENABLE ROW LEVEL SECURITY;
ALTER TABLE affiliate_referrals ENABLE ROW LEVEL SECURITY;

-- ai_insights
ALTER TABLE ai_insights ENABLE ROW LEVEL SECURITY;
CREATE POLICY "View own insights" ON ai_insights FOR SELECT USING (
  EXISTS (SELECT 1 FROM outlets WHERE id = ai_insights.outlet_id AND owner_id = auth.uid())
  OR EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND outlet_id = ai_insights.outlet_id)
);

-- ============================================
-- INDEXES
-- ============================================
CREATE INDEX idx_products_outlet ON products(outlet_id);
CREATE INDEX idx_products_category ON products(outlet_id, category);
CREATE INDEX idx_products_barcode ON products(barcode);
CREATE INDEX idx_transactions_outlet ON transactions(outlet_id);
CREATE INDEX idx_transactions_date ON transactions(outlet_id, created_at DESC);
CREATE INDEX idx_transaction_items_tx ON transaction_items(transaction_id);
CREATE INDEX idx_customers_outlet ON customers(outlet_id);
CREATE INDEX idx_employees_date ON employees(outlet_id, date);
CREATE INDEX idx_ai_insights_outlet ON ai_insights(outlet_id, created_at DESC);

PASTIKAN:
- Semua 13 tabel terbuat tanpa error
- RLS policies aktif untuk semua tabel
- Trigger handle_new_user berfungsi (register user baru = outlet auto-create)
- Trigger decrement_stock berfungsi
- Register + login dari Supabase Auth UI berhasil
```

### TEST CHECKLIST Phase 1
- [ ] Semua 13 tabel terbuat tanpa error
- [ ] RLS policies aktif
- [ ] Trigger handle_new_user berfungsi (register user baru, outlet auto-create)
- [ ] Trigger decrement_stock berfungsi
- [ ] Register + login berhasil dari Supabase Auth UI

---

## PHASE 2: Flutter App Shell + Auth + Offline Engine

### FILE LAMPIRAN (Dibuat di Phase Ini)
```
kasirgo/
  pubspec.yaml
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
        product_list_screen.dart      (placeholder)
        product_form_screen.dart      (placeholder)
        pos_screen.dart               (placeholder)
        report_screen.dart            (placeholder)
        customer_list_screen.dart     (placeholder)
        employee_screen.dart          (placeholder)
        settings_screen.dart          (placeholder)
      admin/
        admin_home_screen.dart
      cashier/
        cashier_home_screen.dart
        cashier_pos_screen.dart
      customer/
        customer_menu_screen.dart     (placeholder)
    widgets/
      common/
        loading_widget.dart
        error_widget.dart
        empty_state_widget.dart
        app_drawer.dart
        search_bar.dart
      pos/
        cart_panel.dart               (placeholder)
        product_grid.dart             (placeholder)
        checkout_dialog.dart          (placeholder)
    utils/
      offline_queue.dart
      ai_engine.dart                  (placeholder)
      formatters.dart
      validators.dart
```

### PROMPT (Copy-Paste)

```
=== KASIRGO: Aplikasi kasir UMKM (Flutter mobile + Supabase + React superadmin). 3 role: Owner (full), Admin (CRUD produk), Cashier (POS only). 3 paket: Gratis (500 tx/produk+iklan), 25rb (unlimited+barcode), 50rb (WA+social commerce+QR meja). AI Co-Pilot gratis local compute. Glassmorphism: #4F46E5 #7C3AED #06B6D4. Font Inter. Offline-first: SQLite lokal sync Supabase. 13 tabel DB+RLS. ===
Clone repo [GITHUB_URL] lalu LANJUTKAN project Flutter kasirgo. Phase 1 selesai: Supabase DB + Auth. flutter pub get.
ATURAN: SETIAP selesai 1-2 file, langsung git add . && git commit -m "progress: [nama file]" && git push. JANGAN tunggu semua selesai.
SETELAH PHASE SELESAI: jalankan dev server + minta URL preview + uji live pakai klik (lihat bagian "TEST LIVE PER PHASE"). Jangan hanya bilang build sukses.
SETELAH CLONE: baca file AGENTS.md di root repo untuk konteks lengkap proyek, lalu update checklist Progress Tracker di sana jika ada Phase yang selesai di session ini.
TESTING CEPAT: flutter run -d web-server --web-renderer html --web-hostname 0.0.0.0 --web-port 8080 untuk preview instan (HTML renderer, tidak blank). APK build hanya untuk test final (kamera, SQLite).
APK TARGET: di bawah 10MB per ABI (--split-per-abi --obfuscate).

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
- flutter run -d web-server --web-renderer html --web-hostname 0.0.0.0 --web-port 8080 berjalan
- flutter build apk --debug berhasil (cek ukuran APK: target per ABI <10MB)
- Test: login dengan user yang sudah dibuat di Supabase, pastikan redirect ke screen sesuai role

Laporkan hasil build dan test (web + APK).
```

### TEST CHECKLIST Phase 2
- [ ] flutter analyze clean
- [ ] flutter run web HTML renderer berhasil (tidak blank)
- [ ] flutter build apk --debug berhasil, per ABI di bawah 10MB
- [ ] Login screen muncul dengan glassmorphism design
- [ ] Register user baru, outlet auto-create
- [ ] Role detection berfungsi (owner/admin/cashier redirect berbeda)
- [ ] Offline sync: matikan internet, buat transaksi, nyalakan internet, data sync

---

## PHASE 3: Produk + POS + QRIS + AI Co-Pilot

### FILE LAMPIRAN (Dibuat/Diupdate di Phase Ini)
```
DIBUAT/DIISI:
  lib/models/product.dart               (jika belum)
  lib/services/supabase_service.dart     (CRUD lengkap)
  lib/screens/owner/product_list_screen.dart
  lib/screens/owner/product_form_screen.dart
  lib/screens/owner/pos_screen.dart
  lib/screens/cashier/cashier_pos_screen.dart
  lib/widgets/pos/cart_panel.dart
  lib/widgets/pos/product_grid.dart
  lib/widgets/pos/checkout_dialog.dart
  lib/utils/ai_engine.dart

DIUPDATE:
  lib/screens/owner/owner_home_screen.dart  (AI insight cards)
  lib/app.dart                              (routing tambahan)
```

### PROMPT (Copy-Paste)

```
=== KASIRGO: Aplikasi kasir UMKM (Flutter mobile + Supabase + React superadmin). 3 role: Owner (full), Admin (CRUD produk), Cashier (POS only). 3 paket: Gratis (500 tx/produk+iklan), 25rb (unlimited+barcode), 50rb (WA+social commerce+QR meja). AI Co-Pilot gratis local compute. Glassmorphism: #4F46E5 #7C3AED #06B6D4. Font Inter. Offline-first: SQLite lokal sync Supabase. 13 tabel DB+RLS. ===
Clone repo [GITHUB_URL] lalu LANJUTKAN project Flutter kasirgo. Phase 1-2 selesai: DB + Auth + App shell + navigation. flutter pub get.
ATURAN: SETIAP selesai 1-2 file, langsung git add . && git commit -m "progress: [nama file]" && git push. JANGAN tunggu semua selesai.
SETELAH PHASE SELESAI: jalankan dev server + minta URL preview + uji live pakai klik (lihat bagian "TEST LIVE PER PHASE"). Jangan hanya bilang build sukses.
SETELAH CLONE: baca file AGENTS.md di root repo untuk konteks lengkap proyek, lalu update checklist Progress Tracker di sana jika ada Phase yang selesai di session ini.

Lanjutkan project Flutter kasirgo. Tambahkan modul core berikut:

1. PRODUK MODULE (product_list_screen.dart, product_form_screen.dart)
   - List produk dengan search bar dan filter kategori
   - Grid/List view toggle
   - Swipe to delete
   - Fab button untuk tambah produk
   - Form produk: nama, kategori, harga modal, harga jual, stok, satuan, barcode, expired date, foto produk
   - Foto produk: ambil dari kamera/galeri, simpan LOKAL saja (path disimpan di `image_local_path`). TIDAK upload ke Supabase. Thumbnail ke R2 hanya untuk produk yang dipublikasikan (opt-in).
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

### TEST CHECKLIST Phase 3
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

### FILE LAMPIRAN (Dibuat/Diupdate di Phase Ini)
```
DIBUAT/DIISI:
  lib/screens/owner/report_screen.dart
  lib/screens/owner/customer_list_screen.dart
  lib/screens/owner/employee_screen.dart

DIUPDATE:
  lib/screens/owner/owner_home_screen.dart  (IndexedStack update)
```

### PROMPT (Copy-Paste)

```
=== KASIRGO: Aplikasi kasir UMKM (Flutter mobile + Supabase + React superadmin). 3 role: Owner (full), Admin (CRUD produk), Cashier (POS only). 3 paket: Gratis (500 tx/produk+iklan), 25rb (unlimited+barcode), 50rb (WA+social commerce+QR meja). AI Co-Pilot gratis local compute. Glassmorphism: #4F46E5 #7C3AED #06B6D4. Font Inter. Offline-first: SQLite lokal sync Supabase. 13 tabel DB+RLS. ===
Clone repo [GITHUB_URL] lalu LANJUTKAN project Flutter kasirgo. Phase 1-3 selesai: DB + Auth + App shell + Produk + POS + AI. flutter pub get.
ATURAN: SETIAP selesai 1-2 file, langsung git add . && git commit -m "progress: [nama file]" && git push. JANGAN tunggu semua selesai.
SETELAH PHASE SELESAI: jalankan dev server + minta URL preview + uji live pakai klik (lihat bagian "TEST LIVE PER PHASE"). Jangan hanya bilang build sukses.
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

### TEST CHECKLIST Phase 4
- [ ] Laporan ringkasan menampilkan data akurat
- [ ] Grafik penjualan berfungsi
- [ ] Export Excel berhasil
- [ ] Laporan bank-ready menampilkan format yang benar
- [ ] Pelanggan list, tambah, detail, riwayat berfungsi
- [ ] Absensi check-in/check-out berfungsi
- [ ] History absensi tersimpan

---

## PHASE 5: Premium Features + Subscription Gate

### FILE LAMPIRAN (Dibuat/Diupdate di Phase Ini)
```
DIBUAT:
  lib/screens/owner/settings_screen.dart

DIUPDATE:
  lib/screens/owner/product_form_screen.dart   (multi-channel pricing + diskon)
  lib/screens/owner/product_list_screen.dart    (tier limits)
  lib/screens/owner/pos_screen.dart             (diskon badge)
  lib/screens/owner/owner_home_screen.dart      (notifikasi, flash sale suggest)
  lib/utils/ai_engine.dart                      (flash sale auto-suggest)

SUPABASE EDGE FUNCTION:
  supabase/functions/stock_alert/index.ts
```

### PROMPT (Copy-Paste)

```
=== KASIRGO: Aplikasi kasir UMKM (Flutter mobile + Supabase + React superadmin). 3 role: Owner (full), Admin (CRUD produk), Cashier (POS only). 3 paket: Gratis (500 tx/produk+iklan), 25rb (unlimited+barcode), 50rb (WA+social commerce+QR meja). AI Co-Pilot gratis local compute. Glassmorphism: #4F46E5 #7C3AED #06B6D4. Font Inter. Offline-first: SQLite lokal sync Supabase. 13 tabel DB+RLS. ===
Clone repo [GITHUB_URL] lalu LANJUTKAN project Flutter kasirgo. Phase 1-4 selesai: DB + Auth + App + Produk + POS + AI + Laporan. flutter pub get.
ATURAN: SETIAP selesai 1-2 file, langsung git add . && git commit -m "progress: [nama file]" && git push. JANGAN tunggu semua selesai.
SETELAH PHASE SELESAI: jalankan dev server + minta URL preview + uji live pakai klik (lihat bagian "TEST LIVE PER PHASE"). Jangan hanya bilang build sukses.
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

### TEST CHECKLIST Phase 5
- [ ] Subscription gate berfungsi (free -> basic -> pro)
- [ ] Multi-channel pricing tersimpan dan muncul di POS
- [ ] Diskon produk muncul di POS dengan badge
- [ ] Notifikasi stok menipis dan expired muncul
- [ ] Flash sale auto-suggest berfungsi
- [ ] Iklan muncul di free tier, hilang di berbayar

---

## PHASE 6: WhatsApp + Social Commerce + QR Meja + Health Score

### FILE LAMPIRAN (Dibuat/Diupdate di Phase Ini)
```
DIBUAT:
  lib/utils/wa_helper.dart
  lib/screens/owner/social_commerce_screen.dart
  lib/screens/owner/whatsapp_broadcast_screen.dart
  lib/screens/owner/qr_table_screen.dart
  lib/screens/owner/online_catalog_screen.dart
  lib/screens/owner/health_score_screen.dart
  lib/screens/customer/customer_order_screen.dart

DIUPDATE:
  lib/screens/owner/owner_home_screen.dart      (navigation tambahan)
  lib/screens/owner/report_screen.dart           (per-channel reporting)
  lib/widgets/pos/checkout_dialog.dart           (tombol kirim struk WA)
```

### PROMPT (Copy-Paste)

```
=== KASIRGO: Aplikasi kasir UMKM (Flutter mobile + Supabase + React superadmin). 3 role: Owner (full), Admin (CRUD produk), Cashier (POS only). 3 paket: Gratis (500 tx/produk+iklan), 25rb (unlimited+barcode), 50rb (WA+social commerce+QR meja). AI Co-Pilot gratis local compute. Glassmorphism: #4F46E5 #7C3AED #06B6D4. Font Inter. Offline-first: SQLite lokal sync Supabase. 13 tabel DB+RLS. ===
Clone repo [GITHUB_URL] lalu LANJUTKAN project Flutter kasirgo. Phase 1-5 selesai. flutter pub get.
ATURAN: SETIAP selesai 1-2 file, langsung git add . && git commit -m "progress: [nama file]" && git push. JANGAN tunggu semua selesai.
SETELAH PHASE SELESAI: jalankan dev server + minta URL preview + uji live pakai klik (lihat bagian "TEST LIVE PER PHASE"). Jangan hanya bilang build sukses.
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

### TEST CHECKLIST Phase 6
- [ ] Struk WhatsApp terkirim (intent terbuka)
- [ ] Broadcast promosi ke pelanggan terpilih
- [ ] Social commerce: input transaksi, stok berkurang
- [ ] QR meja: generate, scan, order muncul
- [ ] Health score dashboard akurat
- [ ] Katalog online bisa diakses

---

## PHASE 7: Superadmin Web (React.js + Cloudflare Pages)

### FILE LAMPIRAN (Dibuat di Phase Ini)
```
kasirgo-admin/
  package.json
  tsconfig.json
  vite.config.ts
  tailwind.config.js
  index.html
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
```

### PROMPT (Copy-Paste)

```
=== KASIRGO: Aplikasi kasir UMKM (Flutter mobile + Supabase + React superadmin). 3 role: Owner (full), Admin (CRUD produk), Cashier (POS only). 3 paket: Gratis (500 tx/produk+iklan), 25rb (unlimited+barcode), 50rb (WA+social commerce+QR meja). AI Co-Pilot gratis local compute. Glassmorphism: #4F46E5 #7C3AED #06B6D4. Font Inter. Offline-first: SQLite lokal sync Supabase. 13 tabel DB+RLS. ===
Clone repo [GITHUB_URL] lalu LANJUTKAN project React kasirgo-admin. Phase 1-6 selesai (Flutter app). npm install.
ATURAN: SETIAP selesai 1-2 file, langsung git add . && git commit -m "progress: [nama file]" && git push. JANGAN tunggu semua selesai.
SETELAH PHASE SELESAI: jalankan dev server + minta URL preview + uji live pakai klik (lihat bagian "TEST LIVE PER PHASE"). Jangan hanya bilang build sukses.
SETELAH CLONE: baca file AGENTS.md di root repo untuk konteks lengkap proyek, lalu update checklist Progress Tracker di sana jika ada Phase yang selesai di session ini.

Buat project React.js baru untuk superadmin dashboard KasirGo. Deploy ke Cloudflare Pages.

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
- Deploy ke Cloudflare Pages (connect repo)
- Set environment variables: VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY

PASTIKAN:
- npm run build tidak error
- Deploy ke Cloudflare Pages berhasil
- Test: login superadmin, lihat dashboard, impersonate owner, manage affiliates, backup

Laporkan hasil deploy.
```

### TEST CHECKLIST Phase 7
- [ ] Login superadmin berfungsi
- [ ] Dashboard menampilkan stats
- [ ] User list, search, filter berfungsi
- [ ] Impersonate owner berfungsi
- [ ] Affiliate CRUD berfungsi
- [ ] Backup/restore berfungsi
- [ ] Revenue dashboard akurat
- [ ] Deploy Cloudflare Pages sukses

---

## PHASE 8: Polish + Testing + Final Deploy

### FILE LAMPIRAN (Diupdate di Phase Ini)
```
FLUTTER (semua screen di-update polish):
  lib/screens/              (semua: loading/error/empty state, pull-to-refresh, animasi)
  lib/main.dart             (splash screen)
  lib/config/app_theme.dart (konsistensi glassmorphism)

REACT:
  kasirgo-admin/src/        (final polish + responsive)

BUILD:
  build/app/outputs/        (APK release)
  build/web/                (Flutter web untuk katalog)
```

### PROMPT (Copy-Paste)

```
=== KASIRGO: Aplikasi kasir UMKM (Flutter mobile + Supabase + React superadmin). 3 role: Owner (full), Admin (CRUD produk), Cashier (POS only). 3 paket: Gratis (500 tx/produk+iklan), 25rb (unlimited+barcode), 50rb (WA+social commerce+QR meja). AI Co-Pilot gratis local compute. Glassmorphism: #4F46E5 #7C3AED #06B6D4. Font Inter. Offline-first: SQLite lokal sync Supabase. 13 tabel DB+RLS. ===
Clone repo [GITHUB_URL] lalu LANJUTKAN project. Phase 1-7 selesai: Flutter app + React admin. flutter pub get && npm install.
ATURAN: SETIAP selesai 1-2 file, langsung git add . && git commit -m "progress: [nama file]" && git push. JANGAN tunggu semua selesai.
SETELAH PHASE SELESAI: jalankan dev server + minta URL preview + uji live pakai klik (lihat bagian "TEST LIVE PER PHASE"). Jangan hanya bilang build sukses.
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
   - Deploy ke Cloudflare Pages sebagai static site

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

6. CLOUDFLARE PAGES DEPLOY
   - Deploy React admin ke Cloudflare Pages
   - Deploy Flutter web katalog ke Cloudflare Pages (jika ada)

7. APK BUILD
   - flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/debug-info
   - Upload APK sebagai GitHub release

PASTIKAN:
- Tidak ada error di flutter analyze
- Tidak ada error di npm run build (React)
- Semua flow berjalan lancar
- APK release bisa diinstall dan berfungsi

Laporkan semua hasil final.
```

### TEST CHECKLIST Phase 8
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
- [ ] Cloudflare Pages deploy sukses
- [ ] APK release berfungsi, per ABI <10MB

---

## CONTEXT WINDOW RECOVERY (WAJIB TAHU)

### Tanda Kena Limit
AI mulai lupa / respon lambat / error "context window full"

### Prosedur Recovery (Compact -- pilihan utama)
Compact merangkum chat jadi ringkasan: token hemat, Phase sebelumnya tetap "diingat".
Wajib PUSH dulu supaya detail tersimpan di file (bukan cuma di ringkasan).

```
LANGKAH 1: PUSH DULU
   git add . && git commit -m "checkpoint: [fitur terakhir]" && git push

LANGKAH 2: COMPRESS
   Jalankan fitur Compact pada session yang sama.

LANGKAH 3: MEMORY CHECK (jangan skip)
   Paste: "Baca ulang AGENTS.md di root dan jalankan git log --oneline -5.
   Konfirmasi singkat: status Phase terakhir, schema, dan sisa pekerjaan.
   Jangan coding dulu."
   - Jawaban sesuai -> lanjut ke LANGKAH 4.
   - Jawaban ngawur / detail hilang -> pakai Prosedur Reset di bawah.

LANGKAH 4: LANJUT
   Paste prompt Phase yang sedang/berikutnya (yang berisi "baca AGENTS.md").
```

### Prosedur Reset (fallback kalau Compact bermasalah)
```
LANGKAH 1: PUSH DULU
   git add . && git commit -m "checkpoint: [fitur terakhir]" && git push

LANGKAH 2: RESET
   Tutup session, buka session BARU (atau tombol Reset di tool).

LANGKAH 3: PASTE PROMPT PHASE YANG SAMA
   AI clone repo, baca AGENTS.md + git log, lalu LANJUT dari commit terakhir.

LANGKAH 4: VERIFIKASI
   Katakan: "Lanjutkan dari commit terakhir. Cek git log."
```

### Kapan Compact vs Reset
| Situasi | Tindakan |
|---------|----------|
| Ganti Phase / mulai fitur baru | Push -> Compact -> memory check (Reset kalau ngawur) |
| Debug 1 bug kecil (progress belum bisa push) | Compact, selesaikan, push |
| AI mulai lupa / ngawur / error sama >3x | Push + Reset |
| Baru push 1-2 file, masih banyak kerjaan | Lanjutkan (belum penuh) |
| Sudah 10+ file push dalam 1 session | Pertimbangkan Compact |

---

## HEMAT TOKEN (WAJIB)

Context window terbatas. Ikuti aturan ini supaya tidak cepat penuh:

1. **Push tiap 1-2 file**, bukan tiap 5-10 file.
2. **Jangan minta AI baca file yang tidak relevan** ke task saat ini.
3. **Satu task per pesan.** Jangan gabung banyak perintah dalam 1 pesan.
4. **Jangan bolak-balik revisi file yang sama** berulang kali dalam 1 session.
5. **Kalau error sama kena >3x -> push + RESET.** Jangan debug terus-menerus.
6. **Jangan paste output panjang** (log build besar, dump file) ke chat kalau tidak perlu.
7. **AGENTS.md sudah merangkum konteks.** Tidak perlu cerita ulang proyek dari awal.
8. **Ganti Phase = push -> Compact -> memory check.** Token hemat & Phase lama tetap diingat. Reset hanya kalau hasil Compact ngawur.

---

## TOOLS PER PHASE

| Phase | Tools | Perintah Install |
|-------|-------|-----------------|
| 1 | Supabase Dashboard (web) | - |
| 2 | Flutter SDK | `flutter pub get` |
| 3 | Flutter SDK | `flutter pub get` |
| 4 | Flutter SDK | `flutter pub get` |
| 5 | Flutter SDK + Supabase Dashboard | `flutter pub get` |
| 6 | Flutter SDK | `flutter pub get` |
| 7 | Node.js + npm | `npm install` |
| 8 | Flutter SDK + Node.js | `flutter pub get && npm install` |

---

## TEST LIVE PER PHASE (SETIAP PHASE SELESAI)

Setelah phase selesai: **jalankan dev server -> minta URL preview -> uji pakai klik -> laporkan hasilnya.** Jangan hanya bilang "build sukses".

### Cara Jalankan Live Test

**Flutter (Phase 2-6, 8):**
```
flutter run -d web-server --web-renderer html --web-hostname 0.0.0.0 --web-port 8080
```
Lalu minta URL preview untuk port 8080 (gunakan tool preview/deploy bawaan).

**React admin (Phase 7-8):**
```
npm run dev
```
Lalu minta URL preview untuk port yang muncul (biasanya 5173).

### Yang Diuji Live per Phase

| Phase | Yang diuji live di web preview |
|-------|-------------------------------|
| 1 | Tidak ada app. Cek di Supabase Dashboard: 13 tabel, RLS, trigger jalan |
| 2 | Login/register, redirect per role, navigasi tab, sync online, tampilan glassmorphism |
| 3 | Tambah produk, POS (pilih produk -> cart -> checkout), QRIS tampil, stok berkurang, AI insight card |
| 4 | Laporan (grafik, filter), export Excel, tambah pelanggan, absensi check-in/out |
| 5 | Upgrade tier, multi-channel pricing, diskon di POS, notifikasi, banner iklan free tier |
| 6 | Kirim struk WA, social commerce input, generate QR meja, health score, katalog online |
| 7 | Login superadmin, dashboard stats, user list, impersonate, affiliate, backup, revenue |
| 8 | Full flow end-to-end semua role + offline + upgrade |

### Catatan Penting

- **Fitur native TIDAK jalan di web:** kamera (scan barcode/foto), SQLite drift, image_picker. Untuk fitur ini, build APK: `flutter build apk --debug` -> install ke HP -> uji manual.
- **Yang bisa diuji di web:** UI, navigasi, auth, CRUD Supabase, chart, POS, laporan, WhatsApp intent.
- **Kalau preview blank:** pastikan pakai `--web-renderer html` (bukan CanvasKit).
- **Laporkan ke user:** URL preview + apa saja yang sudah diklik/diuji + error kalau ada.

---

## DOKUMEN REFERENSI (di folder docs/)

| File | Isi |
|------|-----|
| `KASIRGO-WORKFLOW-LENGKAP.md` | DOKUMEN INI -- prompt lengkap + lampiran file per phase |
| `STRATEGI-KASIRGO.md` | Strategi induk: visi, segmentasi, monetisasi, roadmap |
| `PRD-KasirGo.md` | Product Requirements Document |
| `superpowers/specs/2026-09-08-ui-ux-design.md` | Design system (warna, font, komponen, layout) |
| `superpowers/specs/2026-09-08-pos-app-design.md` | POS design spec |
| `superpowers/plans/2026-09-08-kasirgo-implementation.md` | Implementation plan detail per task |