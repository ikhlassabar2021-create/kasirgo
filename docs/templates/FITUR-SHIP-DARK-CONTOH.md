# Template: Rilis Fitur Tanpa Mengganggu App yang Sedang Berjalan

Prinsip dasarnya: **kode fitur ikut di-build ke APK/web dalam keadaan MATI**,
lalu visibilitasnya dikontrol 100% dari server (`feature_flags` atau Program
Pendukung). Begitu flag dinyalakan, HP langsung menampilkan fitur **tanpa
update** (app membaca flag offline-first, cache 5 menit, fallback default).

Contoh di bawah memakai fitur "Catatan Stok Cepat" agar mudah diikuti.

---

## Kasus 1 — Fitur GRATIS, nyala-mati murni dari server

### 1a. Buat layarnya (tetap di-build, tapi belum ada pintu masuk)

`kasirgo/lib/screens/owner/quick_stock_note_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';

class QuickStockNoteScreen extends ConsumerStatefulWidget {
  const QuickStockNoteScreen({super.key});

  @override
  ConsumerState<QuickStockNoteScreen> createState() =>
      _QuickStockNoteScreenState();
}

class _QuickStockNoteScreenState extends ConsumerState<QuickStockNoteScreen> {
  final List<String> _notes = [];

  Future<void> _addNote() async {
    final ctrl = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Catatan'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (value != null && value.isNotEmpty && mounted) {
      setState(() => _notes.add(value));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Catatan Stok Cepat')),
      body: _notes.isEmpty
          ? const Center(
              child: Text('Belum ada catatan.',
                  style: TextStyle(color: AppTheme.textSecondary)))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _notes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => Card(
                child: ListTile(leading: const Icon(Icons.sticky_note_2_rounded),
                    title: Text(_notes[i])),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'quick_stock_note_fab',
        onPressed: _addNote,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Catatan'),
      ),
    );
  }
}
```

### 1b. Gate flag (bukan premium) via `outletFlagsProvider`

Flag non-modul dibaca dari map yang dikembalikan `feature_flags_for_outlet`.
Gunakan provider yang sudah ada:

```dart
// kasirgo/lib/providers/module_provider.dart sudah punya:
//   final outletFlagsProvider =
//       FutureProvider.family<Map<String, bool>, String>(
//           (ref, outletId) => ModuleRegistry.loadFlagsForOutlet(outletId));
```

Di tempat entry point (mis. kartu beranda owner):

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/module_provider.dart';
import '../../screens/owner/quick_stock_note_screen.dart';

Widget _quickStockNoteCard(BuildContext context, WidgetRef ref, String outletId) {
  final flags =
      ref.watch(outletFlagsProvider(outletId)).asData?.value ?? const {};
  final enabled = flags['quick_stock_note'] ?? false;
  if (!enabled) return const SizedBox.shrink(); // tersembunyi total
  return Card(
    child: ListTile(
      leading: const Icon(Icons.sticky_note_2_rounded),
      title: const Text('Catatan Stok Cepat'),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const QuickStockNoteScreen())),
    ),
  );
}
```

> Bila flag `enabled=false` atau `rollout_pct=0`, kartu tidak pernah muncul.
> Begitu flag dinyalakan, kartu muncul di HP **tanpa update APK**.

### 1c. Migrasi SQL (aditif, default MATI)

Simpan ke `docs/migrations/2026-11-08-kasirgo-contoh-quick-stock-note.sql`
(`*.sql` di `docs/migrations/` otomatis tidak di-ignore):

```sql
-- Fitur ship-dark "Catatan Stok Cepat". Default OFF, rollout 0%.
INSERT INTO public.feature_flags (key, enabled, rollout_pct, outlet_types, segments)
VALUES ('quick_stock_note', false, 0, '[]'::jsonb, '[]'::jsonb)
ON CONFLICT (key) DO NOTHING;
```

Terapkan sekali ke Supabase (management API / psql / SQL editor).

### 1d. Rollout bertahap (tanpa build ulang)

```sql
-- Canary: 10% outlet (hash stabil, jadi konsisten per outlet).
UPDATE public.feature_flags SET enabled = true, rollout_pct = 10
WHERE key = 'quick_stock_note';

-- Perluas ke 50%, lalu 100% setelah stabil.
UPDATE public.feature_flags SET rollout_pct = 50 WHERE key = 'quick_stock_note';
UPDATE public.feature_flags SET rollout_pct = 100 WHERE key = 'quick_stock_note';

-- Batasi hanya tipe usaha tertentu bila perlu.
UPDATE public.feature_flags
SET outlet_types = '["kelontong","retail"]'::jsonb
WHERE key = 'quick_stock_note';

-- Rollback darurat (mati total) kapan saja.
UPDATE public.feature_flags SET enabled = false WHERE key = 'quick_stock_note';
```

---

## Kasus 2 — Fitur PREMIUM (Program Pendukung)

Bila fitur terkunci paket berbayar, gunakan mekanisme yang sudah ada.

### 2a. Daftarkan fitur

`kasirgo/lib/services/supporter_service.dart` — tambah ke dua daftar:

```dart
static const Set<String> premiumFeatures = {
  // ...baris lain...
  'quick_stock_note',
};

static const Map<String, String> featureLabels = {
  // ...baris lain...
  'quick_stock_note': 'Catatan Stok Cepat',
};
```

### 2b. Gate tombol aksi (menampilkan dialog upgrade bila terkunci)

```dart
if (!await requireSupporterFeature(context, ref, 'quick_stock_note')) return;
// buka QuickStockNoteScreen
```

### 2c. Gate satu layar penuh

```dart
SupporterFeatureGate(
  featureKey: 'quick_stock_note',
  child: const QuickStockNoteScreen(),
)
```

`SupporterFeatureGate` menampilkan layar terkunci (tombol Trial/Upgrade) bila
belum berlangganan, dan membuka layar langsung bila sudah — data lama tidak
dihapus.

---

## Daftar periksa deploy fitur baru

1. [ ] Kode fitur masuk ke `main`, **tanpa** entry point yang langsung terlihat (atau di-gate).
2. [ ] Migration SQL **aditif + idempoten** (`IF NOT EXISTS` / `ON CONFLICT DO NOTHING`) diterapkan.
3. [ ] Flag `feature_flags` (atau `premiumFeatures`) disiapkan dengan `enabled=false` / `rollout_pct=0`.
4. [ ] Web/admin di-deploy (instan); APK di-build via `release-apk.yml` (tag `v*`, bertahap) — flag tetap OFF.
5. [ ] Naikkan `rollout_pct` bertahap (10 → 50 → 100), pantau error.
6. [ ] Setelah stabil penuh, bersihkan cabang flag usang.

> Web/PWA: push `main` memicu `deploy-web.yml` — pengguna cukup refresh.
> APK: flag yang sudah ada di APK tidak butuh rilis; kode baru butuh tag `v*`.