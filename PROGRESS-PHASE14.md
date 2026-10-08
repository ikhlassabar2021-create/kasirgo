# PROGRESS PHASE 14 - Dokter Bisnis AI

STATUS: ST14-1..ST14-12 SELESAI (termasuk penutup celah).
Sumber spec: `KASIRGO-WORKFLOW-LENGKAP.md` BAGIAN 13 + BAGIAN 14.2.

## Ringkasan sub-task

- ST14-1: migrasi 7 tabel doctor + RLS + view ter-mask + seed config (SELESAI).
- ST14-2: EF `business_doctor_chat` - konteks + provider override + tool-calling +
  blocks JSON + memori digest + fallback lokal + gating Pendukung (SELESAI).
- ST14-3: Admin Control Plane tab "Dokter Bisnis AI" (config global, provider default,
  internet tool, Tes Koneksi, Chat Uji) (SELESAI).
- ST14-4: layar chat owner + DoctorBlocks (text/card/gauge/checklist/choices/action/
  prescription) + gating (SELESAI).
- ST14-5: intake wizard 3 langkah (fisik/visual/perilaku) + deteksi fase (SELESAI).
- ST14-6: Peta Resep + vonis + `save_prescription` + tombol aksi + LAYAR HASIL
  `doctor_result_screen.dart` (gauge animasi, kartu vonis, checklist, timeline, footer)
  (SELESAI; flutter_animate tak tersedia -> animasi bawaan Flutter).
- ST14-7: Catat Hasil Promosi + ROI + tool `fetch_url` gated internet (SELESAI;
  web_search tidak dibuat - provider tidak punya; fetch_url cukup).
- ST14-8: Escalation Ladder `escalate_case` level 1-3 + kasus_bandel (SELESAI).
- ST14-9: sumber data resep internal - snapshot/trend/stok/slow/cashflow/action_history
  + market basket via ai_engine di app (SELESAI, tanpa API baru).
- ST14-10: internet tanpa API - `fetch_url` (SSRF guard) + gate `internet_tool.aktif`
  (SELESAI; web_cache/open_sources preset BELUM - ditunda, lihat CATATAN).
- ST14-11: memori & observasi - tool `observe_progress` (omzet 7d vs 7d),
  EF `doctor_observe` (evaluasi resep overdue -> achieved/failed + teguran bertingkat
  level 1-3 anti-spam 1/hari/outlet, simpan kind reprimand), migrasi kolom
  `doctor_action_logs.status/due_date/reminder_count/last_reminded_at` +
  `doctor_memory.data/resolved_at` + kind reprimand/market/scaling (SELESAI).
  App: banner teguran di chat + chip alasan (lupa/waktu/modal/paham) -> kirim ke AI;
  Admin: tombol "Jalankan Observasi" (semua/satu outlet).
- ST14-12: per-outlet + hardening - override provider per outlet + unlimited_tokens/
  token_quota + RPC admin + rate limit harian (SELESAI; lihat PROGRESS-PHASE15.md
  bagian "Penutup celah").

## CATATAN
- Cron `pg_cron`/`pg_net` TIDAK terpasang di DB live -> observasi via EF `doctor_observe`
  (tombol admin / Supabase Dashboard Scheduled Functions).
- `web_cache` tabel + preset `open_sources` (BMKG/kurs/RSS) DITUNDA (opsional;
  fetch_url generik sudah menutup kebutuhan dasar).
- Rate limit: 60 pesan / 200000 token per hari (default global; bisa override per outlet
  atau unlimited).
- `flutter_animate` tidak di pubspec; animasi memakai widget bawaan (TweenAnimationBuilder).
