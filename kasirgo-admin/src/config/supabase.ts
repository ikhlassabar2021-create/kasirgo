import { createClient } from '@supabase/supabase-js'

// Nilai bawaan (Supabase cloud). Bisa ditimpa saat self-host lewat
// `window.__KASIRGO_ADMIN_CONFIG__ = { supabaseUrl, supabaseAnonKey }`
// yang ditulis oleh installer sebelum bundle admin dimuat.
type RuntimeCfg = { supabaseUrl?: string; supabaseAnonKey?: string }

function runtimeConfig(): RuntimeCfg {
  try {
    const w = window as unknown as { __KASIRGO_ADMIN_CONFIG__?: RuntimeCfg }
    return w.__KASIRGO_ADMIN_CONFIG__ ?? {}
  } catch {
    return {}
  }
}

const cfg = runtimeConfig()

export const SUPABASE_URL =
  cfg.supabaseUrl ?? 'https://lmvjecdvfzsmrowwwpck.supabase.co'
export const SUPABASE_ANON_KEY =
  cfg.supabaseAnonKey ?? 'sb_publishable_8RJnG66i_37cih8GTG1sBA_0B91KOW_'

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)