# PROGRESS PHASE 7.8

SELESAI: ST7.8-DB (Tahap 1/3) - migration SQL + seed Control Plane  [SUDAH DIJALANKAN di Supabase, terverifikasi]
SELESAI: ST7.8-2 - services/supporter_service.dart (config cache+fallback, entitlement, trial, WA owner, checkout)
SELESAI: ST7.8-3 - UI Program Pendukung SATU kartu Rp50.000/bulan (settings + layar modul Pendukung)
SELESAI: ST7.8-4 - gate hasFeature() fitur pindahan (WA Marketing, Social Sync, Katalog Online, QR Meja,
          Health Score Pro, export Excel/PDF, slot staf tambahan)
SELESAI: ST7.8-5 - laporan otomatis ke bos (report_schedule_screen + notifikasi lokal + WA/email one-tap
          + Edge Function report_scheduler)
SELESAI: ST7.8-6 - iklan pelanggan (ad_service + SponsorAdSlot di halaman pesan pelanggan;
          config ads cache+fallback, ad_free Pendukung, blokir judi/dewasa/pinjol, consent UU PDP)
SELESAI: ST7.8-7 - onboarding KYC wajib (wizard 6 field + gate total, anti-dup hash NIK/HP,
          auto-verify server via RPC submit_kyc, draf offline, foto LOKAL, status lengkap)
BERIKUTNYA: ST7.8-8 (Tahap 3/3) - panduan penggunaan (guide_screen dari guide_items: PDF + video)

## Detail ST7.8-DB
File: docs/migrations/2026-09-28-kasirgo-7.8.sql (idempotent, aman diulang)

### Tabel baru
- entitlements (is_supporter, ad_free, features jsonb, trial_ends_at, updated_at)
- billing_events (event, amount, status, ref)
- report_schedules (period daily/weekly/monthly, send_time, day_of_week/month, recipients <=3, channels, content_flags, enabled, last_sent_at)
- outlet_ad_state (ad_enabled, ad_free, impressions)
- guide_items (title, kind pdf/video, category, role, url, file_key, thumbnail_key, sort_order, is_active)
- platform_configs (key, scope global/segment/outlet, scope_ref, value jsonb, version, effective_from, updated_by)
- feature_flags (key unique, enabled, rollout_pct, segments, outlet_types)
- automation_rules (name, trigger, condition, action, enabled)
- segments + outlet_segments
- announcements (title, body, audience, starts_at, ends_at, is_active)
- audit_logs (actor_id, actor_role, action, target, meta)
- admin_users (user_id, role superadmin/finance/support/ops, is_active)

### Revisi tabel
- supporters: SATU tier 'pendukung' (default), amount 50000, status CHECK trial/active/expired/cancelled,
  + trial_started_at, auto_renew, pg_reference_id, updated_at. Baris lama dinormalisasi (tier -> 'pendukung',
  amount -> 50000, status NULL -> 'active').
- outlets: + owner_wa_number (nomor WA owner dari KYC, untuk wa.me mode pribadi).

### Seed Control Plane (platform_configs, scope global/scope_ref 'all')
- ads      -> provider sponsor_lokal, adsterra_key, blocked_categories (judi/dewasa/pinjol), placement, ad_free_for_supporter, consent
- guide    -> show_in_settings, default_category
- report   -> default_period/time, max_recipients 3, channels [email, wa]
- kyc      -> required, auto_verify, fields
- quota    -> max_admin 1, max_cashier 1, extra_from_supporter
- flags    -> enabled {}
- billing  -> supporter_price 50000, period monthly, trial_days 14, auto_renew_default

### RLS (Bagian 3.4)
- supporters: owner outlet sendiri (ALL) + superadmin full
- entitlements: owner read sendiri + superadmin full (tulis via Edge)
- billing_events: owner read sendiri + superadmin full (tulis via Edge)
- report_schedules: owner kelola sendiri (ALL) + superadmin full
- outlet_ad_state: owner kelola sendiri (ALL) + superadmin full
- guide_items / announcements: superadmin full CRUD; client SELECT yang is_active
- platform_configs / feature_flags: superadmin full; client SELECT
- segments / outlet_segments / automation_rules / audit_logs / admin_users: superadmin/Edge only
- Superadmin check: auth.jwt()->>'role' IN ('superowner','superadmin')

### Indexes
supporters(outlet_id, status), billing_events(outlet_id), report_schedules(outlet_id),
guide_items(is_active, sort_order), platform_configs(key, scope/scope_ref), feature_flags(key),
announcements(is_active), audit_logs(created_at DESC), admin_users(user_id).

## Files Created/Modified
- docs/migrations/2026-09-28-kasirgo-7.8.sql: migration 7.8 tahap 1 + seed + RLS + index
- PROGRESS-PHASE7.8.md: dokumen tracking phase ini

## Catatan
- File .sql tidak perlu flutter analyze.
- Tahap berikutnya (ST7.8-5): laporan otomatis ke bos.

