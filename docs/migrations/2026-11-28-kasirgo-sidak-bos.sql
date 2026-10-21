-- Sidak Bos (audit internal stok & kas) - BAGIAN 13.24 #2.
-- Fitur Bos Virtual: owner memeriksa kecocokan stok sistem vs hitung fisik
-- dan kas seharusnya vs uang di laci, lalu menyimpan temuan.
-- Semua ADITIF + idempotent.

-- 1. Sesi sidak (satu pemeriksaan).
CREATE TABLE IF NOT EXISTS public.sidak_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  kind TEXT NOT NULL DEFAULT 'lengkap'
    CHECK (kind IN ('stok', 'kas', 'lengkap')),
  status TEXT NOT NULL DEFAULT 'selesai'
    CHECK (status IN ('draft', 'selesai')),
  period_from TIMESTAMPTZ NOT NULL DEFAULT date_trunc('day', now()),
  period_to TIMESTAMPTZ NOT NULL DEFAULT now(),
  opening_cash NUMERIC(14, 2) NOT NULL DEFAULT 0,
  expected_cash NUMERIC(14, 2) NOT NULL DEFAULT 0,
  actual_cash NUMERIC(14, 2),
  cash_diff NUMERIC(14, 2),
  cash_sales NUMERIC(14, 2) NOT NULL DEFAULT 0,
  non_cash_sales NUMERIC(14, 2) NOT NULL DEFAULT 0,
  stock_value_system NUMERIC(14, 2) NOT NULL DEFAULT 0,
  stock_value_physical NUMERIC(14, 2) NOT NULL DEFAULT 0,
  stock_diff_value NUMERIC(14, 2) NOT NULL DEFAULT 0,
  stock_checked INT NOT NULL DEFAULT 0,
  stock_diff_count INT NOT NULL DEFAULT 0,
  findings JSONB NOT NULL DEFAULT '[]'::jsonb,
  note TEXT,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sidak_sessions_outlet_created
  ON public.sidak_sessions (outlet_id, created_at DESC);

-- 2. Baris hitung fisik per produk.
CREATE TABLE IF NOT EXISTS public.sidak_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES public.sidak_sessions(id) ON DELETE CASCADE,
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  product_id UUID,
  product_name TEXT NOT NULL,
  unit TEXT,
  stock_system NUMERIC(12, 2) NOT NULL DEFAULT 0,
  stock_physical NUMERIC(12, 2) NOT NULL DEFAULT 0,
  diff NUMERIC(12, 2) NOT NULL DEFAULT 0,
  cost_price NUMERIC(12, 2) NOT NULL DEFAULT 0,
  diff_value NUMERIC(14, 2) NOT NULL DEFAULT 0,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sidak_items_session
  ON public.sidak_items (session_id);
CREATE INDEX IF NOT EXISTS idx_sidak_items_outlet
  ON public.sidak_items (outlet_id, created_at DESC);

-- 3. RLS: owner outlet penuh, superadmin penuh.
ALTER TABLE public.sidak_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sidak_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS sidak_sessions_owner_all ON public.sidak_sessions;
CREATE POLICY sidak_sessions_owner_all ON public.sidak_sessions
  FOR ALL TO authenticated
  USING (public.is_outlet_owner(outlet_id) OR public.is_platform_admin())
  WITH CHECK (public.is_outlet_owner(outlet_id) OR public.is_platform_admin());

DROP POLICY IF EXISTS sidak_items_owner_all ON public.sidak_items;
CREATE POLICY sidak_items_owner_all ON public.sidak_items
  FOR ALL TO authenticated
  USING (public.is_outlet_owner(outlet_id) OR public.is_platform_admin())
  WITH CHECK (public.is_outlet_owner(outlet_id) OR public.is_platform_admin());

GRANT SELECT, INSERT, UPDATE, DELETE ON public.sidak_sessions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.sidak_items TO authenticated;

-- 4. Ringkasan kas periode (penjualan tunai vs non-tunai) dihitung server
--    agar tidak terpotong batas limit query klien.
CREATE OR REPLACE FUNCTION public.sidak_cash_summary(
  p_outlet UUID,
  p_from TIMESTAMPTZ,
  p_to TIMESTAMPTZ
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSONB;
BEGIN
  IF NOT (public.is_outlet_owner(p_outlet) OR public.is_platform_admin()) THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  SELECT jsonb_build_object(
    'cash_sales', COALESCE(SUM(t.final_amount) FILTER (
      WHERE lower(coalesce(t.payment_method, 'cash')) IN ('cash', 'tunai')
        AND coalesce(t.payment_status, 'paid') = 'paid'
    ), 0),
    'non_cash_sales', COALESCE(SUM(t.final_amount) FILTER (
      WHERE lower(coalesce(t.payment_method, 'cash')) NOT IN ('cash', 'tunai')
        AND coalesce(t.payment_status, 'paid') = 'paid'
    ), 0),
    'discount_total', COALESCE(SUM(t.total_discount), 0),
    'tx_count', COUNT(*)
  )
  INTO v_result
  FROM public.transactions t
  WHERE t.outlet_id = p_outlet
    AND t.created_at >= p_from
    AND t.created_at <= p_to
    AND lower(coalesce(t.status, 'completed')) NOT IN ('cancelled', 'void');

  RETURN coalesce(v_result, '{}'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION public.sidak_cash_summary(UUID, TIMESTAMPTZ, TIMESTAMPTZ)
  TO authenticated;

-- 5. Catat hasil sidak ke jejak aksi Dokter Bisnis (untuk evaluasi 13.21B).
--    Dipanggil klien setelah sesi tersimpan.
CREATE OR REPLACE FUNCTION public.sidak_log_action(
  p_session UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  s RECORD;
BEGIN
  SELECT * INTO s FROM public.sidak_sessions WHERE id = p_session;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'session not found' USING ERRCODE = 'P0002';
  END IF;
  IF NOT (public.is_outlet_owner(s.outlet_id) OR public.is_platform_admin()) THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.doctor_action_logs (
    outlet_id, action_type, channel, cost, description, action_date, result, outcome, status
  ) VALUES (
    s.outlet_id,
    'sidak_bos',
    'internal',
    0,
    'Sidak stok & kas',
    (s.created_at AT TIME ZONE 'Asia/Jakarta')::date,
    jsonb_build_object(
      'session_id', s.id,
      'cash_diff', s.cash_diff,
      'stock_diff_value', s.stock_diff_value,
      'stock_diff_count', s.stock_diff_count,
      'stock_checked', s.stock_checked
    ),
    CASE
      WHEN coalesce(s.cash_diff, 0) = 0 AND coalesce(s.stock_diff_value, 0) = 0
        THEN 'bersih'
      ELSE 'ada_selisih'
    END,
    'done'
  );

  RETURN jsonb_build_object('ok', true, 'session_id', s.id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.sidak_log_action(UUID) TO authenticated;
