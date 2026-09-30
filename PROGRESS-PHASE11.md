# PROGRESS PHASE 11 — Superadmin Web: Revenue Engine, RBAC, Control Plane, Monitoring

**STATUS PHASE 11: SELESAI (ST11-1..ST11-4).** BERIKUTNYA: Phase 12 (Polish +
Security Audit + Release).

Roadmap: docs/KASIRGO-WORKFLOW-LENGKAP.md Bagian PHASE 11 (ST11-1..ST11-4).
Migrasi: docs/migrations/2026-10-01-kasirgo-11.sql (idempotent; bagian 2-4
**perlu dijalankan ke live** via SQL Editor — access token tidak tersedia
saat pengembangan; bagian 1 sudah live).
Admin: kasirgo-admin (React+Vite, Ocean White tokens), semua data via RPC
SECURITY DEFINER ber-flag admin (admin_users aktif); secret TIDAK dibaca client.

## SELESAI

### ST11-1 — Dashboard 12 Revenue Engine + Supporters + User Management (2026-09-30)
- DB (bagian 1 kasirgo-11.sql) — RAN live:
  - `platform_is_admin()` — cek admin_users aktif (basis semua RPC admin).
  - `platform_revenue_series(p_days, p_granularity)` — series 12 engine
    (pendukung, ppob_margin, restock_b2b, affiliate, fintech, insurance,
    qris_margin, ads, sponsored_receipt, storage, hyperlocal, other)
    per hari/bulan; sumber: supporters, ppob_transactions.profit,
    restock_orders.commission, insurance_leads.commission, billing_events.
  - `platform_supporters_summary()` — active/trial/MRR/revenue_30d/expired.
  - `platform_users_list(p_search, p_tier, p_status, p_limit, p_offset)` —
    FILTER SERVER-SIDE (search nama/email/outlet; tier supporter/trial/free;
    status kyc/paid) + total + pagination (max 100/halaman). Join
    auth.users x outlets x entitlements x outlet_kyc x supporters.
  - `platform_user_detail(p_user_id)` — user + outlet + kyc +
    entitlements + subscription + stats (tx/omzet 30 hari, produk,
    staf) + 5 transaksi terakhir + rekap lead.
  - QA (sebagai superadmin): series 372 baris (31 hari x 12 engine),
    users total 4, detail outlet "Toko Test" benar.
- kasirgo-admin:
  - `src/lib/adminApi.ts` (baru): helper RPC + format Rp/tanggal +
    daftar 12 engine berwarna + `checkAdminRole()` (untuk RBAC ST11-4).
  - `Dashboard.tsx` REWRITE (hapus mock): 4 kartu metrik real (users,
    outlets, pendapatan periode, MRR pendukung); grafik 12 revenue engine
    stacked (BarChart recharts) + toggle Harian(30d)/Bulanan(6bln);
    total per engine; section Program Pendukung (aktif/trial/MRR/30d);
    partner leads (fintech + asuransi, dari platform_revenue_summary);
    daftar outlet terbaru dengan badge KYC/bayar. Token Ocean White.
  - `Users.tsx` REWRITE (hapus mockUsers): daftar REAL via RPC, search
    (debounce 300ms) + filter tier + status KYC/pembayaran, pagination,
    badge tier & KYC; aksi = lihat detail (tombol tambah/edit/hapus
    dihapus karena tidak mungkin via anon key).
  - `UserDetail.tsx` REWRITE (hapus userDirectory mock): data nyata via
    platform_user_detail (outlet, KYC badge, status pembayaran/ad-free,
    5 stat, transaksi terakhir, rekap lead).
- npm run build BERSIH (tsc -b + vite, hanya warning chunk size).

