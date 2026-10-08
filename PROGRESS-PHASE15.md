# PROGRESS PHASE 15 - Master Prompt Karakter & Skill + 12 Fitur Bos Virtual

STATUS: 15A (ST15-1) + 15B (ST15-2) + 15C (ST15-3) SELESAI. Berikutnya ST15-4 (15D Addendum L-O).
Sumber spec: `KASIRGO-WORKFLOW-LENGKAP.md` BAGIAN 13 (13.23-13.26) + BAGIAN 14.3.

## Prinsip (WAJIB)
- Phase 15 = lanjutan Dokter Bisnis AI (Phase 14 tetap ST14-1..12).
- Semua modul baru = Program Pendukung (gate Pendukung), ikuti Design System v2.
- Kunci provider (base_url/api_key/model) HANYA di superadmin. Tidak ubah fitur/skema lama.
- 1 sub-task = 1 commit + push, lalu STOP.

## Subtask

### ST15-1 (15A) Master Prompt Karakter & Skill - SELESAI
- Migrasi `docs/migrations/2026-10-15-kasirgo-15a-master-prompt-skills.sql` (DITERAPKAN):
  - `platform_configs.business_doctor` di-merge (nilai lama dipertahankan):
    - `prompt_utama` = teks BAGIAN 13.23 I (master prompt) + II (addendum A-O) apa adanya.
    - `prompt_utama_default` = salinan teks di atas (untuk tombol Reset ke Default).
    - `skills[]` = [chat, snapshot, trend, low_stock, slow_products, cashflow, memory,
      internet, target, scaling, market_intel, cross_sell, bundling, referral,
      reprimand, weekly_report].
  - `provider_default` (base_url/api_key/model/temperature/max_tokens), role_outlet,
    guardrails, internet_tool, rate_limit DIPERTAHANKAN (ON CONFLICT DO UPDATE value || patch).
- EF `business_doctor_chat` (REDEPLOYED):
  - `SKILL_TOOLS` peta skill -> tool; `toolAllowed()` + `skillList()`; `toolsFor(internetActive, skills)`
    hanya mengirim tool sesuai skill terpilih (kosong = semua aktif, kompatibilitas).
  - System context menyuntik "SKILL AKTIF: ..." agar AI tidak menjanjikan fitur di luar daftar.
  - Tool loop dinaikkan maks 2 -> 3 putaran (master prompt panjang + model reasoning).
- kasirgo-admin `ControlPlane.tsx` `DoctorTab`: field "Master Prompt Karakter & Skill"
  (textarea multi-line + tombol Preview + Reset ke Default) + toggle "Daftar Skill" (chip 16 skill).

### ST15-2 (15B) Bos Virtual Analitik - SELESAI
- Migrasi `docs/migrations/2026-10-18-kasirgo-15b-bos-virtual-analitik.sql` (DITERAPKAN):
  - `outlet_targets`: id, outlet_id, period (day/month), target_amount, set_by (ai/owner),
    source, note, effective_from, UNIQUE (outlet_id, period, effective_from). RLS owner + superadmin.
  - `doctor_scaling_plans`: id, outlet_id, conversation_id, goal, readiness (jsonb),
    roadmap (jsonb 30/60/90), status (open/on_track/achieved/cancelled). RLS owner + superadmin.
  - `web_cache`: id, url (unique), content, source_label, fetched_at, ttl_seconds. RLS service_role/superadmin.
- Edge Function `business_doctor_chat` (REDEPLOYED):
  - Tool baru `get_targets`: baca target aktif outlet + capaian hari ini / bulan ini dari `transactions`.
  - Tool baru `save_target`: simpan usulan target harian/bulanan (sink action progress_tracker).
  - Tool baru `save_scaling_plan`: simpan roadmap 30/60/90 hari ekspansi (sink card).
  - `fetch_url` diperbarui: cek cache `web_cache` sebelum fetch eksternal (TTL 3600 detik).
  - `SKILL_TOOLS`: target -> get_targets, save_target; scaling -> save_scaling_plan; internet -> fetch_url.
