# PROGRESS PHASE 15 - Master Prompt Karakter & Skill + 12 Fitur Bos Virtual

STATUS: 15A (ST15-1) SELESAI. Berikutnya ST15-2 (15B Bos Virtual Analitik).
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
- Verifikasi: config live `skills` terisi, `provider_default` tetap (model deepseek-4.1-flash);
  EF chat superadmin -> `fallback:false`, phase B, jawaban nyata; admin build EXIT 0.

### ST15-2 (15B) Bos Virtual Analitik - BERIKUTNYA
- Migration `outlet_targets`, `doctor_scaling_plans` (+ RLS outlet sendiri); skill target/scaling/market_intel.
- Konsultasi Target (tool get_targets/save_target + kartu Target & Progress + pace alert).
- Business Scaling (checklist kesiapan + roadmap 30/60/90 + layar Peta Ekspansi).
- Intelijen Pasar (input manual + fetch_url + benchmark hyperlocal -> kartu Intel Pasar).

### ST15-3 (15C) Bos Virtual Growth
- Migration `product_bundles`, `product_bundle_items`, `referral_codes`, `customer_referrals`.
- Cross-Selling (chip POS + kartu Peluang Cross-Sell), Bundling (manajer + 1 item POS),
  Referral (kode/kupon + tracking + wa.me).

### ST15-4 (15D) Perilaku Addendum + Hardening
- Laporan Mingguan Proaktif (L), Guardrail Aksi Otomatis/persetujuan (M),
  Benchmark Hyperlocal (N), Kartu Identitas Bisnis (O), uji end-to-end + tracker + dokumen.

## CATATAN
- Cron `doctor_observe`/`doctor_reprimand` (13.15/13.21B) ditunda: ekstensi `pg_cron`/`pg_net`
  TIDAK terpasang di DB live (hanya `pgcrypto`).
- Rate limit owner default 60 pesan / 200000 token per hari (superadmin dikecualikan).
