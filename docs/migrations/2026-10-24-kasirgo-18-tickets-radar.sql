-- ============================================================================
-- KasirGo - Batch 18 (1.0.8): Tiket Support + Radius Radar
-- 2026-10-24
-- ----------------------------------------------------------------------------
-- Isi:
--   1) Tabel support_tickets + support_ticket_replies + RLS
--      (owner/staf membuat & membalas tiket outletnya; superadmin melihat,
--       membalas, mengubah status open/proses/close, dan menghapus).
--   2) Radius default radar hyperlocal 3 km -> 10 km (radar lebih berguna;
--      max tetap 10 km dari config max_radius_km).
-- Idempoten.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1) TABEL
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.support_tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  created_by UUID,
  subject TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','proses','close')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  closed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_support_tickets_outlet
  ON public.support_tickets(outlet_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_support_tickets_status
  ON public.support_tickets(status);

CREATE TABLE IF NOT EXISTS public.support_ticket_replies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id UUID NOT NULL REFERENCES public.support_tickets(id) ON DELETE CASCADE,
  author_uid UUID,
  author_role TEXT NOT NULL DEFAULT 'staf' CHECK (author_role IN ('owner','staf','superadmin')),
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_support_ticket_replies_ticket
  ON public.support_ticket_replies(ticket_id, created_at);

CREATE OR REPLACE FUNCTION public.touch_support_ticket_updated()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.updated_at := now();
  IF NEW.status = 'close' AND OLD.status <> 'close' THEN
    NEW.closed_at := now();
  ELSIF NEW.status <> 'close' THEN
    NEW.closed_at := NULL;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_support_tickets_updated ON public.support_tickets;
CREATE TRIGGER trg_support_tickets_updated
  BEFORE UPDATE ON public.support_tickets
  FOR EACH ROW EXECUTE FUNCTION public.touch_support_ticket_updated();

-- ---------------------------------------------------------------------------
-- 2) RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_ticket_replies ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Outlet member read tickets" ON public.support_tickets;
CREATE POLICY "Outlet member read tickets" ON public.support_tickets
  FOR SELECT TO authenticated
  USING (public.is_outlet_member(outlet_id));

DROP POLICY IF EXISTS "Outlet member insert tickets" ON public.support_tickets;
CREATE POLICY "Outlet member insert tickets" ON public.support_tickets
  FOR INSERT TO authenticated
  WITH CHECK (public.is_outlet_member(outlet_id));

DROP POLICY IF EXISTS "Owner update tickets" ON public.support_tickets;
CREATE POLICY "Owner update tickets" ON public.support_tickets
  FOR UPDATE TO authenticated
  USING (public.is_outlet_owner(outlet_id))
  WITH CHECK (public.is_outlet_owner(outlet_id));

DROP POLICY IF EXISTS "Superadmin full tickets" ON public.support_tickets;
CREATE POLICY "Superadmin full tickets" ON public.support_tickets
  FOR ALL TO authenticated
  USING (public.is_platform_admin())
  WITH CHECK (public.is_platform_admin());

DROP POLICY IF EXISTS "Outlet member read replies" ON public.support_ticket_replies;
CREATE POLICY "Outlet member read replies" ON public.support_ticket_replies
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.support_tickets t
    WHERE t.id = ticket_id AND public.is_outlet_member(t.outlet_id)
  ));

DROP POLICY IF EXISTS "Outlet member insert replies" ON public.support_ticket_replies;
CREATE POLICY "Outlet member insert replies" ON public.support_ticket_replies
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.support_tickets t
    WHERE t.id = ticket_id AND public.is_outlet_member(t.outlet_id)
  ));

DROP POLICY IF EXISTS "Superadmin full replies" ON public.support_ticket_replies;
CREATE POLICY "Superadmin full replies" ON public.support_ticket_replies
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.support_tickets t
    WHERE t.id = ticket_id AND public.is_platform_admin()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.support_tickets t
    WHERE t.id = ticket_id AND public.is_platform_admin()
  ));

-- ---------------------------------------------------------------------------
-- 3) RADAR: radius default 10 km (max tetap 10 km)
-- ---------------------------------------------------------------------------
UPDATE public.platform_configs
SET value = jsonb_set(value, '{radius_default_km}', '"10"')
WHERE key = 'hyperlocal' AND scope = 'global';
