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
- ST10-2: Hyperlocal data report (agregat anonim per wilayah + consent
  UU PDP).
