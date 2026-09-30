import { supabase } from '../config/supabase'

// ---------------------------------------------------------------------------
// Admin API helpers - semua data via RPC SECURITY DEFINER (superadmin only).
// Secret TIDAK pernah dikirim ke client: kolom secret_config tidak dibaca di sini.
// ---------------------------------------------------------------------------

export const rp = async <T>(fn: string, params: Record<string, unknown> = {}): Promise<T> => {
  const { data, error } = await supabase.rpc(fn, params)
  if (error) throw new Error(error.message)
  return data as T
}

export const fmtRp = (v: number | null | undefined): string => {
  const n = Number(v ?? 0)
  if (Math.abs(n) >= 1_000_000_000) return `Rp ${(n / 1_000_000_000).toFixed(1)}M`
  if (Math.abs(n) >= 1_000_000) return `Rp ${(n / 1_000_000).toFixed(1)}jt`
  if (Math.abs(n) >= 1_000) return `Rp ${(n / 1_000).toFixed(0)}rb`
  return `Rp ${n.toFixed(0)}`
}

export const fmtDate = (iso: string | null | undefined): string => {
  if (!iso) return '-'
  const d = new Date(iso)
  return d.toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' })
}

// 12 revenue engine + warna chart (Ocean White tokens).
export const REVENUE_ENGINES: { key: string; label: string; color: string }[] = [
  { key: 'pendukung', label: 'Pendukung', color: '#0284C7' },
  { key: 'ppob_margin', label: 'PPOB', color: '#06B6D4' },
  { key: 'restock_b2b', label: 'B2B Restock', color: '#10B981' },
  { key: 'affiliate', label: 'Affiliate', color: '#4F46E5' },
  { key: 'fintech', label: 'Fintech', color: '#8B5CF6' },
  { key: 'insurance', label: 'Asuransi', color: '#F59E0B' },
  { key: 'qris_margin', label: 'QRIS', color: '#EF4444' },
  { key: 'ads', label: 'Iklan', color: '#EC4899' },
  { key: 'sponsored_receipt', label: 'Sponsor Struk', color: '#14B8A6' },
  { key: 'storage', label: 'Storage', color: '#64748B' },
  { key: 'hyperlocal', label: 'Hyperlocal', color: '#3B82F6' },
  { key: 'other', label: 'Lainnya', color: '#94A3B8' },
]

export type RevenueRow = { bucket: string; engine: string; amount: number }

export type UsersListResult = {
  total: number
  rows: {
    user_id: string
    name: string
    email: string
    outlet_id: string | null
    outlet_name: string | null
    outlet_type: string | null
    is_supporter: boolean
    ad_free: boolean
    on_trial: boolean
    kyc_status: string
    payment_status: string
    tx_count: number
    created_at: string
  }[]
}

export type UserDetailResult = {
  user: { id: string; email: string; name: string; created_at: string } | null
  outlet: { id: string; name: string; type: string; address: string; phone: string; created_at: string } | null
  kyc: Record<string, unknown> | null
  entitlements: Record<string, unknown> | null
  subscription: Record<string, unknown> | null
  stats: Record<string, number>
  recent_transactions: { id: string; final_amount: number; payment_method: string; order_status: string; created_at: string }[]
  leads: { fintech: number; insurance: number; restock: number }
}

// Guard: user saat ini harus admin aktif (dipakai layout + route guard).
export const checkAdminRole = async (): Promise<{
  isAdmin: boolean
  role: string
} | null> => {
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return null
  const { data } = await supabase
    .from('admin_users')
    .select('role')
    .eq('user_id', user.id)
    .eq('is_active', true)
    .maybeSingle()
  if (!data) return null
  return { isAdmin: true, role: data.role ?? 'superadmin' }
}

// ---------------------------------------------------------------------------
// ST11-2: audit, backup, impersonate, intelligence
// ---------------------------------------------------------------------------

export type AuditRow = {
  id: string
  actor_id: string | null
  actor_role: string | null
  action: string
  target: string | null
  meta: Record<string, unknown>
  created_at: string
  actor_email: string
}

export type AuditListResult = { total: number; rows: AuditRow[] }

export type BackupRunRow = {
  id: string
  outlet_id: string
  outlet_name: string | null
  kind: 'full' | 'quick'
  status: string
  row_count: number
  size_bytes: number
  created_at: string
}

export type BackupListResult = { rows: BackupRunRow[] }

export type ImpersonateResult = {
  outlet: { id: string; name: string; outlet_type?: string; type?: string; address?: string; phone?: string; created_at?: string } | null
  entitlements: Record<string, unknown> | null
  summary: {
    product_count: number; customer_count: number; staff_count: number
    tx_today: number; omzet_today: number; omzet_30d: number
  }
  last7d: { day: string; tx: number; omzet: number }[]
  top_products: { product_name: string; qty: number; omzet: number }[]
  recent_transactions: { id: string; final_amount: number; payment_method: string; order_status: string; created_at: string }[]
  staff: { email: string | null; role: string; is_active: boolean }[]
}

