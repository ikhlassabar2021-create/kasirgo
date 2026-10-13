-- ---------------------------------------------------------------------------
-- KasirGo - Pilihan Kurir pada Pesanan Online
-- Owner/kasir memilih siapa yang mengantar pesanan DIANTAR:
--   kurir_warung | grab | gojek
-- Disimpan di kolom `orders.courier` (TEXT, nullable). Pemilihan dilakukan
-- owner/kasir saat memproses pesanan (bukan pembeli). Idempotent.
-- ---------------------------------------------------------------------------

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS courier TEXT;

-- Batasi nilai yang diizinkan (nullable = belum dipilih).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'orders_courier_check'
  ) THEN
    ALTER TABLE public.orders
      ADD CONSTRAINT orders_courier_check
      CHECK (courier IS NULL OR courier IN ('kurir_warung', 'grab', 'gojek'));
  END IF;
END $$;

-- Realtime: pastikan perubahan kolom courier ikut terkirim (tabel sudah
-- terdaftar realtime sejak migrasi 17a; ALTER kolom tidak perlu republish).
