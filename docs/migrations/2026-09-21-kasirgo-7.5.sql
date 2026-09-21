-- Migration KasirGo 7.5: Zero-Friction Onboarding, Dual-Mode QRIS, Settlement & Disbursement, Platform Financial Config
-- Tanggal: 2026-09-21

-- ============================================================================
-- 1. CREATE NEW TABLES (BAGIAN 3)
-- ============================================================================

-- 1.1 merchants
CREATE TABLE IF NOT EXISTS merchants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_uuid VARCHAR(100) UNIQUE NOT NULL,
  store_name VARCHAR(150) NOT NULL DEFAULT 'Warung Saya',
  owner_name VARCHAR(100),
  owner_ktp VARCHAR(20),
  payout_bank_code VARCHAR(20),
  payout_account_number VARCHAR(50),
  payout_account_name VARCHAR(100),
  is_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 1.2 platform_financial_configs
CREATE TABLE IF NOT EXISTS platform_financial_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  min_qris_amount NUMERIC DEFAULT 1000,
  max_qris_amount NUMERIC DEFAULT 10000000,
  qris_free_threshold NUMERIC DEFAULT 500000,
  qris_base_mdr_percent NUMERIC DEFAULT 0.3,
  kasirgo_margin_percent NUMERIC DEFAULT 0.1,
  kasirgo_margin_flat NUMERIC DEFAULT 0,
  fee_bearer VARCHAR(20) DEFAULT 'MERCHANT',
  min_disbursement_amount NUMERIC DEFAULT 50000,
  disbursement_fee_standard NUMERIC DEFAULT 2500,
  disbursement_fee_instant NUMERIC DEFAULT 3500,
  auto_settlement_schedules TEXT[] DEFAULT ARRAY['12:00','19:00'],
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  updated_by UUID REFERENCES auth.users(id)
);

-- 1.3 settlements
CREATE TABLE IF NOT EXISTS settlements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
  batch_ref TEXT,
  total_net NUMERIC DEFAULT 0,
  status TEXT DEFAULT 'pending',
  scheduled_at TIMESTAMPTZ,
  settled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 1.4 disbursements
CREATE TABLE IF NOT EXISTS disbursements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
  amount NUMERIC NOT NULL,
  mode TEXT DEFAULT 'standard' CHECK (mode IN ('standard','instant')),
  fee NUMERIC DEFAULT 0,
  status TEXT DEFAULT 'pending',
  provider_ref TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 2. ALTER EXISTING TABLES
-- ============================================================================