## Detail ST7.8-2 s/d ST7.8-4 (Flutter)

### services/supporter_service.dart (ST7.8-2)
- Entitlements: isSupporter, adFree, features, trialEndsAt, status (none/trial/active/expired/cancelled),
  hasAccess, isTrialActive, trialDaysLeft.
- getConfig(key) dari platform_configs (scope global, versi terbaru) + cache SharedPreferences (TTL 300s) + fallback.
- getBillingConfig(): platform_configs('billing') -> platform_financial_configs -> fallback (50000/30 hari/trial 14).
- getAdsConfig(), getEntitlements(outletId), hasFeature(outletId, key), isSupporter(outletId).
- premiumFeatures: wa_marketing, social_sync, online_catalog, qr_table, ai_pro, health_score_pro,
  advanced_report, export_excel, export_pdf, backup_cloud, multi_outlet, extra_staff, custom_receipt.
- featureLabels: label manusiawi tiap fitur (dipakai dialog terkunci).
- ensureTrial(outletId): reverse trial 14 hari idempoten (set entitlements.trial_ends_at + catat supporters 'trial').
- setAutoRenew, saveOwnerWa/getOwnerWa (normalisasi 08xx -> 628xx; fallback ke outlet_kyc.phone).
- checkout(): QRIS existing (static/dinamis) -> insert supporters + upsert entitlements + billing_events.

### UI Program Pendukung (ST7.8-3)
- settings_screen.dart: 3 tier (Kawan/Pro/Setia) DIGANTI satu kartu "Pendukung KasirGo" harga dari config
  + daftar benefit + tombol Dukung/Perpanjang + switch auto-renew + badge status (PENDUKUNG/TRIAL sisa hari).
- _handleJoinSupporter -> _handleSupport (checkout QRIS via SupporterService) + _confirmSupportDialog.
- _showUpgradeModal (kuota staf penuh) -> arahkan ke Pendukung (bukan Pro/Enterprise); _buildUpgradeOption dihapus.
- screens/modules/supporter_screen.dart: dari layar statis -> layar fungsional (harga, benefit, checkout,
  status, sisa trial, auto-renew).

### Gate fitur (ST7.8-4)
- widgets/common/supporter_gate.dart (BARU): SupporterFeatureGate (pembungkus layar terkunci),
  requireSupporterFeature() (cek imperatif + dialog), showSupporterLockedDialog(). Data lama TIDAK dihapus.
- owner_home_screen.dart: _pushGated() membungkus modul WA Marketing (wa_marketing), Social Commerce
  (social_sync), QR Meja (qr_table), Katalog Online (online_catalog), Health Score (health_score_pro).
- report_screen.dart: _exportExcel (export_excel) + _exportBankReadyPdf (export_pdf) dicek via requireSupporterFeature.
- employee_screen.dart: tombol tambah karyawan (extra_staff) dicek via requireSupporterFeature.

### Verifikasi
- flutter analyze: bersih pada semua file baru/diubah (hanya info deprecated_member_use & unnecessary_underscores
  lama di file yang tidak terkait).
- flutter build web --release: SUKSES.

### ST7.8-5 (laporan otomatis ke bos)
- pubspec: + flutter_local_notifications ^22.3.1, + timezone ^0.11.1.
- services/notification_service.dart (BARU): init (izin Android 13+/iOS), scheduleReportReminder()
  (zonedSchedule, repeat daily/weekly/monthly, zona Asia/Jakarta), cancelReportReminder();
  payload 'report:<outletId>'.
- services/report_scheduler_service.dart (BARU): model ReportSchedule (period, send_time, day_of_week,
  day_of_month, recipients<=3, channels, content_flags), load/save ke report_schedules,
  nextRun() hitung jadwal berikutnya, applyLocalReminder(), buildReportText() (omzet, transaksi,
  rata-rata, produk terlaris), sendViaWhatsApp()/sendViaEmail() (one-tap via url_launcher).
- screens/owner/report_schedule_screen.dart (BARU): toggle aktif, periode harian/mingguan/bulanan,
  jam (time picker), hari/tanggal, sampai 3 penerima, toggle isi laporan, toggle kanal WA/email,
  info jadwal berikutnya, tombol Kirim Sekarang + Simpan Jadwal.
  Kanal email = "Email (PDF)": laporan dibuat PDF (pdf + printing) lalu dibagikan lewat share sheet.
- settings_screen.dart: entri "Laporan Otomatis ke Bos" -> ReportScheduleScreen.
- app.dart: inisialisasi NotificationService; tap notifikasi -> buka WA dengan laporan siap kirim.
- android/app/src/main/AndroidManifest.xml: RECEIVE_BOOT_COMPLETED + ScheduledNotificationReceiver +
  ScheduledNotificationBootReceiver (agar jadwal bertahan setelah reboot).
