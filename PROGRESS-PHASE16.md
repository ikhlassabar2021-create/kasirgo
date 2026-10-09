# PROGRESS PHASE 16 - Squad Digital Marketing AI

STATUS: BELUM DIMULAI. Menunggu ST16-1.
Sumber spec: `KASIRGO-WORKFLOW-LENGKAP.md` BAGIAN 13.28 (+ 13.28.6 Superadmin Config LLM) + BAGIAN 15.

## Prinsip (WAJIB)
- Fitur "Tim Marketing Digital dalam satu aplikasi": owner chat/brief -> 3 tim AI
  (Team Desain, Team Promosi, Team Iklan) bekerja berurutan.
- SEMUA fitur baru = Program Pendukung (gate Pendukung), ikuti Design System v2
  "Centennial Modern Ocean White". Jangan ubah fitur/logic/skema lama. Bahasa Indonesia.
- Kredensial LLM + kanal social/ads HANYA superadmin, terenkripsi
  (`api_key_enc`/`token_enc`), HANYA `service_role`. Owner tidak pernah melihat token.
- Billing iklan ditanggung owner di platform masing-masing (KasirGo tidak menampung uang iklan).
- Reuse pola BAGIAN 13.4/13.8 (`business_doctor`): provider default + override per outlet,
  unlimited token / token_quota + batas request token.
- 1 sub-task = 1 commit + push, lalu STOP.

## Data Model (BAGIAN 13.28.3)
- `dm_assets` (outlet_id, kind image/video/copy, title, file_path, caption, hashtags,
  source pos_product/brief/template, status draft/approved/published, created_at).
- `dm_posts` (outlet_id, asset_id, channel fb/fb_group/ig/tiktok/shopee/wa_status, status
  draft/queued/posted/failed, scheduled_at, posted_at, post_url, error).
- `dm_campaigns` (outlet_id, channel meta/google/tiktok/shopee, objective, budget_daily,
  start/end, status draft/approved/active/paused/done, external_id, metrics JSONB).
- `dm_settings` per outlet (mode per tim, budget limit, jam hening, watermark,
  connected_accounts token_enc, last_sync).
- Index: outlet_id + scheduled_at/status. RLS per outlet; token/kredensial HANYA
  `service_role` + terenkripsi.
- Config LLM (13.28.6): `platform_configs` group `digital_marketing_llm` (scope global/
  segment/outlet) atau tabel `outlet_dm_configs` untuk override per outlet.

## Subtask

### ST16-1 Fondasi Squad DM - BELUM
- Migration: `dm_assets`, `dm_posts`, `dm_campaigns`, `dm_settings` (+ RLS per outlet;
  token/kredensial HANYA service_role, terenkripsi); INDEX outlet_id + scheduled_at/status.
- Tab superadmin "Squad Digital Marketing": global config (provider gambar/video/copy,
  base_url + api_key + model LLM + unlimited token/token_quota + batas request token,
  mode TERPUSAT atau PER OUTLET, batas budget global, whitelist konten terlarang) +
  per-outlet connect akun (fb/ig/tiktok/shopee) -> token_enc.
- Edge Function `dm_creative`: pipeline copy (LLM) + gambar (template + foto produk +
  teks harga) -> `dm_assets`; gaya copy sesuai outlet_type; watermark opsional.
- Gating Pendukung + kuota asset per bulan (pola BAGIAN 13.8).
- Ikuti Design System v2. `flutter analyze` bersih. commit+push, STOP.

### ST16-2 Team Desain UI + Video - BELUM
- Layar owner "Studio Desain": brief chat -> AI buat 3 opsi copy + gambar (preview) ->
  pilih/edit -> save `dm_assets`; ambil produk otomatis dari POS (nama/foto/harga/promo).
- Video 15-30 detik: naskah AI + template animasi (foto produk + teks + musik) -> MP4;
  preview + regenerate.
- Mode per tim (MANUAL/AUTO) di `dm_settings`; jam hening + filter klaim medis/terlarang.
- Tombol Dokter Bisnis: resep -> "Buat Video Promo" (tool `create_asset`) -> pipeline Team Desain.
- `flutter analyze` bersih. commit+push, STOP.

### ST16-3 Team Promosi - jadwal + posting - BELUM
- Kalender konten mingguan (`dm_posts`): draft/queued/posted/failed; geser/hapus.
- Kanal: WA status + broadcast (wa.me), FB feed/fanpage + IG (Meta Graph API bila connected),
  TikTok (Content Posting API bila connected), Shopee (OpenAPI bila connected);
  BELUM connected -> asset ke WA owner + tombol "Buka Aplikasi Kanal" (manual 1-tap).
- AI jadwalkan jam optimal dari data jam ramai pelanggan (BAGIAN 13.17);
  anti-spam fb_group (draft manual).
- Report: posting sukses/gagal + reach bila API tersedia.
- Uji posting draft ke 1 kanal (manual path). `flutter analyze` bersih. commit+push, STOP.

### ST16-4 Team Iklan + Hardening + Tes - BELUM
- Campaign draft: Meta Ads, Google Ads, TikTok Ads, Shopee Ads (objective, geofence radius
  toko, budget harian, jadwal, creative dari `dm_assets`) -> approval WAJIB owner
  (addendum M) -> kirim via API bila connected, else checklist setting manual.
- Monitor hasil (ROAS/CTR/CPC) via API report bila connected -> laporan mingguan +
  rekomendasi geser budget -> rekomendasi masuk chat Dokter Bisnis.
- Guardrail: budget limit harian (owner + batas global superadmin), pause otomatis bila
  ROAS < target, `audit_logs` semua aksi.
- Uji end-to-end: brief -> asset -> post draft -> campaign draft -> approval; gating
  non-Pendukung; token tidak bocor; PROGRESS-PHASE16.md SELESAI. commit+push, STOP.

## CATATAN
- Prasyarat: Phase 14 & 15 SELESAI.
- Auto-posting butuh koneksi akun resmi; bila belum -> fallback "mesin produksi aset +
  reminder posting manual 1-tap" (tidak menjanjikan autopost penuh).
- Batas realistis: kualitas video bergantung template; fokus template rapi + teks harga +
  foto produk asli.
