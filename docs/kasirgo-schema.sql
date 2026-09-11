-- ============================================
-- KasirGo: Complete Database Schema
-- ============================================
-- Bagian 1: TABLES
-- ============================================

CREATE TABLE outlets (
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

CREATE TABLE user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('admin', 'cashier')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, outlet_id)
);

CREATE TABLE products (
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
  image_local_path TEXT NOT NULL DEFAULT '',
  thumb_key TEXT,
  min_stock_alert DECIMAL(12,2) DEFAULT 5,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE product_prices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  channel TEXT NOT NULL CHECK (channel IN ('offline', 'tokopedia', 'shopee', 'blibli', 'gofood', 'grabfood', 'shopeefood')),
  price DECIMAL(12,2) NOT NULL,
  platform_fee_percent DECIMAL(5,2) DEFAULT 0
);

CREATE TABLE product_discounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  discount_percent DECIMAL(5,2),
  discount_amount DECIMAL(12,2),
  start_date TIMESTAMPTZ NOT NULL,
  end_date TIMESTAMPTZ NOT NULL,
  is_flash_sale BOOLEAN DEFAULT false
);

CREATE TABLE transactions (
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

CREATE TABLE transaction_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id UUID REFERENCES transactions(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id),
  product_name TEXT NOT NULL,
  quantity DECIMAL(12,2) NOT NULL,
  unit_price DECIMAL(12,2) NOT NULL,
  discount DECIMAL(12,2) DEFAULT 0,
  subtotal DECIMAL(12,2) NOT NULL
);

CREATE TABLE customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  phone_wa TEXT,
  total_spent DECIMAL(12,2) DEFAULT 0,
  loyalty_points INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE employees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id),
  check_in_time TIMESTAMPTZ,
  check_out_time TIMESTAMPTZ,
  shift TEXT DEFAULT 'pagi',
  date DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  tier TEXT NOT NULL CHECK (tier IN ('free', 'basic_25', 'pro_50')),
  start_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  end_date TIMESTAMPTZ NOT NULL,
  payment_method TEXT,
  payment_status TEXT DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'expired')),
  amount DECIMAL(12,2) NOT NULL DEFAULT 0
);

CREATE TABLE affiliates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  email TEXT UNIQUE,
  referral_code TEXT UNIQUE NOT NULL,
  commission_percent DECIMAL(5,2) DEFAULT 10,
  total_earned DECIMAL(12,2) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE affiliate_referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  affiliate_id UUID REFERENCES affiliates(id) ON DELETE CASCADE,
  referred_user_id UUID REFERENCES auth.users(id),
  outlet_id UUID REFERENCES outlets(id),
  commission_amount DECIMAL(12,2) DEFAULT 0,
  status TEXT DEFAULT 'active',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE ai_insights (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  insight_type TEXT NOT NULL,
  data JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- Bagian 2: TRIGGERS
-- ============================================

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO outlets (owner_id, name, type)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'business_name', 'Toko Baru'), COALESCE(NEW.raw_user_meta_data->>'business_type', 'warung'));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

CREATE OR REPLACE FUNCTION decrement_stock()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE products SET stock = stock - NEW.quantity WHERE id = NEW.product_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER tr_decrement_stock
  AFTER INSERT ON transaction_items
  FOR EACH ROW EXECUTE FUNCTION decrement_stock();

-- ============================================
-- Bagian 2: RLS POLICIES
-- ============================================

ALTER TABLE outlets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner can manage own outlet" ON outlets FOR ALL USING (owner_id = auth.uid());
CREATE POLICY "Admin/Cashier can view own outlet" ON outlets FOR SELECT USING (
  EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND outlet_id = outlets.id)
);

ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner can manage roles" ON user_roles FOR ALL USING (
  EXISTS (SELECT 1 FROM outlets WHERE id = user_roles.outlet_id AND owner_id = auth.uid())
);

ALTER TABLE products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner/Admin can manage products" ON products FOR ALL USING (
  EXISTS (SELECT 1 FROM outlets WHERE id = products.outlet_id AND owner_id = auth.uid())
  OR EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND outlet_id = products.outlet_id AND role = 'admin')
);
CREATE POLICY "Cashier can view products" ON products FOR SELECT USING (
  EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND outlet_id = products.outlet_id AND role = 'cashier')
);