- App Owner:
  - `business_doctor_service.dart`: method `getTargets`, `saveTarget`, `getScalingPlans`, `updateScalingPlanStatus`, `getMarketIntel`.
  - Layar baru `screens/owner/doctor_scaling_screen.dart`: daftar scaling plans aktif,
    tujuan, status chips, checklist kesiapan usaha, roadmap tahapan H-30/60/90, CTA konsultasi.
  - `owner_home_screen.dart`:
    - Widget `_TargetProgressCard`: progress bar capaian vs target omzet, Pace Alert bila jam >= 14:00 & progress < 50%, CTA konsultasi.
    - Widget `_MarketIntelCard`: kartu intelijen pasar terbaru + tanggal + tombol "Terapkan ke Harga".
    - Quick Actions: ditambah item "Peta Ekspansi" (Scaling 30/60/90) mengarah ke `DoctorScalingScreen`.
- Verifikasi E2E:
  - Chat Warung Test simpan target Rp 150.000/hari -> baris tersimpan di `outlet_targets`.
  - Chat Warung Test simpan scaling plan buka cabang 90 hari -> baris tersimpan di `doctor_scaling_plans`.
  - `dart analyze` bersih (0 error). Web release built & deployed.

- Verifikasi: config live `skills` terisi, `provider_default` tetap (model deepseek-4.1-flash);
  EF chat superadmin -> `fallback:false`, phase B, jawaban nyata; admin build EXIT 0.

### ST14-6 (lanjutan) Layar HASIL Diagnosa penuh (BAGIAN 13.21A) - SELESAI
- Layar baru `kasirgo/lib/screens/owner/doctor_result_screen.dart`: header + tanggal,
  gauge Skor Kesehatan Usaha (animasi TweenAnimationBuilder, warna hijau/kuning/merah),
  kartu VONIS berwarna, Peta Resep (checklist bernomor + tombol Kerjakan/Check),
  target & timeline, footer "Mulai Jalankan"/"Simpan-Dibagikan"/"Tanya Dokter". Ramah gaptek.
  (Animasi pakai widget bawaan Flutter; `flutter_animate` TIDAK terpasang & tak boleh install.)
- EF `business_doctor_chat` (REDEPLOYED): blok `prescription` + `verdict`, `verdict_body`,
  `score` (0-100), `score_hint`; param tool `save_prescription` diperluas.
- `business_doctor_screen.dart`: tombol "Lihat Hasil Diagnosa" di bawah kartu resep ->
  `_openResult()` membuka `DoctorResultScreen`.
- Teruji E2E: blok prescription berisi score/verdict/verdict_body; `dart analyze` 2 file bersih.

## Penutup celah Phase 14 (unlimited token + token_quota) - SELESAIST14-1..12 sudah selesai, namun field `unlimited_tokens` + `token_quota` belum ada:
- Migrasi `docs/migrations/2026-10-16-kasirgo-14d-unlimited-token-quota.sql` (DITERAPKAN):
  `ALTER TABLE outlet_ai_configs ADD unlimited_tokens bool default false, token_quota int`;
  RPC list/set diperbarui menyertakan field.
- EF `business_doctor_chat` (REDEPLOYED): kuota per outlet - bila unlimited ON tidak diblokir;
  bila OFF pakai `token_quota` (null -> global tokens_per_day); pemakaian tetap dicatat.
- Admin `DoctorTab` override: toggle "Unlimited token" + input "Kuota Token / Hari" + kolom "Kuota".
- Verifikasi E2E: list memuat field; unlimited ON -> owner token 255649>200000 tidak diblokir;
  token_quota=10 -> diblokir; cleanup override uji; admin build EXIT 0.

### ST15-2 (15B) Bos Virtual Analitik - SELESAI
(Lihat detail di bagian "ST15-2 (15B) Bos Virtual Analitik - SELESAI" di atas.)

