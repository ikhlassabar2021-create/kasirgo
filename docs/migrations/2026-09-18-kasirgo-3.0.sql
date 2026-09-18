-- Migration KasirGo 3.0: OS UMKM Indonesia, Gratis Selamanya
-- Tanggal: 2026-09-18

-- ============================================================================
-- 1. ALTER EXISTING TABLES
-- ============================================================================

-- 1.1 Outlets: rename type -> outlet_type, drop subscription_tier & subscription_expiry
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'outlets' AND column_name = 'type'
  ) THEN
    ALTER TABLE outlets RENAME COLUMN type TO outlet_type;
  END IF;
END $$;

ALTER TABLE outlets 
  DROP COLUMN IF EXISTS subscription_tier,
  DROP COLUMN IF EXISTS subscription_expiry;

-- 1.2 User Roles: tambah role 'kitchen'
ALTER TABLE user_roles DROP CONSTRAINT IF EXISTS user_roles_role_check;
ALTER TABLE user_roles ADD CONSTRAINT user_roles_role_check 
  CHECK (role IN ('owner', 'admin', 'cashier', 'kitchen'));

-- 1.3 Products: tambah has_variants
ALTER TABLE products 
  ADD COLUMN IF NOT EXISTS has_variants BOOLEAN DEFAULT false;

-- 1.4 Transactions: tambah gateway_ref, settlement_status, tip_amount, shift_id, debt_id, sync_status, event_id, device_id
ALTER TABLE transactions 
  ADD COLUMN IF NOT EXISTS gateway_ref TEXT,
  ADD COLUMN IF NOT EXISTS settlement_status TEXT DEFAULT 'n/a',
  ADD COLUMN IF NOT EXISTS tip_amount DECIMAL(12,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS shift_id UUID,
  ADD COLUMN IF NOT EXISTS debt_id UUID,
  ADD COLUMN IF NOT EXISTS sync_status TEXT DEFAULT 'synced',
  ADD COLUMN IF NOT EXISTS event_id TEXT,
  ADD COLUMN IF NOT EXISTS device_id TEXT;

-- 1.5 Transaction Items: tambah variant_id, note
ALTER TABLE transaction_items 
  ADD COLUMN IF NOT EXISTS variant_id UUID,
  ADD COLUMN IF NOT EXISTS note TEXT;

-- ============================================================================
-- 2. CREATE NEW TABLES
-- ============================================================================

-- 2.1 supporters
CREATE TABLE IF NOT EXISTS supporters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  tier TEXT NOT NULL CHECK (tier IN ('pendukung','pro','setia')),
  start_date TIMESTAMPTZ DEFAULT NOW(),
  end_date TIMESTAMPTZ,
  amount DECIMAL(12,2) DEFAULT 0,
  status TEXT DEFAULT 'active'
);

-- 2.2 supporter_benefits
CREATE TABLE IF NOT EXISTS supporter_benefits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  benefit_key TEXT NOT NULL,
  enabled BOOLEAN DEFAULT true,
  UNIQUE(outlet_id, benefit_key)
);

-- 2.3 product_variants
CREATE TABLE IF NOT EXISTS product_variants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  sku TEXT,
  price_delta DECIMAL(12,2) DEFAULT 0,
  stock DECIMAL(12,2) DEFAULT 0
);

-- 2.4 stock_logs
CREATE TABLE IF NOT EXISTS stock_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id),
  variant_id UUID,
  delta DECIMAL(12,2) NOT NULL,
  reason TEXT NOT NULL,
  ref_id UUID,
  device_id TEXT,
  event_id TEXT UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.5 debts
CREATE TABLE IF NOT EXISTS debts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  customer_id UUID REFERENCES customers(id),
  transaction_id UUID REFERENCES transactions(id),
  amount DECIMAL(12,2) NOT NULL,
  paid_amount DECIMAL(12,2) DEFAULT 0,
  status TEXT DEFAULT 'unpaid' CHECK (status IN ('unpaid','partial','paid')),
  due_date DATE,
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.6 debt_payments
CREATE TABLE IF NOT EXISTS debt_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  debt_id UUID REFERENCES debts(id) ON DELETE CASCADE,
  amount DECIMAL(12,2) NOT NULL,
  paid_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.7 shifts
