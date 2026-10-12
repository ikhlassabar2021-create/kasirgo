-- ============================================================================
-- KasirGo - Fix Checkout Pembeli (QRIS statis gambar) + Info Ongkir
-- Tanggal: 2026-11-05
--
-- Tujuan:
--   1. Menyimpan gambar QRIS statis milik toko (base64) di DB agar Pembeli
--      dapat melihat QR asli saat checkout (sebelumnya hanya di HP owner).
--      Catatan: ini konfigurasi pembayaran (bukan foto produk) dan berupa teks
--      base64 - sesuai kebijakan "Database = teks & angka saja".
--   2. get_public_outlet_payment mengembalikan kolom qris_image + delivery_rules
--      outlet (enabled/mode/value/free_above/max_km) agar Pembeli tahu ongkir
--      SEBELUM memesan.
--
-- Aman dijalankan berulang (idempotent).
-- ============================================================================

ALTER TABLE public.outlet_payment_configs
  ADD COLUMN IF NOT EXISTS qris_image TEXT DEFAULT '';

-- RPC publik: pelanggan anonim baca info pembayaran satu outlet (+ QRIS gambar
-- + aturan ongkir) supaya bisa menampilkan QR & estimasi ongkir di checkout.
DROP FUNCTION IF EXISTS public.get_public_outlet_payment(TEXT);
CREATE OR REPLACE FUNCTION public.get_public_outlet_payment(p_outlet TEXT)
RETURNS TABLE (
  merchant_name TEXT,
  bank_wallet TEXT,
  account_number TEXT,
  nmid TEXT,
  instruction TEXT,
  qris_image TEXT,
  delivery_enabled BOOLEAN,
  delivery_mode TEXT,
  delivery_value NUMERIC,
  delivery_free_above NUMERIC,
  delivery_max_km NUMERIC
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
    COALESCE((o.delivery_rules->>'enabled')::boolean, false) AS delivery_enabled,
    COALESCE(o.delivery_rules->>'mode', 'flat') AS delivery_mode,
    COALESCE((o.delivery_rules->>'value')::numeric, 0) AS delivery_value,
    COALESCE((o.delivery_rules->>'free_above')::numeric, 0) AS delivery_free_above,
    COALESCE((o.delivery_rules->>'max_km')::numeric, 3) AS delivery_max_km
  FROM public.outlet_payment_configs c
  JOIN public.outlets o ON o.id = c.outlet_id
  WHERE c.outlet_id = p_outlet::uuid
    AND c.is_active = TRUE
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.get_public_outlet_payment(TEXT) TO anon, authenticated;

-- ============================================================================
-- VERIFIKASI:
--   Owner: Pengaturan -> QRIS Toko -> upload gambar QRIS -> Simpan.
--   Pembeli: checkout -> gambar QRIS tampil + ongkir tampil.
-- ============================================================================