- supabase/functions/report_scheduler/index.ts (BARU, BELUM di-deploy): cron bangun laporan +
  kirim email (Resend via RESEND_API_KEY/REPORT_FROM_EMAIL) + lampiran PDF (pdf-lib) + update last_sent_at.
  Deploy: supabase functions deploy report_scheduler --no-verify-jwt + jadwalkan pg_cron (CRON_SECRET).
- Catatan: notifikasi lokal berjalan di HP; pengiriman email otomatis penuh butuh Edge Function
  ter-deploy + RESEND_API_KEY. Di web, notifikasi mengikuti izin browser (opsional).

### ST7.8-6 (iklan pelanggan)
- services/ad_service.dart (BARU): baca config `ads` via SupporterService.getAdsConfig() (cache+fallback),
  model SponsorAd, AdDecision; consent tersimpan (SharedPreferences 'ad_consent_state_v1');
  isOutletAdFree() via RPC get_public_ad_state (fallback ke entitlements);
  decide(): owner -> tidak ada iklan, Pendukung/ad_free -> skip, consent wajib sebelum tampil,
  blokir kategori judi/dewasa/pinjol (hardcoded + config), sponsor_lokal diutamakan, adsterra fallback.
- widgets/ads/sponsor_ad_slot.dart (BARU): kartu iklan WAJAR non-intrusif + label "Iklan Sponsor",
  kartu consent UU PDP (Setuju/Tolak), tap buka URL sponsored (eksternal). Tidak popunder,
  tidak menutupi tombol, tidak ada iklan tersembunyi. HANYA dirender di halaman pelanggan.
- screens/customer/customer_order_screen.dart: SponsorAdSlot di atas katalog (sisi pelanggan QR meja).
- docs/migrations/2026-09-29-public-ad-state.sql (BARU, SUDAH DIJALANKAN di Supabase, terverifikasi):
  RPC get_public_ad_state(p_outlet) SECURITY DEFINER untuk anon (boolean aman saja).
- Catatan: config `ads` (provider, adsterra_key, sponsor_local[], blocked_categories, placement,
  ad_free_for_supporter, consent_required) dikelola superadmin lewat Control Plane (ST7.8-9).
  Iklan owner-visible TIDAK ada; katalog online owner tetap bersih.


## Catatan lama
- Tahap berikutnya (ST7.8-APP): services/supporter_service.dart (baca harga/durasi dari
  platform_financial_configs + fallback), entitlement hasFeature(), reverse trial 14 hari saat KYC
  verified, simpan nomor WA owner dari KYC; lalu UI Program Pendukung (satu kartu Rp50.000/bulan).



### ST7.8-7 (KYC wajib / onboarding)
- docs/migrations/2026-09-29-outlet-kyc.sql (BARU, SUDAH DIJALANKAN di Supabase, terverifikasi):
  tabel outlet_kyc (outlet_id UNIQUE, status unsubmitted/draft/pending_review/verified/rejected,
  auto_verified, reject_reason, nik_hash, phone_hash, verified_at) + RLS owner/superadmin +
  RPC submit_kyc(...) SECURITY DEFINER: auto-verify 6 field (email/HP/nama toko/alamat/nama/KTP+selfie
  + consent) + anti-duplikat hash NIK/HP (pgcrypto digest sha256, NIK mentah TIDAK disimpan).
- services/kyc_verification_service.dart (REWRITE): KycStatus enum + mapping, KycRecord, KycService
  (cachedStatus/fetchRecord/refreshIfStale 5 menit, saveDraft/loadDraft/clearDraft offline,
  submit() panggil RPC + tangani duplicate_nik/duplicate_phone; foto hanya path lokal).
- screens/auth/onboarding_kyc_screen.dart (BARU): wizard 3 langkah -> Data Usaha (5 field, auto-isi
  email/nama toko/alamat/HP dari outlet + user_metadata) -> Dokumen (kamera KTP + selfie memegang KTP,
  kompres 1200x1600 q80, NIK opsional, tips foto benar/salah) -> Tinjau + consent UU PDP; simpan draf,
  banner status ditolak/ditinjau, panel terverifikasi; tanpa tombol lewati.
- widgets/common/kyc_gate.dart (BARU): gate total sebelum verified -> hanya wizard KYC + bantuan + logout;
  banner "Selesaikan verifikasi untuk mulai berjualan"; staf (admin/kasir) bila outlet belum verified
  melihat pesan hubungi pemilik (tidak bisa submit KYC owner).
- app.dart: semua rute owner (produk/POS/laporan/pelanggan/karyawan/pengaturan) + admin + kasir
  dibungkus KycGate.
- settings_screen.dart: kartu status KYC pakai skema baru (status/reject_reason) + tombol
  "Lengkapi / Perbarui" -> OnboardingKycScreen.
- kyc_upload_screen.dart: jadi alias tipis ke OnboardingKycScreen (kompatibilitas).
- Catatan: Edge Function verify_kyc TIDAK dipakai lagi; auto-verify + anti-duplikat kini di RPC server
  (lebih aman, tanpa upload foto). Foto KTP/selfie tetap LOKAL (kebijakan foto lokal).
