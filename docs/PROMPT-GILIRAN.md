# KASIRGO - PROMPT GILIRAN (siap tempel)

Dokumen ini berisi prompt siap-tempel untuk memulai tiap sub-task. Ganti isi
bagian "PHASE AKTIF" setiap ganti phase.

## Status ringkas

- Phase 1 s.d. Phase 13B: SELESAI.
- Phase 13C (Superadmin kelola Payment Gateway + uji sandbox + go-live): DALAM PROSES.
  - ST13C-1 SELESAI: RPC `admin_list_outlet_pg_configs` / `admin_set_outlet_pg_status`
    + tabel "Status Payment Gateway per Outlet" di Control Plane; EF
    `test_payment_connection` izinkan superadmin; EF `create_payment` blok `disabled`.
  - ST13C-2 SELESAI: E2E sandbox Warung Test lulus semua (tes koneksi, charge QRIS
    dinamis, webhook settlement -> PAID, idempotent, signature salah 401, alur POS
    transaksi unpaid -> paid).
  - ST13C-3 (go-live + audit keamanan) menyusul.
- Phase 13A (QRIS Dinamis Midtrans, zero-custody): SELESAI.
- Phase 13B (Retrofit app ke Midtrans): SELESAI (ST13B-1 `3b6765a`, ST13B-3 `6cddb0a`).
- Blocker eksternal: channel QRIS akun Midtrans production belum aktif
  (`402 Payment channel is not activated`) -> charge QRIS nyata belum menghasilkan
  `qr_string`. Alur webhook -> PAID sudah terbukti lulus. Aksi user: aktifkan QRIS
  di dashboard Midtrans.

## Prompt pembuka (tempel di awal sesi)

```text
=== KASIRGO super-app kasir UMKM (Flutter + Supabase + React admin).
Baca HANYA docs/PROMPT-GILIRAN.md + AGENTS.md. Jangan install/pub get/build APK.
Design System v2 "Centennial Modern Ocean White": token di config/app_theme.dart,
DILARANG hardcode warna/font. Testing: flutter build web --release --base-href /kasirgo/
lalu serve build/web (JANGAN flutter run -d web-server, JANGAN build APK di sandbox).
1 sub-task = 1 commit + push main & gh-pages. Migrasi di docs/migrations/ (root).
Server Key Midtrans TIDAK PERNAH di klien (zero-custody, hanya EF + Vault).
Selesai 1 sub-task: git add . && git commit && git push, lalu STOP dan lapor singkat.
===
```

## Phase 13B (SELESAI) - ringkas untuk konteks

- ST13B-1 `3b6765a`: `payment_service.dart` -> `PgProviderClient` + `MidtransProvider`.
- ST13B-2 (dalam `3b6765a`): `checkout_dialog.dart` render QR asli + polling status.
- ST13B-3 `6cddb0a`: wizard `midtrans_connect_screen.dart` + Tes Koneksi.
- Gating QRIS dinamis via `hasFeature('payment_gateway')`; QRIS statis gratis.

## Aturan berhenti

Kerjakan HANYA phase aktif. Setelah DoD: commit + push, lapor ringkas, BERHENTI.
JANGAN mulai phase berikutnya sampai user mengetik "lanjut".
