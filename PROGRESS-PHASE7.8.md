# PROGRESS PHASE 7.8

SELESAI: ST7.8-DB (Tahap 1/3) - migration SQL + seed Control Plane
BERIKUTNYA: ST7.8-APP (Tahap 2/3) - service + entitlement + trial + UI

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
- Tahap berikutnya (ST7.8-APP): services/supporter_service.dart (baca harga/durasi dari
  platform_financial_configs + fallback), entitlement hasFeature(), reverse trial 14 hari saat KYC
  verified, simpan nomor WA owner dari KYC; lalu UI Program Pendukung (satu kartu Rp50.000/bulan).