### ST15-3 (15C) Bos Virtual Growth - SELESAI
- Migrasi `docs/migrations/2026-10-19-kasirgo-15c-bos-virtual-growth.sql` (DITERAPKAN):
  - `product_bundles` (nama, bundle_price, original_price, is_active) + `product_bundle_items`
    (bundle_id, product_id, quantity). RLS owner/superadmin.
  - `referral_codes` (code unik, reward_amount pembawa, friend_reward_amount teman, min_spend,
    max_redemptions, redeemed_count, is_active) + `customer_referrals` (status pending/converted/
    rewarded, spend_amount, transaction_id). RLS owner/superadmin.
  - RPC `increment_referral_redeemed(code_id)`; RPC publik `get_public_bundles(outlet)` untuk katalog anon.
- Edge Function `business_doctor_chat` (REDEPLOYED):
  - Tool `get_cross_sell` (association rule dari 200 transaksi: support/confidence/lift),
    `save_bundle` (resolve produk by nama/ID + hitung original_price + sink card),
    `save_referral` (kode berjenjang + sink card). SKILL_TOOLS: cross_sell/bundling/referral.
  - Helper `crossSellRules()` di EF; action_key enum + prompt ditambah `referral`.
- App Flutter:
  - `utils/ai_engine.dart`: metode baru `crossSellRules(baskets, minSupport, topN)` (association rule).
  - `services/growth_service.dart` (BARU): CRUD bundle, referral code, tracking konversi + stats.
  - `screens/owner/bundle_manager_screen.dart` (BARU): manajer bundling (buat/ubah/hapus/aktifkan,
    pemilihan produk multi-qty, tampil harga normal vs paket + hemat).
  - `screens/owner/referral_screen.dart` (BARU): kode referral berjenjang, ringkasan konversi,
    toggle aktif, bagikan via wa.me.
  - `screens/owner/pos_screen.dart`: strip bundling + chip saran cross-sell; bundling dijual 1 item
    (productId `bundle:<id>`); tap chip menambah produk saran ke keranjang.
  - `screens/owner/owner_home_screen.dart`: kartu "Peluang Cross-Sell" (AIEngine) + shortcut
    "Paket Bundling" & "Referral" di Quick Actions.
  - `screens/owner/business_doctor_screen.dart`: aksi resep bundling/cross_sell -> BundleManagerScreen,
    referral -> ReferralScreen (di-gate Pendukung).
  - `screens/customer/customer_catalog_screen.dart`: strip "Paket Hemat" dari RPC `get_public_bundles`,
    pesan paket via WA.
  - `services/supabase_service.dart`: `getPublicBundles(outletId)`.
- Verifikasi E2E (chat Warung Test):
  - `get_cross_sell` mengembalikan aturan (kosong wajar karena outlet uji tanpa transaksi).
  - `save_referral` -> baris `referral_codes` (HEMAT10, reward 5000/3000) tersimpan.
  - `save_bundle` -> `product_bundles` Sembako Hemat (harga 28000, original 31000, 2 item) tersimpan.
  - `dart analyze` file baru bersih (0 error). Web release built & deployed.

### ST15-4 (15D) Perilaku Addendum + Hardening
- Cross-Selling (chip POS + kartu Peluang Cross-Sell), Bundling (manajer + 1 item POS),
  Referral (kode/kupon + tracking + wa.me).

### ST15-4 (15D) Perilaku Addendum + Hardening
- Laporan Mingguan Proaktif (L), Guardrail Aksi Otomatis/persetujuan (M),
  Benchmark Hyperlocal (N), Kartu Identitas Bisnis (O), uji end-to-end + tracker + dokumen.

## CATATAN
- Cron `doctor_observe`/`doctor_reprimand` (13.15/13.21B) ditunda: ekstensi `pg_cron`/`pg_net`
  TIDAK terpasang di DB live (hanya `pgcrypto`).
- Rate limit owner default 60 pesan / 200000 token per hari (superadmin dikecualikan).
