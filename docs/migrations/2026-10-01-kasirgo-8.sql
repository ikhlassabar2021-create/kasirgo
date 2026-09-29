-- ============================================================================
-- KasirGo — Phase 8: Modul per outlet_type (ST8-1)
-- Tanggal: 2026-10-01
--
-- Tabel baru (semua belum ada di live DB):
--   product_variants    — varian produk (retail/cafe): nama, sku/barcode,
--                         price_delta, stok per varian
--   recipes             — resep/BOM produk jadi (cafe): yield_qty, HPP
--   recipe_items        — bahan resep: ingredient_product_id + qty
--   shifts              — shift kasir: opening/closing cash, selisih
--   tips                — tip per transaksi/kasir/shift
--   transaction_payments— split bill: banyak metode per transaksi
--   stock_logs          — jejak perubahan stok (produk/varian/bahan resep)
-- Kolom baru: products.has_variants
--
-- RLS pola outlet_id:
--   Owner: FULL (outlet sendiri)
--   Admin: manage product_variants; read recipes/shifts/tips/payments/stock_logs
--   Cashier: read variants/recipes; INSERT shifts/tips/transaction_payments/
--            stock_logs; read shifts/tips/payments/stock_logs outlet sendiri
--   Superadmin: via service key (bypass RLS, tanpa policy)
--
-- CARA PAKAI: Supabase Dashboard -> SQL Editor -> tempel semua -> RUN.
-- Aman dijalankan berulang (idempotent).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 0. Kolom products.has_variants
-- ---------------------------------------------------------------------------
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS has_variants BOOLEAN NOT NULL DEFAULT false;

-- ---------------------------------------------------------------------------
-- 1. product_variants
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.product_variants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  sku TEXT,
  barcode TEXT,
  price_delta NUMERIC NOT NULL DEFAULT 0,
  stock NUMERIC NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.product_variants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Owner manage own product_variants" ON public.product_variants;
CREATE POLICY "Owner manage own product_variants" ON public.product_variants
  FOR ALL
  USING (EXISTS (SELECT 1 FROM public.outlets o
    WHERE o.id = product_variants.outlet_id AND o.owner_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.outlets o
    WHERE o.id = product_variants.outlet_id AND o.owner_id = auth.uid()));

DROP POLICY IF EXISTS "Admin manage outlet product_variants" ON public.product_variants;
CREATE POLICY "Admin manage outlet product_variants" ON public.product_variants
  FOR ALL
  USING (EXISTS (SELECT 1 FROM public.user_roles ur
    WHERE ur.user_id = auth.uid() AND ur.outlet_id = product_variants.outlet_id
      AND ur.role IN ('admin','owner')))
  WITH CHECK (EXISTS (SELECT 1 FROM public.user_roles ur
    WHERE ur.user_id = auth.uid() AND ur.outlet_id = product_variants.outlet_id
      AND ur.role IN ('admin','owner')));

DROP POLICY IF EXISTS "Cashier read outlet product_variants" ON public.product_variants;
CREATE POLICY "Cashier read outlet product_variants" ON public.product_variants
  FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.user_roles ur
    WHERE ur.user_id = auth.uid() AND ur.outlet_id = product_variants.outlet_id
      AND ur.role IN ('cashier','admin','owner')));

-- ---------------------------------------------------------------------------
-- 2. recipes + recipe_items
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.recipes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  yield_qty NUMERIC NOT NULL DEFAULT 1,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (outlet_id, product_id)
);

CREATE TABLE IF NOT EXISTS public.recipe_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  recipe_id UUID NOT NULL REFERENCES public.recipes(id) ON DELETE CASCADE,
  ingredient_product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  qty NUMERIC NOT NULL DEFAULT 0,
  unit TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recipe_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Owner manage own recipes" ON public.recipes;
CREATE POLICY "Owner manage own recipes" ON public.recipes
  FOR ALL
  USING (EXISTS (SELECT 1 FROM public.outlets o
    WHERE o.id = recipes.outlet_id AND o.owner_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.outlets o
    WHERE o.id = recipes.outlet_id AND o.owner_id = auth.uid()));

