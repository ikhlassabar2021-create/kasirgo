-- ============================================================
-- KasirGo: RESET TOTAL DATA TEST (v2 — robust)
-- ============================================================
-- Tujuan: mengosongkan SEMUA akun auth + semua data outlet,
--         supaya testing mulai dari nol.
--
-- CARA PAKAI:
--   1. Supabase Dashboard -> SQL Editor -> New query
--   2. Tempel SELURUH isi file ini
--   3. Klik RUN  (bagian bawah akan menampilkan jumlah sisa data)
--
-- PERINGATAN: TIDAK BISA dibatalkan. Semua akun & data hilang.
-- Akun superadmin web memakai data mock, tidak terpengaruh.
--
-- VERSI INI TIDAK ERROR walau ada tabel yang belum dibuat:
-- hanya tabel yang benar-benar ada yang dihapus.
-- ============================================================

DO $$
DECLARE
  -- Urutan: anak dulu, induk belakangan (aman terhadap foreign key).
  t TEXT;
  tables TEXT[] := ARRAY[
    -- turunan transaksi
    'debt_payments',
    'transaction_items',
    'transactions',
    'tips',
    'shifts',
    -- produk & varian/resep
    'recipe_items',
    'recipes',
    'product_variants',
    'product_prices',
    'product_discounts',
    'products',
    -- operasional
    'stock_logs',
    'customers',
    'employees',
    'debts',
    'restock_orders',
    'ppob_transactions',
    'ppob_products',
    -- keuangan / settlement
    'settlements',
    'disbursements',
    -- lain-lain
    'ai_insights',
    'subscriptions',
    'supporters',
    'supporter_benefits',
    'receipt_sponsors',
    'affiliate_referrals',
    'affiliates',
    'fintech_leads',
    'merchants',
    'platform_financial_configs',
    'outlet_kyc',
    'user_roles',
    'outlets'
  ];
BEGIN
  FOREACH t IN ARRAY tables LOOP
    IF EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = t
    ) THEN
      EXECUTE format('DELETE FROM public.%I', t);
      RAISE NOTICE 'Dihapus: public.%', t;
    ELSE
      RAISE NOTICE 'Dilewati (tidak ada): public.%', t;
    END IF;
  END LOOP;
END $$;

-- Hapus SEMUA akun auth (paling terakhir).
DELETE FROM auth.users;

-- ============================================================
-- VERIFIKASI: hitung sisa (harus 0 semua)
-- ============================================================
SELECT 'auth.users' AS tabel, COUNT(*) AS sisa FROM auth.users
UNION ALL SELECT 'outlets', COALESCE((SELECT COUNT(*) FROM outlets), 0)
UNION ALL SELECT 'user_roles', COUNT(*) FROM user_roles
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'transactions', COUNT(*) FROM transactions
UNION ALL SELECT 'transaction_items', COUNT(*) FROM transaction_items
UNION ALL SELECT 'customers', COUNT(*) FROM customers
UNION ALL SELECT 'employees', COUNT(*) FROM employees;