-- 2.1 ALTER outlets: tambah merchant_id, device_uuid
ALTER TABLE outlets 
  ADD COLUMN IF NOT EXISTS merchant_id UUID REFERENCES merchants(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS device_uuid TEXT;

-- 2.2 ALTER transactions: tambah merchant_id, pg_reference_id, qris_type, payment_status,
--     gross_amount, mdr_fee_deducted, kasirgo_margin_deducted, net_amount_to_merchant
ALTER TABLE transactions 
  ADD COLUMN IF NOT EXISTS merchant_id UUID REFERENCES merchants(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS pg_reference_id TEXT,
  ADD COLUMN IF NOT EXISTS qris_type TEXT DEFAULT 'static',
  ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'PAID',
  ADD COLUMN IF NOT EXISTS gross_amount NUMERIC DEFAULT 0,
  ADD COLUMN IF NOT EXISTS mdr_fee_deducted NUMERIC DEFAULT 0,
  ADD COLUMN IF NOT EXISTS kasirgo_margin_deducted NUMERIC DEFAULT 0,
  ADD COLUMN IF NOT EXISTS net_amount_to_merchant NUMERIC DEFAULT 0;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'transactions_qris_type_check'
  ) THEN
    ALTER TABLE transactions ADD CONSTRAINT transactions_qris_type_check CHECK (qris_type IN ('static', 'dynamic'));
  END IF;
END $$;

-- ============================================================================
-- 3. ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- 3.1 platform_financial_configs: superowner full, client SELECT-only
ALTER TABLE platform_financial_configs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Superowner full access financial config" ON platform_financial_configs;
CREATE POLICY "Superowner full access financial config" ON platform_financial_configs
  FOR ALL
  USING (COALESCE(auth.jwt()->>'role', '') = 'superowner')
  WITH CHECK (COALESCE(auth.jwt()->>'role', '') = 'superowner');

DROP POLICY IF EXISTS "Client select financial config" ON platform_financial_configs;
CREATE POLICY "Client select financial config" ON platform_financial_configs
  FOR SELECT
  USING (true);

-- 3.2 merchants: merchant baris sendiri, superowner full
ALTER TABLE merchants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Superowner full access merchants" ON merchants;
CREATE POLICY "Superowner full access merchants" ON merchants
  FOR ALL
  USING (COALESCE(auth.jwt()->>'role', '') = 'superowner')
  WITH CHECK (COALESCE(auth.jwt()->>'role', '') = 'superowner');

DROP POLICY IF EXISTS "Merchant manage own merchant" ON merchants;
CREATE POLICY "Merchant manage own merchant" ON merchants
  FOR ALL
  USING (
    id IN (
      SELECT merchant_id FROM outlets WHERE owner_id = auth.uid()
      UNION
      SELECT o.merchant_id FROM outlets o
      JOIN user_roles ur ON ur.outlet_id = o.id
      WHERE ur.user_id = auth.uid()
    )
    OR device_uuid = (COALESCE(auth.jwt()->>'device_uuid', ''))
  )
  WITH CHECK (
    id IN (
      SELECT merchant_id FROM outlets WHERE owner_id = auth.uid()
    )
    OR device_uuid = (COALESCE(auth.jwt()->>'device_uuid', ''))
  );

-- 3.3 settlements: merchant baris sendiri, superowner full
ALTER TABLE settlements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Superowner full access settlements" ON settlements;
CREATE POLICY "Superowner full access settlements" ON settlements
  FOR ALL
  USING (COALESCE(auth.jwt()->>'role', '') = 'superowner')
  WITH CHECK (COALESCE(auth.jwt()->>'role', '') = 'superowner');

DROP POLICY IF EXISTS "Merchant view own settlements" ON settlements;
CREATE POLICY "Merchant view own settlements" ON settlements
  FOR SELECT
  USING (
    merchant_id IN (
      SELECT merchant_id FROM outlets WHERE owner_id = auth.uid()
      UNION
      SELECT o.merchant_id FROM outlets o
      JOIN user_roles ur ON ur.outlet_id = o.id
      WHERE ur.user_id = auth.uid()
    )
  );

-- 3.4 disbursements: merchant baris sendiri, superowner full
ALTER TABLE disbursements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Superowner full access disbursements" ON disbursements;
CREATE POLICY "Superowner full access disbursements" ON disbursements
  FOR ALL
  USING (COALESCE(auth.jwt()->>'role', '') = 'superowner')
  WITH CHECK (COALESCE(auth.jwt()->>'role', '') = 'superowner');

DROP POLICY IF EXISTS "Merchant manage own disbursements" ON disbursements;
CREATE POLICY "Merchant manage own disbursements" ON disbursements
  FOR ALL
  USING (
    merchant_id IN (
      SELECT merchant_id FROM outlets WHERE owner_id = auth.uid()
      UNION
      SELECT o.merchant_id FROM outlets o
      JOIN user_roles ur ON ur.outlet_id = o.id
      WHERE ur.user_id = auth.uid()
    )
  )
  WITH CHECK (
    merchant_id IN (
      SELECT merchant_id FROM outlets WHERE owner_id = auth.uid()
    )
  );

-- ============================================================================
-- 4. SEED platform_financial_configs
-- ============================================================================

INSERT INTO platform_financial_configs (
  min_qris_amount,
  max_qris_amount,
  qris_free_threshold,
  qris_base_mdr_percent,
  kasirgo_margin_percent,
  kasirgo_margin_flat,
  fee_bearer,
  min_disbursement_amount,
  disbursement_fee_standard,
  disbursement_fee_instant,
  auto_settlement_schedules
)
SELECT 
  1000,
  10000000,
  500000,
  0.3,
  0.1,
  0,
  'MERCHANT',
  50000,
  2500,
  3500,
  ARRAY['12:00','19:00']
WHERE NOT EXISTS (
  SELECT 1 FROM platform_financial_configs
);

-- ============================================================================
-- 5. INDEXES (merchant_id/outlet_id + status)
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_merchants_device_uuid ON merchants(device_uuid);
CREATE INDEX IF NOT EXISTS idx_merchants_is_verified ON merchants(is_verified);

CREATE INDEX IF NOT EXISTS idx_outlets_merchant_id ON outlets(merchant_id);
CREATE INDEX IF NOT EXISTS idx_outlets_device_uuid ON outlets(device_uuid);

CREATE INDEX IF NOT EXISTS idx_transactions_merchant_id ON transactions(merchant_id);
CREATE INDEX IF NOT EXISTS idx_transactions_payment_status ON transactions(payment_status);
CREATE INDEX IF NOT EXISTS idx_transactions_qris_type ON transactions(qris_type);

CREATE INDEX IF NOT EXISTS idx_settlements_merchant_id ON settlements(merchant_id);
CREATE INDEX IF NOT EXISTS idx_settlements_status ON settlements(status);

CREATE INDEX IF NOT EXISTS idx_disbursements_merchant_id ON disbursements(merchant_id);
CREATE INDEX IF NOT EXISTS idx_disbursements_status ON disbursements(status);
