-- KasirGo - Fix trial Program Pendukung tidak aktif.
--
-- Masalah: RPC `ensure_supporter_trial` tidak berefek untuk outlet yang SUDAH
-- punya baris di `entitlements` atau `supporters` (mis. sisa checkout gagal,
-- trial legacy, atau entitlements kosong yang pernah dibuat):
--   1) `INSERT ... ON CONFLICT DO NOTHING` -> `trial_ends_at` tetap NULL.
--   2) `IF NOT EXISTS (SELECT 1 FROM supporters WHERE outlet_id=...)` -> karena
--      sudah ada baris (mis. 'pending'/'cancelled'), baris trial baru tak dibuat.
-- Akibatnya `hasAccess = is_supporter || isTrialActive` tetap FALSE walau owner
-- menekan "Coba Trial Gratis" -> fitur Pendukung tetap terkunci.
--
-- Perbaikan:
--   * entitlements: upsert yang MENGISI trial_ends_at bila masih NULL
--     (COALESCE) -> idempoten, satu trial per outlet, tidak memperpanjang trial
--     yang sudah pernah berjalan.
--   * supporters: buat baris trial bila belum ada baris status trial/active.
--
-- Idempoten.

CREATE OR REPLACE FUNCTION public.ensure_supporter_trial(p_outlet uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_days INT;
  v_trial_end timestamptz;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.outlets o WHERE o.id = p_outlet AND o.owner_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'not_owner';
  END IF;

  SELECT COALESCE((value->>'trial_days')::int, 14) INTO v_days
  FROM (SELECT value FROM public.platform_configs WHERE key = 'billing'
        ORDER BY version DESC LIMIT 1) c;

  -- Isi masa trial bila BELUM pernah diisi (tidak menimpa/memperpanjang).
  INSERT INTO public.entitlements AS e
    (outlet_id, is_supporter, ad_free, features, trial_ends_at)
  VALUES
    (p_outlet, false, false, '{}'::jsonb, now() + make_interval(days => v_days))
  ON CONFLICT (outlet_id) DO UPDATE
    SET trial_ends_at = COALESCE(e.trial_ends_at, EXCLUDED.trial_ends_at)
  RETURNING e.trial_ends_at INTO v_trial_end;

  -- Catat baris supporters trial bila belum ada baris trial/active.
  IF NOT EXISTS (
    SELECT 1 FROM public.supporters
    WHERE outlet_id = p_outlet AND status IN ('trial', 'active')
  ) THEN
    INSERT INTO public.supporters
      (outlet_id, tier, amount, status, trial_started_at,
       start_date, end_date, auto_renew)
    VALUES
      (p_outlet, 'pendukung', 0, 'trial', now(),
       now(), v_trial_end, true);
  END IF;

  RETURN jsonb_build_object(
    'status', 'trial',
    'trial_days', v_days,
    'trial_ends_at', v_trial_end
  );
END;
$function$;
