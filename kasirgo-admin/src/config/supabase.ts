import { createClient } from '@supabase/supabase-js'

export const SUPABASE_URL = 'https://lmvjecdvfzsmrowwwpck.supabase.co'
export const SUPABASE_ANON_KEY =
  'sb_publishable_8RJnG66i_37cih8GTG1sBA_0B91KOW_'

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)
