-- ============================================================================
-- KASIRGO PHASE 9 - ST9-1: PPOB (katalog + transaksi + margin otomatis)
-- Tanggal: 2026-10-01
-- Catatan: jalankan di SQL Editor Supabase (project lmvjecdvfzsmrowwwpck).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. ppob_products: katalog produk PPOB (modal/cost dari provider, HARGA JUAL
--    dihitung app: cost + margin% dari platform_configs('ppob') - BUKAN hardcode)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ppob_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sku TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'pulsa',
  nominal NUMERIC(14,2),
  cost_price NUMERIC(14,2) NOT NULL DEFAULT 0,
  sell_price NUMERIC(14,2),
  provider TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.ppob_products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read active ppob catalog" ON public.ppob_products;
CREATE POLICY "Public read active ppob catalog"
  ON public.ppob_products FOR SELECT
  TO anon, authenticated
  USING (is_active = true);

-- ---------------------------------------------------------------------------
-- 2. ppob_transactions: riwayat transaksi PPOB per outlet
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ppob_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ppob_product_id UUID REFERENCES public.ppob_products(id) ON DELETE SET NULL,
  product_name TEXT NOT NULL DEFAULT '',
  customer_ref TEXT NOT NULL DEFAULT '',
  amount NUMERIC(14,2) NOT NULL DEFAULT 0,
  cost_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
  profit NUMERIC(14,2) NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','success','failed')),
  payment_method TEXT NOT NULL DEFAULT 'cash'
    CHECK (payment_method IN ('cash','qris','saldo')),
  provider_ref TEXT,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.ppob_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Owner full ppob tx" ON public.ppob_transactions;
CREATE POLICY "Owner full ppob tx"
  ON public.ppob_transactions FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.outlets o
            WHERE o.id = ppob_transactions.outlet_id AND o.owner_id = auth.uid())
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.outlets o
            WHERE o.id = ppob_transactions.outlet_id AND o.owner_id = auth.uid())
  );

DROP POLICY IF EXISTS "Admin read ppob tx" ON public.ppob_transactions;
CREATE POLICY "Admin read ppob tx"
  ON public.ppob_transactions FOR SELECT
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.user_roles ur
            WHERE ur.user_id = auth.uid()
              AND ur.outlet_id = ppob_transactions.outlet_id
              AND ur.role IN ('admin','cashier'))
  );

DROP POLICY IF EXISTS "Staff insert ppob tx" ON public.ppob_transactions;
CREATE POLICY "Staff insert ppob tx"
  ON public.ppob_transactions FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.user_roles ur
            WHERE ur.user_id = auth.uid()
              AND ur.outlet_id = ppob_transactions.outlet_id
              AND ur.role IN ('admin','cashier'))
  );

-- ---------------------------------------------------------------------------
-- 3. Index
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_ppob_products_category
  ON public.ppob_products (category, is_active);