### ST11-2 — Impersonate Read-Only + Audit + Backup/Restore + Intelijen Platform (2026-09-30)
- DB (bagian 2 kasirgo-11.sql) — **BELUM DIJALANKAN ke live** (access token
  tidak tersedia di sesi ini; jalankan seluruh file via SQL Editor, idempotent):
  - Tabel: `backup_runs` (snapshot JSONB + kind full/quick + RLS admin),
    `backup_schedules` (per outlet, cadence daily/weekly, RLS admin).
  - RPC (semua SECURITY DEFINER + cek platform_is_admin + jejak audit via
    `log_admin_action()` yang sudah ada):
    - `platform_impersonate_view(p_user_id)` — snapshot read-only outlet
      (ringkasan hari/30 hari, 7 hari terakhir, produk terlaris, 10 TX
      terakhir, staf) + audit `impersonate_view`.
    - `platform_audit_list(p_limit, p_offset)` — baca audit_logs + email aktor.
    - `platform_backup_create(p_outlet_id, p_kind)` — full = master data +
      transaksi 90 hari + items; quick = master data saja.
    - `platform_backup_list()` — tanpa payload; `platform_backup_get(p_id)`
      — payload utk unduh (audit `backup_download`).
    - `platform_backup_restore(p_id)` — ISI HANYA baris hilang (ON CONFLICT
      DO NOTHING): produk/varian/pelanggan; transaksi TIDAK dipulihkan agar
      keuangan tidak dobel; kolom sesuai docs/kasirgo-schema.sql
      (products TANPA sku/is_active; customers pakai `phone_wa`).
    - `platform_backup_schedule_set(...)` + `platform_backup_run_due()` —
      backup terjadwal tanpa cron (dipicu client saat halaman dibuka).
    - `platform_intelligence()` — KPI platform, tren harian 30d, outlet
      aktif per minggu, churn risk (>=3 TX lalu idle >14 hari), anomali
      z-score > 2.5; agregat tanpa data pribadi.
- kasirgo-admin:
  - `Backup.tsx` REWRITE: pilih outlet + tipe (cepat/penuh), riwayat
    snapshot real, unduh JSON, pulihkan (konfirmasi), jadwal per outlet,
    auto `run_due` saat halaman dibuka.
  - `UserDetail.tsx`: tombol **Impersonate (Read-Only)** -> modal snapshot
    (KPI, 7 hari, produk terlaris, TX terakhir, staf).
  - `Audit.tsx` BARU (route /audit): jejak audit terpaginasi + badge warna
    per aksi.
  - `Intelligence.tsx` BARU (route /intelligence): KPI, LineChart transaksi
    harian, churn risk, anomali, retensi mingguan (recharts).
  - Sidebar + judul halaman + routing diperbarui.
- npm run build BERSIH.
- QA live PENDING (setelah SQL dijalankan): panggil tiap RPC sebagai
  superadmin; verifikasi audit muncul di /audit; buat backup -> unduh ->
  restore di outlet test.

### ST11-3 — Control Plane: Inheritance Global->Segment->Outlet + Versi & Rollback (2026-09-30)
- DB (bagian 3 kasirgo-11.sql) — **BELUM DIJALANKAN ke live** (sama dgn ST11-2):
  - Tabel `platform_config_history` (config_key, scope, scope_ref, version,
    value, changed_by, note) + RLS admin + index.
  - RPC:
    - `platform_config_save(p_key, p_scope, p_scope_ref, p_value, p_note)` —
      upsert platform_configs dengan version+1 + updated_by + 1 baris
      riwayat + audit (menggantikan update langsung client).
    - `platform_config_effective(p_key, p_outlet_id)` — resolusi
      Outlet > Segment > Global (segment terbaru menang bila >1).
    - `platform_config_versions(...)` + `platform_config_rollback(...)`
      (rollback = simpan nilai lama sebagai versi baru, ter-audit).
    - `platform_segment_list/upsert/delete/set_outlets` — CRUD segment
      (basis rollout ST11-4).
- kasirgo-admin:
  - `controlPlane.ts`: `saveConfig()` kini via RPC platform_config_save
    (semua tab config otomatis dapat version+1, updated_by, riwayat, audit).
  - `ControlPlane.tsx`: tab baru **"Override & Riwayat"** — pilih config
    (ads/guide/report/kyc/quota/flags/billing) + scope (global/segment/
    outlet) + editor JSON + preview nilai efektif per outlet (menampilkan
    sumber outlet/segment/global) + riwayat versi dgn tombol Rollback.
