-- ============================================================================
-- KasirGo — Alur bayar dine-in (konfirmasi kasir) + Katalog/Meja tersimpan DB
-- Tanggal: 2026-10-09
--
-- Isi:
--   1) transactions.payment_status ('unpaid' | 'paid') — pesanan dine-in
--      pelanggan lahir 'unpaid'; kasir konfirmasi -> 'paid' -> masuk KDS.
--   2) products.is_published — produk yang tampil di Katalog Online publik.
--   3) Tabel outlet_tables — daftar meja QR dikelola owner (tambah/hapus).
--   4) place_dine_in_order: hanya cash/qris (transfer bank dihapus) + unpaid.
--   5) RPC confirm_dinein_payment (kasir klik Bayar).
--   6) RPC get_public_catalog (katalog publik hanya produk is_published).
--
-- Aman dijalankan berulang (idempotent).
-- ============================================================================

-- 1) Status pembayaran pesanan --------------------------------------------
ALTER TABLE public.transactions
  ADD COLUMN IF NOT EXISTS payment_status TEXT NOT NULL DEFAULT 'paid';

-- 2) Publikasi produk ke katalog online ------------------------------------
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS is_published BOOLEAN NOT NULL DEFAULT false;

-- 3) Daftar meja per outlet (QR Meja Dine-in) ------------------------------
CREATE TABLE IF NOT EXISTS public.outlet_tables (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.outlet_tables ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Owner manage outlet tables" ON public.outlet_tables;
CREATE POLICY "Owner manage outlet tables" ON public.outlet_tables
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.outlets o
    WHERE o.id = outlet_tables.outlet_id AND o.owner_id = auth.uid()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.outlets o
    WHERE o.id = outlet_tables.outlet_id AND o.owner_id = auth.uid()
  ));

DROP POLICY IF EXISTS "Staff view outlet tables" ON public.outlet_tables;
CREATE POLICY "Staff view outlet tables" ON public.outlet_tables
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.user_roles ur
    WHERE ur.user_id = auth.uid() AND ur.outlet_id = outlet_tables.outlet_id
  ));

GRANT SELECT, INSERT, UPDATE, DELETE ON public.outlet_tables TO authenticated;

CREATE INDEX IF NOT EXISTS idx_outlet_tables_outlet
  ON public.outlet_tables(outlet_id, sort_order);

-- 4) place_dine_in_order: hanya cash/qris, lahir 'unpaid' -------------------
CREATE OR REPLACE FUNCTION public.place_dine_in_order(
  p_outlet TEXT,
  p_table TEXT,
  p_items JSONB,
  p_payment_method TEXT
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
  v_method TEXT;
BEGIN
  v_outlet := p_outlet::uuid;

  IF NOT EXISTS (SELECT 1 FROM public.outlets o WHERE o.id = v_outlet) THEN
    RAISE EXCEPTION 'Outlet tidak ditemukan';
  END IF;

  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array'
     OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Pesanan kosong';
  END IF;

  -- Transfer bank dihapus: hanya QRIS atau Tunai (kasir yang konfirmasi).
  v_method := CASE WHEN p_payment_method = 'qris' THEN 'qris' ELSE 'cash' END;

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
    outlet_id, user_id, customer_id, channel, payment_method, payment_status,
    total_amount, total_discount, final_amount, status, notes, order_status, created_at
  ) VALUES (
    v_outlet, NULL, NULL, 'dine_in', v_method, 'unpaid',
    v_total, 0, v_total, 'completed',
    'Meja ' || COALESCE(NULLIF(trim(p_table), ''), '-'),
    'baru', now()
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

GRANT EXECUTE ON FUNCTION public.place_dine_in_order(TEXT, TEXT, JSONB, TEXT) TO anon, authenticated;

-- Wrapper 3-arg (kompatibel klien lama).
CREATE OR REPLACE FUNCTION public.place_dine_in_order(
  p_outlet TEXT,
  p_table TEXT,
  p_items JSONB
)
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.place_dine_in_order(p_outlet, p_table, p_items, 'cash');
$$;

GRANT EXECUTE ON FUNCTION public.place_dine_in_order(TEXT, TEXT, JSONB) TO anon, authenticated;

-- 5) Konfirmasi bayar oleh kasir/owner -------------------------------------
CREATE OR REPLACE FUNCTION public.confirm_dinein_payment(p_tx UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.transactions t
    WHERE t.id = p_tx
      AND (
        EXISTS (SELECT 1 FROM public.outlets o WHERE o.id = t.outlet_id AND o.owner_id = auth.uid())
        OR EXISTS (
          SELECT 1 FROM public.user_roles r
          WHERE r.user_id = auth.uid()
            AND r.outlet_id = t.outlet_id
            AND r.role IN ('admin', 'cashier')
        )
      )
  ) THEN
    RAISE EXCEPTION 'Tidak berhak mengonfirmasi pesanan ini';
  END IF;

  UPDATE public.transactions
     SET payment_status = 'paid'
   WHERE id = p_tx AND channel = 'dine_in';
END;
$$;

GRANT EXECUTE ON FUNCTION public.confirm_dinein_payment(UUID) TO authenticated;

-- 6) Katalog online publik: hanya produk yang owner publikasikan -----------
CREATE OR REPLACE FUNCTION public.get_public_catalog(p_outlet TEXT)
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
    AND p.is_published = true
    AND p.stock > 0
  ORDER BY p.name;
$$;

GRANT EXECUTE ON FUNCTION public.get_public_catalog(TEXT) TO anon, authenticated;

-- ============================================================================
-- VERIFIKASI:
--   1) Pesanan pelanggan -> payment_status 'unpaid' (belum ke KDS).
--   2) Kasir klik "Konfirmasi Bayar" (RPC confirm_dinein_payment) -> 'paid'
--      -> pesanan tampil di KDS dapur.
--   3) Owner toggle produk di Katalog Online -> kolom products.is_published.
--   4) Daftar meja QR tersimpan di tabel outlet_tables.
-- ============================================================================
