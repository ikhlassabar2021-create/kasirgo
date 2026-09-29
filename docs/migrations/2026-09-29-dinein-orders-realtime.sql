-- ============================================================================
-- KasirGo — Pesanan Dine-in Masuk untuk Kasir/Dapur (Realtime + item)
-- Tanggal: 2026-09-29
--
-- Tujuan:
--   1) Simpan nomor meja ke transactions.notes.
--   2) Kolom order_status untuk progres dapur (baru/diproses/siap/selesai).
--   3) RPC set_order_status (kasir/owner).
--   4) Aktifkan Supabase Realtime pada tabel transactions.
--
-- CARA PAKAI:
--   Supabase Dashboard -> SQL Editor -> New query -> tempel semua -> RUN.
-- Aman dijalankan berulang (idempotent).
-- ============================================================================

-- 1) Kolom tambahan -------------------------------------------------------
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS order_status TEXT DEFAULT 'baru';

-- 2) place_dine_in_order: simpan nomor meja ke notes ----------------------
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

  v_method := CASE
    WHEN p_payment_method IN ('qris', 'bank_transfer') THEN p_payment_method
    ELSE 'cash'
  END;

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
    total_amount, total_discount, final_amount, status, notes, order_status, created_at
  ) VALUES (
    v_outlet, NULL, NULL, 'dine_in', v_method,
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

-- 3) RPC ubah status pesanan (kasir/owner) --------------------------------
CREATE OR REPLACE FUNCTION public.set_order_status(p_tx UUID, p_status TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_status NOT IN ('baru', 'diproses', 'siap', 'selesai') THEN
    RAISE EXCEPTION 'Status tidak valid';
  END IF;

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
    RAISE EXCEPTION 'Tidak berhak mengubah pesanan ini';
  END IF;

  UPDATE public.transactions SET order_status = p_status WHERE id = p_tx;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_order_status(UUID, TEXT) TO authenticated;

-- 4) Aktifkan Realtime untuk transactions ---------------------------------
ALTER TABLE public.transactions REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime')
     AND NOT EXISTS (
       SELECT 1 FROM pg_publication_tables
       WHERE pubname = 'supabase_realtime'
         AND schemaname = 'public'
         AND tablename = 'transactions'
     )
  THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.transactions';
  END IF;
END $$;

-- ============================================================================
-- VERIFIKASI:
--   Pelanggan kirim pesanan -> kasir (menu Pesanan Masuk) langsung menerima
--   tanpa refresh; item + nomor meja + metode bayar tampil.
-- ============================================================================