export type IntelligenceResult = {
  kpis: { total_outlets: number; active_30d: number; new_30d: number; avg_tx_per_outlet_30d: number }
  trend: { day: string; tx: number; omzet: number }[]
  weekly_active: { week: string; outlets: number; tx: number }[]
  churn_risk: { outlet_id: string; outlet_name: string; last_tx_at: string; tx_total: number }[]
  anomaly: { day: string; tx: number; z: number }[]
}

export const fmtBytes = (b: number): string => {
  if (b >= 1_048_576) return `${(b / 1_048_576).toFixed(1)} MB`
  if (b >= 1024) return `${(b / 1024).toFixed(0)} KB`
  return `${b} B`
}

// ---------------------------------------------------------------------------
// Phase 13: Outlet Terdaftar, Fitur Utama, Laporan Utama
// ---------------------------------------------------------------------------

// Modul (fitur) yang bisa di-toggle superadmin per outlet -> key `module_<name>`.
export const MODULE_LABELS: { key: string; label: string }[] = [
  { key: 'module_pos', label: 'Kasir (POS)' },
  { key: 'module_inventory', label: 'Inventori / Stok' },
  { key: 'module_debt', label: 'Kasbon / Piutang' },
  { key: 'module_variants', label: 'Varian Produk' },
  { key: 'module_wholesalePrice', label: 'Harga Grosir' },
  { key: 'module_splitBill', label: 'Pisah Tagihan' },
  { key: 'module_dailyDigest', label: 'AI Digest Harian' },
  { key: 'module_ppob', label: 'PPOB (Pulsa/Token)' },
  { key: 'module_restockB2B', label: 'Kulakan B2B' },
  { key: 'module_tableManagement', label: 'QR Meja' },
  { key: 'module_kitchenDisplay', label: 'KDS (Dapur)' },
]

export type OutletRow = {
  outlet_id: string
  outlet_name: string | null
  outlet_type: string | null
  address: string | null
  phone: string | null
  created_at: string
  user_id: string
  owner_name: string
  email: string
  kyc_status: string
  auto_verified: boolean | null
  reject_reason: string | null
  verified_at: string | null
  is_supporter: boolean
  on_trial: boolean
  trial_ends_at: string | null
  supp_status: string
  staff_count: number
  tx_count: number
  omzet_total: number
}

export type OutletsListResult = { total: number; rows: OutletRow[] }

export type OutletStaffRow = {
  user_id: string
  role: string
  created_at: string
  email: string
}

export type OutletReportResult = {
  outlet_id: string
  start: string
  end: string
  pos: { omzet: number; count: number }
  ppob: { omzet: number; untung: number; count: number }
  pg: { untung: number; count: number }
  b2b: { komisi: number; count: number }
  insurance: { komisi: number; count: number }
  fintech: { pengajuan: number; count: number }
  omzet_total: number
  untung_total: number
  count_total: number
}

export type MainReportResult = {
  period_days: number
  plans: { trial: number; free: number; pendukung: number }
  pendukung: { revenue_period: number; mrr: number; active: number }
  ppob: { omzet: number; untung: number; count: number }
  pg: { untung: number; count: number }
}

export const platformOutletsList = (
  params: { p_search?: string | null; p_kyc?: string; p_plan?: string; p_limit?: number; p_offset?: number },
) => rp<OutletsListResult>('platform_outlets_list', {
  p_search: params.p_search ?? null,
  p_kyc: params.p_kyc ?? 'verified',
  p_plan: params.p_plan ?? 'all',
  p_limit: params.p_limit ?? 25,
  p_offset: params.p_offset ?? 0,
})

export const platformSetVerification = (outletId: string, status: string, reason?: string | null) =>
  rp<void>('platform_outlet_set_verification', {
    p_outlet_id: outletId, p_status: status, p_reason: reason ?? null,
  })

export const platformSetPlan = (outletId: string, plan: string) =>
  rp<void>('platform_outlet_set_plan', { p_outlet_id: outletId, p_plan: plan })

export const platformOutletFeatures = (outletId: string) =>
  rp<{ effective: Record<string, boolean>; overrides: Record<string, boolean> }>(
    'platform_outlet_features', { p_outlet_id: outletId })

export const platformOutletSetFeature = (outletId: string, key: string, enabled: boolean) =>
  rp<void>('platform_outlet_set_feature', {
    p_outlet_id: outletId, p_key: key, p_enabled: enabled,
  })

export const platformOutletStaff = (outletId: string) =>
  rp<{ rows: OutletStaffRow[] }>('platform_outlet_staff', { p_outlet_id: outletId })

export const platformOutletRemoveStaff = (outletId: string, userId: string) =>
  rp<void>('platform_outlet_remove_staff', { p_outlet_id: outletId, p_user_id: userId })

export const platformOutletDeleteAccount = (outletId: string) =>
  rp<void>('platform_outlet_delete_account', { p_outlet_id: outletId })

export const platformOutletReport = (outletId: string, start: string, end: string) =>
  rp<OutletReportResult>('platform_outlet_report', {
    p_outlet_id: outletId, p_start: start, p_end: end,
  })

export const platformMainReport = (days = 30) =>
  rp<MainReportResult>('platform_main_report', { p_days: days })
