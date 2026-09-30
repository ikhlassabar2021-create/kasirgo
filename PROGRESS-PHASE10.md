# PROGRESS PHASE 10 — Fintech Lead + Hyperlocal Data + Micro-insurance

Roadmap: docs/KASIRGO-WORKFLOW-LENGKAP.md Bagian PHASE 10 (ST10-1..ST10-3).
Kontrol: link partner / komisi via platform_configs (superadmin, tanpa ubah koding).
Migrasi: docs/migrations/2026-10-01-kasirgo-10.sql (idempotent).

## SELESAI

### ST10-1 — Fintech Lead: Modal Usaha (2026-09-30)
- DB (bagian 1 kasirgo-10.sql) — RAN live:
  - `fintech_leads`: outlet_id, user_id, partner, amount_requested,
    tenor_months, status lead|apply|approved|rejected|cancelled, ref,
    eligibility_score, payload jsonb (AGREGAT ANONIM), note.
  - RLS: Owner FULL; staf read + insert; index (outlet+created, status).
  - Config `platform_configs('fintech_partner', global)`: enabled=true,
    partner_name, apply_url='', wa_number='' (fallback manual wa.me).
- `lib/services/fintech_service.dart` (baru):
  - `computeCashFlow()` — skor kelayakan LOKAL dari transaksi 90 hari:
    volume (60%) + konsistensi (40%), plafon indikatif = 30% omzet bulanan
    x faktor konsistensi, clamp Rp500rb-20jt, bulat 50rb.
  - `CashFlowProfile.toPayload()` — hanya agregat (tx_count, monthly_omzet,
    avg_basket, active_months, consistency, score) TANPA PII pelanggan.
  - `submitLead()` (status apply + ref FIN-<tanggal>), `getLeads()`,
    `buildWaLink()` fallback manual, `loadConfig()`.
- `lib/screens/owner/fintech_screen.dart` (baru): kartu estimasi plafon +
  skor bar + mini-stats; dialog Ajukan (jumlah default plafon, tenor
  3/6/12) -> lead tercatat -> buka channel partner (link/URL atau wa.me);
  riwayat pengajuan + badge status; catatan privasi UU PDP.
- Kartu "Modal Usaha" di owner home, gated config `fintechEnabledProvider`.
- QA DB: insert lead (ref FIN-QA-0001, payload anonim) OK via RLS owner;
  config enabled=true; data QA dibersihkan.

### Cara uji ST10-1
1. Owner: kartu "Modal Usaha" -> lihat estimasi plafon + skor dari
   transaksi 90 hari -> "Ajukan Modal" -> lead muncul di riwayat
   (status APPLY) -> WA/link partner terbuka bila sudah diatur superadmin.
2. Superadmin: platform_configs('fintech_partner') set apply_url / wa_number
   -> channel pengajuan berubah tanpa update APK.

## BERIKUTNYA
- ST10-3: Micro-insurance toko (produk asuransi dari config, ajukan
  polis, riwayat + komisi).

### ST10-2 — Hyperlocal Data Report (2026-09-30)
- DB (bagian 2 kasirgo-10.sql) — RAN live:
  - `hyperlocal_reports`: outlet_id, region, period (YYYY-MM), payload
    jsonb, is_anonymous=TRUE (dipaksa), created_at.
  - RLS: SELECT semua authenticated (data sudah anonim-teragregasi);
    INSERT hanya owner outlet sendiri + wajib is_anonymous=TRUE.
  - RPC `hyperlocal_submit(p_outlet, p_region, p_period, p_payload)`
    (SECURITY DEFINER: validasi ownership + periode, paksa anonim).
  - Index (region+period, outlet+created). Config `hyperlocal` (enabled).
- `lib/services/hyperlocal_service.dart` (baru):
  - Consent opt-in owner (SharedPreferences per outlet, UU PDP).
  - `buildAggregate()` — dari transaksi bulan berjalan: tx_count,
    total_omzet, avg_basket, busy_hours (histogram jam), top_products /
    top_products_omzet — TANPA PII pelanggan.
  - `submit()` via RPC; `getRegionInsights()` — gabung laporan anonim
    region periode terbaru (jumlah toko peserta, rata-rata belanja,
    jam ramai gabungan, produk terlaris wilayah).
- `lib/screens/owner/hyperlocal_screen.dart` (baru): kartu consent
  (switch + dialog persetujuan UU PDP), form wilayah + tombol kirim
  (hanya saat consent), kartu insight wilayah (tren, jam ramai,
  produk terlaris, jumlah toko anonim).
- Kartu "Tren Wilayah" di owner home, gated `hyperlocalEnabledProvider`.
- QA DB: submit via RPC OK (is_anonymous=true tersimpan); submit untuk
  outlet lain -> exception forbidden; data QA dibersihkan.

### Cara uji ST10-2
1. Owner: kartu "Tren Wilayah" -> aktifkan izin (dialog persetujuan) ->
   isi wilayah -> "Kirim Laporan Bulan Ini" -> insight wilayah tampil
   (saat toko lain di region sama ikut kirim, angka tergabung).
2. Privasi: matikan switch -> data berhenti dikirim; DB hanya menyimpan
   payload agregat (is_anonymous=true, tanpa PII).

## BERIKUTNYA (lanjutan)
- ST10-3: Micro-insurance toko.
