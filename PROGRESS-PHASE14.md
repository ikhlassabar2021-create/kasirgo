# PROGRESS PHASE 14 - Dokter Bisnis AI

STATUS: ST14-1..ST14-16 SELESAI (termasuk penutup celah + delegasi & eskalasi).
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
- ST14-13: audio soundbox POS + master switch suara per outlet (`voice_service.dart`,
  `VoiceAudioConfig`: sapaan_awal/full_voice_loop/apel_pagi/teguran_resep/
  soundbox_pos/shop_floor) (SELESAI).
- ST14-14: full voice loop + multimodal (lampirkan berkas PDF/Excel/CSV + tempel
  tautan web + tombol Bicara) di layar Dokter (SELESAI).
- ST14-15: persona dokter (Bos Tegas / Partner Santai / Analis Taktis), Dosis Harian
  (3 langkah kecil tanpa modal), gamifikasi (XP/level/streak/badge) + ROI (SELESAI).
- ST14-16: delegasi tugas ke karyawan (`doctor_delegations`, papan delegasi owner,
  kartu tugas staf `DelegationTasksCard`, XP staf) + eskalasi "Laporan Merah ke Bos
  Besar" (tugas macet >3 hari atau kasus bandel level >=3 -> audio tegas +
  `logBossReport(kind:'eskalasi')` + kirim ulang via WA `boss_wa_number`) +
  pantauan lapangan (komentar suara antrean/stok) (SELESAI).
  Verifikasi live: staff flow (Kerjakan -> Selesai -> XP 8/level 1) PASS;
  owner escalation (seed tugas due -5 hari) -> kartu "Laporan Merah ke Bos Besar"
  + "Kirim Ulang ke Bos" tampil, 0 console error, data uji dibersihkan.
- ST14-17: kualitas suara & akurasi input suara (SELESAI).
  `voice_service.dart`: `VoicePersonaProfile` (rate/pitch/volume + `gender`) untuk
  `bos_tegas` / `partner_santai` / `analis_taktis`; `VoiceOption` + `_loadVoiceOptions`
  (cache suara Indonesia perangkat), `_bestVoiceFor` (skor locale id-ID/online +
  cocok/tidak cocok gender), `listIndonesianVoices`, `selectVoice` (persist
  `kasirgo_voice_device`), `_applyPersona` menukar suara perangkat sesuai gender
  persona bila owner belum memilih manual -> tiap persona benar-benar beda karakter.
  `speech_service.dart`: locale dipaksa `id-ID` (tidak pernah null), sesi kontinu
  + auto-restart (`_maxRestarts=8`), `listenMode: dictation`, `autoPunctuation`,
  `pauseFor: 6s`, `contextualPhrases` kosakata UMKM.
  `business_doctor_screen.dart`: tombol "Pilih Suara Perangkat (Pria/Wanita)"
  (bottom sheet + pratinjau "Coba suara ini" + "Pilih Otomatis"), caption
  "Suara aktif: <nama>", meter level mikrofon (0..1 dinormalkan Android dB / iOS
  negatif), guard `_speechSent`, dan `await _speech.stop()` sebelum TTS agar suara
  Dokter tidak terekam, plus `_normalizeSpeech` (QRIS/omzet/KasirGo/WhatsApp).
  Verifikasi live (Playwright 1280x1200, owner Toko Test): "Persona Dokter" tampil,
  tombol pemilih suara membuka alur, pesan kosong menyesuaikan platform
  (web: "Browser ini tidak menyediakan suara Indonesia"), mic -> "Mendengarkan..."
  tanpa error, 0 console error. Deploy gh-pages + main (commit `4060dcb`).
- ST14-18: suara manusiawi via cloud TTS gratis (Google Translate TTS) (SELESAI).
  Akar masalah: suara kaku berasal dari TTS bawaan perangkat/browser (kualitas
  mesin lama). Solusi: Edge Function `tts_speak` (Supabase) memanggil Google
  Translate TTS (`translate_tts?...&tl=id&client=tw-ob`) - gratis, tanpa API key,
  suara Indonesia natural. EF: JWT wajib, cache in-memory (maks 40 entri),
  `MAX_CHARS=1200`, pemecahan teks <=180 karakter lalu mp3 digabung, balasan
  `{ok,provider,voice,persona,playback_rate,mime,ms,audio(base64)}`.
  `voice_service.dart`: `audioplayers` memutar mp3 dari `BytesSource`; `_speakCloud`
  dipakai lebih dulu, TTS perangkat tetap jadi fallback offline; cloud otomatis
  dimatikan setelah 3 kegagalan beruntun (`_noteCloudFail`), `available` tetap
  benar, getter `cloudActive`. Persona dibedakan lewat tempo putar klien
  (`playback_rate` 0.93 bos tegas / 1.06 partner santai / 0.98 analis taktis)
  karena Google mengabaikan parameter `ttsspeed` (dibuktikan: byte audio identik
  untuk 0.35-1.0). Catatan: Google Translate TTS hanya suara perempuan; karakter
  pria didekati dengan tempo lebih lambat.
