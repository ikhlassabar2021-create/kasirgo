import { supabase } from '../config/supabase'

export type ConfigKey =
  | 'ads'
  | 'guide'
  | 'report'
  | 'kyc'
  | 'quota'
  | 'flags'
  | 'billing'

export interface PlatformConfig {
  id?: string
  key: ConfigKey
  scope: string
  scope_ref: string
  value: Record<string, any>
  version?: number
}

export interface GuideItem {
  id?: string
  title: string
  kind: 'pdf' | 'video'
  category: string
  role: string
  url: string | null
  file_key: string | null
  thumbnail_key: string | null
  sort_order: number
  is_active: boolean
}

export interface Integration {
  id?: string
  key: string
  label: string | null
  base_url: string | null
  public_config: Record<string, any>
  secret_config: Record<string, any>
  is_active: boolean
}

export interface FeatureFlag {
  id?: string
  key: string
  enabled: boolean
  rollout_pct: number
  segments: any[]
  outlet_types: any[]
}

export interface AutomationRule {
  id?: string
  name: string
  trigger: string
  condition: Record<string, any>
  action: Record<string, any>
  enabled: boolean
}

export interface AuditLog {
  id: string
  actor_role: string | null
  action: string | null
  target: string | null
  meta: Record<string, any>
  created_at: string
}

async function logAction(action: string, target: string, meta: Record<string, any> = {}) {
  try {
    await supabase.rpc('log_admin_action', {
      p_action: action,
      p_target: target,
      p_meta: meta,
    })
  } catch (e) {
    console.warn('audit log failed', e)
  }
}

// ---------------------------------------------------------------------------
// platform_configs (global scope)
// ---------------------------------------------------------------------------
export async function loadConfig(key: ConfigKey): Promise<Record<string, any> | null> {
  const { data, error } = await supabase
    .from('platform_configs')
    .select('id,key,scope,scope_ref,value,version')
    .eq('key', key)
    .eq('scope', 'global')
    .order('version', { ascending: false })
    .limit(1)
    .maybeSingle()
  if (error) throw error
  return data?.value ?? null
}

export async function saveConfig(key: ConfigKey, value: Record<string, any>) {
  // ST11-3: simpan via RPC agar version+1, updated_by, riwayat, dan audit
  // konsisten (tabel ditulis SECURITY DEFINER, bukan langsung dari client).
  const { error } = await supabase.rpc('platform_config_save', {
    p_key: key,
    p_scope: 'global',
    p_scope_ref: 'all',
    p_value: value,
  })
  if (error) throw error
}

// ---------------------------------------------------------------------------
// guide_items CRUD
// ---------------------------------------------------------------------------
export async function listGuideItems(): Promise<GuideItem[]> {
  const { data, error } = await supabase
    .from('guide_items')
    .select('*')
    .order('sort_order', { ascending: true })
  if (error) throw error
  return (data ?? []) as GuideItem[]
}

export async function upsertGuideItem(item: GuideItem) {
  const { error } = await supabase.from('guide_items').upsert(
    { ...item, updated_at: new Date().toISOString() },
    { onConflict: 'id' },
  )
  if (error) throw error
  await logAction(item.id ? 'guide.update' : 'guide.create', `guide_items:${item.title}`)
}

export async function deleteGuideItem(id: string) {
  const { error } = await supabase.from('guide_items').delete().eq('id', id)
  if (error) throw error
  await logAction('guide.delete', `guide_items:${id}`)
}

// ---------------------------------------------------------------------------
// platform_integrations
// ---------------------------------------------------------------------------
export async function listIntegrations(): Promise<Integration[]> {
  const { data, error } = await supabase
    .from('platform_integrations')
    .select('*')
    .order('key', { ascending: true })
  if (error) throw error
  return (data ?? []) as Integration[]
}

export async function saveIntegration(integration: Integration) {
  const payload: Record<string, any> = {
    key: integration.key,
    label: integration.label,
    base_url: integration.base_url,
    public_config: integration.public_config ?? {},
    is_active: integration.is_active,
    updated_at: new Date().toISOString(),
  }
  // Hanya simpan secret bila ada isinya (jangan timpa dengan kosong).
  const secret = integration.secret_config ?? {}
  const nonEmpty = Object.fromEntries(
    Object.entries(secret).filter(([, v]) => v !== '' && v !== null && v !== undefined),
  )
  if (Object.keys(nonEmpty).length > 0) payload.secret_config = nonEmpty

  if (integration.id) {
    const { error } = await supabase.from('platform_integrations').update(payload).eq('id', integration.id)
    if (error) throw error
  } else {
    const { error } = await supabase
      .from('platform_integrations')
      .upsert({ ...payload, secret_config: secret }, { onConflict: 'key' })
    if (error) throw error
  }
  await logAction('integration.save', `platform_integrations:${integration.key}`, {
    active: integration.is_active,
  })
}

