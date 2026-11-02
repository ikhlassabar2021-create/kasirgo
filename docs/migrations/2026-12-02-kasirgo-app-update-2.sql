-- KasirGo: lanjutan sistem update — RPC baca riwayat notifikasi (admin).
CREATE OR REPLACE FUNCTION public.admin_list_notifications(p_limit integer DEFAULT 50)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_platform_admin() THEN RETURN jsonb_build_object('forbidden', true); END IF;
  RETURN COALESCE(
    (SELECT jsonb_agg(row_to_json(t) ORDER BY t.created_at DESC)
     FROM (SELECT id, kind, channel, title, body, release_id, status,
                  recipient_count, error, created_at
           FROM public.system_notifications
           ORDER BY created_at DESC LIMIT p_limit) t),
    '[]'::jsonb
  );
END $$;
GRANT EXECUTE ON FUNCTION public.admin_list_notifications(integer) TO authenticated;