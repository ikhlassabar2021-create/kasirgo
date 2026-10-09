-- 2026-10-23-kasirgo-fix-delete-owner-outlet.sql
-- Hapus outlet milik owner (multi-outlet) secara aman.
-- Masalah: FK `affiliate_referrals.outlet_id` -> outlets(id) TANPA aksi ON DELETE
-- (NO ACTION) sehingga DELETE outlet gagal bila ada baris referral yang menunjuk
-- outlet tsb. Semua FK lain sudah ON DELETE CASCADE.
-- Solusi: RPC SECURITY DEFINER yang:
--   1. Memverifikasi pemanggil = owner outlet (atau platform admin).
--   2. Menolak menghapus outlet terakhir milik owner (agar akun tetap punya outlet).
--   3. Melepas referensi affiliate_referrals (SET NULL) tanpa menghapus riwayat komisi.
--   4. Menghapus outlet (cascade ke produk/transaksi/dll).
-- RLS `outlets` "Owner can manage own outlet" FOR ALL sudah mengizinkan DELETE owner,
-- namun tetap divalidasi di sini.

CREATE OR REPLACE FUNCTION public.delete_owner_outlet(p_outlet UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_owner UUID;
  v_is_admin BOOLEAN;
  v_count INT;
BEGIN
  SELECT owner_id INTO v_owner FROM public.outlets WHERE id = p_outlet;
  IF v_owner IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Outlet tidak ditemukan');
  END IF;

  v_is_admin := COALESCE(public.is_platform_admin(), false);
  IF auth.uid() IS NULL OR (auth.uid() <> v_owner AND NOT v_is_admin) THEN
    RETURN jsonb_build_object('success', false, 'message', 'Tidak berwenang menghapus outlet ini');
  END IF;

  SELECT COUNT(*) INTO v_count FROM public.outlets WHERE owner_id = v_owner;
  IF v_count <= 1 THEN
    RETURN jsonb_build_object('success', false, 'message', 'Minimal harus ada 1 outlet');
  END IF;

  UPDATE public.affiliate_referrals SET outlet_id = NULL WHERE outlet_id = p_outlet;

  DELETE FROM public.outlets WHERE id = p_outlet;

  RETURN jsonb_build_object('success', true, 'message', 'Outlet berhasil dihapus');
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_owner_outlet(UUID) TO authenticated;