// ---------------------------------------------------------------------------
// financial config
// ---------------------------------------------------------------------------
export async function loadFinancialConfig(): Promise<Record<string, any>> {
  const { data, error } = await supabase
    .from('platform_financial_configs')
    .select('*')
    .order('updated_at', { ascending: false })
    .limit(1)
    .maybeSingle()
  if (error) throw error
  return data ?? {}
}

export async function saveFinancialConfig(values: Record<string, any>) {
  const current = await supabase
    .from('platform_financial_configs')
    .select('id')
    .order('updated_at', { ascending: false })
    .limit(1)
    .maybeSingle()
  const payload = { ...values, updated_at: new Date().toISOString() }
  if (current.data?.id) {
    const { error } = await supabase.from('platform_financial_configs').update(payload).eq('id', current.data.id)
    if (error) throw error
  } else {
    const { error } = await supabase.from('platform_financial_configs').insert(payload)
    if (error) throw error
  }
  await logAction('financial.update', 'platform_financial_configs')
}

// ---------------------------------------------------------------------------
// feature_flags
// ---------------------------------------------------------------------------
export async function listFeatureFlags(): Promise<FeatureFlag[]> {
  const { data, error } = await supabase.from('feature_flags').select('*').order('key')
  if (error) throw error
  return (data ?? []) as FeatureFlag[]
}

export async function upsertFeatureFlag(flag: FeatureFlag) {
  const { error } = await supabase.from('feature_flags').upsert(
    { ...flag, updated_at: new Date().toISOString() },
    { onConflict: 'key' },
  )
  if (error) throw error
  await logAction('flag.save', `feature_flags:${flag.key}`, { enabled: flag.enabled })
}

export async function deleteFeatureFlag(id: string) {
  const { error } = await supabase.from('feature_flags').delete().eq('id', id)
  if (error) throw error
  await logAction('flag.delete', `feature_flags:${id}`)
}

// ---------------------------------------------------------------------------
// automation_rules
// ---------------------------------------------------------------------------
export async function listAutomationRules(): Promise<AutomationRule[]> {
  const { data, error } = await supabase
    .from('automation_rules')
    .select('*')
    .order('created_at', { ascending: false })
  if (error) throw error
  return (data ?? []) as AutomationRule[]
}

export async function upsertAutomationRule(rule: AutomationRule) {
  const { error } = await supabase.from('automation_rules').upsert(rule, { onConflict: 'id' })
  if (error) throw error
  await logAction('automation.save', `automation_rules:${rule.name}`, { enabled: rule.enabled })
}

export async function deleteAutomationRule(id: string) {
  const { error } = await supabase.from('automation_rules').delete().eq('id', id)
  if (error) throw error
  await logAction('automation.delete', `automation_rules:${id}`)
}

// ---------------------------------------------------------------------------
// audit_logs
// ---------------------------------------------------------------------------
export async function listAuditLogs(limit = 50): Promise<AuditLog[]> {
  const { data, error } = await supabase
    .from('audit_logs')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(limit)
  if (error) throw error
  return (data ?? []) as AuditLog[]
}

// ---------------------------------------------------------------------------
// Langganan Pendukung (verifikasi pembayaran QRIS/transfer manual)
// ---------------------------------------------------------------------------
export interface PendingSupporter {
  id: string
  outlet_id: string
  outlet_name?: string
  amount: number
  status: string
  pg_reference_id?: string
  updated_at: string
}

export async function listPendingSupporters(): Promise<PendingSupporter[]> {
  const { data, error } = await supabase
    .from('supporters')
    .select('id, outlet_id, amount, status, pg_reference_id, updated_at, outlets(name)')
    .in('status', ['pending', 'pending_verification'])
    .order('updated_at', { ascending: false })
    .limit(100)
  if (error) throw error
  return (data ?? []).map((r: any) => ({
    id: r.id,
    outlet_id: r.outlet_id,
    outlet_name: r.outlets?.name ?? r.outlet_id,
    amount: r.amount,
    status: r.status,
    pg_reference_id: r.pg_reference_id,
    updated_at: r.updated_at,
  }))
}

export async function setSupporterStatus(id: string, approve: boolean) {
  const { data, error } = await supabase.rpc('admin_set_supporter_status', {
    p_supporter_id: id,
    p_approve: approve,
  })
  if (error) throw error
  await logAdminAction(
    approve ? 'supporter_approve' : 'supporter_reject',
    id,
    { via: 'control_plane' }
  )
  return data
}

async function logAdminAction(action: string, target: string, meta: Record<string, any>) {
  try {
    await supabase.rpc('log_admin_action', {
      p_action: action,
      p_target: target,
      p_meta: meta,
    })
  } catch (_) {
    /* audit best-effort */
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
export function maskSecret(value: any): string {
  if (value === null || value === undefined || value === '') return ''
  const s = String(value)
  if (s.length <= 4) return '••••'
  return '••••••••' + s.slice(-4)
}