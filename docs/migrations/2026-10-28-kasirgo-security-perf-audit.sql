-- =============================================================================
-- KasirGo Tahap 3 - Security / Performance Audit
-- 1) Rate limit + validasi order anon (place_dine_in_order)
-- 2) RLS DELETE produk: owner outlet / superowner saja
-- 3) Composite index (transactions, products)
-- 4) Proteksi akun anon (KYC/link email/phone) - audit
-- Idempoten: aman dijalankan berulang.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) RATE LIMIT ORDER ANON
--    Pelanggan tanpa login (perangkat anon) hanya boleh membuat pesanan
--    max N per jendela waktu. Mencegah spam order via QR meja / katalog.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.order_rate_limits (
  device_key TEXT PRIMARY KEY,
  window_start TIMESTAMPTZ NOT NULL DEFAULT now(),
  order_count INT NOT NULL DEFAULT 0
);

ALTER TABLE public.order_rate_limits ENABLE ROW LEVEL SECURITY;

-- Tabel internal: hanya service_role (via SECURITY DEFINER function) yang menulis.
-- Tidak ada policy => anon/authenticated tidak bisa baca/tulis langsung.

CREATE OR REPLACE FUNCTION public.check_order_rate_limit(
  p_device_key TEXT,
  p_max_orders INT DEFAULT 10,
  p_window_minutes INT DEFAULT 10
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.order_rate_limits%ROWTYPE;
  v_key TEXT := COALESCE(NULLIF(trim(p_device_key), ''), 'anon');
BEGIN
  INSERT INTO public.order_rate_limits (device_key)
  VALUES (v_key)
  ON CONFLICT (device_key) DO NOTHING;

  SELECT * INTO v_row
    FROM public.order_rate_limits
    WHERE device_key = v_key
    FOR UPDATE;

  -- Reset jendela bila sudah lewat.
  IF v_row.window_start < now() - make_interval(mins => GREATEST(p_window_minutes, 1)) THEN
    UPDATE public.order_rate_limits
      SET window_start = now(), order_count = 1
      WHERE device_key = v_key;
    RETURN true;
  END IF;

  IF v_row.order_count >= GREATEST(p_max_orders, 1) THEN
    RETURN false;
  END IF;

  UPDATE public.order_rate_limits
    SET order_count = order_count + 1
    WHERE device_key = v_key;
  RETURN true;
END;
$$;

-- Hanya service_role; RPC order yang memanggilnya (SECURITY DEFINER).
REVOKE ALL ON FUNCTION public.check_order_rate_limit(TEXT, INT, INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_order_rate_limit(TEXT, INT, INT) TO service_role;

-- Bungkus ulang place_dine_in_order dengan rate limit + validasi perangkat.
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
  v_device TEXT;
  v_allowed BOOLEAN;
  v_count INT;
  v_distinct INT;
BEGIN
  v_outlet := p_outlet::uuid;

  IF NOT EXISTS (SELECT 1 FROM public.outlets o WHERE o.id = v_outlet) THEN
    RAISE EXCEPTION 'Outlet tidak ditemukan';
  END IF;

  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array'
     OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Pesanan kosong';
  END IF;

  -- Batas ukuran pesanan (anti-abuse): maks 100 baris item.
  IF jsonb_array_length(p_items) > 100 THEN
    RAISE EXCEPTION 'Pesanan terlalu banyak';
  END IF;

  -- Validasi item: produk valid, qty wajar (1..999), tanpa duplikat liaran.
  SELECT count(*), count(DISTINCT (it->>'product_id'))
    INTO v_count, v_distinct
    FROM jsonb_array_elements(p_items) it;
  IF v_count <> v_distinct THEN
    RAISE EXCEPTION 'Item pesanan duplikat';
  END IF;

  -- Rate limit per perangkat (anon). Kunci: outlet + nomor meja.
  v_device := v_outlet::text || '|' || COALESCE(NULLIF(trim(p_table), ''), '-');
  SELECT public.check_order_rate_limit(v_device, 10, 10) INTO v_allowed;
  IF NOT v_allowed THEN
    RAISE EXCEPTION 'Terlalu banyak pesanan. Coba lagi beberapa saat lagi.';
  END IF;

  -- Transfer bank dihapus: hanya QRIS atau Tunai (kasir yang konfirmasi).
  v_method := CASE WHEN p_payment_method = 'qris' THEN 'qris' ELSE 'cash' END;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_pid := NULLIF(v_item->>'product_id', '')::uuid;
    v_qty := COALESCE((v_item->>'quantity')::int, 0);
    IF v_pid IS NULL OR v_qty <= 0 OR v_qty > 999 THEN
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

-- -----------------------------------------------------------------------------
-- 2) RLS DELETE PRODUK: hanya owner outlet / superowner.
--    Admin tidak boleh hapus produk (sesuai matriks hak akses). Pastikan
--    policy DELETE tegas: bukan sekadar "member".
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Owner delete products" ON public.products;
CREATE POLICY "Owner delete products" ON public.products
  FOR DELETE TO authenticated
  USING (public.is_outlet_owner(outlet_id));

-- -----------------------------------------------------------------------------
-- 3) COMPOSITE INDEX (perf query laporan & katalog).
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_tx_outlet_created
  ON public.transactions (outlet_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_tx_outlet_payment_created
  ON public.transactions (outlet_id, payment_status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_products_outlet_name
  ON public.products (outlet_id, name);

CREATE INDEX IF NOT EXISTS idx_products_outlet_published
  ON public.products (outlet_id, is_published)
  WHERE is_published = true;

-- -----------------------------------------------------------------------------
-- 4) PROTEKSI AKUN ANON (audit dokumentasi).
--    Akun anonim hanya boleh: baca katalog publik, buat order, lihat status
--    order sendiri. Tidak boleh baca tabel sensitif. Migrasi ini TIDAK memberi
--    akses baru; hanya memastikan tidak ada policy longgar utk anon di tabel
--    sensitif. (Tabel tanpa policy = tertutup untuk anon.)
-- -----------------------------------------------------------------------------
DO $$
DECLARE
  t TEXT;
  sensitive TEXT[] := ARRAY[
    'outlet_kyc', 'outlet_pg_configs', 'payment_orders', 'supporters',
    'subscriptions', 'settlements', 'disbursements', 'fintech_leads',
    'settlement_accounts', 'platform_financial_configs', 'platform_integrations',
    'ai_insights', 'doctor_messages', 'doctor_memory', 'dm_campaigns'
  ];
BEGIN
  FOREACH t IN ARRAY sensitive LOOP
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = t) THEN
      EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
      -- Pastikan tidak ada policy dengan role anon.
      EXECUTE format($f$
        DO $inner$
        DECLARE pol RECORD;
        BEGIN
          FOR pol IN
            SELECT policyname FROM pg_policies
            WHERE schemaname = 'public' AND tablename = %L
              AND 'anon' = ANY(roles)
          LOOP
            EXECUTE format('DROP POLICY IF EXISTS %%I ON public.%%I', pol.policyname, %L);
          END LOOP;
        END
        $inner$;
      $f$, t, t);
    END IF;
  END LOOP;
END $$;

-- Selesai.
