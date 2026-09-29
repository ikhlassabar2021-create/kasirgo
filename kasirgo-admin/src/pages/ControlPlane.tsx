import { useEffect, useState } from 'react';
import {
  Megaphone,
  BookOpen,
  Coins,
  ShieldCheck,
  Users,
  Flag,
  Zap,
  Plug,
  ScrollText,
  Save,
  Plus,
  Trash2,
  RefreshCw,
  AlertTriangle,
  Eye,
  EyeOff,
  SlidersHorizontal,
  Lock,
} from 'lucide-react';
import {
  loadConfig,
  saveConfig,
  listGuideItems,
  upsertGuideItem,
  deleteGuideItem,
  listIntegrations,
  saveIntegration,
  loadFinancialConfig,
  saveFinancialConfig,
  listFeatureFlags,
  upsertFeatureFlag,
  deleteFeatureFlag,
  listAutomationRules,
  upsertAutomationRule,
  deleteAutomationRule,
  listAuditLogs,
} from '../lib/controlPlane';
import type {
  ConfigKey,
  GuideItem,
  Integration,
  FeatureFlag,
  AutomationRule,
  AuditLog,
} from '../lib/controlPlane';

type TabId =
  | 'ads'
  | 'guide'
  | 'financial'
  | 'report'
  | 'kyc'
  | 'quota'
  | 'flags'
  | 'automation'
  | 'integrations'
  | 'audit';

const TABS: { id: TabId; name: string; icon: any }[] = [
  { id: 'ads', name: 'Iklan', icon: Megaphone },
  { id: 'guide', name: 'Panduan', icon: BookOpen },
  { id: 'financial', name: 'Financial', icon: Coins },
  { id: 'report', name: 'Laporan', icon: ScrollText },
  { id: 'kyc', name: 'KYC', icon: ShieldCheck },
  { id: 'quota', name: 'Kuota & Limit', icon: Users },
  { id: 'flags', name: 'Feature Flags', icon: Flag },
  { id: 'automation', name: 'Otomatisasi', icon: Zap },
  { id: 'integrations', name: 'Integrasi & Secret', icon: Plug },
  { id: 'audit', name: 'Audit Log', icon: ScrollText },
];

const inputCls =
  'w-full px-3.5 py-2.5 rounded-xl border border-slate-200 bg-slate-50/50 hover:bg-white focus:bg-white text-xs text-slate-800 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-sky-500/30 focus:border-sky-500 transition duration-150';
const labelCls = 'block text-[11px] font-bold text-slate-600 uppercase tracking-wider mb-1.5';

function Card({ title, subtitle, children, action }: any) {
  return (
    <div className="bg-white p-4 sm:p-6 rounded-2xl border border-slate-200/80 shadow-sm">
      <div className="flex items-start justify-between gap-3 pb-4 mb-4 border-b border-slate-100">
        <div>
          <h2 className="text-sm sm:text-base font-bold text-slate-900">{title}</h2>
          {subtitle && <p className="text-xs text-slate-500 mt-0.5">{subtitle}</p>}
        </div>
        {action}
      </div>
      {children}
    </div>
  );
}

