-- KasirGo: hapus fitur notifikasi email update (SMTP hanya untuk verifikasi email).
-- System update tetap memakai banner in-app (get_latest_app_release), tanpa email.
DROP FUNCTION IF EXISTS public.admin_list_notifications(integer);
DROP FUNCTION IF EXISTS public.admin_log_notification(text, text, text, text, uuid, text, integer, text);
DROP TABLE IF EXISTS public.system_notifications;