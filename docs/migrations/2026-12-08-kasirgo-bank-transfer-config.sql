-- ============================================================================
-- KasirGo - Rekening Transfer Bank per Outlet
-- Tanggal: 2026-12-08
--
-- Tujuan:
--   Owner mengisi Nama Bank / No. Rekening / Atas Nama di Pengaturan.
--   Info rekening dipakai saat pelanggan memilih "Transfer Bank" di POS
--   (checkout kasir) dan ditampilkan di layar Program Pendukung.
--   Data disimpan di outlet_payment_configs (teks saja, bukan foto).
--
-- Aman dijalankan berulang (idempotent).
-- ============================================================================

ALTER TABLE public.outlet_payment_configs
  ADD COLUMN IF NOT EXISTS bank_name TEXT DEFAULT '';
ALTER TABLE public.outlet_payment_configs
  ADD COLUMN IF NOT EXISTS bank_account_number TEXT DEFAULT '';
ALTER TABLE public.outlet_payment_configs
  ADD COLUMN IF NOT EXISTS bank_account_name TEXT DEFAULT '';

-- RPC publik: pelanggan anonim baca info pembayaran satu outlet
-- (+ QRIS gambar + aturan ongkir + rekening transfer bank).
DROP FUNCTION IF EXISTS public.get_public_outlet_payment(TEXT);
CREATE OR REPLACE FUNCTION public.get_public_outlet_payment(p_outlet TEXT)
RETURNS TABLE (
  merchant_name TEXT,
  bank_wallet TEXT,
  account_number TEXT,
  nmid TEXT,
  instruction TEXT,
  qris_image TEXT,
  bank_name TEXT,
  bank_account_number TEXT,
  bank_account_name TEXT,
  delivery_enabled BOOLEAN,
  delivery_mode TEXT,
  delivery_value NUMERIC,
  delivery_free_above NUMERIC,
  delivery_max_km NUMERIC,
  delivery_manual BOOLEAN,
  delivery_manual_value NUMERIC
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    c.merchant_name,
    c.bank_wallet,
    c.account_number,
    c.nmid,
    c.instruction,
    COALESCE(c.qris_image, '') AS qris_image,
    COALESCE(c.bank_name, '') AS bank_name,
    COALESCE(c.bank_account_number, '') AS bank_account_number,
    COALESCE(c.bank_account_name, '') AS bank_account_name,
    COALESCE((o.delivery_rules->>'enabled')::boolean, false) AS delivery_enabled,
    COALESCE(o.delivery_rules->>'mode', 'flat') AS delivery_mode,
    COALESCE((o.delivery_rules->>'value')::numeric, 0) AS delivery_value,
    COALESCE((o.delivery_rules->>'free_above')::numeric, 0) AS delivery_free_above,
    COALESCE((o.delivery_rules->>'max_km')::numeric, 3) AS delivery_max_km,
    COALESCE((o.delivery_rules->>'manual')::boolean, false) AS delivery_manual,
    COALESCE((o.delivery_rules->>'manual_value')::numeric, 0) AS delivery_manual_value
  FROM public.outlet_payment_configs c
  JOIN public.outlets o ON o.id = c.outlet_id
  WHERE c.outlet_id = p_outlet::uuid
    AND c.is_active = TRUE
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.get_public_outlet_payment(TEXT) TO anon, authenticated;

-- ============================================================================
-- VERIFIKASI:
--   Owner: Pengaturan -> Transfer Bank -> isi bank/no. rekening/atas nama -> Simpan.
--   Kasir: POS -> pilih Transfer Bank -> rekening toko tampil.
--   Program Pendukung: bagian transfer manual menampilkan rekening toko.
-- ============================================================================
