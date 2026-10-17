-- Kunci fitur Program Pendukung sampai owner benar-benar upgrade.
--
-- Kebijakan: trial hanya berlaku bila superadmin mengaktifkan
-- `platform_configs.billing.trial_enabled` (default false). Baris trial lama
-- yang masih tersisa (dibuat saat flag pernah aktif) tidak boleh lagi membuka
-- fitur premium, sehingga semua fitur terkunci sebelum upgrade dan tidak ada
-- "trial 0 hari" yang tetap memberi akses.
--
-- Idempoten: aman dijalankan berulang.

DO $$
DECLARE
  v_trial_enabled BOOLEAN;
BEGIN
  SELECT COALESCE((value->>'trial_enabled')::boolean, false)
    INTO v_trial_enabled
  FROM public.platform_configs
  WHERE key = 'billing'
  ORDER BY version DESC
  LIMIT 1;

  IF v_trial_enabled IS TRUE THEN
    RETURN;
  END IF;

  -- Bersihkan trial pada entitlements (kecuali outlet yang sudah Pendukung aktif).
  UPDATE public.entitlements
     SET trial_ends_at = NULL
   WHERE trial_ends_at IS NOT NULL
     AND is_supporter IS NOT TRUE;

  -- Tutup baris trial pada supporters agar tidak dihitung sebagai akses aktif.
  UPDATE public.supporters
     SET status = 'expired'
   WHERE status = 'trial';

  -- Normalisasi status trial yang tertinggal di profil outlet.
  UPDATE public.outlets
     SET subscription_tier = 'free',
         subscription_expiry = NULL
   WHERE subscription_tier = 'trial';
END $$;

-- Penegakan sisi server: trial hanya diakui bila flag aktif. Berlaku untuk
-- Edge Function (Dokter Bisnis, Squad DM) dan pengecekan lain yang memakai
-- fungsi ini, sehingga trial lama tidak membuka fitur premium.
CREATE OR REPLACE FUNCTION public.outlet_supporter_active(target_outlet uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT
    EXISTS (
      SELECT 1 FROM public.supporters s
      WHERE s.outlet_id = target_outlet AND s.status = 'active'
        AND (s.end_date IS NULL OR s.end_date > NOW())
    )
    OR (
      COALESCE((
        SELECT (value->>'trial_enabled')::boolean
        FROM public.platform_configs
        WHERE key = 'billing'
        ORDER BY version DESC
        LIMIT 1
      ), false)
      AND (
        EXISTS (
          SELECT 1 FROM public.supporters s
          WHERE s.outlet_id = target_outlet AND s.status = 'trial'
            AND s.end_date IS NOT NULL AND s.end_date > NOW()
        )
        OR EXISTS (
          SELECT 1 FROM public.entitlements e
          WHERE e.outlet_id = target_outlet
            AND e.trial_ends_at IS NOT NULL AND e.trial_ends_at > NOW()
        )
      )
    )
    OR EXISTS (
      SELECT 1 FROM public.entitlements e
      WHERE e.outlet_id = target_outlet AND e.is_supporter = true
    );
$function$;
