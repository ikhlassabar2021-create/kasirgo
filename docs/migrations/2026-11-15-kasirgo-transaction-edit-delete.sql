-- Item 7: Owner dapat MELIHAT DETAIL, MENGUBAH, dan MENGHAPUS transaksi
-- dari layar Laporan.
--
-- Alasan RPC (bukan langsung tabel): RLS `transactions` / `transaction_items`
-- hanya punya policy SELECT + INSERT (tanpa UPDATE/DELETE). Operasi tulis
-- dilakukan lewat RPC SECURITY DEFINER yang memvalidasi kepemilikan outlet,
-- menyesuaikan stok (produk/varian) dan mencatat jejak `stock_logs`
-- (reason 'koreksi'), lalu menghitung ulang total transaksi.

-- ===========================================================================
-- UPDATE: ubah metode bayar + quantity/harga item (opsional)
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.update_transaction(
  p_transaction UUID,
  p_payment_method TEXT DEFAULT NULL,
  p_items JSONB DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_outlet UUID;
  v_tx RECORD;
  v_item RECORD;
  v_new JSONB;
  v_new_qty NUMERIC;
  v_new_price NUMERIC;
  v_delta NUMERIC;
  v_new_total NUMERIC := 0;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  END IF;

  SELECT * INTO v_tx FROM public.transactions WHERE id = p_transaction FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'TRANSACTION_NOT_FOUND');
  END IF;
  v_outlet := v_tx.outlet_id;

  IF NOT (public.is_outlet_owner(v_outlet) OR public.is_platform_admin()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'FORBIDDEN');
  END IF;

  IF p_items IS NOT NULL THEN
    FOR v_new IN SELECT * FROM jsonb_array_elements(p_items) LOOP
      SELECT * INTO v_item FROM public.transaction_items
        WHERE id = (v_new->>'id')::uuid AND transaction_id = p_transaction FOR UPDATE;
      CONTINUE WHEN NOT FOUND;

      v_new_qty := COALESCE((v_new->>'quantity')::numeric, v_item.quantity);
      v_new_price := COALESCE((v_new->>'unit_price')::numeric, v_item.unit_price);
      IF v_new_qty <= 0 OR v_new_price < 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'INVALID_ITEM');
      END IF;

      -- delta > 0 berarti stok dikembalikan (item dikurangi).
      v_delta := v_item.quantity - v_new_qty;

      UPDATE public.transaction_items
         SET quantity = v_new_qty,
             unit_price = v_new_price,
             subtotal = (v_new_qty * v_new_price) - COALESCE(discount, 0)
       WHERE id = v_item.id;

      IF v_delta <> 0 THEN
        IF v_item.variant_id IS NOT NULL THEN
          UPDATE public.product_variants
             SET stock = stock + v_delta, updated_at = NOW()
           WHERE id = v_item.variant_id;
          INSERT INTO public.stock_logs
              (outlet_id, product_id, variant_id, change, reason, ref_id, note, user_id)
          SELECT pv.outlet_id, pv.product_id, pv.id, v_delta, 'koreksi',
                 p_transaction, 'Edit transaksi', v_uid
            FROM public.product_variants pv WHERE pv.id = v_item.variant_id;
        ELSE
          UPDATE public.products
             SET stock = stock + v_delta, updated_at = NOW()
           WHERE id = v_item.product_id;
          INSERT INTO public.stock_logs
              (outlet_id, product_id, change, reason, ref_id, note, user_id)
          VALUES (v_outlet, v_item.product_id, v_delta, 'koreksi',
                  p_transaction, 'Edit transaksi', v_uid);
        END IF;
      END IF;
    END LOOP;
  END IF;

  SELECT COALESCE(SUM(subtotal), 0) INTO v_new_total
    FROM public.transaction_items WHERE transaction_id = p_transaction;

  UPDATE public.transactions
     SET payment_method = COALESCE(p_payment_method, payment_method),
         total_amount = v_new_total,
         final_amount = v_new_total + COALESCE(delivery_pass_through, 0)
                        - COALESCE(total_discount, 0),
         product_revenue = CASE
             WHEN product_revenue IS NOT NULL OR COALESCE(delivery_pass_through, 0) > 0
               THEN v_new_total
             ELSE product_revenue
           END
   WHERE id = p_transaction;

  RETURN jsonb_build_object('success', true, 'transaction_id', p_transaction, 'total', v_new_total);
END;
$$;

-- ===========================================================================
-- DELETE: hapus transaksi + kembalikan stok tiap item
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.delete_transaction(p_transaction UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_outlet UUID;
  v_item RECORD;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  END IF;

  SELECT outlet_id INTO v_outlet FROM public.transactions WHERE id = p_transaction FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'TRANSACTION_NOT_FOUND');
  END IF;

  IF NOT (public.is_outlet_owner(v_outlet) OR public.is_platform_admin()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'FORBIDDEN');
  END IF;

  FOR v_item IN SELECT * FROM public.transaction_items WHERE transaction_id = p_transaction LOOP
    IF v_item.variant_id IS NOT NULL THEN
      UPDATE public.product_variants
         SET stock = stock + v_item.quantity, updated_at = NOW()
       WHERE id = v_item.variant_id;
      INSERT INTO public.stock_logs
          (outlet_id, product_id, variant_id, change, reason, ref_id, note, user_id)
      SELECT pv.outlet_id, pv.product_id, pv.id, v_item.quantity, 'koreksi',
             p_transaction, 'Hapus transaksi', v_uid
        FROM public.product_variants pv WHERE pv.id = v_item.variant_id;
    ELSE
      UPDATE public.products
         SET stock = stock + v_item.quantity, updated_at = NOW()
       WHERE id = v_item.product_id;
      INSERT INTO public.stock_logs
          (outlet_id, product_id, change, reason, ref_id, note, user_id)
      VALUES (v_outlet, v_item.product_id, v_item.quantity, 'koreksi',
              p_transaction, 'Hapus transaksi', v_uid);
    END IF;
  END LOOP;

  DELETE FROM public.transactions WHERE id = p_transaction;

  RETURN jsonb_build_object('success', true, 'transaction_id', p_transaction);
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_transaction(UUID, TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_transaction(UUID) TO authenticated;

-- ============================================================================
-- VERIFIKASI:
--   SELECT proname FROM pg_proc WHERE proname IN
--     ('update_transaction','delete_transaction');
-- ============================================================================