CREATE TABLE IF NOT EXISTS shifts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id),
  shift TEXT DEFAULT 'pagi',
  opened_at TIMESTAMPTZ DEFAULT NOW(),
  closed_at TIMESTAMPTZ,
  opening_cash DECIMAL(12,2) DEFAULT 0,
  closing_cash DECIMAL(12,2)
);

-- 2.8 tips
CREATE TABLE IF NOT EXISTS tips (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  transaction_id UUID REFERENCES transactions(id),
  user_id UUID REFERENCES auth.users(id),
  amount DECIMAL(12,2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.9 recipes
CREATE TABLE IF NOT EXISTS recipes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  yield_qty DECIMAL(12,2) DEFAULT 1
);

-- 2.10 recipe_items
CREATE TABLE IF NOT EXISTS recipe_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_id UUID REFERENCES recipes(id) ON DELETE CASCADE,
  ingredient_product_id UUID REFERENCES products(id),
  qty DECIMAL(12,2) NOT NULL
);

-- 2.11 ppob_products
CREATE TABLE IF NOT EXISTS ppob_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sku TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  category TEXT,
  cost_price DECIMAL(12,2),
  sell_price DECIMAL(12,2)
);

-- 2.12 ppob_transactions
CREATE TABLE IF NOT EXISTS ppob_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  ppob_product_id UUID REFERENCES ppob_products(id),
  customer_ref TEXT,
  amount DECIMAL(12,2) NOT NULL,
  status TEXT DEFAULT 'pending',
  provider_ref TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.13 restock_orders
CREATE TABLE IF NOT EXISTS restock_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  distributor TEXT,
  tracking_id TEXT,
  amount DECIMAL(12,2) DEFAULT 0,
  status TEXT DEFAULT 'draft',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.14 fintech_leads
CREATE TABLE IF NOT EXISTS fintech_leads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  partner TEXT,
  amount_requested DECIMAL(12,2),
  status TEXT DEFAULT 'lead',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.15 receipt_sponsors
CREATE TABLE IF NOT EXISTS receipt_sponsors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  brand TEXT NOT NULL,
  image_key TEXT,
  target_url TEXT,
  region TEXT,
  active_from TIMESTAMPTZ,
  active_to TIMESTAMPTZ,
  impression_count INTEGER DEFAULT 0
);

-- ============================================================================
-- 3. CREATE INDEXES PADA outlet_id TIAP TABEL BARU
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_supporters_outlet_id ON supporters(outlet_id);
CREATE INDEX IF NOT EXISTS idx_supporter_benefits_outlet_id ON supporter_benefits(outlet_id);
CREATE INDEX IF NOT EXISTS idx_product_variants_product_id ON product_variants(product_id);
CREATE INDEX IF NOT EXISTS idx_stock_logs_outlet_id ON stock_logs(outlet_id);
CREATE INDEX IF NOT EXISTS idx_debts_outlet_id ON debts(outlet_id);
CREATE INDEX IF NOT EXISTS idx_debt_payments_debt_id ON debt_payments(debt_id);
CREATE INDEX IF NOT EXISTS idx_shifts_outlet_id ON shifts(outlet_id);
CREATE INDEX IF NOT EXISTS idx_tips_outlet_id ON tips(outlet_id);
CREATE INDEX IF NOT EXISTS idx_recipes_outlet_id ON recipes(outlet_id);
CREATE INDEX IF NOT EXISTS idx_recipe_items_recipe_id ON recipe_items(recipe_id);
CREATE INDEX IF NOT EXISTS idx_ppob_transactions_outlet_id ON ppob_transactions(outlet_id);
CREATE INDEX IF NOT EXISTS idx_restock_orders_outlet_id ON restock_orders(outlet_id);
CREATE INDEX IF NOT EXISTS idx_fintech_leads_outlet_id ON fintech_leads(outlet_id);
