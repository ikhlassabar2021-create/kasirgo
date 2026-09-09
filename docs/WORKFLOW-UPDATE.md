# WORKFLOW UPDATE TERAKHIR -- KasirGo

> STATUS: Phase 0-1 SELESAI. Phase 2 SEDANG DIKERJAKAN. AGENTS.md = memori proyek (auto-load tiap session/reset).

---

## 1. PERSIAPAN (sekali saja)

Upload ke **root folder project** di MonkeyCode (folder tempat `.git` berada):
- `AGENTS.md` -- memori proyek (auto-load tiap session/reset)
- `docs/MONKEYCODE-WORKFLOW.md` -- berisi prompt lengkap semua Phase

Download dari `/workspace`, pastikan versi terbaru (sudah dikoreksi).

---

## 2. CARA KERJA: SATU SESSION = SATU PHASE

```
1. Buka session/task baru MonkeyCode
2. Paste instruksi awal (sesuai phase yang dikerjakan)
3. AI baca AGENTS.md -> paham konteks & progress -> cek git log --oneline
4. Kerjakan phase, PUSH tiap 1-2 file selesai (save point)
5. Test live (cek Test Check di workflow doc)
6. Update checklist Progress Tracker di AGENTS.md
7. Commit + push. Reset context. Selesai.
```

---

## 3. INSTRUKSI AWAL per KONDISI

**Jika masih di tengah Phase 2 (resume):**
```
=== KASIRGO: Aplikasi kasir UMKM (Flutter mobile + Supabase + React superadmin). 3 role: Owner (full), Admin (CRUD produk), Cashier (POS only). 3 paket: Gratis (500 tx/produk+iklan), 25rb (unlimited+barcode), 50rb (WA+social commerce+QR meja). AI Co-Pilot gratis local compute. Glassmorphism: #4F46E5 #7C3AED #06B6D4. Font Inter. Offline-first: SQLite lokal sync Supabase. 13 tabel DB+RLS. ===
Baca AGENTS.md di root project. Proyek sedang di Phase 2 (Flutter app shell + auth + offline engine). Cek git log --oneline -10 dan file yang sudah ada. Lanjutkan Phase 2 dari titik terakhir sesuai bagian "PHASE 2" di docs/MONKEYCODE-WORKFLOW.md. Push tiap 1-2 file, JANGAN tunggu semua selesai.
```

**Jika mulai Phase baru (3-8):**
```
=== KASIRGO: Aplikasi kasir UMKM (Flutter mobile + Supabase + React superadmin). 3 role: Owner (full), Admin (CRUD produk), Cashier (POS only). 3 paket: Gratis (500 tx/produk+iklan), 25rb (unlimited+barcode), 50rb (WA+social commerce+QR meja). AI Co-Pilot gratis local compute. Glassmorphism: #4F46E5 #7C3AED #06B6D4. Font Inter. Offline-first: SQLite lokal sync Supabase. 13 tabel DB+RLS. ===
Baca AGENTS.md di root project. Kerjakan prompt Phase [X] di docs/MONKEYCODE-WORKFLOW.md. Push tiap 1-2 file, JANGAN tunggu semua selesai.
```

---

## 4. ATURAN PUSH (JANGAN TUNGGU AKHIR PHASE)

```
SETIAP selesai 1-2 file:
  git add . && git commit -m "progress: [nama file]" && git push
```

Session mati sebelum push = code hilang. Push = save point.

---

## 5. KENA LIMIT CONTEXT

| Kondisi | Aksi |
|---------|------|
| Lanjut phase / session baru | **Reset context** -- AGENTS.md auto-muat ulang, langsung siap |
| Tengah debug 1 bug rumit | **Compact** dulu, selesaikan, baru reset |
| Task mati | Task baru, paste instruksi awal, AI baca git log + AGENTS.md |

Reset > Compact. Compact hasilnya lossy (ada detail hilang), hanya untuk debug bug rumit.

---

## 6. PROGRESS TRACKER (update di AGENTS.md tiap phase selesai)

```
[x] Phase 0: Design docs + PRD + workflow
[x] Phase 1: Supabase DB + Auth
[ ] Phase 2: Flutter app shell + auth + offline engine   <-- SEDANG DIKERJAKAN
[ ] Phase 3: Produk + POS + QRIS + AI Co-Pilot
[ ] Phase 4: Laporan + pelanggan + karyawan
[ ] Phase 5: Premium features + subscription gate
[ ] Phase 6: WhatsApp + social commerce + QR meja + health score
[ ] Phase 7: Superadmin web (React + Vercel)
[ ] Phase 8: Polish + testing + final deploy
```

---

## REFERENSI FILE

- `/workspace/AGENTS.md` -- memori proyek (upload ke root folder task baru)
- `/workspace/docs/MONKEYCODE-WORKFLOW.md` -- prompt lengkap Phase 1-8 + Test Check (upload ke root/docs/ di task baru)
