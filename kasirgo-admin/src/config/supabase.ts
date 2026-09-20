import { createClient } from '@supabase/supabase-js'

export const SUPABASE_URL = 'https://lmvjecdvfzsmrowwwpck.supabase.co'
export const SUPABASE_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxtdmplY2R2ZnpzbXJvd3d3cGNrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkxMjk3MjgsImV4cCI6MjEwNDcwNTcyOH0.6waUmz-Kj32gGuxBs4DutgBDQtsSljazTuJQw_qZstI'

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)
