-- ============================================================================
-- KasirGo — place_dine_in_order: tambah metode pembayaran (opsional)
-- Tanggal: 2026-09-29
--
-- Tujuan:
--   Pelanggan memilih metode pembayaran (Tunai / QRIS) saat konfirmasi.
--   Fungsi 4-arg dipakai app versi baru; fungsi 3-arg tetap ada (kompatibilitas)
--   dan hanya memanggil fungsi 4-arg dengan 'cash'.
--
-- CARA PAKAI:
--   Supabase Dashboard -> SQL Editor -> New query -> tempel semua -> RUN.
-- Aman dijalankan berulang (idempotent).
-- ============================================================================

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
    v_outlet, NULL, NULL, 'dine_in', v_method,
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

GRANT EXECUTE ON FUNCTION public.place_dine_in_order(TEXT, TEXT, JSONB, TEXT) TO anon, authenticated;

-- Fungsi lama (3-arg) diarahkan ke versi baru agar app lama tetap jalan.
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