DROP POLICY IF EXISTS "Staff read outlet recipes" ON public.recipes;
CREATE POLICY "Staff read outlet recipes" ON public.recipes
  FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.user_roles ur
    WHERE ur.user_id = auth.uid() AND ur.outlet_id = recipes.outlet_id
      AND ur.role IN ('cashier','admin','owner')));

DROP POLICY IF EXISTS "Owner manage own recipe_items" ON public.recipe_items;
CREATE POLICY "Owner manage own recipe_items" ON public.recipe_items
  FOR ALL
  USING (EXISTS (SELECT 1 FROM public.outlets o
    WHERE o.id = recipe_items.outlet_id AND o.owner_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.outlets o
    WHERE o.id = recipe_items.outlet_id AND o.owner_id = auth.uid()));

DROP POLICY IF EXISTS "Staff read outlet recipe_items" ON public.recipe_items;
CREATE POLICY "Staff read outlet recipe_items" ON public.recipe_items
  FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.user_roles ur
    WHERE ur.user_id = auth.uid() AND ur.outlet_id = recipe_items.outlet_id
      AND ur.role IN ('cashier','admin','owner')));

-- ---------------------------------------------------------------------------
-- 3. shifts + tips
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.shifts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','closed')),
  opened_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  closed_at TIMESTAMPTZ,
  opening_cash NUMERIC NOT NULL DEFAULT 0,
  closing_cash NUMERIC,
  expected_cash NUMERIC,
  difference NUMERIC,
  total_cash NUMERIC,
  total_qris NUMERIC,
  total_transfer NUMERIC,
  total_tip NUMERIC NOT NULL DEFAULT 0,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.tips (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  transaction_id UUID REFERENCES public.transactions(id) ON DELETE SET NULL,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  shift_id UUID REFERENCES public.shifts(id) ON DELETE SET NULL,
  amount NUMERIC NOT NULL DEFAULT 0,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tips ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Owner manage own shifts" ON public.shifts;
CREATE POLICY "Owner manage own shifts" ON public.shifts
  FOR ALL
  USING (EXISTS (SELECT 1 FROM public.outlets o
    WHERE o.id = shifts.outlet_id AND o.owner_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.outlets o
    WHERE o.id = shifts.outlet_id AND o.owner_id = auth.uid()));

DROP POLICY IF EXISTS "Staff read outlet shifts" ON public.shifts;
CREATE POLICY "Staff read outlet shifts" ON public.shifts
  FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.user_roles ur
    WHERE ur.user_id = auth.uid() AND ur.outlet_id = shifts.outlet_id
      AND ur.role IN ('cashier','admin','owner')));

DROP POLICY IF EXISTS "Cashier insert own shifts" ON public.shifts;
CREATE POLICY "Cashier insert own shifts" ON public.shifts
  FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM public.user_roles ur
    WHERE ur.user_id = auth.uid() AND ur.outlet_id = shifts.outlet_id
      AND ur.role IN ('cashier','admin','owner'))
    AND shifts.user_id = auth.uid());

DROP POLICY IF EXISTS "Owner manage own tips" ON public.tips;
CREATE POLICY "Owner manage own tips" ON public.tips
  FOR ALL
  USING (EXISTS (SELECT 1 FROM public.outlets o
    WHERE o.id = tips.outlet_id AND o.owner_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.outlets o
    WHERE o.id = tips.outlet_id AND o.owner_id = auth.uid()));

DROP POLICY IF EXISTS "Staff read outlet tips" ON public.tips;
CREATE POLICY "Staff read outlet tips" ON public.tips
  FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.user_roles ur
    WHERE ur.user_id = auth.uid() AND ur.outlet_id = tips.outlet_id
      AND ur.role IN ('cashier','admin','owner')));

