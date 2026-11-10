-- ============================================================================
-- Superadmin: edit & reset akun owner dari halaman "Outlet Terdaftar".
--   - platform_account_edit           : ubah nama owner, email, nama outlet, telepon
--   - platform_account_reset_password : set ulang password owner (Superadmin/RBAC)
-- Sekuritas: SECURITY DEFINER + cek platform_is_admin(); jejak audit wajib.
-- ============================================================================

-- Edit data akun owner (auth.users) + outlet terkait. Hanya field non-null/'' yang diubah.
CREATE OR REPLACE FUNCTION public.platform_account_edit(
  p_outlet_id uuid,
  p_name text DEFAULT NULL,
  p_email text DEFAULT NULL,
  p_outlet_name text DEFAULT NULL,
  p_phone text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ok boolean;
  v_owner uuid;
  v_email text;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT owner_id INTO v_owner FROM public.outlets WHERE id = p_outlet_id;
  IF v_owner IS NULL THEN RAISE EXCEPTION 'outlet_not_found'; END IF;

  IF p_email IS NOT NULL AND btrim(p_email) <> '' THEN
    v_email := lower(btrim(p_email));
    IF EXISTS (SELECT 1 FROM auth.users WHERE email = v_email AND id <> v_owner) THEN
      RAISE EXCEPTION 'email_sudah_dipakai';
    END IF;
    UPDATE auth.users SET email = v_email, updated_at = now() WHERE id = v_owner;
  END IF;

  IF p_name IS NOT NULL AND btrim(p_name) <> '' THEN
    UPDATE auth.users
    SET raw_user_meta_data = jsonb_set(
          COALESCE(raw_user_meta_data, '{}'::jsonb),
          '{name}', to_jsonb(btrim(p_name)), true),
        updated_at = now()
    WHERE id = v_owner;
  END IF;

  UPDATE public.outlets
  SET name  = COALESCE(NULLIF(btrim(p_outlet_name), ''), name),
      phone = COALESCE(NULLIF(btrim(p_phone), ''), phone)
  WHERE id = p_outlet_id;

  PERFORM public.log_admin_action('account.edit', p_outlet_id::text,
    jsonb_build_object('owner_id', v_owner,
                       'name', p_name, 'email', lower(p_email),
                       'outlet_name', p_outlet_name));
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_account_edit(uuid, text, text, text, text) TO authenticated;

-- Reset password owner (bcrypt via pgcrypto). Tidak mengembalikan password.
CREATE OR REPLACE FUNCTION public.platform_account_reset_password(
  p_outlet_id uuid,
  p_new_password text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ok boolean;
  v_owner uuid;
BEGIN
  SELECT public.platform_is_admin() INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT owner_id INTO v_owner FROM public.outlets WHERE id = p_outlet_id;
  IF v_owner IS NULL THEN RAISE EXCEPTION 'outlet_not_found'; END IF;

  IF p_new_password IS NULL OR length(p_new_password) < 6 THEN
    RAISE EXCEPTION 'password minimal 6 karakter';
  END IF;

  UPDATE auth.users
  SET encrypted_password = crypt(p_new_password, gen_salt('bf')),
      updated_at = now()
  WHERE id = v_owner;

  PERFORM public.log_admin_action('account.password_reset', p_outlet_id::text,
    jsonb_build_object('owner_id', v_owner));
END;
$$;
GRANT EXECUTE ON FUNCTION public.platform_account_reset_password(uuid, text) TO authenticated;