CREATE INDEX IF NOT EXISTS idx_ppob_tx_outlet_created
  ON public.ppob_transactions (outlet_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ppob_tx_status
  ON public.ppob_transactions (status);
CREATE INDEX IF NOT EXISTS idx_ppob_tx_product
  ON public.ppob_transactions (ppob_product_id);
CREATE INDEX IF NOT EXISTS idx_ppob_tx_customer
  ON public.ppob_transactions (customer_ref);

-- ---------------------------------------------------------------------------
-- 4. Seed katalog demo (modal = nominal; harga jual auto: modal + margin%)
-- ---------------------------------------------------------------------------
INSERT INTO public.ppob_products (sku, name, category, nominal, cost_price, provider)
VALUES
  ('PULSA-5K',   'Pulsa 5.000',            'pulsa',   5000,   5150,  'demo'),
  ('PULSA-10K',  'Pulsa 10.000',           'pulsa',   10000,  10250, 'demo'),
  ('PULSA-25K',  'Pulsa 25.000',           'pulsa',   25000,  25500, 'demo'),
  ('PULSA-50K',  'Pulsa 50.000',           'pulsa',   50000,  50750, 'demo'),
  ('PULSA-100K', 'Pulsa 100.000',          'pulsa',   100000, 101000,'demo'),
  ('DATA-2GB',   'Paket Data 2GB / 7 Hari','data',    15000,  13500, 'demo'),
  ('DATA-5GB',   'Paket Data 5GB / 30 Hari','data',   35000,  31500, 'demo'),
  ('DATA-10GB',  'Paket Data 10GB / 30 Hari','data',  55000,  49500, 'demo'),
  ('PLN-20K',    'Token PLN 20.000',       'pln',     20000,  20000, 'demo'),
  ('PLN-50K',    'Token PLN 50.000',       'pln',     50000,  50000, 'demo'),
  ('PLN-100K',   'Token PLN 100.000',      'pln',     100000, 100000,'demo'),
  ('GAME-86DM',  'Mobile Legends 86 DM',   'game',    20000,  18000, 'demo'),
  ('GAME-172DM', 'Mobile Legends 172 DM',  'game',    40000,  35500, 'demo'),
  ('EMONEY-25K', 'E-Money 25.000',         'e-money', 25000,  25000, 'demo'),
  ('EMONEY-50K', 'E-Money 50.000',         'e-money', 50000,  50000, 'demo')
ON CONFLICT (sku) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 5. Config PPOB di platform_configs (margin default 5%, provider demo)
-- ---------------------------------------------------------------------------
INSERT INTO public.platform_configs (key, scope, value)
SELECT 'ppob', 'global', jsonb_build_object(
  'provider', 'demo',
  'api_key', '',
  'endpoint', '',
  'margin_percent', 5,
  'updated_at', NOW()
)
WHERE NOT EXISTS (
  SELECT 1 FROM public.platform_configs
  WHERE key = 'ppob' AND scope = 'global'
);

-- ============================================================================
-- VERIFIKASI:
--   SELECT count(*) FROM public.ppob_products;             -- 15
--   SELECT column_name FROM information_schema.columns
--     WHERE table_name='ppob_transactions' ORDER BY ordinal_position;
--   SELECT value->>'margin_percent' FROM public.platform_configs
--     WHERE key='ppob' AND scope='global';                 -- 5
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 6. ST9-2: settlements (ledger saldo closed-loop)
--    Saldo outlet = SUM(amount) WHERE status IN ('success','PPOB_USED').
--    amount positif = QRIS masuk; negatif = dipakai PPOB.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.settlements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  amount NUMERIC(14,2) NOT NULL DEFAULT 0,
  source TEXT NOT NULL DEFAULT 'qris'
    CHECK (source IN ('qris','ppob','manual')),
  status TEXT NOT NULL DEFAULT 'success'
    CHECK (status IN ('pending','success','failed','PPOB_USED')),
  ppob_transaction_id UUID REFERENCES public.ppob_transactions(id) ON DELETE SET NULL,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.settlements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Owner full settlements" ON public.settlements;
CREATE POLICY "Owner full settlements"
  ON public.settlements FOR ALL
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.outlets o
                 WHERE o.id = settlements.outlet_id AND o.owner_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.outlets o
                 WHERE o.id = settlements.outlet_id AND o.owner_id = auth.uid()));

DROP POLICY IF EXISTS "Staff read settlements" ON public.settlements;
CREATE POLICY "Staff read settlements"
  ON public.settlements FOR SELECT
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.user_roles ur
                 WHERE ur.user_id = auth.uid()
                   AND ur.outlet_id = settlements.outlet_id));

