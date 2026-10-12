-- ============================================================================
-- KasirGo - Hardening Validasi Pembayaran Pesanan Online (anti dobel)
-- Tanggal: 2026-11-06
--
-- Masalah:
--   Ketika banyak pesanan menumpuk, kasir bisa menekan "Pembayaran Valid &
--   Proses" / "Selesai" lebih dari sekali (tap ganda atau realtime reload).
--   RPC lama `validate_order_payment` selalu meng-UPDATE tanpa cek status, dan
--   `complete_order` bisa membuat DUA transaksi bila dipanggil bersamaan
--   (keduanya lolos cek `status <> 'selesai'`).
--
-- Perbaikan:
--   1. validate_order_payment: kunci baris (FOR UPDATE) + idempoten (bila sudah
--      divalidasi -> success/idempotent) + tolak validasi ulang pesanan final.
--   2. complete_order: kunci baris (FOR UPDATE) agar hanya SATU transaksi dibuat
--      walau dipanggil bersamaan; tetap idempoten.
--
-- Aman dijalankan berulang (idempotent).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1) validate_order_payment - kunci baris + state-aware + idempoten
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.validate_order_payment(p_order uuid, p_accept boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_outlet UUID;
  v_status TEXT;
  v_payment TEXT;
BEGIN
  SELECT outlet_id, status, payment_status
    INTO v_outlet, v_status, v_payment
    FROM public.orders
    WHERE id = p_order
    FOR UPDATE;

  IF v_outlet IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'ORDER_NOT_FOUND');
  END IF;
  IF NOT (public.is_outlet_member(v_outlet) OR public.is_platform_admin()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'FORBIDDEN');
  END IF;

  -- Idempoten: sudah divalidasi & diproses -> jangan gandakan.
  IF p_accept AND v_payment = 'divalidasi' AND v_status IN ('diproses', 'siap') THEN
    RETURN jsonb_build_object('success', true, 'idempotent', true, 'accepted', true);
  END IF;

  -- Idempoten: sudah ditolak -> jangan gandakan.
  IF NOT p_accept AND v_payment = 'ditolak' AND v_status = 'dibatalkan' THEN
    RETURN jsonb_build_object('success', true, 'idempotent', true, 'accepted', false);
  END IF;

  -- Sudah final (selesai/dibatalkan) -> tidak boleh divalidasi ulang.
  IF v_status IN ('selesai', 'dibatalkan') THEN
    RETURN jsonb_build_object('success', false, 'error', 'ALREADY_FINALIZED');
  END IF;

  IF p_accept THEN
    UPDATE public.orders
      SET payment_status = 'divalidasi', status = 'diproses',
          validated_by = auth.uid(), validated_at = NOW(), updated_at = NOW()
      WHERE id = p_order;
  ELSE
    UPDATE public.orders
      SET payment_status = 'ditolak', status = 'dibatalkan',
          validated_by = auth.uid(), validated_at = NOW(), updated_at = NOW()
      WHERE id = p_order;
  END IF;

  RETURN jsonb_build_object('success', true, 'accepted', p_accept);
END; $function$;

-- ---------------------------------------------------------------------------
-- 2) complete_order - kunci baris agar transaksi tidak dobel saat bersamaan
-- ---------------------------------------------------------------------------
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

  SELECT id INTO v_customer FROM public.customers
    WHERE outlet_id = v_ord.outlet_id AND phone_wa = v_ord.buyer_phone LIMIT 1;

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

  RETURN jsonb_build_object('success', true, 'transaction_id', v_tx, 'total', v_ord.total);
END; $function$;

GRANT EXECUTE ON FUNCTION public.validate_order_payment(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_order(uuid) TO authenticated;

-- ============================================================================
-- VERIFIKASI:
--   Kasir: Pesanan Online -> tap "Pembayaran Valid & Proses" 2x cepat ->
--   kedua balasan success, hanya SATU perubahan; tap pada pesanan selesai ->
--   error ALREADY_FINALIZED. "Selesai" 2x -> hanya SATU transaksi.
-- ============================================================================
