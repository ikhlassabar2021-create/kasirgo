-- ============================================================================
-- KasirGo — Onboarding anti-bingung: seed produk contoh saat outlet baru dibuat.
-- Tanggal: 2026-12-06
-- Jalankan di: Supabase Dashboard -> SQL Editor (idempotent).
--
-- Saat pemilik mendaftar, trigger handle_new_user membuat outlet baru. Trigger
-- ini (AFTER INSERT ON outlets) otomatis mengisi beberapa produk contoh
-- (category = 'Contoh') sesuai tipe usaha, sehingga POS tidak kosong dan
-- pemilik bisa langsung mencoba transaksi tanpa mengisi apa pun terlebih dahulu.
--
-- Produk contoh ditandai kategori 'Contoh' agar mudah dikenali dan dihapus
-- sekaligus lewat tombol "Hapus produk contoh" di beranda.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.seed_sample_products_on_outlet()
RETURNS TRIGGER AS $$
DECLARE
  v_type text := lower(COALESCE(NEW.type, 'warung'));
BEGIN
  -- Makanan & minuman (Cafe / Restoran / Kedai Kopi)
  IF v_type IN ('cafe', 'restoran', 'kedai kopi') THEN
    INSERT INTO public.products (outlet_id, name, category, cost_price, base_price, stock, unit)
    VALUES
      (NEW.id, 'Kopi Susu', 'Contoh', 8000, 15000, 25, 'cup'),
      (NEW.id, 'Nasi Goreng', 'Contoh', 12000, 18000, 15, 'porsi'),
      (NEW.id, 'Es Teh Manis', 'Contoh', 3000, 5000, 30, 'gelas'),
      (NEW.id, 'Roti Bakar', 'Contoh', 8000, 12000, 20, 'porsi');

  -- Gerobak / kaki lima
  ELSIF v_type = 'gerobak' THEN
    INSERT INTO public.products (outlet_id, name, category, cost_price, base_price, stock, unit)
    VALUES
      (NEW.id, 'Air Mineral', 'Contoh', 3000, 5000, 50, 'btl'),
      (NEW.id, 'Gorengan', 'Contoh', 1000, 2000, 60, 'pcs'),
      (NEW.id, 'Kopi Sachet', 'Contoh', 2000, 4000, 40, 'sachet'),
      (NEW.id, 'Teh Botol', 'Contoh', 4000, 6000, 30, 'btl');

  -- Jasa / layanan (tanpa stok, is_service = true)
  ELSIF v_type = 'jasa' THEN
    INSERT INTO public.products (outlet_id, name, category, cost_price, base_price, stock, unit, is_service)
    VALUES
      (NEW.id, 'Jasa Antar (Contoh)', 'Contoh', 0, 10000, 0, 'kali', true),
      (NEW.id, 'Jasa Perbaikan (Contoh)', 'Contoh', 0, 25000, 0, 'kali', true);

  -- Warung Sembako / Madura / Kelontong / Minimarket + default 'warung'
  ELSIF v_type IN ('warung sembako', 'warung madura', 'kelontong', 'minimarket', 'warung') THEN
    INSERT INTO public.products (outlet_id, name, category, cost_price, base_price, stock, unit)
    VALUES
      (NEW.id, 'Beras 1kg', 'Contoh', 12000, 15000, 30, 'pcs'),
      (NEW.id, 'Minyak Goreng 1L', 'Contoh', 16000, 19000, 20, 'pcs'),
      (NEW.id, 'Indomie Goreng', 'Contoh', 3000, 4000, 40, 'pcs'),
      (NEW.id, 'Gula Pasir 1kg', 'Contoh', 14000, 17000, 15, 'pcs');

  -- Retail / Toko Baju / Apotek / Lainnya
  ELSE
    INSERT INTO public.products (outlet_id, name, category, cost_price, base_price, stock, unit)
    VALUES
      (NEW.id, 'Produk Contoh A', 'Contoh', 8000, 12000, 20, 'pcs'),
      (NEW.id, 'Produk Contoh B', 'Contoh', 12000, 18000, 15, 'pcs');
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public';

DROP TRIGGER IF EXISTS trg_seed_sample_products ON public.outlets;
CREATE TRIGGER trg_seed_sample_products
  AFTER INSERT ON public.outlets
  FOR EACH ROW EXECUTE FUNCTION public.seed_sample_products_on_outlet();

-- ============================================================================
-- (Opsional) Backfill untuk outlet yang sudah ada tapi masih kosong.
-- Dikomentari default agar tidak mengubah data test yang sudah ada.
-- Jalankan manual bila ingin outlet lama juga mendapat produk contoh.
-- ============================================================================
-- DO $$
-- DECLARE r RECORD;
-- BEGIN
--   FOR r IN
--     SELECT o.id, o.type AS t
--     FROM public.outlets o
--     WHERE NOT EXISTS (SELECT 1 FROM public.products p WHERE p.outlet_id = o.id)
--   LOOP
--     INSERT INTO public.products (outlet_id, name, category, cost_price, base_price, stock, unit)
--     SELECT r.id, s.name, 'Contoh', s.cost_price, s.base_price, s.stock, s.unit
--     FROM (VALUES
--       ('Produk Contoh A', 8000::numeric, 12000::numeric, 20::numeric, 'pcs'),
--       ('Produk Contoh B', 12000::numeric, 18000::numeric, 15::numeric, 'pcs')
--     ) AS s(name, cost_price, base_price, stock, unit);
--   END LOOP;
-- END $$;

-- ============================================================================
-- SELESAI
-- ============================================================================