CREATE INDEX IF NOT EXISTS idx_settlements_outlet_created
  ON public.settlements (outlet_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_settlements_status
  ON public.settlements (status);

-- Saldo outlet (closed-loop).
CREATE OR REPLACE FUNCTION public.get_outlet_saldo(p_outlet uuid)
RETURNS numeric
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(SUM(amount), 0)
  FROM public.settlements
  WHERE outlet_id = p_outlet AND status IN ('success','PPOB_USED');
$$;

-- Pakai saldo untuk PPOB: atomik (cek cukup -> catat PPOB_USED -> sukseskan tx).
CREATE OR REPLACE FUNCTION public.ppob_use_saldo(
  p_outlet uuid, p_tx uuid, p_amount numeric)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_saldo numeric;
  v_new numeric;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'invalid_amount';
  END IF;

  -- Hak akses: owner outlet ATAU staf terdaftar.
  IF NOT (
    EXISTS (SELECT 1 FROM public.outlets o
            WHERE o.id = p_outlet AND o.owner_id = auth.uid())
    OR EXISTS (SELECT 1 FROM public.user_roles ur
               WHERE ur.user_id = auth.uid() AND ur.outlet_id = p_outlet)
  ) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT public.get_outlet_saldo(p_outlet) INTO v_saldo;
  IF v_saldo < p_amount THEN
    RAISE EXCEPTION 'insufficient_saldo';
  END IF;

  -- Tx harus pending & milik outlet yang sama.
  UPDATE public.ppob_transactions
     SET status = 'success',
         payment_method = 'saldo',
         provider_ref = COALESCE(provider_ref, 'SALDO-' || p_tx::text),
         updated_at = NOW()
   WHERE id = p_tx AND outlet_id = p_outlet AND status = 'pending';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'tx_not_pending';
  END IF;

  INSERT INTO public.settlements
    (outlet_id, amount, source, status, ppob_transaction_id, note)
  VALUES
    (p_outlet, -p_amount, 'ppob', 'PPOB_USED', p_tx, 'Pembelian PPOB');

  v_new := v_saldo - p_amount;
  RETURN v_new;
END;
$$;

-- QRIS settlement masuk ke saldo (dipanggil webhook/setoran owner).
CREATE OR REPLACE FUNCTION public.settlement_add_qris(
  p_outlet uuid, p_amount numeric, p_note text DEFAULT NULL)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_outlet uuid;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'invalid_amount';
  END IF;

  -- Hanya owner outlet yang boleh menyetor manual.
  SELECT o.id INTO v_outlet FROM public.outlets o
   WHERE o.id = p_outlet AND o.owner_id = auth.uid();
  IF v_outlet IS NULL THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.settlements
    (outlet_id, amount, source, status, note)
  VALUES (p_outlet, p_amount, 'qris', 'success', p_note);

  RETURN public.get_outlet_saldo(p_outlet);
END;
$$;

-- ---------------------------------------------------------------------------
-- 7. ST9-3: restock_orders (B2B) + config b2b_restock
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.restock_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  distributor TEXT NOT NULL DEFAULT '',
  tracking_id TEXT NOT NULL UNIQUE,
  amount NUMERIC(14,2) NOT NULL DEFAULT 0,
  commission NUMERIC(14,2) NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('draft','pending','confirmed','shipped','completed','cancelled')),
  items_note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.restock_orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Owner full restock" ON public.restock_orders;
CREATE POLICY "Owner full restock"
  ON public.restock_orders FOR ALL
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.outlets o
                 WHERE o.id = restock_orders.outlet_id AND o.owner_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.outlets o
                 WHERE o.id = restock_orders.outlet_id AND o.owner_id = auth.uid()));

DROP POLICY IF EXISTS "Staff read restock" ON public.restock_orders;
CREATE POLICY "Staff read restock"
  ON public.restock_orders FOR SELECT
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.user_roles ur
                 WHERE ur.user_id = auth.uid()
                   AND ur.outlet_id = restock_orders.outlet_id));

DROP POLICY IF EXISTS "Staff insert restock" ON public.restock_orders;
CREATE POLICY "Staff insert restock"
  ON public.restock_orders FOR INSERT
  TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.user_roles ur
                 WHERE ur.user_id = auth.uid()
                   AND ur.outlet_id = restock_orders.outlet_id));

CREATE INDEX IF NOT EXISTS idx_restock_outlet_created
  ON public.restock_orders (outlet_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_restock_status
  ON public.restock_orders (status);

-- Config B2B restock (link distributor + komisi; superadmin yang mengubah).
INSERT INTO public.platform_configs (key, scope, value)
SELECT 'b2b_restock', 'global', jsonb_build_object(
  'enabled', false,
  'distributor_url', '',
  'distributor_name', 'Distributor B2B',
  'commission_percent', 2,
  'allowed_domains', '[]'::jsonb,
  'updated_at', NOW()
)
WHERE NOT EXISTS (
  SELECT 1 FROM public.platform_configs
  WHERE key = 'b2b_restock' AND scope = 'global'
);

-- PPOB aktif by default (demo mode) + gate enabled.
UPDATE public.platform_configs
   SET value = CASE
         WHEN value ? 'enabled' THEN value
         ELSE jsonb_set(value, '{enabled}', 'true'::jsonb, true)
       END
 WHERE key = 'ppob' AND scope = 'global'
   AND NOT COALESCE((value->>'enabled')::boolean, false);

-- ============================================================================
