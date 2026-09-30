# PROGRESS PHASE 11 — Superadmin Web: Revenue Engine, RBAC, Control Plane, Monitoring

Roadmap: docs/KASIRGO-WORKFLOW-LENGKAP.md Bagian PHASE 11 (ST11-1..ST11-4).
Migrasi: docs/migrations/2026-10-01-kasirgo-11.sql (idempotent).
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
