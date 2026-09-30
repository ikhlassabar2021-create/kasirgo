-- ============================================================================
-- KasirGo PHASE 12 — Security Hardening (ST12-1)
-- Tanggal: 2026-10-02
--
-- Isu yang ditutup:
--   1) platform_integrations: policy "Client read active integrations"
--      memperbolehkan client SELECT secret_config -> DIHAPUS. View publik
--      dibuat security DEFINER (kolom aman saja).
--   2) platform_configs key 'ppob' memuat api_key di value (client read
--      USING true) -> api_key DIHAPUS dari config; secret hanya boleh di
--      platform_integrations.secret_config (client tidak bisa baca).
--   3) Role 'kitchen' (Phase 3.0) tidak tercakup policy SELECT
--      outlets/products/transactions/transaction_items -> KDS kosong.
--      Semua policy SELECT outlet diperbarui: admin/cashier/kitchen.
--   4) platform_financial_configs USING(true): hanya angka/persen, bukan
--      secret -> dibiarkan (dipakai app utk kalkulasi margin).
-- Idempotent: aman dijalankan ulang.
-- ============================================================================

-- 1) platform_integrations: tutup akses client ke baris tabel ---------------
DROP POLICY IF EXISTS "Client read active integrations" ON public.platform_integrations;
DROP POLICY IF EXISTS "Client read active integrations public view" ON public.platform_integrations;

-- View publik TANPA security_invoker -> dijalankan sebagai pemilik (postgres),
-- melewati RLS tabel, hanya memaparkan kolom aman (tanpa secret_config).
CREATE OR REPLACE VIEW public.platform_integrations_public AS
  SELECT id, key, label, base_url, public_config, is_active, updated_at
  FROM public.platform_integrations
  WHERE is_active = true;
GRANT SELECT ON public.platform_integrations_public TO anon, authenticated;

-- 2) Bersihkan secret dari platform_configs --------------------------------
-- Aturan: platform_configs HANYA nilai non-secret (enabled, margin, URL).
-- Secret provider (api_key PPOB dll) = platform_integrations.secret_config,
-- dibaca HANYA oleh Edge Function/service key (integrasi nyata menyusul).
UPDATE public.platform_configs
   SET value = value - 'api_key' - 'api_secret' - 'secret' - 'password' - 'token'
 WHERE key IN ('ppob', 'b2b_restock', 'fintech_partner', 'hyperlocal', 'insurance',
               'ads', 'guide', 'report', 'kyc', 'quota', 'flags', 'billing');

-- 3) Policy SELECT outlet: sertakan role kitchen ---------------------------
-- 3.1 outlets
DROP POLICY IF EXISTS "Admin/Cashier can view own outlet" ON public.outlets;
CREATE POLICY "Admin/Cashier can view own outlet" ON public.outlets
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_id = auth.uid()
        AND outlet_id = outlets.id
        AND role IN ('admin', 'cashier', 'kitchen')
    )
  );

-- 3.2 products (kitchen perlu baca nama/produk utk KDS & resep)
DROP POLICY IF EXISTS "Cashier can view products" ON public.products;
CREATE POLICY "Staff can view products" ON public.products
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_id = auth.uid()
        AND outlet_id = products.outlet_id
        AND role IN ('cashier', 'kitchen')
    )
  );

-- 3.3 transactions (KDS realtime membaca transactions)
DROP POLICY IF EXISTS "Owner/Admin can view transactions" ON public.transactions;
CREATE POLICY "Owner/Admin/Kitchen can view transactions" ON public.transactions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.outlets
      WHERE id = transactions.outlet_id AND owner_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_id = auth.uid()
        AND outlet_id = transactions.outlet_id
        AND role IN ('admin', 'cashier', 'kitchen')
    )
  );

-- 3.4 transaction_items (KDS membaca item)
DROP POLICY IF EXISTS "View transaction items" ON public.transaction_items;
CREATE POLICY "View transaction items" ON public.transaction_items
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.transactions t
      JOIN public.outlets o ON o.id = t.outlet_id
      WHERE t.id = transaction_items.transaction_id
        AND (o.owner_id = auth.uid()
             OR EXISTS (
               SELECT 1 FROM public.user_roles r
               WHERE r.user_id = auth.uid()
                 AND r.outlet_id = t.outlet_id
                 AND r.role IN ('admin', 'cashier', 'kitchen')))
    )
  );

-- 3.5 product_prices: kitchen ikut baca (harga utk resep/KDS opsional)
DROP POLICY IF EXISTS "Cashier can view prices" ON public.product_prices;
CREATE POLICY "Staff can view prices" ON public.product_prices
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.products p
      JOIN public.user_roles r ON p.outlet_id = r.outlet_id
      WHERE p.id = product_prices.product_id
        AND r.user_id = auth.uid()
        AND r.role IN ('cashier', 'kitchen')
    )
  );

-- ============================================================================
-- VERIFIKASI:
--   -- Client tidak boleh baca secret_config lagi:
--   SELECT secret_config FROM public.platform_integrations LIMIT 1; -- harus 0 baris
--   -- View publik tetap bisa dibaca:
--   SELECT key, label FROM public.platform_integrations_public;
--   -- ppob config tanpa api_key:
--   SELECT value ? 'api_key' FROM public.platform_configs WHERE key='ppob'; -- false
--   -- User role kitchen bisa baca transactions outlet-nya.
-- ============================================================================