ALTER TABLE product_prices ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner/Admin can manage prices" ON product_prices FOR ALL USING (
  EXISTS (SELECT 1 FROM products p JOIN outlets o ON p.outlet_id = o.id WHERE p.id = product_prices.product_id AND o.owner_id = auth.uid())
  OR EXISTS (SELECT 1 FROM products p JOIN user_roles r ON p.outlet_id = r.outlet_id WHERE p.id = product_prices.product_id AND r.user_id = auth.uid() AND r.role = 'admin')
);
CREATE POLICY "Cashier can view prices" ON product_prices FOR SELECT USING (
  EXISTS (SELECT 1 FROM products p JOIN user_roles r ON p.outlet_id = r.outlet_id WHERE p.id = product_prices.product_id AND r.user_id = auth.uid() AND r.role = 'cashier')
);

ALTER TABLE product_discounts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner/Admin can manage discounts" ON product_discounts FOR ALL USING (
  EXISTS (SELECT 1 FROM products p JOIN outlets o ON p.outlet_id = o.id WHERE p.id = product_discounts.product_id AND o.owner_id = auth.uid())
  OR EXISTS (SELECT 1 FROM products p JOIN user_roles r ON p.outlet_id = r.outlet_id WHERE p.id = product_discounts.product_id AND r.user_id = auth.uid() AND r.role = 'admin')
);

ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner/Admin can view transactions" ON transactions FOR SELECT USING (
  EXISTS (SELECT 1 FROM outlets WHERE id = transactions.outlet_id AND owner_id = auth.uid())
  OR EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND outlet_id = transactions.outlet_id AND role IN ('admin', 'cashier'))
);
CREATE POLICY "Any role can insert transactions" ON transactions FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM outlets WHERE id = transactions.outlet_id AND owner_id = auth.uid())
  OR EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND outlet_id = transactions.outlet_id)
);

ALTER TABLE transaction_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "View transaction items" ON transaction_items FOR SELECT USING (
  EXISTS (SELECT 1 FROM transactions t JOIN outlets o ON t.outlet_id = o.id WHERE t.id = transaction_items.transaction_id AND o.owner_id = auth.uid())
  OR EXISTS (SELECT 1 FROM transactions t JOIN user_roles r ON t.outlet_id = r.outlet_id WHERE t.id = transaction_items.transaction_id AND r.user_id = auth.uid())
);
CREATE POLICY "Insert transaction items" ON transaction_items FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM transactions t JOIN outlets o ON t.outlet_id = o.id WHERE t.id = transaction_items.transaction_id AND o.owner_id = auth.uid())
  OR EXISTS (SELECT 1 FROM transactions t JOIN user_roles r ON t.outlet_id = r.outlet_id WHERE t.id = transaction_items.transaction_id AND r.user_id = auth.uid())
);

ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Manage customers" ON customers FOR ALL USING (
  EXISTS (SELECT 1 FROM outlets WHERE id = customers.outlet_id AND owner_id = auth.uid())
  OR EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND outlet_id = customers.outlet_id AND role IN ('admin', 'cashier'))
);

ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Manage employees" ON employees FOR ALL USING (
  EXISTS (SELECT 1 FROM outlets WHERE id = employees.outlet_id AND owner_id = auth.uid())
  OR (EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND outlet_id = employees.outlet_id) AND employees.user_id = auth.uid())
);

ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "View own subscriptions" ON subscriptions FOR SELECT USING (
  EXISTS (SELECT 1 FROM outlets WHERE id = subscriptions.outlet_id AND owner_id = auth.uid())
);

ALTER TABLE affiliates ENABLE ROW LEVEL SECURITY;
ALTER TABLE affiliate_referrals ENABLE ROW LEVEL SECURITY;

ALTER TABLE ai_insights ENABLE ROW LEVEL SECURITY;
CREATE POLICY "View own insights" ON ai_insights FOR SELECT USING (
  EXISTS (SELECT 1 FROM outlets WHERE id = ai_insights.outlet_id AND owner_id = auth.uid())
  OR EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND outlet_id = ai_insights.outlet_id)
);

-- ============================================
-- Bagian 2: INDEXES
-- ============================================

CREATE INDEX idx_products_outlet ON products(outlet_id);
CREATE INDEX idx_products_category ON products(outlet_id, category);
CREATE INDEX idx_products_barcode ON products(barcode);
CREATE INDEX idx_transactions_outlet ON transactions(outlet_id);
CREATE INDEX idx_transactions_date ON transactions(outlet_id, created_at DESC);
CREATE INDEX idx_transaction_items_tx ON transaction_items(transaction_id);
CREATE INDEX idx_customers_outlet ON customers(outlet_id);
CREATE INDEX idx_employees_date ON employees(outlet_id, date);
CREATE INDEX idx_ai_insights_outlet ON ai_insights(outlet_id, created_at DESC);