- ST14-19: akurasi STT lokal dengan kamus usaha (SELESAI).
  `lib/utils/speech_lexicon.dart` (BARU): `SpeechLexicon` memperbaiki transkrip
  dalam 3 lapis - (1) kamus frasa tetap ~80 entri (kasir go, qris, kris, omset,
  stok, kulakan, kasbon, piutang, whatsapp, tiktok, shopee, rp, persen, dst),
  dicocokkan batas kata dan frasa panjang lebih dulu; (2) penggabungan akhiran
  "-nya" yang dipisah STT ("omset nya" -> "omzetnya"); (3) koreksi jarak edit
  (Levenshtein) terhadap nama produk outlet, mendukung frasa multi kata
  ("gula paser" -> "Gula Pasir"), toleransi 1 huruf (4-6 huruf) / 2 huruf (7+),
  satu salah dengar per kata pada frasa, wajib huruf awal sama, kata <4 huruf
  dan kata umum (`_protected`) tidak dikoreksi. `business_doctor_screen.dart`:
  `_prepareLexicon()` memuat nama produk aktif dari `SupabaseService().getProducts`
  sekali saat layar dibuka (juga dipicu saat mulai merekam), `_normalizeSpeech`
  kini memakai `SpeechLexicon.correct`. Semua lokal, gratis, tanpa jaringan.
  Test `test/speech_lexicon_test.dart` 8 kasus PASS.

