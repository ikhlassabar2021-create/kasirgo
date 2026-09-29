-- ============================================================================
-- KasirGo — Info Pembayaran Outlet (bayar langsung di meja: QRIS / Transfer)
-- Tanggal: 2026-09-29
--
-- Tujuan:
--   Pelanggan QR meja membayar langsung di meja (scan QRIS / transfer bank),
--   tanpa antre di kasir. Info pembayaran disimpan di DB (teks saja, bukan
--   gambar — sesuai kebijakan foto) dan dibaca publik lewat RPC SECURITY DEFINER.
--
-- CARA PAKAI:
--   Supabase Dashboard -> SQL Editor -> New query -> tempel semua -> RUN.
-- Aman dijalankan berulang (idempotent).
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.outlet_payment_configs (
  outlet_id UUID PRIMARY KEY REFERENCES public.outlets(id) ON DELETE CASCADE,
  merchant_name TEXT DEFAULT '',
  bank_wallet TEXT DEFAULT '',
  account_number TEXT DEFAULT '',
  nmid TEXT DEFAULT '',
  instruction TEXT DEFAULT '',
  is_active BOOLEAN DEFAULT TRUE,
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.outlet_payment_configs ENABLE ROW LEVEL SECURITY;

-- Owner hanya bisa mengelola info pembayaran outlet miliknya sendiri.
DROP POLICY IF EXISTS opc_owner_all ON public.outlet_payment_configs;
CREATE POLICY opc_owner_all ON public.outlet_payment_configs
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.outlets o
      WHERE o.id = outlet_payment_configs.outlet_id
        AND o.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.outlets o
      WHERE o.id = outlet_payment_configs.outlet_id
        AND o.owner_id = auth.uid()
    )
  );

-- RPC publik: pelanggan anonim baca info pembayaran satu outlet.
CREATE OR REPLACE FUNCTION public.get_public_outlet_payment(p_outlet TEXT)
RETURNS TABLE (
  merchant_name TEXT,
  bank_wallet TEXT,
  account_number TEXT,
  nmid TEXT,
  instruction TEXT
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT c.merchant_name, c.bank_wallet, c.account_number, c.nmid, c.instruction
  FROM public.outlet_payment_configs c
  WHERE c.outlet_id = p_outlet::uuid
    AND c.is_active = TRUE
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.get_public_outlet_payment(TEXT) TO anon, authenticated;

-- ============================================================================
-- VERIFIKASI:
--   Owner: Pengaturan -> QRIS Toko -> isi Bank/E-Wallet + No. Rekening -> Simpan.
--   Pelanggan: scan QR meja -> pesan -> dialog bayar menampilkan info transfer.
-- ============================================================================
