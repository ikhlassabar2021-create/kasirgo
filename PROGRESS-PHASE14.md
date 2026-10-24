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


- ST14-24: Memori jangka panjang Dokter Bisnis + Pengetahuan manual + hapus riwayat (SELESAI).
  Tujuan: Dokter Bisnis mengingat percakapan sebelumnya (lintas sesi), belajar dari
  ringkasan, bisa diberi pengetahuan manual dari dalam fitur, dan riwayat bisa dihapus.
  (1) Migrasi `docs/migrations/2026-11-29-kasirgo-doctor-memory-knowledge.sql`
  (DITERAPKAN live): `doctor_memory_kind_check` ditambah `knowledge` & `chat_summary`;
  kolom `origin TEXT DEFAULT 'doctor'`; unique partial index
  `uq_doctor_memory_chat_summary` pada `(conversation_id)` WHERE kind='chat_summary'
  (menjamin 1 ringkasan per percakapan); index `idx_doctor_memory_kind_created`.
  (2) EF `business_doctor_chat` (REDEPLOYED): `buildSystem(..., knowledge=[], summaries=[])`
  menyuntik blok "PENGETAHUAN YANG DICATAT OWNER" + "RINGKASAN PERCAKAPAN SEBELUMNYA";
  kontrak balasan +`"summary"`; saat request memuat `knowledgeRows` (kind='knowledge',
  limit 15) + `summaryRows` (kind='chat_summary', limit 6, mengecualikan percakapan
  aktif) + `actionLogs`; ringkasan percakapan di-upsert (1 baris per conversation).
  (3) `business_doctor_service.dart`: `listMemories` +`origin`, limit 80; BARU
  `addKnowledge(outletId, {title, content})` -> kind='knowledge', origin='manual',
  status='open'.
  (4) UI `doctor_cases_screen.dart`: pemisahan `_filteredKnowledge` (kind=='knowledge')
  vs `_filteredNotes`; section baru "Pengetahuan Saya" sebelum "Catatan Memori";
  AppBar IconButton "Tambah Pengetahuan" + tombol di empty state; `_openKnowledgeForm()`
  (bottom sheet Form: Judul maks 120, Isi 3-6 baris maks 1000, validator judul wajib
  + isi minimal 3 karakter, simpan -> snack "Pengetahuan disimpan. Dokter Bisnis akan
  mengingatnya." -> reload). `_kindLabel` ditambah knowledge/chat_summary/reprimand/
  market/scaling/weekly_report.
  (5) Verifikasi backend E2E: baris pengetahuan manual disuntik -> balasan chat mengutip
  isinya; `chat_summary` otomatis terbentuk (origin 'chat'); percakapan kedua mengingat
  ringkasan dari percakapan pertama (lintas percakapan). Data QA dibersihkan.
  (6) Verifikasi UI live (Playwright): `e2e/doctor_memory_knowledge_verify.mjs` -
  form terbuka, 2 field terisi, simpan sukses, baris muncul, 0 console error;
  `e2e/doctor_memory_delete_verify.mjs` - menu baris -> "Hapus" -> konfirmasi ->
  baris hilang (`ROW_GONE true`), 0 console error. Sisa data QA di DB dihapus.
  (7) `flutter analyze lib` 21 info pra-ada (0 error/warning); build web release
  md5 `fc7192e2d1e90b60e7ed2a1193ce9724` = live; gh-pages `496ca32`.

- ST14-25: Navigasi menu Dokter Bisnis (layar utama chat-only) (SELESAI).
  Tujuan: permintaan owner "semua fitur di dalam Dokter Bisnis dibuat navigasi menu
  saja, di tengah hanya fitur chat" - sebelumnya kartu-kartu fitur (identitas bisnis,
  briefing, dosis, tugas, kondisi toko, resep, intake, kamera klinis, ROI, evaluasi,
  persetujuan aksi, persona/suara, laporan mingguan) menumpuk di atas chat.
  (1) `business_doctor_screen.dart`: state baru `_pane` + `_paneTitle`; AppBar
  menampilkan tombol Back + judul pane saat berada di pane, dan IconButton bergrid
  (tooltip "Menu Dokter") dengan badge merah berisi `_attentionCount` saat di chat.
  Body memilih antara chat (`_buildList`) dan `_buildPaneBody()`.
  (2) `_openDoctorMenu()` - bottom sheet "Menu Dokter Bisnis / Semua fitur ada di sini.
  Layar utama khusus chat." berisi daftar `_MenuEntry` (ikon, judul, subjudul, warna,
  onTap, badge opsional): Ringkasan Bisnis, Briefing Harian, Dosis Harian, Tugas &
  Delegasi, Kondisi Toko, Resep Aktif, Cek Fisik Toko, Kamera Klinis, Rapor ROI
  Promosi, Evaluasi Resep, Persetujuan Aksi, Persona & Suara, Riwayat Kasus,
  Lapor ke Bos. Entri navigasi memanggil `_openPane(key, title)`; entri aksi langsung
  memanggil `_openIntake`, `_openKameraKlinis`, `DoctorCasesScreen`, `_reportToBoss`.
  (3) `_buildPaneBody()` merender tiap pane dari widget yang sudah ada
  (overview/briefing/dose/weekly/tasks/shopfloor/redreport/prescription/roi/
  evaluation/alerts/approvals/voice) - tidak ada logika fitur yang diubah.
  (4) `_buildList` dipangkas menjadi chat-only: banner perhatian ringkas
  (`_buildAttentionBanner`: "N hal perlu perhatian. Buka menu untuk melihat
  detailnya.", tap -> menu) + welcome/staffWelcome + gelembung chat + indikator
  loading + disclaimer. Kode mati dihapus: `_chatShowsRecipe`, `_buildIntakeCta`,
  `_buildKameraKlinisCta` (`_buildRoiBanner` dipertahankan karena dipakai pane ROI).
  (5) Verifikasi UI lokal + live (Playwright) `e2e/doctor_menu_verify.mjs`:
  login owner -> Dokter Bisnis terbuka tanpa kartu identitas -> menu terbuka ->
  14 entri terbaca (Ringkasan Bisnis, Tugas & Delegasi, Persona & Suara, Riwayat
  Kasus, Lapor ke Bos terverifikasi) -> siklus pane Ringkasan Bisnis / Tugas &
  Delegasi / Persona & Suara (menu tertutup, judul pane tampil, chat tersembunyi,
  tombol "Kembali ke chat" bekerja) -> Riwayat Kasus terbuka -> kembali ke chat;
  0 console error. `e2e/doctor_memory_knowledge_verify.mjs` &
  `e2e/doctor_memory_delete_verify.mjs` disesuaikan (buka "Menu Dokter" sebelum
  "Riwayat Kasus", helper assertion membaca `textContent` selain `aria-label`,
  cek snackbar 1,8 dtk) dan LULUS: form pengetahuan tersimpan + snackbar, baris
  terhapus (`ROW_GONE true`), 0 console error.
  (6) Catatan teknis E2E: Flutter web tidak mengekspos tooltip IconButton sebagai
  `aria-label`, jadi klik memakai `flt-semantics[role="button"]` yang cocok dengan
  teks tombol; `has()` harus memeriksa `textContent` juga.
  (7) `flutter analyze lib` 21 info pra-ada (0 error/warning); build web release
  md5 `9017d5da7e97cebb9f1c421da14078b0` = live; gh-pages `8bf3d94`.

## ST14-26: Suara Balasan Dokter Selalu Aktif (23 Okt 2026) - SELESAI
- Keluhan: jawaban Dokter Bisnis hanya dibacakan bila input berasal dari suara
  (STT / catatan suara), tidak saat pengguna mengetik.
- AKAR: gate di `_send` hanya `if ((spoken || _voiceNoteMode) && reply.isNotEmpty)`
  sehingga balasan untuk input teks tidak pernah memanggil `_speakReply`.
- FIX `business_doctor_screen.dart`: `_speakReply(reply)` kini hanya bergantung pada
  `_audioAktif`; pemanggilan di akhir `_send` menjadi
  `if (reply.trim().isNotEmpty && (_audioAktif || _voiceNoteMode))`, lalu loop suara
  hanya dilanjutkan bila `played && (spoken || _voiceNoteMode)`.
- FIX `voice_service.dart`: `_speakCloud` melaporkan hasil nyata `_playSegments`
  (`Future<bool>`), `AbortError` dari generasi lama diabaikan (bukan kegagalan),
  sehingga fallback TTS perangkat tetap jalan bila cloud gagal.
- Verifikasi: probe Playwright lokal (build baru) -> input teks menghasilkan
  fetch `tts_speak` (+21,7 dtk) + 10 `media-play` sesudah balasan; `ERRORS 0`.
  `flutter test test/speech_text_utils_test.dart test/stt_fix_transcript_test.dart`
  15/15 lulus; `flutter analyze` 2 file bersih; build web release sukses dan live
  (md5 `df913eb2b42cf3d543b5ef03c1ba2f86` = build lokal, gh-pages `518ca44`).
- Rilis APK `1.0.4+5`: GitHub Release `v1.0.4-apk-20261023` (3 APK + AAB +
  `SHA256SUMS.txt`, signed) + mirror `/apk/` di GitHub Pages.

## ST14-27: Jawaban Kedua Tetap Dibacakan (24 Okt 2026) - SELESAI
- Keluhan: suara Dokter Bisnis hanya terdengar pada balasan PERTAMA; balasan
  berikutnya tampil di layar tetapi tidak dibacakan.
- Diagnosa: kode aplikasi memang memanggil TTS untuk setiap balasan (dibuktikan
  lewat probe dua pesan: `tts_speak` + `media-play` muncul pada M1 dan M2),
  jadi penyebabnya di sisi pemutaran: (a) endpoint suara neural Edge bersifat
  best-effort, satu kegagalan langsung jatuh ke TTS perangkat; (b)
  `audioplayers` Android kadang diam saat pemutar yang sama dipakai untuk audio
  kedua (terutama setelah mikrofon/STT dipakai); (c) TTS perangkat tanpa paket
  suara `id-ID` bisa tidak bersuara tanpa error.
- FIX `voice_service.dart`:
  - `speak()` -> `Future<bool>` (benar-benar diputar/dibacakan).
  - `_fetchCloudAudio()`: percobaan ulang 1x (jeda 500 ms) sebelum
    `_noteCloudFail` dan fallback TTS perangkat.
  - `_resetPlayer()`: `AudioPlayer` baru untuk setiap pemutaran; pemutar lama
    di-dispose (tidak bisa "nyangkut" diam pada pemutaran berikutnya).
  - `_playSegments(segments, gen, player)`: pengawas `onPlayerStateChanged`;
    bila status `playing` tidak tercapai dalam 3 dtk -> gagal -> `_speakCloud`
    mengulang sekali lalu fallback TTS perangkat.
  - `_ensureIndonesianLanguage()`: cek `isLanguageAvailable('id-ID')`, lalu
    `id`, agar HP tanpa paket suara tidak senyap.
- FIX `business_doctor_screen.dart`: `_speakReply` mengembalikan hasil nyata
  (dulu selalu `true`), sehingga `_resumeVoiceLoop` tidak membuka mikrofon
  setelah balasan yang gagal dibacakan.
- Verifikasi: probe Playwright dua pesan berturut-turut (lokal, cloud TTS aktif)
  -> M1 fetch `tts_speak` +56,7 dtk lalu 2 `media-play`; M2 fetch +44,2 dtk lalu
  2 `media-play`; `ERRORS 0`. `flutter analyze` 2 file bersih; 15/15 test
  speech lulus; build web release sukses, live md5
  `e9806d33ef91b7059e3e7473c7eece78` = build lokal (gh-pages `6f77fdd`).
- Rilis APK `1.0.5+6` (versionCode 2006): GitHub Release
  `v1.0.5-apk-20261024` (3 APK + AAB + `SHA256SUMS.txt`, signed) + mirror
  `/apk/` di GitHub Pages (gh-pages `e65d39e`).
- CATATAN: balasan Dokter masih 40-60 dtk (tool loop EF). Pesan kedua yang
  dikirim saat `_loading` masih ditahan (belum dikirim) - kandidat perbaikan
  berikutnya (antrean pesan / indikator progres).

## CATATAN
- Cron `pg_cron`/`pg_net` TIDAK terpasang di DB live -> observasi via EF `doctor_observe`
  (tombol admin / Supabase Dashboard Scheduled Functions).
- `web_cache` tabel + preset `open_sources` (BMKG/kurs/RSS) DITUNDA (opsional;
  fetch_url generik sudah menutup kebutuhan dasar).
- Rate limit: 60 pesan / 200000 token per hari (default global; bisa override per outlet
  atau unlimited).
- `flutter_animate` tidak di pubspec; animasi memakai widget bawaan (TweenAnimationBuilder).
