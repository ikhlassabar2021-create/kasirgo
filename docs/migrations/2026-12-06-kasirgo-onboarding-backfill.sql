-- ============================================================================
-- KasirGo — Backfill produk contoh untuk outlet yang sudah ada tapi kosong.
-- Tanggal: 2026-12-06
-- Jalankan di: Supabase Dashboard -> SQL Editor (idempotent).
--
-- Hanya menyasar outlet yang BELUM punya produk sama sekali. Logika seeding
-- identik dengan trigger seed_sample_products_on_outlet (type-aware), sehingga
-- outlet jasa mendapat produk layanan (is_service), warung mendapat sembako, dst.
-- ============================================================================

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT o.id AS outlet_id, lower(COALESCE(o.type, 'warung')) AS t
    FROM public.outlets o
    WHERE NOT EXISTS (SELECT 1 FROM public.products p WHERE p.outlet_id = o.id)
  LOOP
    -- Makanan & minuman (Cafe / Restoran / Kedai Kopi)
    IF r.t IN ('cafe', 'restoran', 'kedai kopi') THEN
      INSERT INTO public.products (outlet_id, name, category, cost_price, base_price, stock, unit)
      VALUES
        (r.outlet_id, 'Kopi Susu', 'Contoh', 8000, 15000, 25, 'cup'),
        (r.outlet_id, 'Nasi Goreng', 'Contoh', 12000, 18000, 15, 'porsi'),
        (r.outlet_id, 'Es Teh Manis', 'Contoh', 3000, 5000, 30, 'gelas'),
        (r.outlet_id, 'Roti Bakar', 'Contoh', 8000, 12000, 20, 'porsi');

    -- Gerobak / kaki lima
    ELSIF r.t = 'gerobak' THEN
      INSERT INTO public.products (outlet_id, name, category, cost_price, base_price, stock, unit)
      VALUES
        (r.outlet_id, 'Air Mineral', 'Contoh', 3000, 5000, 50, 'btl'),
        (r.outlet_id, 'Gorengan', 'Contoh', 1000, 2000, 60, 'pcs'),
        (r.outlet_id, 'Kopi Sachet', 'Contoh', 2000, 4000, 40, 'sachet'),
        (r.outlet_id, 'Teh Botol', 'Contoh', 4000, 6000, 30, 'btl');

    -- Jasa / layanan (tanpa stok, is_service = true)
    ELSIF r.t = 'jasa' THEN
      INSERT INTO public.products (outlet_id, name, category, cost_price, base_price, stock, unit, is_service)
      VALUES
        (r.outlet_id, 'Jasa Antar (Contoh)', 'Contoh', 0, 10000, 0, 'kali', true),
        (r.outlet_id, 'Jasa Perbaikan (Contoh)', 'Contoh', 0, 25000, 0, 'kali', true);

    -- Warung Sembako / Madura / Kelontong / Minimarket + default 'warung'
    ELSIF r.t IN ('warung sembako', 'warung madura', 'kelontong', 'minimarket', 'warung') THEN
      INSERT INTO public.products (outlet_id, name, category, cost_price, base_price, stock, unit)
      VALUES
        (r.outlet_id, 'Beras 1kg', 'Contoh', 12000, 15000, 30, 'pcs'),
        (r.outlet_id, 'Minyak Goreng 1L', 'Contoh', 16000, 19000, 20, 'pcs'),
        (r.outlet_id, 'Indomie Goreng', 'Contoh', 3000, 4000, 40, 'pcs'),
        (r.outlet_id, 'Gula Pasir 1kg', 'Contoh', 14000, 17000, 15, 'pcs');

    -- Retail / Toko Baju / Apotek / Lainnya
    ELSE
      INSERT INTO public.products (outlet_id, name, category, cost_price, base_price, stock, unit)
      VALUES
        (r.outlet_id, 'Produk Contoh A', 'Contoh', 8000, 12000, 20, 'pcs'),
        (r.outlet_id, 'Produk Contoh B', 'Contoh', 12000, 18000, 15, 'pcs');
    END IF;
  END LOOP;
END $$;

-- ============================================================================
-- SELESAI
-- ============================================================================