-- ============================================================================
-- KasirGo - Item 6: Pesanan online selesai -> simpan pembeli ke daftar pelanggan
-- ============================================================================
-- Tujuan:
--   Saat pesanan online diselesaikan (complete_order), pembeli otomatis
--   dicatat ke tabel `customers` outlet (bila belum ada). Bila sudah ada
--   (dicocokkan lewat nomor WA), total belanja (produk, bukan titipan ongkir)
--   ditambahkan.
--
-- Idempoten: pembuatan/penambahan pelanggan HANYA terjadi saat transaksi
--   pertama dibuat (guard idempoten status='selesai' di atas).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.complete_order(p_order uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_ord RECORD;
  v_tx UUID;
  v_customer UUID;
  v_it RECORD;
BEGIN
  SELECT * INTO v_ord FROM public.orders WHERE id = p_order FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'ORDER_NOT_FOUND');
  END IF;
  IF NOT (public.is_outlet_member(v_ord.outlet_id) OR public.is_platform_admin()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'FORBIDDEN');
  END IF;

  -- Idempoten: sudah selesai & transaksi ada -> kembalikan yang sama.
  IF v_ord.status = 'selesai' AND v_ord.transaction_id IS NOT NULL THEN
    RETURN jsonb_build_object('success', true, 'idempotent', true, 'transaction_id', v_ord.transaction_id);
  END IF;
  IF v_ord.payment_status <> 'divalidasi' THEN
    RETURN jsonb_build_object('success', false, 'error', 'PAYMENT_NOT_VALIDATED');
  END IF;

  -- Cari pelanggan outlet berdasarkan nomor WA pembeli.
  SELECT id INTO v_customer FROM public.customers
    WHERE outlet_id = v_ord.outlet_id AND phone_wa = v_ord.buyer_phone LIMIT 1;

  IF v_customer IS NULL
     AND v_ord.buyer_phone IS NOT NULL
     AND btrim(v_ord.buyer_phone) <> '' THEN
    INSERT INTO public.customers (outlet_id, name, phone_wa, total_spent)
    VALUES (
      v_ord.outlet_id,
      COALESCE(NULLIF(btrim(v_ord.buyer_name), ''), 'Pembeli Online'),
      v_ord.buyer_phone,
      v_ord.subtotal
    )
    RETURNING id INTO v_customer;
  ELSIF v_customer IS NOT NULL THEN
    UPDATE public.customers
      SET total_spent = COALESCE(total_spent, 0) + v_ord.subtotal
      WHERE id = v_customer;
  END IF;

  INSERT INTO public.transactions (
    outlet_id, user_id, customer_id, channel, payment_method,
    total_amount, total_discount, final_amount, status,
    order_status, payment_status, notes, paid_at,
    gross_amount, product_revenue, delivery_pass_through, order_id
  ) VALUES (
    v_ord.outlet_id, auth.uid(), v_customer, 'online', 'qris',
    v_ord.subtotal, 0, v_ord.total, 'completed',
    'selesai', 'paid', 'Pesanan online ' || COALESCE(v_ord.code,''), NOW(),
    v_ord.total, v_ord.subtotal, v_ord.delivery_fee, p_order
  ) RETURNING id INTO v_tx;

  FOR v_it IN SELECT * FROM public.order_items WHERE order_id = p_order LOOP
    INSERT INTO public.transaction_items (
      transaction_id, product_id, product_name, quantity, unit_price, discount, subtotal
    ) VALUES (
      v_tx, v_it.product_id, v_it.name_snapshot, v_it.qty, v_it.price_snapshot, 0, v_it.line_total
    );
  END LOOP;

  UPDATE public.orders
    SET status = 'selesai', transaction_id = v_tx, updated_at = NOW()
    WHERE id = p_order;

  RETURN jsonb_build_object(
    'success', true,
    'transaction_id', v_tx,
    'customer_id', v_customer,
    'total', v_ord.total
  );
END; $function$;

GRANT EXECUTE ON FUNCTION public.complete_order(uuid) TO authenticated;