function SaveButton({ onClick, loading, label = 'Simpan' }: any) {
  return (
    <button
      onClick={onClick}
      disabled={loading}
      className={`flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl font-semibold text-xs shadow-md transition active:scale-95 ${
        loading
          ? 'bg-sky-400 text-white cursor-not-allowed'
          : 'bg-gradient-to-r from-cyan-500 to-sky-600 hover:from-cyan-600 hover:to-sky-700 text-white shadow-sky-500/25'
      }`}
    >
      {loading ? <RefreshCw className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
      {label}
    </button>
  );
}

function useToast() {
  const [msg, setMsg] = useState<{ type: 'ok' | 'err'; text: string } | null>(null);
  const show = (type: 'ok' | 'err', text: string) => {
    setMsg({ type, text });
    setTimeout(() => setMsg(null), 3000);
  };
  return { msg, show };
}

function Toast({ msg }: { msg: { type: 'ok' | 'err'; text: string } | null }) {
  if (!msg) return null;
  return (
    <div
      className={`fixed bottom-5 right-5 z-50 px-4 py-2.5 rounded-xl text-xs font-semibold shadow-lg ${
        msg.type === 'ok' ? 'bg-emerald-500 text-white' : 'bg-red-500 text-white'
      }`}
    >
      {msg.text}
    </div>
  );
}

// ===========================================================================
// Generic JSON config sub-form components
// ===========================================================================
function AdsTab() {
  const [v, setV] = useState<any>({
    provider: 'sponsor_lokal',
    adsterra_key: '',
    sponsor_local: [],
    blocked_categories: ['judi', 'dewasa', 'pinjol'],
    placement: ['catalog', 'qr_menu'],
    ad_free_for_supporter: true,
    consent_required: true,
  });
  const [loading, setLoading] = useState(false);
  const { msg, show } = useToast();

  useEffect(() => {
    loadConfig('ads').then((d) => d && setV({ ...v, ...d })).catch(() => {});
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const sponsors: string[] = v.sponsor_local ?? [];

  return (
    <Card title="Iklan Sisi Pelanggan" subtitle="Iklan hanya tampil di halaman pelanggan. Owner tidak melihat iklan.">
      <div className="max-w-[760px] space-y-3.5">
        <div>
          <label className={labelCls}>Provider</label>
          <select className={inputCls} value={v.provider} onChange={(e) => setV({ ...v, provider: e.target.value })}>
            <option value="sponsor_lokal">Sponsor Lokal (diutamakan)</option>
            <option value="adsterra">Adsterra</option>
          </select>
        </div>
        <div>
          <label className={labelCls}>Adsterra Key / Zona</label>
          <input className={inputCls} type="password" value={v.adsterra_key ?? ''} onChange={(e) => setV({ ...v, adsterra_key: e.target.value })} placeholder="••••••••" />
        </div>
        <div>
          <label className={labelCls}>Kategori Diblokir (pisahkan koma)</label>
          <input className={inputCls} value={(v.blocked_categories ?? []).join(', ')} onChange={(e) => setV({ ...v, blocked_categories: e.target.value.split(',').map((s) => s.trim()).filter(Boolean) })} />
          <p className="text-[11px] text-slate-400 mt-1">Judi, dewasa, pinjol diblokir permanen oleh sistem.</p>
        </div>
        <div>
          <label className={labelCls}>Placement (pisahkan koma)</label>
          <input className={inputCls} value={(v.placement ?? []).join(', ')} onChange={(e) => setV({ ...v, placement: e.target.value.split(',').map((s) => s.trim()).filter(Boolean) })} />
        </div>
        <div className="grid grid-cols-2 gap-3">
          <label className="flex items-center gap-2 text-xs font-semibold text-slate-600">
            <input type="checkbox" checked={!!v.ad_free_for_supporter} onChange={(e) => setV({ ...v, ad_free_for_supporter: e.target.checked })} />
            Bebas iklan untuk Pendukung
          </label>
          <label className="flex items-center gap-2 text-xs font-semibold text-slate-600">
            <input type="checkbox" checked={!!v.consent_required} onChange={(e) => setV({ ...v, consent_required: e.target.checked })} />
            Wajib consent UU PDP
          </label>
        </div>

        <div className="pt-2 border-t border-slate-100">
          <div className="flex items-center justify-between mb-2">
            <label className={labelCls}>Sponsor Lokal</label>
            <button
              onClick={() => setV({ ...v, sponsor_local: [...sponsors, ''] })}
              className="flex items-center gap-1 text-[11px] font-bold text-sky-600 hover:text-sky-700"
            >
              <Plus className="w-3.5 h-3.5" /> Tambah
            </button>
          </div>
          {sponsors.length === 0 && <p className="text-[11px] text-slate-400">Belum ada sponsor lokal.</p>}
          {sponsors.map((s, i) => (
            <div key={i} className="flex gap-2 mb-2">
              <input
                className={inputCls}
                value={s}
                placeholder="https://sponsor.example.com"
                onChange={(e) => {
                  const next = [...sponsors];
                  next[i] = e.target.value;
                  setV({ ...v, sponsor_local: next });
                }}
              />
              <button
                onClick={() => setV({ ...v, sponsor_local: sponsors.filter((_, j) => j !== i) })}
                className="px-3 rounded-xl bg-red-50 text-red-500 hover:bg-red-100"
              >
                <Trash2 className="w-4 h-4" />
              </button>
            </div>
          ))}
        </div>

        <SaveButton loading={loading} onClick={async () => {
          setLoading(true);
          try { await saveConfig('ads', v); show('ok', 'Konfigurasi Iklan disimpan.'); }
          catch (e: any) { show('err', e.message); } finally { setLoading(false); }
        }} />
      </div>
      <Toast msg={msg} />
    </Card>
  );
}

function GuideTab() {
  const [items, setItems] = useState<GuideItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const { msg, show } = useToast();

  const empty: GuideItem = {
    title: '', kind: 'pdf', category: 'umum', role: 'all',
    url: '', file_key: '', thumbnail_key: '', sort_order: 0, is_active: true,
  };
  const [draft, setDraft] = useState<GuideItem>(empty);

  const reload = async () => {
    setLoading(true);
    try { setItems(await listGuideItems()); } catch (e: any) { show('err', e.message); }
    finally { setLoading(false); }
  };
  useEffect(() => { reload(); /* eslint-disable-next-line */ }, []);

  const save = async () => {
    if (!draft.title.trim()) { show('err', 'Judul wajib diisi.'); return; }
    setSaving(true);
    try {
      await upsertGuideItem({ ...draft, url: draft.url || null, file_key: draft.file_key || null, thumbnail_key: draft.thumbnail_key || null });
      show('ok', 'Panduan disimpan.');
      setDraft(empty);
      await reload();
    } catch (e: any) { show('err', e.message); } finally { setSaving(false); }
  };

  return (
    <Card title="Panduan (PDF / Video)" subtitle="Konten tampil di aplikasi owner lewat menu Panduan.">
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
        <div className="space-y-3">
          <div>
            <label className={labelCls}>Judul</label>
            <input className={inputCls} value={draft.title} onChange={(e) => setDraft({ ...draft, title: e.target.value })} />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className={labelCls}>Jenis</label>
              <select className={inputCls} value={draft.kind} onChange={(e) => setDraft({ ...draft, kind: e.target.value as any })}>
                <option value="pdf">PDF</option>
                <option value="video">Video</option>
              </select>
            </div>
            <div>
              <label className={labelCls}>Role</label>
              <select className={inputCls} value={draft.role} onChange={(e) => setDraft({ ...draft, role: e.target.value })}>
                <option value="all">Semua</option>
                <option value="owner">Owner</option>
                <option value="admin">Admin</option>
                <option value="cashier">Kasir</option>
                <option value="customer">Pelanggan</option>
              </select>
            </div>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className={labelCls}>Kategori</label>
              <input className={inputCls} value={draft.category} onChange={(e) => setDraft({ ...draft, category: e.target.value })} placeholder="mulai, produk, pos..." />
            </div>
            <div>
              <label className={labelCls}>Urutan</label>
              <input className={inputCls} type="number" value={draft.sort_order} onChange={(e) => setDraft({ ...draft, sort_order: Number(e.target.value) })} />
            </div>
          </div>
          <div>
            <label className={labelCls}>URL (video YouTube / PDF eksternal)</label>
            <input className={inputCls} value={draft.url ?? ''} onChange={(e) => setDraft({ ...draft, url: e.target.value })} placeholder="https://youtu.be/..." />
          </div>
          <div>
            <label className={labelCls}>File Key (R2, untuk PDF)</label>
            <input className={inputCls} value={draft.file_key ?? ''} onChange={(e) => setDraft({ ...draft, file_key: e.target.value })} placeholder="guides/panduan-pos.pdf" />
          </div>
          <div>
            <label className={labelCls}>Thumbnail Key (R2)</label>
            <input className={inputCls} value={draft.thumbnail_key ?? ''} onChange={(e) => setDraft({ ...draft, thumbnail_key: e.target.value })} />
          </div>
          <label className="flex items-center gap-2 text-xs font-semibold text-slate-600">
            <input type="checkbox" checked={draft.is_active} onChange={(e) => setDraft({ ...draft, is_active: e.target.checked })} />
            Aktif
          </label>
          <div className="flex gap-2">
            <SaveButton loading={saving} label={draft.id ? 'Perbarui' : 'Tambah'} onClick={save} />
            {draft.id && (
              <button onClick={() => setDraft(empty)} className="px-4 py-2.5 rounded-xl text-xs font-semibold border border-slate-200 text-slate-600 hover:bg-slate-50">
                Batal
              </button>
            )}
          </div>
        </div>

        <div className="space-y-2 max-h-[520px] overflow-y-auto pr-1">
          {loading && <p className="text-xs text-slate-400">Memuat...</p>}
          {!loading && items.length === 0 && <p className="text-xs text-slate-400">Belum ada panduan.</p>}
          {items.map((it) => (
            <div key={it.id} className="flex items-center gap-2 p-3 rounded-xl border border-slate-200 bg-slate-50/50">
              <div className="flex-1 min-w-0">
                <p className="text-xs font-bold text-slate-800 truncate">{it.title}</p>
                <p className="text-[10px] text-slate-500">{it.kind} · {it.category} · {it.role} · #{it.sort_order} {it.is_active ? '' : '· nonaktif'}</p>
              </div>
              <button onClick={() => setDraft(it)} className="text-[11px] font-bold text-sky-600 hover:text-sky-700">Edit</button>
              <button
                onClick={async () => {
                  if (!confirm(`Hapus "${it.title}"?`)) return;
                  try { await deleteGuideItem(it.id!); await reload(); show('ok', 'Terhapus.'); }
                  catch (e: any) { show('err', e.message); }
                }}
                className="text-red-500 hover:text-red-600"
              >
                <Trash2 className="w-4 h-4" />
              </button>
            </div>
          ))}
        </div>
      </div>
      <Toast msg={msg} />
    </Card>
  );
}

type StructuredField = {
  key: string;
  label: string;
  type: 'text' | 'number' | 'boolean' | 'list';
  hint?: string;
  placeholder?: string;
  options?: string[];
};

function StructuredConfigTab({
  configKey,
  title,
  subtitle,
  fields,
}: {
  configKey: ConfigKey;
  title: string;
  subtitle: string;
  fields: StructuredField[];
}) {
  const [v, setV] = useState<Record<string, any>>({});
  const [loading, setLoading] = useState(false);
  const { msg, show } = useToast();
  useEffect(() => {
    loadConfig(configKey).then((d) => setV(d ?? {})).catch(() => {});
  }, [configKey]);

  const set = (k: string, val: any) => setV((prev) => ({ ...prev, [k]: val }));

  return (
    <Card title={title} subtitle={subtitle}>
      <div className="max-w-[760px] space-y-3.5">
        {fields.map((f) => (
          <div key={f.key}>
            <label className={labelCls}>{f.label}</label>
            {f.type === 'boolean' ? (
              <label className="flex items-center gap-2 text-xs font-semibold text-slate-600">
                <input type="checkbox" checked={!!v[f.key]} onChange={(e) => set(f.key, e.target.checked)} />
                {f.hint ?? 'Aktifkan'}
              </label>
            ) : f.type === 'list' ? (
              <input
                className={inputCls}
                value={Array.isArray(v[f.key]) ? v[f.key].join(', ') : v[f.key] ?? ''}
                placeholder={f.placeholder}
                onChange={(e) => set(f.key, e.target.value.split(',').map((s) => s.trim()).filter(Boolean))}
              />
            ) : f.options ? (
              <select className={inputCls} value={v[f.key] ?? ''} onChange={(e) => set(f.key, e.target.value)}>
                {f.options.map((o) => <option key={o} value={o}>{o}</option>)}
              </select>
            ) : (
              <input
                className={inputCls}
                type={f.type}
                value={v[f.key] ?? ''}
                placeholder={f.placeholder}
                onChange={(e) => set(f.key, f.type === 'number' ? Number(e.target.value) : e.target.value)}
              />
            )}
            {f.hint && f.type !== 'boolean' && <p className="text-[11px] text-slate-400 mt-1">{f.hint}</p>}
          </div>
        ))}
        <SaveButton loading={loading} onClick={async () => {
          setLoading(true);
          try { await saveConfig(configKey, v); show('ok', `${title} disimpan.`); }
          catch (e: any) { show('err', e.message); } finally { setLoading(false); }
        }} />
      </div>
      <Toast msg={msg} />
    </Card>
  );
}

function FinancialTab() {
  const [v, setV] = useState<any>({});
  const [loading, setLoading] = useState(false);
  const { msg, show } = useToast();
  useEffect(() => { loadFinancialConfig().then(setV).catch(() => {}); }, []);

  const num = (k: string, label: string, suffix?: string) => (
    <div>
      <label className={labelCls}>{label}{suffix ? ` (${suffix})` : ''}</label>
      <input className={inputCls} type="number" value={v[k] ?? 0} onChange={(e) => setV({ ...v, [k]: Number(e.target.value) })} />
    </div>
  );

  return (
    <Card title="Konfigurasi Finansial" subtitle="Margin, limit QRIS, dan fee pencairan platform.">
      <div className="max-w-[760px] space-y-3.5">
        <div className="grid grid-cols-2 gap-3">
          {num('qris_base_mdr_percent', 'MDR Base QRIS', '%')}
          {num('kasirgo_margin_percent', 'Margin Platform', '%')}
          {num('kasirgo_margin_flat', 'Margin Flat', 'Rp')}
          {num('min_qris_amount', 'Min QRIS', 'Rp')}
          {num('max_qris_amount', 'Max QRIS', 'Rp')}
          {num('qris_free_threshold', 'Ambang Bebas Fee', 'Rp')}
          {num('min_disbursement_amount', 'Min Pencairan', 'Rp')}
          {num('disbursement_fee_standard', 'Fee Pencairan Standard', 'Rp')}
          {num('disbursement_fee_instant', 'Fee Pencairan Instant', 'Rp')}
        </div>
        <div>
          <label className={labelCls}>Fee Bearer</label>
          <select className={inputCls} value={v.fee_bearer ?? 'MERCHANT'} onChange={(e) => setV({ ...v, fee_bearer: e.target.value })}>
            <option value="MERCHANT">Merchant</option>
            <option value="CUSTOMER">Customer</option>
          </select>
        </div>
        <div>
          <label className={labelCls}>Jadwal Auto Settlement (pisahkan koma)</label>
          <input className={inputCls} value={(v.auto_settlement_schedules ?? []).join(', ')} onChange={(e) => setV({ ...v, auto_settlement_schedules: e.target.value.split(',').map((s) => s.trim()).filter(Boolean) })} />
        </div>
        <SaveButton loading={loading} onClick={async () => {
          setLoading(true);
          try {
            const { id, updated_at, updated_by, ...rest } = v;
            await saveFinancialConfig(rest);
            show('ok', 'Konfigurasi finansial disimpan.');
          } catch (e: any) { show('err', e.message); } finally { setLoading(false); }
        }} />
      </div>
      <Toast msg={msg} />
    </Card>
  );
}

function FlagsTab() {
  const [flags, setFlags] = useState<FeatureFlag[]>([]);
  const { msg, show } = useToast();
  const [draft, setDraft] = useState<FeatureFlag>({ key: '', enabled: false, rollout_pct: 100, segments: [], outlet_types: [] });

  const reload = async () => { try { setFlags(await listFeatureFlags()); } catch (e: any) { show('err', e.message); } };
  useEffect(() => { reload(); /* eslint-disable-next-line */ }, []);

  return (
    <Card title="Feature Flags" subtitle="Nyala/mati fitur + rollout bertahap per segmen/outlet_type.">
      <div className="max-w-[760px] space-y-3 mb-5">
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className={labelCls}>Key</label>
            <input className={inputCls} value={draft.key} onChange={(e) => setDraft({ ...draft, key: e.target.value })} placeholder="wa_marketing" />
          </div>
          <div>
            <label className={labelCls}>Rollout %</label>
            <input className={inputCls} type="number" value={draft.rollout_pct} onChange={(e) => setDraft({ ...draft, rollout_pct: Number(e.target.value) })} />
          </div>
        </div>
        <label className="flex items-center gap-2 text-xs font-semibold text-slate-600">
          <input type="checkbox" checked={draft.enabled} onChange={(e) => setDraft({ ...draft, enabled: e.target.checked })} /> Aktif
        </label>
        <SaveButton label="Simpan Flag" onClick={async () => {
          if (!draft.key.trim()) { show('err', 'Key wajib.'); return; }
          try { await upsertFeatureFlag(draft); setDraft({ key: '', enabled: false, rollout_pct: 100, segments: [], outlet_types: [] }); await reload(); show('ok', 'Flag disimpan.'); }
          catch (e: any) { show('err', e.message); }
        }} />
      </div>
      <div className="space-y-2">
        {flags.length === 0 && <p className="text-xs text-slate-400">Belum ada feature flag.</p>}
        {flags.map((f) => (
          <div key={f.key} className="flex items-center gap-3 p-3 rounded-xl border border-slate-200 bg-slate-50/50">
            <span className={`w-2 h-2 rounded-full ${f.enabled ? 'bg-emerald-500' : 'bg-slate-300'}`} />
            <span className="text-xs font-bold text-slate-800 flex-1">{f.key}</span>
            <span className="text-[11px] text-slate-500">rollout {f.rollout_pct}%</span>
            <button onClick={() => setDraft(f)} className="text-[11px] font-bold text-sky-600">Edit</button>
            <button onClick={async () => { if (!confirm(`Hapus ${f.key}?`)) return; try { await deleteFeatureFlag(f.id!); await reload(); } catch (e: any) { show('err', e.message); } }} className="text-red-500">
              <Trash2 className="w-4 h-4" />
            </button>
          </div>
        ))}
      </div>
      <Toast msg={msg} />
    </Card>
  );
}

function AutomationTab() {
  const [rules, setRules] = useState<AutomationRule[]>([]);
  const { msg, show } = useToast();
  const [draft, setDraft] = useState<AutomationRule>({ name: '', trigger: 'trial_expiring', condition: {}, action: {}, enabled: true });

  const reload = async () => { try { setRules(await listAutomationRules()); } catch (e: any) { show('err', e.message); } };
  useEffect(() => { reload(); /* eslint-disable-next-line */ }, []);

  const presets = ['auto_trial', 'auto_lock', 'auto_report', 'auto_kyc', 'trial_expiring', 'payment_failed'];

  return (
    <Card title="Otomatisasi Dasar" subtitle="Auto-trial/auto-lock, auto-report, auto-KYC. Atur sekali, jalan otomatis.">
      <div className="max-w-[760px] space-y-3 mb-5">
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className={labelCls}>Nama Rule</label>
            <input className={inputCls} value={draft.name} onChange={(e) => setDraft({ ...draft, name: e.target.value })} placeholder="Auto-lock outlet kedaluwarsa" />
          </div>
          <div>
            <label className={labelCls}>Trigger</label>
            <select className={inputCls} value={draft.trigger} onChange={(e) => setDraft({ ...draft, trigger: e.target.value })}>
              {presets.map((p) => <option key={p} value={p}>{p}</option>)}
            </select>
          </div>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className={labelCls}>Condition (JSON)</label>
            <textarea className={`${inputCls} font-mono min-h-[80px]`} value={JSON.stringify(draft.condition)} onChange={(e) => { try { setDraft({ ...draft, condition: JSON.parse(e.target.value) }); } catch {} }} />
          </div>
          <div>
            <label className={labelCls}>Action (JSON)</label>
            <textarea className={`${inputCls} font-mono min-h-[80px]`} value={JSON.stringify(draft.action)} onChange={(e) => { try { setDraft({ ...draft, action: JSON.parse(e.target.value) }); } catch {} }} />
          </div>
        </div>
        <label className="flex items-center gap-2 text-xs font-semibold text-slate-600">
          <input type="checkbox" checked={draft.enabled} onChange={(e) => setDraft({ ...draft, enabled: e.target.checked })} /> Aktif
        </label>
        <SaveButton label="Simpan Rule" onClick={async () => {
          if (!draft.name.trim()) { show('err', 'Nama wajib.'); return; }
          try { await upsertAutomationRule(draft); setDraft({ name: '', trigger: 'trial_expiring', condition: {}, action: {}, enabled: true }); await reload(); show('ok', 'Rule disimpan.'); }
          catch (e: any) { show('err', e.message); }
        }} />
      </div>
      <div className="space-y-2">
        {rules.length === 0 && <p className="text-xs text-slate-400">Belum ada rule otomatisasi.</p>}
        {rules.map((r) => (
          <div key={r.id} className="flex items-center gap-3 p-3 rounded-xl border border-slate-200 bg-slate-50/50">
            <span className={`w-2 h-2 rounded-full ${r.enabled ? 'bg-emerald-500' : 'bg-slate-300'}`} />
            <div className="flex-1 min-w-0">
              <p className="text-xs font-bold text-slate-800 truncate">{r.name}</p>
              <p className="text-[10px] text-slate-500">{r.trigger}</p>
            </div>
            <button onClick={() => setDraft(r)} className="text-[11px] font-bold text-sky-600">Edit</button>
            <button onClick={async () => { if (!confirm(`Hapus ${r.name}?`)) return; try { await deleteAutomationRule(r.id!); await reload(); } catch (e: any) { show('err', e.message); } }} className="text-red-500">
              <Trash2 className="w-4 h-4" />
            </button>
          </div>
        ))}
      </div>
      <Toast msg={msg} />
    </Card>
  );
}

function IntegrationsTab() {
  const [items, setItems] = useState<Integration[]>([]);
  const [shape, setShape] = useState<Record<string, { base_url: string; public_config: string; secret_config: string; is_active: boolean }>>({});
  const [reveal, setReveal] = useState<Record<string, boolean>>({});
  const [loading, setLoading] = useState(true);
  const { msg, show } = useToast();

  const reload = async () => {
    setLoading(true);
    try {
      const data = await listIntegrations();
      setItems(data);
      const s: any = {};
      data.forEach((it) => {
        s[it.key] = {
          base_url: it.base_url ?? '',
          public_config: JSON.stringify(it.public_config ?? {}, null, 2),
          secret_config: JSON.stringify(it.secret_config ?? {}, null, 2),
          is_active: it.is_active,
        };
      });
      setShape(s);
    } catch (e: any) { show('err', e.message); } finally { setLoading(false); }
  };
  useEffect(() => { reload(); /* eslint-disable-next-line */ }, []);

  const save = async (it: Integration) => {
    const form = shape[it.key];
    try {
      await saveIntegration({
        ...it,
        base_url: form.base_url || null,
        public_config: JSON.parse(form.public_config || '{}'),
        secret_config: JSON.parse(form.secret_config || '{}'),
        is_active: form.is_active,
      });
      show('ok', `${it.label ?? it.key} disimpan.`);
      await reload();
    } catch (e: any) { show('err', e.message); }
  };

  if (loading) return <Card title="Integrasi & Secret" subtitle="Memuat..."><p className="text-xs text-slate-400">Memuat...</p></Card>;

  return (
    <Card title="Integrasi & Secret" subtitle="Kredensial integrasi. Secret disimpan aman & tidak pernah dikirim ke aplikasi klien.">
      <div className="space-y-4">
        {items.map((it) => {
          const form = shape[it.key] ?? { base_url: '', public_config: '{}', secret_config: '{}', is_active: false };
          const secrets = Object.keys(JSON.parse(form.secret_config || '{}'));
          return (
            <div key={it.key} className="p-4 rounded-xl border border-slate-200">
              <div className="flex items-center justify-between mb-3">
                <div className="flex items-center gap-2">
                  <Lock className="w-4 h-4 text-slate-400" />
                  <span className="text-xs font-bold text-slate-800">{it.label ?? it.key}</span>
                  <span className="text-[10px] text-slate-400 font-mono">{it.key}</span>
                </div>
                <label className="flex items-center gap-2 text-[11px] font-semibold text-slate-600">
                  <input type="checkbox" checked={form.is_active} onChange={(e) => setShape({ ...shape, [it.key]: { ...form, is_active: e.target.checked } })} />
                  Aktif
                </label>
              </div>
              <div className="grid grid-cols-1 lg:grid-cols-2 gap-3">
                <div>
                  <label className={labelCls}>Base URL</label>
                  <input className={inputCls} value={form.base_url} onChange={(e) => setShape({ ...shape, [it.key]: { ...form, base_url: e.target.value } })} />
                </div>
                <div>
                  <label className={labelCls}>Secret (JSON) {secrets.length > 0 && <span className="text-amber-500">· {secrets.length} tersimpan</span>}</label>
                  <div className="relative">
                    <textarea
                      className={`${inputCls} font-mono min-h-[90px]`}
                      style={reveal[it.key] ? {} : { color: 'transparent', textShadow: '0 0 8px rgba(15,23,42,0.6)' }}
                      value={form.secret_config}
                      onChange={(e) => setShape({ ...shape, [it.key]: { ...form, secret_config: e.target.value } })}
                    />
                    <button
                      onClick={() => setReveal({ ...reveal, [it.key]: !reveal[it.key] })}
                      className="absolute top-2 right-2 p-1.5 rounded-lg bg-white border border-slate-200 text-slate-500"
                    >
                      {reveal[it.key] ? <EyeOff className="w-3.5 h-3.5" /> : <Eye className="w-3.5 h-3.5" />}
                    </button>
                  </div>
                  <p className="text-[10px] text-slate-400 mt-1">Nilai secret yang ada ditampilkan ter-mask. Isi hanya bila ingin mengubah.</p>
                </div>
                <div className="lg:col-span-2">
                  <label className={labelCls}>Public Config (JSON, aman ke klien)</label>
                  <textarea className={`${inputCls} font-mono min-h-[70px]`} value={form.public_config} onChange={(e) => setShape({ ...shape, [it.key]: { ...form, public_config: e.target.value } })} />
                </div>
              </div>
              <div className="mt-3">
                <SaveButton label="Simpan Integrasi" onClick={() => save(it)} />
              </div>
            </div>
          );
        })}
      </div>
      <Toast msg={msg} />
    </Card>
  );
}

function AuditTab() {
  const [logs, setLogs] = useState<AuditLog[]>([]);
  const [loading, setLoading] = useState(true);
  const { msg, show } = useToast();
  const reload = async () => {
    setLoading(true);
    try { setLogs(await listAuditLogs(100)); } catch (e: any) { show('err', e.message); } finally { setLoading(false); }
  };
  useEffect(() => { reload(); /* eslint-disable-next-line */ }, []);
  return (
    <Card
      title="Audit Log"
      subtitle="Jejak aksi tim superadmin. Secret tidak pernah dicatat."
      action={
        <button onClick={reload} className="p-2 rounded-lg border border-slate-200 text-slate-500 hover:bg-slate-50">
          <RefreshCw className="w-4 h-4" />
        </button>
      }
    >
      <div className="space-y-2">
        {loading && <p className="text-xs text-slate-400">Memuat...</p>}
        {!loading && logs.length === 0 && <p className="text-xs text-slate-400">Belum ada aktivitas.</p>}
        {logs.map((l) => (
          <div key={l.id} className="flex items-center gap-3 p-2.5 rounded-lg border border-slate-100 bg-slate-50/40 text-xs">
            <span className="font-mono text-[10px] text-sky-600 font-bold">{l.action}</span>
            <span className="text-slate-600 flex-1 truncate">{l.target}</span>
            <span className="text-[10px] text-slate-400">{l.actor_role}</span>
            <span className="text-[10px] text-slate-400">{new Date(l.created_at).toLocaleString('id-ID')}</span>
          </div>
        ))}
      </div>
      <Toast msg={msg} />
    </Card>
  );
}

// ===========================================================================
export function ControlPlanePage() {
  const [activeId, setActiveId] = useState<TabId>('ads');
  const [warning] = useState<string | null>(null);

  return (
    <div className="space-y-4 max-w-[1100px] mx-auto text-slate-800 fade-in">
      <div className="bg-white p-4 sm:p-5 rounded-2xl border border-slate-200/80 shadow-sm flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <div className="w-11 h-11 rounded-xl bg-gradient-to-br from-cyan-500 to-sky-600 p-0.5 shadow-md shadow-sky-500/20 shrink-0">
            <div className="w-full h-full bg-white rounded-[10px] flex items-center justify-center text-sky-600">
              <SlidersHorizontal className="w-5 h-5" />
            </div>
          </div>
          <div className="min-w-0">
            <h1 className="text-base sm:text-lg font-bold text-slate-900 tracking-tight">Control Plane</h1>
            <p className="text-slate-500 text-xs mt-0.5">Atur semua konfigurasi & integrasi tanpa mengubah koding.</p>
          </div>
        </div>
        <span className="px-2.5 py-1 bg-sky-50 text-sky-700 border border-sky-200/80 rounded-full text-[10px] font-bold tracking-wide self-start sm:self-auto">
          KONFIGURASI PLATFORM
        </span>
      </div>

      {warning && (
        <div className="flex items-center gap-2 p-3 rounded-xl bg-amber-50 border border-amber-200 text-xs text-amber-700">
          <AlertTriangle className="w-4 h-4" /> {warning}
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-[240px_1fr] gap-3.5 sm:gap-4">
        <aside className="bg-white p-2.5 rounded-2xl border border-slate-200/80 shadow-sm h-max lg:sticky lg:top-4">
          <nav className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-1 gap-1">
            {TABS.map((tab) => {
              const Icon = tab.icon;
              const isActive = tab.id === activeId;
              return (
                <button
                  key={tab.id}
                  onClick={() => setActiveId(tab.id)}
                  className={`flex items-center gap-2.5 px-3 py-2.5 rounded-xl text-xs font-semibold transition ${
                    isActive
                      ? 'bg-gradient-to-r from-cyan-500 to-sky-600 text-white shadow-sm shadow-sky-500/25'
                      : 'text-slate-600 hover:bg-slate-100 hover:text-slate-900'
                  }`}
                >
                  <Icon className={`w-4 h-4 shrink-0 ${isActive ? 'text-white' : 'text-slate-500'}`} />
                  <span className="truncate">{tab.name}</span>
                </button>
              );
            })}
          </nav>
        </aside>

        <div className="min-w-0">
          {activeId === 'ads' && <AdsTab />}
          {activeId === 'guide' && <GuideTab />}
          {activeId === 'financial' && <FinancialTab />}
          {activeId === 'report' && <StructuredConfigTab configKey="report" title="Laporan Otomatis" subtitle="Template, jadwal default, kanal, dan batas penerima." fields={[
            { key: 'default_period', label: 'Periode Default', type: 'text', options: ['daily', 'weekly', 'monthly'] },
            { key: 'default_time', label: 'Jam Default', type: 'text', placeholder: '21:00' },
            { key: 'max_recipients', label: 'Maks Penerima', type: 'number', hint: 'Jumlah maksimum penerima laporan.' },
            { key: 'channels', label: 'Kanal', type: 'list', placeholder: 'email, wa', hint: 'Pisahkan dengan koma.' },
          ]} />}
          {activeId === 'kyc' && <StructuredConfigTab configKey="kyc" title="KYC" subtitle="Wajib/tidak, auto-verify, dan daftar field." fields={[
            { key: 'required', label: 'KYC Wajib', type: 'boolean', hint: 'Aplikasi terkunci sampai terverifikasi' },
            { key: 'auto_verify', label: 'Auto-Verify', type: 'boolean', hint: 'Verifikasi otomatis bila 6 field valid' },
            { key: 'fields', label: 'Field Wajib', type: 'list', placeholder: 'email, phone, store_name...', hint: 'Pisahkan dengan koma.' },
          ]} />}
          {activeId === 'quota' && <StructuredConfigTab configKey="quota" title="Kuota & Limit" subtitle="Kuota staf gratis & kebijakan tambahan." fields={[
            { key: 'max_admin', label: 'Maks Admin Gratis', type: 'number' },
            { key: 'max_cashier', label: 'Maks Kasir Gratis', type: 'number' },
            { key: 'extra_from_supporter', label: 'Slot Tambahan via Pendukung', type: 'boolean', hint: 'Buka slot ekstra untuk Pendukung' },
          ]} />}
          {activeId === 'flags' && <FlagsTab />}
          {activeId === 'automation' && <AutomationTab />}
          {activeId === 'integrations' && <IntegrationsTab />}
          {activeId === 'audit' && <AuditTab />}
        </div>
      </div>
    </div>
  );
}