DROP POLICY IF EXISTS "Cashier insert own tips" ON public.tips;
CREATE POLICY "Cashier insert own tips" ON public.tips
  FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM public.user_roles ur
    WHERE ur.user_id = auth.uid() AND ur.outlet_id = tips.outlet_id
      AND ur.role IN ('cashier','admin','owner'))
    AND tips.user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 4. transaction_payments (Split Bill)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.transaction_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  transaction_id UUID NOT NULL REFERENCES public.transactions(id) ON DELETE CASCADE,
  method TEXT NOT NULL
    CHECK (method IN ('cash','qris','bank_transfer')),
  amount NUMERIC NOT NULL DEFAULT 0,
  ref TEXT,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  shift_id UUID REFERENCES public.shifts(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.transaction_payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Owner manage own transaction_payments" ON public.transaction_payments;
CREATE POLICY "Owner manage own transaction_payments" ON public.transaction_payments
  FOR ALL
  USING (EXISTS (SELECT 1 FROM public.outlets o
    WHERE o.id = transaction_payments.outlet_id AND o.owner_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.outlets o
    WHERE o.id = transaction_payments.outlet_id AND o.owner_id = auth.uid()));

DROP POLICY IF EXISTS "Staff read outlet transaction_payments" ON public.transaction_payments;
CREATE POLICY "Staff read outlet transaction_payments" ON public.transaction_payments
  FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.user_roles ur
    WHERE ur.user_id = auth.uid() AND ur.outlet_id = transaction_payments.outlet_id
      AND ur.role IN ('cashier','admin','owner')));

DROP POLICY IF EXISTS "Cashier insert own transaction_payments" ON public.transaction_payments;
CREATE POLICY "Cashier insert own transaction_payments" ON public.transaction_payments
  FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM public.user_roles ur
    WHERE ur.user_id = auth.uid() AND ur.outlet_id = transaction_payments.outlet_id
      AND ur.role IN ('cashier','admin','owner')));

-- ---------------------------------------------------------------------------
-- 5. stock_logs (jejak stok: produk biasa / varian / bahan resep)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.stock_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
  variant_id UUID REFERENCES public.product_variants(id) ON DELETE CASCADE,
  change NUMERIC NOT NULL DEFAULT 0,
  reason TEXT NOT NULL DEFAULT 'penjualan'
    CHECK (reason IN ('penjualan','resep','restock','koreksi','lainnya')),
  ref_id UUID,
  note TEXT,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.stock_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Owner manage own stock_logs" ON public.stock_logs;
CREATE POLICY "Owner manage own stock_logs" ON public.stock_logs
  FOR ALL
  USING (EXISTS (SELECT 1 FROM public.outlets o
    WHERE o.id = stock_logs.outlet_id AND o.owner_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.outlets o
    WHERE o.id = stock_logs.outlet_id AND o.owner_id = auth.uid()));

DROP POLICY IF EXISTS "Staff read outlet stock_logs" ON public.stock_logs;
CREATE POLICY "Staff read outlet stock_logs" ON public.stock_logs
  FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.user_roles ur
    WHERE ur.user_id = auth.uid() AND ur.outlet_id = stock_logs.outlet_id
      AND ur.role IN ('cashier','admin','owner')));

DROP POLICY IF EXISTS "Cashier insert outlet stock_logs" ON public.stock_logs;
CREATE POLICY "Cashier insert outlet stock_logs" ON public.stock_logs
  FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM public.user_roles ur
    WHERE ur.user_id = auth.uid() AND ur.outlet_id = stock_logs.outlet_id
      AND ur.role IN ('cashier','admin','owner')));