- ST14-20: jeda napas antar kalimat + pembersihan teks TTS (SELESAI).
  `supabase/functions/tts_speak/index.ts`: teks dipecah per kalimat
  (`splitForSpeech`: titik/seru/tanya/elipsis; kalimat >180 karakter dipecah di
  koma -> titik koma -> em dash -> spasi) sehingga tiap potongan tetap di bawah
  batas Google (~190 karakter). Balasan EF kini menyertakan
  `segments:[{audio(base64), pause_ms}]` (jeda 170 ms di ujung kalimat, 120/110 ms
  di tengah klausa, plus jitter 60-100 ms agar tidak terasa metronom) di samping
  `audio` gabungan (kontrak lama tetap jalan). `voice_service.dart`:
  `_SpeechSegment` + `_parseSegments` + `_playSegments` memutar tiap segmen
  berurutan via `BytesSource` lalu menunggu jeda; jeda diskalakan per persona
  (bos tegas 1.18x, analis taktis 1.08x, partner santai 0.95x, maks 900 ms);
  `_speakGen` mencegah loop segmen lama lanjut setelah `stop()`. `_naturalize`
  diperluas: buang markdown (`* _ ` # >`), tautan `[teks](url)` -> teks, buang
  URL, "25rb"/"1,5jt" -> "25 ribu"/"1,5 juta", `±` -> "sekitar", `->` -> "menjadi",
  rapikan spasi sebelum tanda baca. Hasil ukur E2E live: 2 segmen, durasi audio
  9,53 s + jeda 0,34 s, pemutaran nyata 10,20 s (rasio 1,01 = semua kalimat
  terputar penuh), tombol berhenti memotong suara dalam 308 ms, 0 console error.
- ST14-21: perbaikan transkrip STT via LLM + tampilkan teks terkoreksi (SELESAI).
  Edge Function BARU `stt_fix` (JWT wajib, `MAX_INPUT=800`, timeout LLM 12 s,
  temperature 0.1, max_tokens 400): meminta model membakukan transkrip Indonesia
  (ejaan, tanda baca, istilah usaha, nama produk dari `vocabulary` <=40) tanpa
  mengubah maksud; provider diambil dari `outlet_ai_configs` lalu
  `platform_configs.business_doctor.provider_default`; guard `empty_result` dan
  `unsafe_result` (panjang hasil <2 karakter atau >2,2x input) -> kembalikan teks
  asli. `business_doctor_service.dart`: `fixTranscript()` (timeout klien 10 s,
  fallback teks asli saat gagal) + helper `resolveFixedTranscript` (dipisah agar
  bisa diuji). `business_doctor_screen.dart`: hasil `_fixSpeechCloud` ditulis ke
  kolom input (kursor di akhir) sebelum dikirim, jadi owner melihat teks yang
  benar-benar dipakai dan bisa mengoreksi ulang. Uji live dengan JWT owner:
  "omset nya turun gak sih bos minggu ini gimana ya" -> "Omzetnya turun gak sih,
  bos? Minggu ini gimana ya?"; "stok gula paser tinggal berapa" -> "Stok Gula
  Pasir tinggal berapa"; "kasir go kenapa laporan kosong" -> "KasirGo kenapa
  laporan kosong"; kalimat yang sudah benar tidak diubah. Test
  `test/stt_fix_transcript_test.dart` 5 kasus PASS (sukses, spasi, ok=false,
  teks kosong, respons tanpa `text`).
- ST14-22: mode voice note (tanya suara -> jawab suara) + dedupe transkrip (SELESAI).
  Keluhan owner: di HP hasil STT masih dobel kata / tidak akurat dan jawaban AI
  selalu berupa teks. Perbaikan:
  (1) Utilitas bersama BARU `lib/utils/speech_text_utils.dart`
  (`mergeTranscriptSegments`, `collapseRepeats`, `cleanTranscript`) dipakai
  `speech_service.dart` dan layar Dokter, sehingga aturan pembersihan transkrip
  tidak lagi terduplikasi di dua tempat dan bisa diuji unit.
  (2) `business_doctor_screen.dart`: `_Msg.voiceNote` + state `_voiceNoteMode`,
  `_showTranscript`, `_expandedVoiceNotes` (Set<_Msg>); preferensi perangkat
  disimpan di SharedPreferences (`kasirgo_doctor_voice_note`,
  `kasirgo_doctor_voice_transcript`). Saat mode aktif: hasil STT TIDAK ditampilkan
  sebagai teks (kecuali "Tampilkan Teks Suara" dinyalakan), balasan AI langsung
  dibacakan lewat `_speakReply(force: true)`, gelembung pesan owner tampil
  "Pesan suara - ketuk untuk lihat teks" dan gelembung jawaban tampil
  "Jawaban suara - ketuk untuk lihat teks" (ketuk = buka transkrip). Tombol
  mikrofon diberi warna primer + tooltip "Bicara (jawaban dibacakan)"; baris
  input memakai hint mode voice note. Dua toggle baru di kartu Audio: "Mode
  Voice Note" dan "Tampilkan Teks Suara" (nonaktif bila audio utama mati).
  (3) Test BARU `test/speech_text_utils_test.dart` 10 kasus (sambung transkrip
  tanpa dobel, tumpang tindih 1-2 kata, input kosong, hapus pengulangan 1-2 kata,
  huruf besar/tanda baca, rapikan spasi) PASS. Regresi `speech_lexicon_test`
  (8) + `stt_fix_transcript_test` (5) juga PASS (23 total).
  (4) `flutter analyze lib` tetap 22 info pra-ada (0 error/warning); build web
  release sukses dan di-deploy ke gh-pages.
- ST14-23: verifikasi E2E mode voice note di web live (SELESAI).
  Skrip baru `e2e/doctor_voice_note_verify.mjs` (Playwright, service worker
  diblokir + cache-bust) login owner -> Dokter Bisnis AI -> kartu "Suara
  Interaktif". Hasil: preferensi awal kosong; toggle "Mode Voice Note"
  (switch ke-2 di kartu) -> `flutter.kasirgo_doctor_voice_note=true`; toggle
  "Tampilkan Teks Suara" -> `..._voice_transcript=true`; kedua toggle
  dikembalikan ke `false` -> state tersimpan benar; hint baris input berubah
  menjadi "Mode voice note: ketuk mikrofon lalu bicara..." saat mode aktif dan
  hilang saat mode mati; 0 console error. Catatan teknis: label toggle berada
  di luar node `role="switch"`, jadi klik dilakukan lewat bounding box switch,
  bukan teks label. Deploy gh-pages `14b2015`, md5 `main.dart.js` live
  `99309546483e1672546fb6f96d085a82` = build lokal.


## CATATAN
- Cron `pg_cron`/`pg_net` TIDAK terpasang di DB live -> observasi via EF `doctor_observe`
  (tombol admin / Supabase Dashboard Scheduled Functions).
- `web_cache` tabel + preset `open_sources` (BMKG/kurs/RSS) DITUNDA (opsional;
  fetch_url generik sudah menutup kebutuhan dasar).
- Rate limit: 60 pesan / 200000 token per hari (default global; bisa override per outlet
  atau unlimited).
- `flutter_animate` tidak di pubspec; animasi memakai widget bawaan (TweenAnimationBuilder).