- npm run build BERSIH.
- QA live PENDING (setelah SQL dijalankan): simpan override outlet ->
  platform_config_effective mengembalikan source=outlet; rollback versi.

### ST11-4 — RBAC + Route Guard, Announcements, Monitoring, Rules Engine, Feature Flags Rollout (2026-09-30)
- DB (bagian 4 kasirgo-11.sql) — **BELUM DIJALANKAN ke live**:
  - RBAC: `platform_admin_list/upsert/set_active` (role superadmin/finance/
    support/ops; email dicari di auth.users).
  - Announcements: `platform_announcement_list/upsert/delete`.
  - `platform_monitoring()` — outlet aktif, pendukung pending verifikasi,
    PPOB gagal/pending 24 jam, transaksi sync macet, backup jatuh tempo,
    rules/flags aktif, error audit terakhir.
  - `platform_rules_run()` — rules engine dasar: metrik (tx_today_total,
    ppob_failed_24h, pending_supporters, idle_outlets_14d) dengan op
    gte/lte + trigger churn_idle_days; hasil MATCH tercatat di audit.
  - `feature_flags_for_outlet(p_outlet_id)` — evaluasi SERVER-SIDE:
    enabled + rollout_pct (hash deterministik outlet_id) + outlet_types +
    segments membership.
- Flutter (staged rollout diterapkan ke app):
  - `module_registry.dart`: `loadFlagsForOutlet(outletId)` via RPC dengan
    fallback select langsung + rollout hash lokal saat offline; cache TTL
    5 menit per outlet; `effectiveModules(outletType, flags:)`.
  - `module_provider.dart`: `outletFlagsProvider` (family per outlet);
    `activeModulesProvider` memakai flags per outlet (fallback default).
  - `flutter analyze` penuh: 21 issues = baseline lama (0 baru).
- kasirgo-admin:
  - Route guard RBAC (`RoleGuard` per route) + sidebar difilter per role
    (superadmin semua; finance=revenue/intelligence; support=users/backup;
    ops=users/control-plane); footer sidebar menampilkan role.
  - ControlPlane tab baru: **Pengumuman** (CRUD + aktif/nonaktif),
    **Monitoring** (KPI kesehatan + tombol "Jalankan Rules" + hasil match),
    **Admin & RBAC** (tambah/update admin by email, ubah role, aktif/nonaktif).
- npm run build BERSIH (tsc + vite).
- QA live PENDING (setelah SQL dijalankan): login superadmin -> semua menu;
  buat admin role=finance -> login -> menu terbatas + route lain ditolak;
  ubah feature_flags rollout_pct=50 -> app dua outlet berbeda hasil beda
  (deterministik); aktifkan announcement -> muncul di app sesuai audiens.

## QA Manual Phase 11 (setelah menjalankan bagian 2-4 SQL)
1. Jalankan `docs/migrations/2026-10-01-kasirgo-11.sql` penuh di SQL Editor
   (idempotent — bagian 1 aman dijalankan ulang).
2. Login superadmin di /kasirgo/admin/ -> Dashboard 12 engine, Users, Audit,
   Intelligence, Backup, Control Plane (11 tab).
3. UserDetail -> Impersonate -> modal snapshot + entri audit "impersonate_view".
4. Backup: buat quick backup -> unduh JSON -> restore (konfirmasi).
5. Override & Riwayat: simpan override outlet -> preview efektif
   source=outlet -> rollback versi.
6. Admin & RBAC: tambah admin role lain -> login akun itu -> menu + route
   sesuai role.
7. Flutter: ubah feature_flags (enabled/rollout_pct/outlet_types) -> buka app
   (modul ikut dalam <= 5 menit TTL) TANPA rebuild.

## BERIKUTNYA: Phase 12 — Polish + Security Audit + Release
- Security audit: RLS review semua tabel, secret scan, rate limit Edge
  Functions, proguard, permission manifest.
- Polish: empty state, error state, onboarding, panduan in-app final.
- Release: APK release split-per-abi <10MB, deploy gh-pages app + admin,
  tag rilis, catatan rilis.
