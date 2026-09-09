-- ============================================
-- KASIRGO: Database Schema
-- ============================================

CREATE TABLE IF NOT EXISTS outlets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'warung',
  address TEXT,
  phone TEXT,
  subscription_tier TEXT NOT NULL DEFAULT 'free' CHECK (subscription_tier IN ('free', 'basic_25', 'pro_50')),
  subscription_expiry TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('admin', 'cashier')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, outlet_id)
);

CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  category TEXT DEFAULT 'Umum',
  barcode TEXT,
  cost_price DECIMAL(12,2) DEFAULT 0,
  base_price DECIMAL(12,2) NOT NULL DEFAULT 0,
  stock DECIMAL(12,2) DEFAULT 0,
  unit TEXT DEFAULT 'pcs',
  expired_date DATE,
  image_url TEXT,
  min_stock_alert DECIMAL(12,2) DEFAULT 5,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS product_prices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  channel TEXT NOT NULL CHECK (channel IN ('offline', 'tokopedia', 'shopee', 'blibli', 'gofood', 'grabfood', 'shopeefood')),
  price DECIMAL(12,2) NOT NULL,
  platform_fee_percent DECIMAL(5,2) DEFAULT 0
);

CREATE TABLE IF NOT EXISTS product_discounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  discount_percent DECIMAL(5,2),
  discount_amount DECIMAL(12,2),
  start_date TIMESTAMPTZ NOT NULL,
  end_date TIMESTAMPTZ NOT NULL,
  is_flash_sale BOOLEAN DEFAULT false
);

CREATE TABLE IF NOT EXISTS transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id),
  customer_id UUID,
  channel TEXT NOT NULL DEFAULT 'offline',
  payment_method TEXT NOT NULL DEFAULT 'cash' CHECK (payment_method IN ('cash', 'qris', 'bank_transfer')),
  total_amount DECIMAL(12,2) NOT NULL,
  total_discount DECIMAL(12,2) DEFAULT 0,
  final_amount DECIMAL(12,2) NOT NULL,
  status TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('completed', 'voided')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS transaction_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id UUID REFERENCES transactions(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id),
  product_name TEXT NOT NULL,
  quantity DECIMAL(12,2) NOT NULL,
  unit_price DECIMAL(12,2) NOT NULL,
  discount DECIMAL(12,2) DEFAULT 0,
  subtotal DECIMAL(12,2) NOT NULL
);

CREATE TABLE IF NOT EXISTS customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  phone_wa TEXT,
  total_spent DECIMAL(12,2) DEFAULT 0,
  loyalty_points INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS employees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id),
  check_in_time TIMESTAMPTZ,
  check_out_time TIMESTAMPTZ,
  shift TEXT DEFAULT 'pagi',
  date DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE IF NOT EXISTS subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  tier TEXT NOT NULL CHECK (tier IN ('free', 'basic_25', 'pro_50')),
  start_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  end_date TIMESTAMPTZ NOT NULL,
  payment_method TEXT,
  payment_status TEXT DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'expired')),
  amount DECIMAL(12,2) NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS affiliates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  email TEXT UNIQUE,
  referral_code TEXT UNIQUE NOT NULL,
  commission_percent DECIMAL(5,2) DEFAULT 10,
  total_earned DECIMAL(12,2) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS affiliate_referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  affiliate_id UUID REFERENCES affiliates(id) ON DELETE CASCADE,
  outlet_id UUID REFERENCES outlets(id),
  subscription_tier TEXT NOT NULL,
  commission_amount DECIMAL(12,2) DEFAULT 0,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'paid')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ai_insights (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  insight_type TEXT NOT NULL,
  data JSONB NOT NULL DEFAULT '{}',
  generated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- RLS POLICIES
-- ============================================

ALTER TABLE outlets ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_prices ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_discounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaction_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_insights ENABLE ROW LEVEL SECURITY;

-- Owner: full access to own outlet
CREATE POLICY owner_outlets ON outlets FOR ALL USING (owner_id = auth.uid());
CREATE POLICY owner_products ON products FOR ALL USING (outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid()));
CREATE POLICY owner_transactions ON transactions FOR ALL USING (outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid()));
CREATE POLICY owner_customers ON customers FOR ALL USING (outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid()));
CREATE POLICY owner_employees ON employees FOR ALL USING (outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid()));
CREATE POLICY owner_subscriptions ON subscriptions FOR ALL USING (outlet_id IN (SELECT id FROM outlets WHERE owner_id = auth.uid()));

-- Admin: CRUD products, read reports
CREATE POLICY admin_products ON products FOR ALL USING (outlet_id IN (SELECT outlet_id FROM user_roles WHERE user_id = auth.uid() AND role = 'admin'));
CREATE POLICY admin_transactions_read ON transactions FOR SELECT USING (outlet_id IN (SELECT outlet_id FROM user_roles WHERE user_id = auth.uid() AND role = 'admin'));

-- Cashier: read products, create transactions
CREATE POLICY cashier_products_read ON products FOR SELECT USING (outlet_id IN (SELECT outlet_id FROM user_roles WHERE user_id = auth.uid() AND role = 'cashier'));
CREATE POLICY cashier_transactions_insert ON transactions FOR INSERT WITH CHECK (outlet_id IN (SELECT outlet_id FROM user_roles WHERE user_id = auth.uid() AND role = 'cashier'));

-- ============================================
-- FUNCTIONS
-- ============================================

-- Auto-create outlet on user signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER SECURITY DEFINER SET search_path = 'public' AS $$
BEGIN
  INSERT INTO public.outlets (owner_id, name, type)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'business_name', 'Outlet Baru'), COALESCE(NEW.raw_user_meta_data->>'business_type', 'warung'));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Auto-decrement stock on transaction
CREATE OR REPLACE FUNCTION decrement_stock()
RETURNS TRIGGER SECURITY DEFINER SET search_path = 'public' AS $$
BEGIN
  UPDATE public.products SET stock = stock - NEW.quantity, updated_at = NOW()
  WHERE id = NEW.product_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_transaction_item_insert ON transaction_items;
CREATE TRIGGER on_transaction_item_insert
  AFTER INSERT ON transaction_items
  FOR EACH ROW EXECUTE FUNCTION decrement_stock();

-- ============================================
-- INDEXES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_products_outlet ON products(outlet_id);
CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode);
CREATE INDEX IF NOT EXISTS idx_transactions_outlet ON transactions(outlet_id);
CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transaction_items_tx ON transaction_items(transaction_id);
CREATE INDEX IF NOT EXISTS idx_customers_outlet ON customers(outlet_id);
CREATE INDEX IF NOT EXISTS idx_employees_outlet_date ON employees(outlet_id, date);
CREATE INDEX IF NOT EXISTS idx_ai_insights_outlet ON ai_insights(outlet_id, insight_type);