-- ---------------------------------------------------------------------------
-- 6. Index
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_product_variants_product ON public.product_variants(product_id);
CREATE INDEX IF NOT EXISTS idx_product_variants_outlet ON public.product_variants(outlet_id);
CREATE INDEX IF NOT EXISTS idx_product_variants_barcode ON public.product_variants(barcode);
CREATE INDEX IF NOT EXISTS idx_recipes_outlet_product ON public.recipes(outlet_id, product_id);
CREATE INDEX IF NOT EXISTS idx_recipe_items_recipe ON public.recipe_items(recipe_id);
CREATE INDEX IF NOT EXISTS idx_recipe_items_ingredient ON public.recipe_items(ingredient_product_id);
CREATE INDEX IF NOT EXISTS idx_shifts_outlet_opened ON public.shifts(outlet_id, opened_at DESC);
CREATE INDEX IF NOT EXISTS idx_shifts_user ON public.shifts(user_id);
CREATE INDEX IF NOT EXISTS idx_tips_outlet_shift ON public.tips(outlet_id, shift_id);
CREATE INDEX IF NOT EXISTS idx_tips_transaction ON public.tips(transaction_id);
CREATE INDEX IF NOT EXISTS idx_tips_user ON public.tips(user_id);
CREATE INDEX IF NOT EXISTS idx_transaction_payments_transaction ON public.transaction_payments(transaction_id);
CREATE INDEX IF NOT EXISTS idx_stock_logs_outlet_created ON public.stock_logs(outlet_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stock_logs_product ON public.stock_logs(product_id);
CREATE INDEX IF NOT EXISTS idx_stock_logs_variant ON public.stock_logs(variant_id);
CREATE INDEX IF NOT EXISTS idx_products_outlet_has_variants ON public.products(outlet_id, has_variants);

-- ---------------------------------------------------------------------------
-- 7. ST8-2: transaction_items.variant_id + trigger stok varian + stock_logs
-- ---------------------------------------------------------------------------
ALTER TABLE public.transaction_items
  ADD COLUMN IF NOT EXISTS variant_id UUID REFERENCES public.product_variants(id) ON DELETE SET NULL;

-- Trigger stok: item dengan variant_id -> kurangi stok VARIAN (+log);
-- tanpa variant_id -> kurangi stok produk (+log). Satu sumber kebenaran.
CREATE OR REPLACE FUNCTION public.decrement_stock()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_outlet UUID;
  v_user UUID;
BEGIN
  SELECT t.outlet_id, t.user_id INTO v_outlet, v_user
    FROM public.transactions t WHERE t.id = NEW.transaction_id;

  IF NEW.variant_id IS NOT NULL THEN
    UPDATE public.product_variants
       SET stock = stock - NEW.quantity, updated_at = NOW()
     WHERE id = NEW.variant_id;
    INSERT INTO public.stock_logs (outlet_id, product_id, variant_id, change, reason, ref_id, user_id)
    SELECT pv.outlet_id, pv.product_id, pv.id, -NEW.quantity, 'penjualan', NEW.transaction_id, v_user
      FROM public.product_variants pv WHERE pv.id = NEW.variant_id;
  ELSE
    UPDATE public.products SET stock = stock - NEW.quantity, updated_at = NOW()
     WHERE id = NEW.product_id;
    INSERT INTO public.stock_logs (outlet_id, product_id, change, reason, ref_id, user_id)
    VALUES (v_outlet, NEW.product_id, -NEW.quantity, 'penjualan', NEW.transaction_id, v_user);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS decrement_stock_trigger ON public.transaction_items;
CREATE TRIGGER decrement_stock_trigger
  AFTER INSERT ON public.transaction_items
  FOR EACH ROW EXECUTE FUNCTION public.decrement_stock();

-- Hapus trigger duplikat dari schema lama (menyebabkan stok berkurang 2x).
DROP TRIGGER IF EXISTS tr_decrement_stock ON public.transaction_items;

-- ============================================================================
-- VERIFIKASI:
--   SELECT table_name FROM information_schema.tables WHERE table_schema='public'
--     AND table_name IN ('product_variants','recipes','recipe_items','shifts',
--                        'tips','transaction_payments','stock_logs');
--   SELECT column_name FROM information_schema.columns
--     WHERE table_name='products' AND column_name='has_variants';
-- ============================================================================
