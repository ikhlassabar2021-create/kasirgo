-- ============================================================================
-- KasirGo — Customer QR Order (dine-in) TANPA LOGIN
-- Tanggal: 2026-09-28
--
-- Tujuan:
--   Pelanggan scan QR meja -> lihat menu -> kirim pesanan.
--   Pelanggan TIDAK punya akun, jadi akses lewat fungsi SECURITY DEFINER
--   (bypass RLS secara aman & terbatas), bukan membuka tabel ke anon.
--
-- CARA PAKAI:
--   Supabase Dashboard -> SQL Editor -> New query -> tempel semua -> RUN.
-- Aman dijalankan berulang (idempotent).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) Menu publik satu outlet (hanya produk stok > 0, field aman saja)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_public_menu(p_outlet TEXT)
RETURNS TABLE (
  id UUID,
  name TEXT,
  category TEXT,
  price NUMERIC,
  stock NUMERIC,
  unit TEXT
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p.id, p.name, p.category, p.base_price, p.stock, p.unit
  FROM public.products p
  WHERE p.outlet_id = p_outlet::uuid
    AND p.stock > 0
  ORDER BY p.name;
$$;

GRANT EXECUTE ON FUNCTION public.get_public_menu(TEXT) TO anon, authenticated;

-- ----------------------------------------------------------------------------
-- 1b) Cari outlet publik dari ID atau nama (untuk pelanggan anonim)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_public_outlet(p_code TEXT)
RETURNS TABLE (id UUID, name TEXT, type TEXT)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT o.id, o.name, o.type
  FROM public.outlets o
  WHERE o.id::text = p_code
     OR lower(o.name) = lower(p_code)
  ORDER BY (o.id::text = p_code) DESC
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.get_public_outlet(TEXT) TO anon, authenticated;

-- ----------------------------------------------------------------------------
-- 2) Simpan pesanan dine-in dari pelanggan (hitung harga di server)
--    p_items contoh: [{"product_id":"...","quantity":2}, ...]
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.place_dine_in_order(
  p_outlet TEXT,
  p_table TEXT,
  p_items JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_outlet UUID;
  v_tx UUID;
  v_total NUMERIC := 0;
  v_item JSONB;
  v_pid UUID;
  v_qty INT;
  v_price NUMERIC;
  v_pname TEXT;
BEGIN
  v_outlet := p_outlet::uuid;

  IF NOT EXISTS (SELECT 1 FROM public.outlets o WHERE o.id = v_outlet) THEN
    RAISE EXCEPTION 'Outlet tidak ditemukan';
  END IF;

  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array'
     OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Pesanan kosong';
  END IF;

  -- Hitung total memakai harga di database (anti manipulasi dari klien)
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_pid := NULLIF(v_item->>'product_id', '')::uuid;
    v_qty := COALESCE((v_item->>'quantity')::int, 0);
    IF v_pid IS NULL OR v_qty <= 0 THEN
      RAISE EXCEPTION 'Item pesanan tidak valid';
    END IF;
    SELECT p.base_price INTO v_price
      FROM public.products p
      WHERE p.id = v_pid AND p.outlet_id = v_outlet;
    IF v_price IS NULL THEN
      RAISE EXCEPTION 'Produk tidak ditemukan di outlet ini';
    END IF;
    v_total := v_total + (v_price * v_qty);
  END LOOP;

  INSERT INTO public.transactions (
    outlet_id, user_id, customer_id, channel, payment_method,
    total_amount, total_discount, final_amount, status, created_at
  ) VALUES (
    v_outlet, NULL, NULL, 'dine_in', 'cash',
    v_total, 0, v_total, 'completed', now()
  )
  RETURNING id INTO v_tx;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_pid := (v_item->>'product_id')::uuid;
    v_qty := (v_item->>'quantity')::int;
    SELECT p.base_price, p.name INTO v_price, v_pname
      FROM public.products p WHERE p.id = v_pid;
    INSERT INTO public.transaction_items (
      transaction_id, product_id, product_name, quantity,
      unit_price, discount, subtotal
    ) VALUES (
      v_tx, v_pid, v_pname, v_qty, v_price, 0, v_price * v_qty
    );
  END LOOP;

  RETURN v_tx;
END;
$$;

GRANT EXECUTE ON FUNCTION public.place_dine_in_order(TEXT, TEXT, JSONB) TO anon, authenticated;

-- ============================================================================
-- VERIFIKASI:
--   Owner buka QR Meja -> pelanggan scan -> pilih menu -> Pesan.
--   Cek di kasir/laporan: muncul transaksi channel 'dine_in'.
-- ============================================================================
