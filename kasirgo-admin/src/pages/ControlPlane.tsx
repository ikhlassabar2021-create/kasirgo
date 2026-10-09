import { useEffect, useState, useCallback } from 'react';
import type { ReactNode } from 'react';
import {
  Megaphone,
  BookOpen,
  Coins,
  ShieldCheck,
  Users,
  Flag,
  Zap,
  ScrollText,
  Save,
  Plus,
  Trash2,
  RefreshCw,
  AlertTriangle,
  Eye,
  EyeOff,
  SlidersHorizontal,
  Layers,
  Activity,
  Wallet,
  Store,
  Truck,
  ImagePlus,
  X,
  Stethoscope,
  CalendarClock,
} from 'lucide-react';
import {
  loadConfig,
  saveConfig,
  listGuideItems,
  upsertGuideItem,
  deleteGuideItem,
  loadFinancialConfig,
  saveFinancialConfig,
  listFeatureFlags,
  upsertFeatureFlag,
  deleteFeatureFlag,
  listAutomationRules,
  upsertAutomationRule,
  deleteAutomationRule,
  listAuditLogs,
  listPendingSupporters,
  setSupporterStatus,
  getIntegration,
  saveIntegrationSecrets,
  listOutletPgConfigs,
  setOutletPgStatus,
  testDoctorProvider,
  testDoctorChat,
  listOutletAiConfigs,
  setOutletAiConfig,
  deleteOutletAiConfig,
  listOutletDmConfigs,
  setOutletDmConfig,
  deleteOutletDmConfig,
  testDmProvider,
  listDmChannelAccounts,
  setDmChannelAccount,
  deleteDmChannelAccount,
} from '../lib/controlPlane';
import type {
  ConfigKey,
  GuideItem,
  FeatureFlag,
  AutomationRule,
  AuditLog,
  PendingSupporter,
  OutletPgConfig,
  OutletAiConfig,
  OutletDmConfig,
  DmChannelAccount,
} from '../lib/controlPlane';
import { supabase } from '../config/supabase';
import { rp as supabaseRpc, platformOutletsList, UsersListResult } from '../lib/adminApi';

type TabId =
  | 'ads'
  | 'guide'
  | 'financial'
  | 'doctor'
  | 'squad_dm'
  | 'ppob'
  | 'b2b'
  | 'modal_usaha'
  | 'affiliate'
  | 'system'
  | 'report'
  | 'kyc'
  | 'quota'
  | 'flags'
  | 'automation'
  | 'override'
  | 'announcements'
  | 'monitoring'
  | 'admins'
  | 'audit';

const TABS: { id: TabId; name: string; icon: any }[] = [
  { id: 'ads', name: 'Iklan', icon: Megaphone },
  { id: 'guide', name: 'Panduan', icon: BookOpen },
  { id: 'financial', name: 'Payment Gateway', icon: Coins },
  { id: 'doctor', name: 'Dokter Bisnis AI', icon: Stethoscope },
  { id: 'squad_dm', name: 'Squad Digital Marketing', icon: ImagePlus },
  { id: 'ppob', name: 'PPOB', icon: Wallet },
  { id: 'b2b', name: 'B2B Kulakan', icon: Truck },
  { id: 'modal_usaha', name: 'Modal Usaha', icon: Store },
  { id: 'affiliate', name: 'Afiliasi', icon: Users },
  { id: 'system', name: 'Integrasi Sistem', icon: SlidersHorizontal },
  { id: 'report', name: 'Laporan', icon: ScrollText },
  { id: 'kyc', name: 'KYC', icon: ShieldCheck },
  { id: 'quota', name: 'Kuota & Limit', icon: Users },
  { id: 'flags', name: 'Feature Flags', icon: Flag },
  { id: 'automation', name: 'Otomatisasi', icon: Zap },
  { id: 'override', name: 'Override & Riwayat', icon: Layers },
  { id: 'announcements', name: 'Pengumuman', icon: Megaphone },
  { id: 'monitoring', name: 'Monitoring', icon: Activity },
  { id: 'admins', name: 'Admin & RBAC', icon: ShieldCheck },
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
// Iklan: banner lokal (base64) + kode HTML/script/URL. Tanpa sponsor lokal /
// adsterra (dihapus). Kreatif disimpan langsung di platform_configs 'ads'.
// ===========================================================================
type AdCreative = {
  id: string;
  name: string;
  title: string;
  subtitle: string;
  cta_label: string;
  target_url: string;
  html_code: string;
  script_code: string;
  image_base64: string;
  image_mime: string;
  media_type: 'image' | 'video' | 'html' | 'none';
  category: string;
  is_active: boolean;
};

function newCreative(): AdCreative {
  return {
    id: 'ad_' + Math.random().toString(36).slice(2, 10),
    name: '',
    title: '',
    subtitle: '',
    cta_label: '',
    target_url: '',
    html_code: '',
    script_code: '',
    image_base64: '',
    image_mime: '',
    media_type: 'image',
    category: '',
    is_active: true,
  };
}

function AdsTab() {
  const [v, setV] = useState<any>({
    placement: ['catalog', 'qr_menu'],
    blocked_categories: ['judi', 'dewasa', 'pinjol'],
    ad_free_for_supporter: true,
    consent_required: true,
    creatives: [],
  });
  const [loading, setLoading] = useState(false);
  const [busy, setBusy] = useState<string | null>(null);
  const { msg, show } = useToast();

  useEffect(() => {
    loadConfig('ads')
      .then((d) => d && setV((prev: any) => ({ ...prev, ...d, creatives: d.creatives ?? [] })))
      .catch(() => {});
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const creatives: AdCreative[] = Array.isArray(v.creatives) ? v.creatives : [];

  const setCreative = (idx: number, patch: Partial<AdCreative>) => {
    const next = [...creatives];
    next[idx] = { ...next[idx], ...patch };
    setV({ ...v, creatives: next });
  };

  const addCreative = () => setV({ ...v, creatives: [...creatives, newCreative()] });
  const removeCreative = (idx: number) =>
    setV({ ...v, creatives: creatives.filter((_, i) => i !== idx) });

  const uploadBanner = async (idx: number, file: File) => {
    const isVideo = file.type.startsWith('video/');
    const maxBytes = isVideo ? 3 * 1024 * 1024 : 1024 * 1024;
    if (file.size > maxBytes) {
      show('err', `Ukuran maks ${isVideo ? '3MB' : '1MB'} (${(file.size / 1024 / 1024).toFixed(2)}MB).`);
      return;
    }
    setBusy(creatives[idx].id);
    try {
      const base64: string = await new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => {
          const s = String(reader.result ?? '');
          resolve(s.includes(',') ? s.slice(s.indexOf(',') + 1) : s);
        };
        reader.onerror = reject;
        reader.readAsDataURL(file);
      });
      setCreative(idx, {
        image_base64: base64,
        image_mime: file.type,
        media_type: isVideo ? 'video' : 'image',
      });
    } catch (e: any) {
      show('err', e.message ?? 'Gagal membaca file.');
    } finally {
      setBusy(null);
    }
  };

  return (
    <Card title="Iklan Sisi Pelanggan" subtitle="Iklan hanya tampil di halaman pelanggan. Banner gambar disimpan lokal (embedded), bukan di storage.">
      <div className="max-w-[860px] space-y-4">
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
            <label className={labelCls}>Kreatif Iklan</label>
            <button onClick={addCreative} className="flex items-center gap-1 text-[11px] font-bold text-sky-600 hover:text-sky-700">
              <Plus className="w-3.5 h-3.5" /> Tambah Iklan
            </button>
          </div>
          {creatives.length === 0 && <p className="text-[11px] text-slate-400">Belum ada iklan.</p>}
          <div className="space-y-3">
            {creatives.map((c, i) => (
              <div key={c.id} className="p-4 rounded-xl border border-slate-200 bg-slate-50/40 space-y-3">
                <div className="grid grid-cols-1 sm:grid-cols-[1fr_auto] gap-3">
                  <div>
                    <label className={labelCls}>Nama Iklan (internal)</label>
                    <input className={inputCls} value={c.name} onChange={(e) => setCreative(i, { name: e.target.value })} placeholder="Promo Kopi A" />
                  </div>
                  <div className="flex items-end gap-2">
                    <label className="flex items-center gap-2 text-xs font-semibold text-slate-600 mb-2">
                      <input type="checkbox" checked={c.is_active} onChange={(e) => setCreative(i, { is_active: e.target.checked })} /> Aktif
                    </label>
                    <button onClick={() => removeCreative(i)} className="mb-1 p-2 rounded-lg bg-red-50 text-red-500 hover:bg-red-100">
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                  <div>
                    <label className={labelCls}>Judul</label>
                    <input className={inputCls} value={c.title} onChange={(e) => setCreative(i, { title: e.target.value })} />
                  </div>
                  <div>
                    <label className={labelCls}>Subjudul</label>
                    <input className={inputCls} value={c.subtitle} onChange={(e) => setCreative(i, { subtitle: e.target.value })} />
                  </div>
                  <div>
                    <label className={labelCls}>Label CTA</label>
                    <input className={inputCls} value={c.cta_label} onChange={(e) => setCreative(i, { cta_label: e.target.value })} placeholder="Order sekarang" />
                  </div>
                </div>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <label className={labelCls}>URL Tujuan</label>
                    <input className={inputCls} value={c.target_url} onChange={(e) => setCreative(i, { target_url: e.target.value })} placeholder="https://wa.me/62..." />
                  </div>
                  <div>
                    <label className={labelCls}>Kategori (opsional)</label>
                    <input className={inputCls} value={c.category} onChange={(e) => setCreative(i, { category: e.target.value })} placeholder="makanan, promo" />
                  </div>
                </div>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <label className={labelCls}>Kode HTML (opsional)</label>
                    <textarea className={`${inputCls} font-mono min-h-[70px]`} value={c.html_code} onChange={(e) => setCreative(i, { html_code: e.target.value })} placeholder="<div>...</div>" />
                  </div>
                  <div>
                    <label className={labelCls}>Kode Script (opsional)</label>
                    <textarea className={`${inputCls} font-mono min-h-[70px]`} value={c.script_code} onChange={(e) => setCreative(i, { script_code: e.target.value })} placeholder="<script>...</script>" />
                  </div>
                </div>

                <div className="flex flex-wrap items-center gap-3">
                  <label className="flex items-center gap-2 px-3 py-2 rounded-xl border border-dashed border-slate-300 bg-white text-[11px] font-semibold text-slate-600 cursor-pointer hover:border-sky-400">
                    <ImagePlus className="w-4 h-4 text-sky-500" />
                    {busy === c.id ? 'Memproses...' : 'Upload Banner (gambar/video, disimpan lokal)'}
                    <input type="file" accept="image/*,video/*" className="hidden"
                      onChange={(e) => { const f = e.target.files?.[0]; if (f) uploadBanner(i, f); e.currentTarget.value = ''; }} />
                  </label>
                  <div>
                    <label className={labelCls}>Atau URL Gambar</label>
                    <input className={inputCls} value={c.image_base64.startsWith('http') ? c.image_base64 : ''} placeholder="https://..."
                      onChange={(e) => setCreative(i, { image_base64: e.target.value, media_type: 'image', image_mime: '' })} />
                  </div>
                  {(c.image_base64 || c.image_mime) && (
                    <div className="relative">
                      {c.image_mime.startsWith('video/') ? (
                        <video src={`data:${c.image_mime};base64,${c.image_base64}`} className="h-16 rounded-lg" muted />
                      ) : (
                        <img src={c.image_base64.startsWith('http') ? c.image_base64 : `data:${c.image_mime || 'image/png'};base64,${c.image_base64}`} className="h-16 rounded-lg object-cover" alt="banner" />
                      )}
                      <button onClick={() => setCreative(i, { image_base64: '', image_mime: '' })}
                        className="absolute -top-2 -right-2 p-1 rounded-full bg-white border border-slate-200 text-slate-500 shadow">
                        <X className="w-3 h-3" />
                      </button>
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
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
  const [pend, setPend] = useState<PendingSupporter[]>([]);
  const [pgSecrets, setPgSecrets] = useState<Record<string, string>>({});
  const [pgExisting, setPgExisting] = useState<string[]>([]);
  const [pgActive, setPgActive] = useState(true);
  const [pgMeta, setPgMeta] = useState({
    provider: 'midtrans',
    mode: 'live_server',
    base_url: 'https://api.midtrans.com',
    callback_url: '',
  });
  const [revealPg, setRevealPg] = useState(false);
  const [loadingPg, setLoadingPg] = useState(false);
  const [outlets, setOutlets] = useState<OutletPgConfig[]>([]);
  const [loadingOutlets, setLoadingOutlets] = useState(false);
  const [busyOutlet, setBusyOutlet] = useState<string | null>(null);
  const { msg, show } = useToast();
  useEffect(() => {
    loadFinancialConfig().then(setV).catch(() => {});
    reloadPend();
    reloadPg();
    reloadOutlets();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const reloadPend = async () => {
    try { setPend(await listPendingSupporters()); } catch { /* ignore */ }
  };

  const reloadOutlets = async () => {
    setLoadingOutlets(true);
    try { setOutlets(await listOutletPgConfigs()); } catch { /* ignore */ } finally { setLoadingOutlets(false); }
  };

  const toggleOutletPg = async (o: OutletPgConfig) => {
    const next = o.status === 'disabled' ? 'verified' : 'disabled';
    setBusyOutlet(o.outlet_id);
    try {
      await setOutletPgStatus(o.outlet_id, next);
      show('ok', next === 'disabled' ? `Payment Gateway ${o.outlet_name} dinonaktifkan.` : `Payment Gateway ${o.outlet_name} diaktifkan.`);
      await reloadOutlets();
    } catch (e: any) { show('err', e.message); } finally { setBusyOutlet(null); }
  };

  const reloadPg = async () => {
    try {
      const it = await getIntegration('payment_gateway');
      if (it) {
        setPgExisting(Object.keys(it.secret_config ?? {}));
        setPgActive(it.is_active);
        const sc = (it.secret_config ?? {}) as Record<string, any>;
        const pc = (it.public_config ?? {}) as Record<string, any>;
        setPgMeta({
          provider: sc.provider ?? pc.provider ?? 'midtrans',
          mode: sc.mode ?? 'live_server',
          base_url: sc.base_url ?? pc.base_url ?? 'https://api.midtrans.com',
          callback_url: sc.callback_url ?? '',
        });
      }
    } catch { /* integrasi belum ada */ }
  };

  const PG_FIELDS: { key: string; label: string }[] = [
    { key: 'api_key', label: 'API Key' },
    { key: 'server_key', label: 'Server Key' },
    { key: 'secret', label: 'Secret' },
    { key: 'client_key', label: 'Client Key' },
    { key: 'public_key', label: 'Public Key' },
    { key: 'merchant_id', label: 'Merchant ID' },
    { key: 'sdk_script_url', label: 'Script / SDK Library URL' },
  ];

  const PG_MODES: { value: string; label: string }[] = [
    { value: 'sandbox_direct', label: 'Sandbox - Langsung dari aplikasi (tes)' },
    { value: 'sandbox_server', label: 'Sandbox - via Edge Function' },
    { value: 'live_server', label: 'Produksi - via Edge Function' },
  ];

  const savePg = async () => {
    const hasSecret = Object.values(pgSecrets).some((x) => x);
    if (!hasSecret && !pgMeta.base_url) { show('err', 'Isi minimal satu field kredensial.'); return; }
    setLoadingPg(true);
    try {
      const secret: Record<string, any> = {
        provider: pgMeta.provider,
        mode: pgMeta.mode,
        base_url: pgMeta.base_url,
        ...pgSecrets,
      };
      if (pgMeta.callback_url) secret.callback_url = pgMeta.callback_url;
      await saveIntegrationSecrets(
        'payment_gateway',
        'Payment Gateway',
        secret,
        { provider: pgMeta.provider, base_url: pgMeta.base_url },
        pgActive,
      );
      show('ok', 'Konfigurasi Payment Gateway disimpan (aman, tidak pernah ke APK).');
      setPgSecrets({});
      await reloadPg();
    } catch (e: any) { show('err', e.message); } finally { setLoadingPg(false); }
  };

  const decide = async (id: string, approve: boolean) => {
    try {
      await setSupporterStatus(id, approve);
      show('ok', approve ? 'Langganan disetujui & aktivasi ditulis.' : 'Langganan ditolak.');
      await reloadPend();
    } catch (e: any) { show('err', e.message); }
  };

  const num = (k: string, label: string, suffix?: string) => (
    <div>
      <label className={labelCls}>{label}{suffix ? ` (${suffix})` : ''}</label>
      <input className={inputCls} type="number" value={v[k] ?? 0} onChange={(e) => setV({ ...v, [k]: Number(e.target.value) })} />
    </div>
  );

  return (
    <Card title="Payment Gateway" subtitle="Margin QRIS, fee pencairan, dan kredensial Payment Gateway (disimpan aman di Control Plane).">
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

        <div className="pt-4 border-t border-slate-100 space-y-3">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="font-semibold text-slate-900 text-sm">Kredensial Payment Gateway</h3>
              <p className="text-[11px] text-slate-500">Secret hanya dibaca server/Edge Function. Ditampilkan ter-mask & tidak pernah dikirim ke aplikasi klien.</p>
            </div>
            <label className="flex items-center gap-2 text-[11px] font-semibold text-slate-600">
              <input type="checkbox" checked={pgActive} onChange={(e) => setPgActive(e.target.checked)} /> Aktif
            </label>
          </div>
          {pgExisting.length > 0 && (
            <p className="text-[11px] text-amber-600">Tersimpan: {pgExisting.join(', ')}. Isi hanya field yang ingin diubah.</p>
          )}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className={labelCls}>Provider</label>
              <select className={inputCls} value={pgMeta.provider} onChange={(e) => setPgMeta({ ...pgMeta, provider: e.target.value })}>
                <option value="midtrans">Midtrans</option>
                <option value="rcb">RCB Pay (Raga Cipta Bersama)</option>
                <option value="other">Lainnya</option>
              </select>
            </div>
            <div>
              <label className={labelCls}>Mode</label>
              <select className={inputCls} value={pgMeta.mode} onChange={(e) => setPgMeta({ ...pgMeta, mode: e.target.value })}>
                {PG_MODES.map((m) => (
                  <option key={m.value} value={m.value}>{m.label}</option>
                ))}
              </select>
            </div>
            <div className="sm:col-span-2">
              <label className={labelCls}>Base URL API</label>
              <input className={inputCls} value={pgMeta.base_url} onChange={(e) => setPgMeta({ ...pgMeta, base_url: e.target.value })} placeholder="https://api.midtrans.com" />
            </div>
            <div className="sm:col-span-2">
              <label className={labelCls}>Callback / Webhook URL</label>
              <input className={inputCls} value={pgMeta.callback_url} onChange={(e) => setPgMeta({ ...pgMeta, callback_url: e.target.value })} placeholder="https://<project>.supabase.co/functions/v1/midtrans_webhook" />
            </div>
          </div>
          {pgMeta.mode === 'sandbox_direct' && (
            <p className="text-[11px] text-amber-600">Mode <b>sandbox langsung</b> menyimpan API key sandbox di aplikasi klien (hanya untuk uji coba). Ganti ke mode Edge Function sebelum produksi.</p>
          )}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            {PG_FIELDS.map((f) => (
              <div key={f.key}>
                <label className={labelCls}>{f.label}</label>
                <div className="relative">
                  <input
                    className={`${inputCls} ${revealPg ? '' : 'font-mono'}`}
                    type={revealPg ? 'text' : 'password'}
                    value={pgSecrets[f.key] ?? ''}
                    placeholder={pgExisting.includes(f.key) ? '••••••••' : ''}
                    onChange={(e) => setPgSecrets({ ...pgSecrets, [f.key]: e.target.value })}
                  />
                  <button type="button" onClick={() => setRevealPg(!revealPg)}
                    className="absolute top-2 right-2 p-1.5 rounded-lg text-slate-400 hover:text-slate-600">
                    {revealPg ? <EyeOff className="w-3.5 h-3.5" /> : <Eye className="w-3.5 h-3.5" />}
                  </button>
                </div>
              </div>
            ))}
          </div>
          <SaveButton loading={loadingPg} label="Simpan Kredensial" onClick={savePg} />
        </div>
      </div>
      <div className="max-w-[960px] mt-8">
        <div className="flex items-center justify-between mb-3">
          <div>
            <h3 className="font-semibold text-slate-900 text-sm">Status Payment Gateway per Outlet</h3>
            <p className="text-[11px] text-slate-500">Kredensial Midtrans diisi owner lewat wizard di aplikasi (Server Key tersimpan di Vault, zero-custody). Superadmin mengelola aktif/nonaktif & tes koneksi.</p>
          </div>
          <button onClick={reloadOutlets} className="p-2 rounded-lg hover:bg-slate-100" title="Muat ulang"><RefreshCw size={16} /></button>
        </div>
        {loadingOutlets && outlets.length === 0 ? (
          <p className="text-sm text-slate-400">Memuat data outlet...</p>
        ) : outlets.length === 0 ? (
          <p className="text-sm text-slate-400">Belum ada data outlet.</p>
        ) : (
          <div className="overflow-x-auto rounded-xl border border-slate-200">
            <table className="w-full text-xs">
              <thead className="bg-slate-50 text-slate-500">
                <tr>
                  <th className="text-left px-3 py-2 font-semibold">Outlet</th>
                  <th className="text-left px-3 py-2 font-semibold">Pemilik</th>
                  <th className="text-left px-3 py-2 font-semibold">Provider</th>
                  <th className="text-left px-3 py-2 font-semibold">Mode</th>
                  <th className="text-left px-3 py-2 font-semibold">Status</th>
                  <th className="text-left px-3 py-2 font-semibold">Tes Terakhir</th>
                  <th className="text-right px-3 py-2 font-semibold">Aksi</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {outlets.map((o) => {
                  const configured = o.has_server_key;
                  const badge =
                    o.status === 'verified' ? 'bg-emerald-50 text-emerald-600'
                    : o.status === 'disabled' ? 'bg-rose-50 text-rose-600'
                    : o.status === 'pending' ? 'bg-amber-50 text-amber-600'
                    : 'bg-slate-100 text-slate-500';
                  const label =
                    o.status === 'verified' ? 'Aktif'
                    : o.status === 'disabled' ? 'Nonaktif'
                    : o.status === 'pending' ? 'Menunggu'
                    : 'Belum diatur';
                  return (
                    <tr key={o.outlet_id} className="hover:bg-slate-50/60">
                      <td className="px-3 py-2.5">
                        <p className="font-semibold text-slate-800">{o.outlet_name}</p>
                        <p className="text-[10px] text-slate-400 capitalize">{o.outlet_type ?? '-'}</p>
                      </td>
                      <td className="px-3 py-2.5 text-slate-500">{o.owner_email ?? '-'}</td>
                      <td className="px-3 py-2.5 text-slate-600">{configured ? (o.provider ?? 'midtrans') : '-'}</td>
                      <td className="px-3 py-2.5 text-slate-600">{configured ? (o.is_production ? 'Produksi' : 'Sandbox') : '-'}</td>
                      <td className="px-3 py-2.5">
                        <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-bold ${badge}`}>{label}</span>
                      </td>
                      <td className="px-3 py-2.5 text-slate-500 max-w-[200px] truncate" title={o.last_test_result ?? ''}>
                        {o.last_test_result ?? '-'}
                      </td>
                      <td className="px-3 py-2.5 text-right">
                        {configured ? (
                          <div className="inline-flex gap-2">
                            <button
                              onClick={async () => {
                                setBusyOutlet(o.outlet_id);
                                try {
                                  const { data, error } = await supabase.functions.invoke('test_payment_connection', { body: { outlet_id: o.outlet_id } });
                                  if (error) throw new Error(error.message);
                                  show(data?.valid ? 'ok' : 'err', data?.message ?? 'Selesai.');
                                  await reloadOutlets();
                                } catch (e: any) { show('err', e.message); } finally { setBusyOutlet(null); }
                              }}
                              disabled={busyOutlet === o.outlet_id}
                              className="px-2.5 py-1 rounded-lg border border-slate-200 text-slate-600 hover:bg-slate-50 disabled:opacity-50"
                            >
                              Tes
                            </button>
                            <button
                              onClick={() => toggleOutletPg(o)}
                              disabled={busyOutlet === o.outlet_id}
                              className={`px-2.5 py-1 rounded-lg text-white disabled:opacity-50 ${o.status === 'disabled' ? 'bg-emerald-500 hover:bg-emerald-600' : 'bg-rose-500 hover:bg-rose-600'}`}
                            >
                              {o.status === 'disabled' ? 'Aktifkan' : 'Nonaktifkan'}
                            </button>
                          </div>
                        ) : (
                          <span className="text-[10px] text-slate-400">Belum ada kredensial</span>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
      <div className="max-w-[760px] mt-8">
        <div className="flex items-center justify-between mb-3">
          <div>
            <h3 className="font-semibold text-slate-900">Verifikasi Langganan Pendukung</h3>
            <p className="text-xs text-slate-500">Pembayaran QRIS/transfer yang dikonfirmasi owner menunggu setujui/tolak di sini.</p>
          </div>
          <button onClick={reloadPend} className="p-2 rounded-lg hover:bg-slate-100" title="Muat ulang"><RefreshCw size={16} /></button>
        </div>
        {pend.length === 0 ? (
          <p className="text-sm text-slate-400">Tidak ada langganan menunggu verifikasi.</p>
        ) : (
          <div className="space-y-2">
            {pend.map((p) => (
              <div key={p.id} className="flex items-center justify-between gap-3 rounded-xl border border-slate-200 bg-white px-4 py-3">
                <div className="min-w-0">
                  <p className="text-sm font-semibold text-slate-900 truncate">{p.outlet_name}</p>
                  <p className="text-xs text-slate-500">
                    Rp {Number(p.amount).toLocaleString('id-ID')} - {p.pg_reference_id ?? '-'} - {p.status === 'pending_verification' ? 'menunggu verifikasi' : 'belum bayar'}
                  </p>
                </div>
                <div className="flex gap-2 shrink-0">
                  <button onClick={() => decide(p.id, true)} className="rounded-lg bg-emerald-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-emerald-700">Setujui</button>
                  <button onClick={() => decide(p.id, false)} className="rounded-lg bg-slate-200 px-3 py-1.5 text-xs font-semibold text-slate-700 hover:bg-slate-300">Tolak</button>
                </div>
              </div>
            ))}
          </div>
        )}
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

// ===========================================================================
// PPOB: margin & endpoint di platform_configs('ppob'), kredensial di
// platform_integrations('ppob'). Harga jual = modal + margin% (otomatis).
// ===========================================================================
function SecretField({
  label,
  value,
  existing,
  reveal,
  onChange,
}: {
  label: string;
  value: string;
  existing: boolean;
  reveal: boolean;
  onChange: (v: string) => void;
}) {
  return (
    <div>
      <label className={labelCls}>{label}</label>
      <input
        className={inputCls}
        type={reveal ? 'text' : 'password'}
        value={value}
        placeholder={existing ? '••••••••' : ''}
        onChange={(e) => onChange(e.target.value)}
      />
    </div>
  );
}

function PpobTab() {
  const [v, setV] = useState<any>({ provider: 'demo', endpoint: '', margin_percent: 5, enabled: true, ip_whitelist: [], product_codes: [] });
  const [secrets, setSecrets] = useState<Record<string, string>>({});
  const [existing, setExisting] = useState<string[]>([]);
  const [active, setActive] = useState(true);
  const [reveal, setReveal] = useState(false);
  const [loading, setLoading] = useState(false);
  const [savingSecret, setSavingSecret] = useState(false);
  const { msg, show } = useToast();

  useEffect(() => {
    loadConfig('ppob').then((d) => d && setV((prev: any) => ({ ...prev, ...d }))).catch(() => {});
    getIntegration('ppob').then((it) => {
      if (it) { setExisting(Object.keys(it.secret_config ?? {})); setActive(it.is_active); }
    }).catch(() => {});
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const saveSecret = async () => {
    if (Object.values(secrets).every((x) => !x)) { show('err', 'Isi minimal satu field kredensial.'); return; }
    setSavingSecret(true);
    try {
      await saveIntegrationSecrets('ppob', 'PPOB', secrets, {}, active);
      show('ok', 'Kredensial PPOB disimpan.');
      setSecrets({});
      const it = await getIntegration('ppob');
      setExisting(Object.keys(it?.secret_config ?? {}));
    } catch (e: any) { show('err', e.message); } finally { setSavingSecret(false); }
  };

  return (
    <Card title="PPOB" subtitle="Provider, margin, endpoint & kredensial. Harga jual = modal + margin% (otomatis).">
      <div className="max-w-[860px] space-y-4">
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
          <div>
            <label className={labelCls}>Provider</label>
            <input className={inputCls} value={v.provider ?? ''} onChange={(e) => setV({ ...v, provider: e.target.value })} placeholder="demo / digiflazz" />
          </div>
          <div>
            <label className={labelCls}>Margin (%)</label>
            <input className={inputCls} type="number" value={v.margin_percent ?? 0} onChange={(e) => setV({ ...v, margin_percent: Number(e.target.value) })} />
          </div>
          <div className="flex items-end pb-2">
            <label className="flex items-center gap-2 text-xs font-semibold text-slate-600">
              <input type="checkbox" checked={v.enabled !== false} onChange={(e) => setV({ ...v, enabled: e.target.checked })} /> PPOB Aktif
            </label>
          </div>
        </div>
        <div>
          <label className={labelCls}>Endpoint URL</label>
          <input className={inputCls} value={v.endpoint ?? ''} onChange={(e) => setV({ ...v, endpoint: e.target.value })} placeholder="https://api.provider.com" />
        </div>
        <div>
          <label className={labelCls}>Callback URL</label>
          <input className={inputCls} value={v.callback_url ?? ''} onChange={(e) => setV({ ...v, callback_url: e.target.value })} placeholder="https://.../functions/v1/ppob-callback" />
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div>
            <label className={labelCls}>IP Whitelist (pisahkan koma)</label>
            <input className={inputCls} value={(v.ip_whitelist ?? []).join(', ')} onChange={(e) => setV({ ...v, ip_whitelist: e.target.value.split(',').map((s) => s.trim()).filter(Boolean) })} placeholder="103.0.0.1, 103.0.0.2" />
          </div>
          <div>
            <label className={labelCls}>Kode Produk (pisahkan koma)</label>
            <input className={inputCls} value={(v.product_codes ?? []).join(', ')} onChange={(e) => setV({ ...v, product_codes: e.target.value.split(',').map((s) => s.trim()).filter(Boolean) })} placeholder="PULSA10, PLN50" />
          </div>
        </div>
        <SaveButton loading={loading} label="Simpan Konfigurasi PPOB" onClick={async () => {
          setLoading(true);
          try { await saveConfig('ppob', v); show('ok', 'Konfigurasi PPOB disimpan.'); }
          catch (e: any) { show('err', e.message); } finally { setLoading(false); }
        }} />

        <div className="pt-4 border-t border-slate-100 space-y-3">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="font-semibold text-slate-900 text-sm">Kredensial Provider PPOB</h3>
              <p className="text-[11px] text-slate-500">Disimpan aman, hanya dibaca Edge Function. Tidak pernah dikirim ke aplikasi klien.</p>
            </div>
            <label className="flex items-center gap-2 text-[11px] font-semibold text-slate-600">
              <input type="checkbox" checked={active} onChange={(e) => setActive(e.target.checked)} /> Aktif
            </label>
          </div>
          {existing.length > 0 && <p className="text-[11px] text-amber-600">Tersimpan: {existing.join(', ')}. Isi hanya field yang ingin diubah.</p>}
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
            <SecretField label="API Key" value={secrets.api_key ?? ''} existing={existing.includes('api_key')} reveal={reveal} onChange={(x) => setSecrets({ ...secrets, api_key: x })} />
            <SecretField label="API Secret" value={secrets.api_secret ?? ''} existing={existing.includes('api_secret')} reveal={reveal} onChange={(x) => setSecrets({ ...secrets, api_secret: x })} />
            <SecretField label="API Token" value={secrets.api_token ?? ''} existing={existing.includes('api_token')} reveal={reveal} onChange={(x) => setSecrets({ ...secrets, api_token: x })} />
          </div>
          <div className="flex items-center gap-3">
            <SaveButton loading={savingSecret} label="Simpan Kredensial" onClick={saveSecret} />
            <button type="button" onClick={() => setReveal(!reveal)} className="p-2 rounded-lg border border-slate-200 text-slate-500 hover:bg-slate-50">
              {reveal ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
            </button>
          </div>
        </div>
      </div>
      <Toast msg={msg} />
    </Card>
  );
}

// ===========================================================================
// B2B Kulakan & Modal Usaha: kode HTML/script + URL tujuan (platform_configs)
// ===========================================================================
function B2bTab() {
  const [v, setV] = useState<any>({ enabled: false, distributor_name: '', distributor_url: '', allowed_domains: [], commission_percent: 2, html_code: '', script_code: '', target_url: '' });
  const [loading, setLoading] = useState(false);
  const { msg, show } = useToast();
  useEffect(() => {
    loadConfig('b2b_restock').then((d) => d && setV((prev: any) => ({ ...prev, ...d }))).catch(() => {});
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  return (
    <Card title="B2B Kulakan" subtitle="Link distributor, komisi, dan embed (kode HTML/script) ke halaman kulakan.">
      <div className="max-w-[760px] space-y-3.5">
        <label className="flex items-center gap-2 text-xs font-semibold text-slate-600">
          <input type="checkbox" checked={v.enabled !== false} onChange={(e) => setV({ ...v, enabled: e.target.checked })} /> Aktifkan B2B Kulakan
        </label>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div>
            <label className={labelCls}>Nama Distributor</label>
            <input className={inputCls} value={v.distributor_name ?? ''} onChange={(e) => setV({ ...v, distributor_name: e.target.value })} />
          </div>
          <div>
            <label className={labelCls}>Komisi (%)</label>
            <input className={inputCls} type="number" value={v.commission_percent ?? 0} onChange={(e) => setV({ ...v, commission_percent: Number(e.target.value) })} />
          </div>
        </div>
        <div>
          <label className={labelCls}>URL Tujuan / Katalog Distributor</label>
          <input className={inputCls} value={v.distributor_url ?? ''} onChange={(e) => setV({ ...v, distributor_url: e.target.value })} placeholder="https://distributor.com/katalog" />
        </div>
        <div>
          <label className={labelCls}>Domain Diizinkan (pisahkan koma)</label>
          <input className={inputCls} value={(v.allowed_domains ?? []).join(', ')} onChange={(e) => setV({ ...v, allowed_domains: e.target.value.split(',').map((s) => s.trim()).filter(Boolean) })} />
        </div>
        <div>
          <label className={labelCls}>URL Tujuan Tambahan</label>
          <input className={inputCls} value={v.target_url ?? ''} onChange={(e) => setV({ ...v, target_url: e.target.value })} placeholder="https://..." />
        </div>
        <div>
          <label className={labelCls}>Kode HTML (opsional)</label>
          <textarea className={`${inputCls} font-mono min-h-[80px]`} value={v.html_code ?? ''} onChange={(e) => setV({ ...v, html_code: e.target.value })} />
        </div>
        <div>
          <label className={labelCls}>Kode Script (opsional)</label>
          <textarea className={`${inputCls} font-mono min-h-[80px]`} value={v.script_code ?? ''} onChange={(e) => setV({ ...v, script_code: e.target.value })} />
        </div>
        <SaveButton loading={loading} label="Simpan B2B Kulakan" onClick={async () => {
          setLoading(true);
          try { await saveConfig('b2b_restock', v); show('ok', 'Konfigurasi B2B disimpan.'); }
          catch (e: any) { show('err', e.message); } finally { setLoading(false); }
        }} />
      </div>
      <Toast msg={msg} />
    </Card>
  );
}

function ModalUsahaTab() {
  const [v, setV] = useState<any>({ enabled: true, partner_name: '', apply_url: '', wa_number: '', target_url: '', html_code: '', script_code: '', commission_percent: 2, commission_flat: 0 });
  const [loading, setLoading] = useState(false);
  const { msg, show } = useToast();
  useEffect(() => {
    loadConfig('fintech_partner').then((d) => d && setV((prev: any) => ({ ...prev, ...d }))).catch(() => {});
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  return (
    <Card title="Modal Usaha" subtitle="Mitra pembiayaan: link pengajuan, WA, embed, dan komisi platform.">
      <div className="max-w-[760px] space-y-3.5">
        <label className="flex items-center gap-2 text-xs font-semibold text-slate-600">
          <input type="checkbox" checked={v.enabled !== false} onChange={(e) => setV({ ...v, enabled: e.target.checked })} /> Aktifkan Modal Usaha
        </label>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div>
            <label className={labelCls}>Nama Mitra</label>
            <input className={inputCls} value={v.partner_name ?? ''} onChange={(e) => setV({ ...v, partner_name: e.target.value })} />
          </div>
          <div>
            <label className={labelCls}>Nomor WA (fallback)</label>
            <input className={inputCls} value={v.wa_number ?? ''} onChange={(e) => setV({ ...v, wa_number: e.target.value })} placeholder="628123..." />
          </div>
        </div>
        <div className="rounded-xl border border-slate-200 bg-slate-50/60 p-3.5 space-y-3">
          <p className="text-[11px] font-bold text-slate-500 uppercase tracking-wide">Komisi Platform</p>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className={labelCls}>Komisi (%)</label>
              <input type="number" step="0.1" className={inputCls} value={v.commission_percent ?? 0} onChange={(e) => setV({ ...v, commission_percent: Number(e.target.value) })} />
            </div>
            <div>
              <label className={labelCls}>Komisi Tetap (Rp)</label>
              <input type="number" step="1000" className={inputCls} value={v.commission_flat ?? 0} onChange={(e) => setV({ ...v, commission_flat: Number(e.target.value) })} />
            </div>
          </div>
          <p className="text-[10px] text-slate-400">Komisi = (plafon disetujui x %) + komisi tetap. Dicatat pada closing modal usaha.</p>
        </div>
        <div>
          <label className={labelCls}>URL Tujuan / Pengajuan</label>
          <input className={inputCls} value={v.apply_url ?? ''} onChange={(e) => setV({ ...v, apply_url: e.target.value })} placeholder="https://mitra.com/ajukan" />
        </div>
        <div>
          <label className={labelCls}>URL Tujuan Tambahan</label>
          <input className={inputCls} value={v.target_url ?? ''} onChange={(e) => setV({ ...v, target_url: e.target.value })} />
        </div>
        <div>
          <label className={labelCls}>Kode HTML (opsional)</label>
          <textarea className={`${inputCls} font-mono min-h-[80px]`} value={v.html_code ?? ''} onChange={(e) => setV({ ...v, html_code: e.target.value })} />
        </div>
        <div>
          <label className={labelCls}>Kode Script (opsional)</label>
          <textarea className={`${inputCls} font-mono min-h-[80px]`} value={v.script_code ?? ''} onChange={(e) => setV({ ...v, script_code: e.target.value })} />
        </div>
        <SaveButton loading={loading} label="Simpan Modal Usaha" onClick={async () => {
          setLoading(true);
          try { await saveConfig('fintech_partner', v); show('ok', 'Konfigurasi Modal Usaha disimpan.'); }
          catch (e: any) { show('err', e.message); } finally { setLoading(false); }
        }} />
      </div>
      <Toast msg={msg} />
    </Card>
  );
}

// Afiliasi: pendaftaran mandiri (otomatis / persetujuan manual) + komisi default
// + pengaturan pembayaran komisi (afiliasi outlet & partner).
function AffiliateTab() {
  const [v, setV] = useState<any>({
    require_approval: false,
    default_commission: 10,
    owner_commission_percent: 5,
    owner_payout_frequency: 'monthly',
    owner_payout_day: 1,
    owner_payout_mode: 'manual',
  });
  const [loading, setLoading] = useState(false);
  const { msg, show } = useToast();
  useEffect(() => {
    loadConfig('affiliate').then((d) => d && setV((prev: any) => ({ ...prev, ...d }))).catch(() => {});
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  const upd = (patch: any) => setV((p: any) => ({ ...p, ...patch }));
  return (
    <Card
      title="Program Afiliasi"
      subtitle="Pendaftaran afiliasi mandiri, komisi default partner, dan pengaturan pembayaran komisi afiliasi outlet."
    >
      <div className="max-w-[760px] space-y-4">
        <div className="rounded-xl border border-slate-200 bg-slate-50/60 p-4 space-y-3">
          <p className="text-[11px] font-bold text-slate-500 uppercase tracking-wide">Mode Pendaftaran</p>
          <label className="flex items-start gap-2.5 text-xs font-semibold text-slate-700">
            <input
              type="radio"
              className="mt-0.5"
              checked={v.require_approval === true}
              onChange={() => upd({ require_approval: true })}
            />
            <span>
              Persetujuan manual
              <span className="block text-[10px] font-normal text-slate-400">
                Pendaftar berstatus pending hingga superadmin menyetujui di halaman Afiliasi.
              </span>
            </span>
          </label>
          <label className="flex items-start gap-2.5 text-xs font-semibold text-slate-700">
            <input
              type="radio"
              className="mt-0.5"
              checked={v.require_approval !== true}
              onChange={() => upd({ require_approval: false })}
            />
            <span>
              Otomatis (default)
              <span className="block text-[10px] font-normal text-slate-400">
                Pendaftar langsung aktif dan bisa mereferensikan seketika.
              </span>
            </span>
          </label>
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div>
            <label className={labelCls}>Komisi Default Partner (%)</label>
            <input
              type="number"
              step="0.1"
              className={inputCls}
              value={v.default_commission ?? 10}
              onChange={(e) => upd({ default_commission: Number(e.target.value) })}
            />
            <p className="text-[10px] text-slate-400 mt-1">Diberikan ke afiliasi partner baru saat mendaftar mandiri.</p>
          </div>
          <div>
            <label className={labelCls}>Komisi Afiliasi Outlet (%)</label>
            <input
              type="number"
              step="0.1"
              className={inputCls}
              value={v.owner_commission_percent ?? 5}
              onChange={(e) => upd({ owner_commission_percent: Number(e.target.value) })}
            />
            <p className="text-[10px] text-slate-400 mt-1">Komisi owner ketika usaha baru bergabung lewat kode referral outlet-nya.</p>
          </div>
        </div>
        <div className="rounded-xl border border-slate-200 bg-slate-50/60 p-4 space-y-3">
          <p className="text-[11px] font-bold text-slate-500 uppercase tracking-wide">Pembayaran Komisi Afiliasi Outlet</p>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
            <div>
              <label className={labelCls}>Frekuensi</label>
              <select className={inputCls} value={v.owner_payout_frequency ?? 'monthly'} onChange={(e) => upd({ owner_payout_frequency: e.target.value })}>
                <option value="monthly">Bulanan</option>
                <option value="weekly">Mingguan</option>
              </select>
            </div>
            <div>
              <label className={labelCls}>{(v.owner_payout_frequency ?? 'monthly') === 'weekly' ? 'Hari (1=Senin)' : 'Tanggal (1-28)'}</label>
              <input
                type="number"
                min={1}
                max={(v.owner_payout_frequency ?? 'monthly') === 'weekly' ? 7 : 28}
                className={inputCls}
                value={v.owner_payout_day ?? 1}
                onChange={(e) => upd({ owner_payout_day: Number(e.target.value) })}
              />
            </div>
            <div>
              <label className={labelCls}>Mode</label>
              <select className={inputCls} value={v.owner_payout_mode ?? 'manual'} onChange={(e) => upd({ owner_payout_mode: e.target.value })}>
                <option value="manual">Manual</option>
                <option value="auto">Otomatis</option>
              </select>
            </div>
          </div>
          <p className="text-[10px] text-slate-400">
            Komisi dicatat pada tabel closing per outlet dan dibayar ke rekening yang diisi owner pada layar Afiliasi.
          </p>
        </div>
        <SaveButton
          loading={loading}
          label="Simpan Program Afiliasi"
          onClick={async () => {
            setLoading(true);
            try {
              await saveConfig('affiliate', v);
              show('ok', 'Konfigurasi afiliasi disimpan.');
            } catch (e: any) {
              show('err', e.message);
            } finally {
              setLoading(false);
            }
          }}
        />
      </div>
      <Toast msg={msg} />
    </Card>
  );
}

// Integrasi sistem: WA, Database, Backup/Restore + jadwal, Cloudflare, API key/URL.
function SystemIntegrationTab() {
  const [v, setV] = useState<any>({
    wa_api_url: '', wa_api_key: '', wa_sender: '',
    database_url: '', database_anon_key: '', database_service_key: '',
    backup_enabled: true, backup_frequency: 'daily', backup_hour: 2, restore_enabled: true,
    cloudflare_account_id: '', cloudflare_api_token: '', cloudflare_r2_bucket: '',
    cloudflare_r2_public_url: '', cloudflare_zone_id: '', apikey_notes: '',
  });
  const [loading, setLoading] = useState(false);
  const { msg, show } = useToast();
  useEffect(() => {
    loadConfig('system').then((d) => d && setV((prev: any) => ({ ...prev, ...d }))).catch(() => {});
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  const upd = (patch: any) => setV((p: any) => ({ ...p, ...patch }));
  return (
    <Card
      title="Integrasi Sistem"
      subtitle="WA, Database, Backup/Restore + jadwal, Cloudflare (R2/storage), dan API key/URL. Tanpa menyentuh koding."
    >
      <div className="max-w-[860px] space-y-5">
        <Section title="WhatsApp Business API">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className={labelCls}>API URL</label>
              <input className={inputCls} value={v.wa_api_url ?? ''} onChange={(e) => upd({ wa_api_url: e.target.value })} placeholder="https://graph.facebook.com/v20.0" />
            </div>
            <div>
              <label className={labelCls}>Nomor Pengirim</label>
              <input className={inputCls} value={v.wa_sender ?? ''} onChange={(e) => upd({ wa_sender: e.target.value })} placeholder="628..." />
            </div>
          </div>
          <div className="mt-3">
            <label className={labelCls}>API Key / Token (rahasia)</label>
            <input type="password" className={inputCls} value={v.wa_api_key ?? ''} onChange={(e) => upd({ wa_api_key: e.target.value })} placeholder="disimpan lokal, tidak dikirim ke APK" />
          </div>
        </Section>

        <Section title="Database">
          <div className="space-y-3">
            <div>
              <label className={labelCls}>URL Database</label>
              <input className={inputCls} value={v.database_url ?? ''} onChange={(e) => upd({ database_url: e.target.value })} placeholder="https://<project>.supabase.co" />
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label className={labelCls}>Anon / Public Key</label>
                <input className={inputCls} value={v.database_anon_key ?? ''} onChange={(e) => upd({ database_anon_key: e.target.value })} />
              </div>
              <div>
                <label className={labelCls}>Service Role Key (rahasia)</label>
                <input type="password" className={inputCls} value={v.database_service_key ?? ''} onChange={(e) => upd({ database_service_key: e.target.value })} />
              </div>
            </div>
          </div>
        </Section>

        <Section title="Backup & Restore">
          <label className="flex items-center gap-2 text-xs font-semibold text-slate-600">
            <input type="checkbox" checked={v.backup_enabled !== false} onChange={(e) => upd({ backup_enabled: e.target.checked })} /> Aktifkan backup terjadwal
          </label>
          <label className="flex items-center gap-2 text-xs font-semibold text-slate-600 mt-2">
            <input type="checkbox" checked={v.restore_enabled !== false} onChange={(e) => upd({ restore_enabled: e.target.checked })} /> Izinkan restore
          </label>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mt-3">
            <div>
              <label className={labelCls}>Jadwal</label>
              <select className={inputCls} value={v.backup_frequency ?? 'daily'} onChange={(e) => upd({ backup_frequency: e.target.value })}>
                <option value="daily">Harian</option>
                <option value="weekly">Mingguan</option>
                <option value="monthly">Bulanan</option>
              </select>
            </div>
            <div>
              <label className={labelCls}>Jam Backup (0-23)</label>
              <input type="number" min={0} max={23} className={inputCls} value={v.backup_hour ?? 2} onChange={(e) => upd({ backup_hour: Number(e.target.value) })} />
            </div>
          </div>
        </Section>

        <Section title="Cloudflare (Storage / R2)">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className={labelCls}>Account ID</label>
              <input className={inputCls} value={v.cloudflare_account_id ?? ''} onChange={(e) => upd({ cloudflare_account_id: e.target.value })} />
            </div>
            <div>
              <label className={labelCls}>Zone ID</label>
              <input className={inputCls} value={v.cloudflare_zone_id ?? ''} onChange={(e) => upd({ cloudflare_zone_id: e.target.value })} />
            </div>
            <div>
              <label className={labelCls}>R2 Bucket</label>
              <input className={inputCls} value={v.cloudflare_r2_bucket ?? ''} onChange={(e) => upd({ cloudflare_r2_bucket: e.target.value })} />
            </div>
            <div>
              <label className={labelCls}>R2 Public URL</label>
              <input className={inputCls} value={v.cloudflare_r2_public_url ?? ''} onChange={(e) => upd({ cloudflare_r2_public_url: e.target.value })} placeholder="https://cdn.domain.com" />
            </div>
          </div>
          <div className="mt-3">
            <label className={labelCls}>API Token (rahasia)</label>
            <input type="password" className={inputCls} value={v.cloudflare_api_token ?? ''} onChange={(e) => upd({ cloudflare_api_token: e.target.value })} />
          </div>
        </Section>

        <Section title="Catatan API Key / URL Lain">
          <textarea className={`${inputCls} min-h-[80px]`} value={v.apikey_notes ?? ''} onChange={(e) => upd({ apikey_notes: e.target.value })} placeholder="Catatan konfigurasi tambahan..." />
        </Section>

        <SaveButton loading={loading} label="Simpan Integrasi Sistem" onClick={async () => {
          setLoading(true);
          try { await saveConfig('system', v); show('ok', 'Integrasi sistem disimpan.'); }
          catch (e: any) { show('err', e.message); } finally { setLoading(false); }
        }} />
      </div>
      <Toast msg={msg} />
    </Card>
  );
}

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="rounded-xl border border-slate-200 bg-slate-50/50 p-4">
      <p className="text-[11px] font-bold text-slate-500 uppercase tracking-wide mb-3">{title}</p>
      {children}
    </div>
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
// ST11-3: Override Global->Segment->Outlet + riwayat versi + rollback
// ===========================================================================
const CONFIG_KEYS: { key: ConfigKey; label: string }[] = [
  { key: 'ads', label: 'Iklan' },
  { key: 'guide', label: 'Panduan' },
  { key: 'report', label: 'Laporan' },
  { key: 'kyc', label: 'KYC' },
  { key: 'quota', label: 'Kuota & Limit' },
  { key: 'flags', label: 'Feature Flags' },
  { key: 'billing', label: 'Billing' },
  { key: 'ppob', label: 'PPOB' },
  { key: 'b2b_restock', label: 'B2B Kulakan' },
  { key: 'fintech_partner', label: 'Modal Usaha' },
  { key: 'system', label: 'Integrasi Sistem' },
];

function OverrideTab() {
  const [cfgKey, setCfgKey] = useState<ConfigKey>('ads');
  const [scope, setScope] = useState<'global' | 'segment' | 'outlet'>('global');
  const [scopeRef, setScopeRef] = useState('all');
  const [segments, setSegments] = useState<{ id: string; name: string }[]>([]);
  const [outlets, setOutlets] = useState<{ outlet_id: string; outlet_name: string }[]>([]);
  const [text, setText] = useState('{}');
  const [loading, setLoading] = useState(false);
  const [saveLoading, setSaveLoading] = useState(false);
  const [versions, setVersions] = useState<any[]>([]);
  const [effective, setEffective] = useState<any>(null);
  const [previewOutlet, setPreviewOutlet] = useState('');
  const { msg, show } = useToast();

  useEffect(() => {
    (async () => {
      try {
        const [seg, users] = await Promise.all([
          supabaseRpc<any>('platform_segment_list'),
          supabaseRpc<UsersListResult>('platform_users_list', { p_limit: 100, p_offset: 0 }),
        ]);
        setSegments((seg?.rows ?? []).map((r: any) => ({ id: r.id, name: r.name })));
        setOutlets((users?.rows ?? [])
          .filter((u) => u.outlet_id)
          .map((u) => ({ outlet_id: u.outlet_id as string, outlet_name: u.outlet_name ?? u.email })));
      } catch { /* daftar opsional */ }
    })();
  }, []);

  const loadCurrent = useCallback(async () => {
    setLoading(true);
    setEffective(null);
    try {
      if (scope === 'global') {
        const v = await loadConfig(cfgKey);
        setText(JSON.stringify(v ?? {}, null, 2));
      } else {
        const { data } = await supabase
          .from('platform_configs')
          .select('value,version')
          .eq('key', cfgKey)
          .eq('scope', scope)
          .eq('scope_ref', scopeRef)
          .order('version', { ascending: false })
          .limit(1)
          .maybeSingle();
        setText(JSON.stringify(data?.value ?? {}, null, 2));
      }
      const hist = await supabaseRpc<any>('platform_config_versions', {
        p_key: cfgKey, p_scope: scope, p_scope_ref: scopeRef, p_limit: 20,
      });
      setVersions(hist?.rows ?? []);
    } catch (e: any) {
      show('err', e.message ?? 'Gagal memuat config');
    } finally {
      setLoading(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [cfgKey, scope, scopeRef]);

  useEffect(() => { loadCurrent(); }, [loadCurrent]);

  const save = async () => {
    let parsed: any;
    try { parsed = JSON.parse(text); }
    catch { show('err', 'JSON tidak valid.'); return; }
    setSaveLoading(true);
    try {
      await supabaseRpc('platform_config_save', {
        p_key: cfgKey, p_scope: scope, p_scope_ref: scopeRef, p_value: parsed,
      });
      show('ok', `Config disimpan (${scope}).`);
      await loadCurrent();
    } catch (e: any) {
      show('err', e.message ?? 'Gagal menyimpan');
    } finally {
      setSaveLoading(false);
    }
  };

  const rollback = async (version: number) => {
    if (!window.confirm(`Rollback config ke versi ${version}? Nilai lama disimpan sebagai versi baru.`)) return;
    try {
      await supabaseRpc('platform_config_rollback', {
        p_key: cfgKey, p_scope: scope, p_scope_ref: scopeRef, p_version: version,
      });
      show('ok', `Rollback ke versi ${version} berhasil.`);
      await loadCurrent();
    } catch (e: any) {
      show('err', e.message ?? 'Rollback gagal');
    }
  };

  const preview = async () => {
    if (!previewOutlet) return;
    try {
      setEffective(await supabaseRpc<any>('platform_config_effective', {
        p_key: cfgKey, p_outlet_id: previewOutlet,
      }));
    } catch (e: any) {
      show('err', e.message ?? 'Gagal memuat nilai efektif');
    }
  };

  return (
    <Card title="Override & Riwayat Versi" subtitle="Urutan resolusi: Outlet > Segment > Global. Setiap simpan tercatat di riwayat dan audit.">
      <div className="max-w-[860px] space-y-4">
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
          <div>
            <label className={labelCls}>Config</label>
            <select className={inputCls} value={cfgKey} onChange={(e) => { setCfgKey(e.target.value as ConfigKey); setScopeRef('all'); }}>
              {CONFIG_KEYS.map((c) => <option key={c.key} value={c.key}>{c.label}</option>)}
            </select>
          </div>
          <div>
            <label className={labelCls}>Scope</label>
            <select className={inputCls} value={scope} onChange={(e) => { const s = e.target.value as any; setScope(s); setScopeRef(s === 'global' ? 'all' : ''); }}>
              <option value="global">Global (semua outlet)</option>
              <option value="segment">Segment</option>
              <option value="outlet">Outlet</option>
            </select>
          </div>
          {scope !== 'global' && (
            <div>
              <label className={labelCls}>{scope === 'segment' ? 'Segment' : 'Outlet'}</label>
              <select className={inputCls} value={scopeRef} onChange={(e) => setScopeRef(e.target.value)}>
                <option value="">Pilih...</option>
                {scope === 'segment' && segments.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
                {scope === 'outlet' && outlets.map((o) => <option key={o.outlet_id} value={o.outlet_id}>{o.outlet_name}</option>)}
              </select>
            </div>
          )}
        </div>

        <div>
          <div className="flex items-center justify-between">
            <label className={labelCls}>Nilai (JSON)</label>
            <button onClick={loadCurrent} className="flex items-center gap-1 text-[11px] font-bold text-sky-600 hover:text-sky-700">
              <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} /> Muat ulang
            </button>
          </div>
          <textarea
            className={`${inputCls} font-mono text-[11px] min-h-[180px]`}
            value={text}
            onChange={(e) => setText(e.target.value)}
            spellCheck={false}
          />
        </div>

        <div className="flex flex-wrap gap-2">
          <SaveButton loading={saveLoading} onClick={save} label={scope === 'global' ? 'Simpan Global' : `Simpan Override ${scope === 'segment' ? 'Segment' : 'Outlet'}`} />
        </div>

        {/* Preview efektif */}
        <div className="pt-3 border-t border-slate-100">
          <label className={labelCls}>Preview Nilai Efektif (pilih outlet)</label>
          <div className="flex gap-2 mt-1">
            <select className={inputCls} value={previewOutlet} onChange={(e) => setPreviewOutlet(e.target.value)}>
              <option value="">Pilih outlet...</option>
              {outlets.map((o) => <option key={o.outlet_id} value={o.outlet_id}>{o.outlet_name}</option>)}
            </select>
            <button onClick={preview} disabled={!previewOutlet}
              className="border border-sky-200 bg-sky-50 text-sky-700 px-4 py-2 rounded-xl text-xs font-semibold hover:bg-sky-100 disabled:opacity-50">
              Lihat
            </button>
          </div>
          {effective && (
            <div className="mt-2 bg-slate-50 rounded-xl p-3 text-xs">
              <p className="font-bold text-slate-700 mb-1">
                Sumber: <span className="text-sky-600 uppercase">{String(effective.source)}</span>
                {effective.version ? <> &bull; versi {String(effective.version)}</> : null}
              </p>
              <pre className="text-[10px] font-mono text-slate-600 whitespace-pre-wrap max-h-40 overflow-auto">
                {effective.value ? JSON.stringify(effective.value, null, 2) : '(tidak ada nilai)'}
              </pre>
            </div>
          )}
        </div>

        {/* Riwayat */}
        <div className="pt-3 border-t border-slate-100">
          <label className={labelCls}>Riwayat Versi</label>
          {versions.length === 0 ? (
            <p className="text-[11px] text-slate-400 mt-1">Belum ada riwayat untuk scope ini.</p>
          ) : (
            <div className="mt-1 bg-white border border-slate-200/80 rounded-xl divide-y divide-slate-50 max-h-56 overflow-y-auto">
              {versions.map((h) => (
                <div key={h.version} className="flex items-center justify-between px-3 py-2 gap-2">
                  <div className="min-w-0">
                    <p className="text-xs font-bold text-slate-700">
                      v{h.version} &bull; {new Date(h.created_at).toLocaleString('id-ID', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' })}
                    </p>
                    <p className="text-[10px] text-slate-400 truncate">{h.changed_by_email}{h.note ? ` — ${h.note}` : ''}</p>
                  </div>
                  <button
                    onClick={() => rollback(h.version)}
                    className="shrink-0 border border-amber-200 bg-amber-50 text-amber-700 px-3 py-1.5 rounded-lg text-[10px] font-bold hover:bg-amber-100"
                  >
                    Rollback
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
      <Toast msg={msg} />
    </Card>
  );
}

// ===========================================================================
// ST11-4: Announcements (pengumuman in-app per audiens)
// ===========================================================================
function AnnouncementsTab() {
  const [rows, setRows] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState({ title: '', body: '', audience: 'all', is_active: true });
  const { msg, show } = useToast();

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await supabaseRpc<any>('platform_announcement_list');
      setRows(res?.rows ?? []);
    } catch (e: any) {
      show('err', e.message ?? 'Gagal memuat pengumuman');
    } finally {
      setLoading(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => { load(); }, [load]);

  const save = async () => {
    if (!form.title.trim()) { show('err', 'Judul wajib diisi.'); return; }
    setSaving(true);
    try {
      await supabaseRpc('platform_announcement_upsert', {
        p_title: form.title, p_body: form.body,
        p_audience: form.audience, p_is_active: form.is_active,
      });
      show('ok', 'Pengumuman disimpan.');
      setForm({ title: '', body: '', audience: 'all', is_active: true });
      await load();
    } catch (e: any) {
      show('err', e.message ?? 'Gagal menyimpan');
    } finally {
      setSaving(false);
    }
  };

  const toggle = async (r: any) => {
    try {
      await supabaseRpc('platform_announcement_upsert', {
        p_id: r.id, p_title: r.title, p_body: r.body ?? '',
        p_audience: r.audience ?? 'all',
        p_starts_at: r.starts_at ?? null, p_ends_at: r.ends_at ?? null,
        p_is_active: !r.is_active,
      });
      await load();
    } catch (e: any) { show('err', e.message ?? 'Gagal mengubah'); }
  };

  const remove = async (r: any) => {
    if (!window.confirm(`Hapus pengumuman "${r.title}"?`)) return;
    try {
      await supabaseRpc('platform_announcement_delete', { p_id: r.id });
      await load();
    } catch (e: any) { show('err', e.message ?? 'Gagal menghapus'); }
  };

  return (
    <Card title="Pengumuman In-App" subtitle="Tampil di aplikasi sesuai audiens (all / owner / supporter).">
      <div className="max-w-[760px] space-y-3.5">
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div>
            <label className={labelCls}>Judul</label>
            <input className={inputCls} value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
          </div>
          <div>
            <label className={labelCls}>Audiens</label>
            <select className={inputCls} value={form.audience} onChange={(e) => setForm({ ...form, audience: e.target.value })}>
              <option value="all">Semua</option>
              <option value="owner">Owner</option>
              <option value="supporter">Pendukung</option>
            </select>
          </div>
        </div>
        <div>
          <label className={labelCls}>Isi</label>
          <textarea className={`${inputCls} min-h-[80px]`} value={form.body} onChange={(e) => setForm({ ...form, body: e.target.value })} />
        </div>
        <label className="flex items-center gap-2 text-xs font-semibold text-slate-600">
          <input type="checkbox" checked={form.is_active} onChange={(e) => setForm({ ...form, is_active: e.target.checked })} />
          Aktif
        </label>
        <SaveButton loading={saving} onClick={save} label="Tambah Pengumuman" />

        <div className="pt-3 border-t border-slate-100">
          {loading ? <p className="text-[11px] text-slate-400">Memuat...</p> : rows.length === 0 ? (
            <p className="text-[11px] text-slate-400">Belum ada pengumuman.</p>
          ) : (
            <div className="bg-white border border-slate-200/80 rounded-xl divide-y divide-slate-50">
              {rows.map((r) => (
                <div key={r.id} className="flex items-center justify-between px-3 py-2.5 gap-2">
                  <div className="min-w-0">
                    <p className="text-xs font-bold text-slate-800 truncate">{r.title}</p>
                    <p className="text-[10px] text-slate-400 truncate">{r.audience} &bull; {r.is_active ? 'aktif' : 'nonaktif'}</p>
                  </div>
                  <div className="flex gap-1.5 shrink-0">
                    <button onClick={() => toggle(r)} className="px-3 py-1.5 rounded-lg border border-sky-200 bg-sky-50 text-sky-700 text-[10px] font-bold hover:bg-sky-100">
                      {r.is_active ? 'Matikan' : 'Aktifkan'}
                    </button>
                    <button onClick={() => remove(r)} className="p-2 rounded-lg bg-red-50 text-red-500 hover:bg-red-100">
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
      <Toast msg={msg} />
    </Card>
  );
}

// ===========================================================================
// ST11-4: Monitoring kesehatan platform + jalankan rules engine
// ===========================================================================
function MonitoringTab() {
  const [data, setData] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [running, setRunning] = useState(false);
  const [ruleResults, setRuleResults] = useState<any[] | null>(null);
  const { msg, show } = useToast();

  const load = useCallback(async () => {
    setLoading(true);
    try { setData(await supabaseRpc<any>('platform_monitoring')); }
    catch (e: any) { show('err', e.message ?? 'Gagal memuat monitoring'); }
    finally { setLoading(false); }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => { load(); }, [load]);

  const runRules = async () => {
    setRunning(true);
    try {
      const res = await supabaseRpc<any>('platform_rules_run');
      setRuleResults(res?.results ?? []);
      show('ok', 'Rules engine dijalankan; hasil match tercatat di audit.');
    } catch (e: any) {
      show('err', e.message ?? 'Gagal menjalankan rules');
    } finally {
      setRunning(false);
    }
  };

  const items: { label: string; value: any; warn?: boolean }[] = data ? [
    { label: 'Total outlet', value: data.outlets_total },
    { label: 'Outlet aktif 30 hari', value: data.outlets_active_30d },
    { label: 'Pendukung menunggu verifikasi', value: data.pending_supporters, warn: data.pending_supporters > 0 },
    { label: 'PPOB gagal 24 jam', value: data.ppob_failed_24h, warn: data.ppob_failed_24h > 0 },
    { label: 'PPOB pending 24 jam', value: data.ppob_pending_24h },
    { label: 'Transaksi sync macet >1 jam', value: data.tx_sync_stuck, warn: data.tx_sync_stuck > 0 },
    { label: 'Backup terjadwal jatuh tempo', value: data.backup_schedules_due, warn: data.backup_schedules_due > 0 },
    { label: 'Rules aktif / flags aktif', value: `${data.automation_rules_active} / ${data.feature_flags_enabled}` },
  ] : [];

  return (
    <Card title="Monitoring Platform" subtitle="Kesehatan sistem & antrean yang perlu ditindak.">
      <div className="space-y-4">
        {loading && <p className="text-[11px] text-slate-400">Memuat...</p>}
        {data && (
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
            {items.map((it) => (
              <div key={it.label} className={`rounded-xl border p-3 ${it.warn ? 'bg-amber-50 border-amber-200' : 'bg-white border-slate-200/80'}`}>
                <p className="text-[9px] font-bold text-slate-400 uppercase">{it.label}</p>
                <p className={`text-lg font-extrabold mt-0.5 ${it.warn ? 'text-amber-600' : 'text-slate-900'}`}>{String(it.value ?? 0)}</p>
              </div>
            ))}
          </div>
        )}

        <div className="pt-3 border-t border-slate-100">
          <div className="flex items-center justify-between mb-2">
            <div>
              <label className={labelCls}>Rules Engine</label>
              <p className="text-[11px] text-slate-400">Evaluasi semua automation_rules aktif; hasil match dicatat di audit.</p>
            </div>
            <button onClick={runRules} disabled={running}
              className="bg-gradient-to-r from-cyan-500 to-sky-600 text-white px-4 py-2.5 rounded-xl text-xs font-semibold shadow-md shadow-sky-500/25 active:scale-95 transition disabled:opacity-50">
              {running ? 'Menjalankan...' : 'Jalankan Rules'}
            </button>
          </div>
          {ruleResults && (
            <div className="bg-white border border-slate-200/80 rounded-xl divide-y divide-slate-50">
              {ruleResults.map((r, i) => (
                <div key={i} className="flex items-center justify-between px-3 py-2 gap-2">
                  <div className="min-w-0">
                    <p className="text-xs font-bold text-slate-700 truncate">{r.rule}</p>
                    <p className="text-[10px] text-slate-400 truncate">{r.detail ?? r.trigger}</p>
                  </div>
                  <span className={`shrink-0 px-2 py-0.5 rounded-full text-[9px] font-bold border ${r.matched ? 'bg-emerald-50 text-emerald-600 border-emerald-200' : 'bg-slate-50 text-slate-400 border-slate-200'}`}>
                    {r.matched ? 'MATCH' : 'tidak'}
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
      <Toast msg={msg} />
    </Card>
  );
}

// ===========================================================================
// ST11-4: Admin & RBAC (kelola admin_users)
// ===========================================================================
const ADMIN_ROLES = ['superadmin', 'finance', 'support', 'ops'];

function AdminsTab() {
  const [rows, setRows] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [email, setEmail] = useState('');
  const [role, setRole] = useState('support');
  const [saving, setSaving] = useState(false);
  const { msg, show } = useToast();

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await supabaseRpc<any>('platform_admin_list');
      setRows(res?.rows ?? []);
    } catch (e: any) {
      show('err', e.message ?? 'Gagal memuat admin');
    } finally {
      setLoading(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => { load(); }, [load]);

  const upsert = async () => {
    if (!email.trim()) { show('err', 'Email wajib diisi.'); return; }
    setSaving(true);
    try {
      await supabaseRpc('platform_admin_upsert', { p_email: email.trim(), p_role: role });
      show('ok', 'Admin disimpan.');
      setEmail('');
      await load();
    } catch (e: any) {
      show('err', e.message ?? 'Gagal menyimpan (user harus sudah terdaftar di aplikasi)');
    } finally {
      setSaving(false);
    }
  };

  const setActive = async (userId: string, active: boolean) => {
    try {
      await supabaseRpc('platform_admin_set_active', { p_user_id: userId, p_active: active });
      await load();
    } catch (e: any) { show('err', e.message ?? 'Gagal mengubah'); }
  };

  const changeRole = async (userId: string, newRole: string) => {
    const r = rows.find((x) => x.user_id === userId);
    if (!r) return;
    try {
      await supabaseRpc('platform_admin_upsert', { p_email: r.email, p_role: newRole });
      await load();
    } catch (e: any) { show('err', e.message ?? 'Gagal mengubah role'); }
  };

  return (
    <Card title="Admin & RBAC" subtitle="Role: superadmin (semua), finance, support, ops. Route guard aktif otomatis.">
      <div className="max-w-[760px] space-y-4">
        <div className="grid grid-cols-1 sm:grid-cols-[1fr_160px_auto] gap-3 items-end">
          <div>
            <label className={labelCls}>Email user terdaftar</label>
            <input className={inputCls} type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="nama@email.com" />
          </div>
          <div>
            <label className={labelCls}>Role</label>
            <select className={inputCls} value={role} onChange={(e) => setRole(e.target.value)}>
              {ADMIN_ROLES.map((r) => <option key={r} value={r}>{r}</option>)}
            </select>
          </div>
          <SaveButton loading={saving} onClick={upsert} label="Tambah / Update" />
        </div>

        <div className="bg-white border border-slate-200/80 rounded-xl divide-y divide-slate-50">
          {loading && <p className="px-3 py-4 text-[11px] text-slate-400">Memuat...</p>}
          {!loading && rows.length === 0 && <p className="px-3 py-4 text-[11px] text-slate-400">Belum ada admin.</p>}
          {rows.map((r) => (
            <div key={r.id} className="flex flex-col sm:flex-row sm:items-center justify-between px-3 py-2.5 gap-2">
              <div className="min-w-0">
                <p className="text-xs font-bold text-slate-800 truncate">{r.email}</p>
                <p className="text-[10px] text-slate-400">{r.is_active ? 'aktif' : 'nonaktif'} &bull; sejak {new Date(r.created_at).toLocaleDateString('id-ID')}</p>
              </div>
              <div className="flex items-center gap-2 shrink-0">
                <select
                  value={r.role ?? 'support'}
                  onChange={(e) => changeRole(r.user_id, e.target.value)}
                  className="border border-slate-200 rounded-lg px-2 py-1.5 text-[11px] bg-white"
                >
                  {ADMIN_ROLES.map((x) => <option key={x} value={x}>{x}</option>)}
                </select>
                <button
                  onClick={() => setActive(r.user_id, !r.is_active)}
                  className={`px-3 py-1.5 rounded-lg text-[10px] font-bold border ${r.is_active ? 'bg-rose-50 text-rose-600 border-rose-200 hover:bg-rose-100' : 'bg-emerald-50 text-emerald-600 border-emerald-200 hover:bg-emerald-100'}`}
                >
                  {r.is_active ? 'Nonaktifkan' : 'Aktifkan'}
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>
      <Toast msg={msg} />
    </Card>
  );
}

// ===========================================================================
// ST14-3: Dokter Bisnis AI - provider LLM global + uji koneksi + chat uji
// ===========================================================================
const DOCTOR_SKILLS: { key: string; label: string }[] = [
  { key: 'chat', label: 'Konsultasi Chat' },
  { key: 'snapshot', label: 'Snapshot Bisnis' },
  { key: 'trend', label: 'Tren Penjualan' },
  { key: 'low_stock', label: 'Stok Menipis' },
  { key: 'slow_products', label: 'Produk Mati' },
  { key: 'cashflow', label: 'Arus Kas & ROI Aksi' },
  { key: 'memory', label: 'Memori & Resep' },
  { key: 'internet', label: 'Internet (Fetch)' },
  { key: 'target', label: 'Konsultasi Target' },
  { key: 'scaling', label: 'Business Scaling' },
  { key: 'market_intel', label: 'Intelijen Pasar' },
  { key: 'cross_sell', label: 'Cross-Selling' },
  { key: 'bundling', label: 'Bundling' },
  { key: 'referral', label: 'Referral' },
  { key: 'reprimand', label: 'Teguran Otomatis' },
  { key: 'weekly_report', label: 'Laporan Mingguan' },
];

function DoctorTab() {
  const [v, setV] = useState<any>({});
  const [loading, setLoading] = useState(false);
  const [probing, setProbing] = useState(false);
  const [probe, setProbe] = useState<string | null>(null);
  const [outlets, setOutlets] = useState<{ outlet_id: string; outlet_name: string | null }[]>([]);
  const [testOutlet, setTestOutlet] = useState('');
  const [testMsg, setTestMsg] = useState('Usaha saya sepi, apa yang harus saya lakukan?');
  const [chatBusy, setChatBusy] = useState(false);
  const [chatOut, setChatOut] = useState<string | null>(null);
  const [observeOutlet, setObserveOutlet] = useState('');
  const [observeBusy, setObserveBusy] = useState(false);
  const [observeOut, setObserveOut] = useState<string | null>(null);
  const [aiConfigs, setAiConfigs] = useState<OutletAiConfig[]>([]);
  const [editOutlet, setEditOutlet] = useState('');
  const [aiForm, setAiForm] = useState<Record<string, any>>({});
  const [aiBusy, setAiBusy] = useState(false);
  const { msg, show } = useToast();

  useEffect(() => {
    loadConfig('business_doctor').then((d) => setV(d ?? {})).catch(() => {});
    platformOutletsList({ p_kyc: 'all', p_plan: 'all', p_limit: 200, p_offset: 0 })
      .then((r) => {
        const rows = (r?.rows ?? []).map((o) => ({ outlet_id: o.outlet_id, outlet_name: o.outlet_name }));
        setOutlets(rows);
        if (rows[0]) setTestOutlet(rows[0].outlet_id);
      })
      .catch(() => {});
    listOutletAiConfigs().then(setAiConfigs).catch(() => {});
  }, []);

  const refreshAiConfigs = () => listOutletAiConfigs().then(setAiConfigs).catch(() => {});

  const openAiEdit = (o: OutletAiConfig) => {
    setEditOutlet(o.outlet_id);
    setAiForm({
      provider: o.provider ?? '',
      base_url: o.base_url ?? '',
      model: o.model ?? '',
      temperature: o.temperature ?? 0.7,
      max_tokens: o.max_tokens ?? 800,
      is_active: o.is_active,
      unlimited_tokens: o.unlimited_tokens ?? false,
      token_quota: o.token_quota ?? '',
      api_key: '',
    });
  };

  const saveAi = async () => {
    if (!editOutlet) { show('err', 'Pilih outlet dulu.'); return; }
    setAiBusy(true);
    try {
      await setOutletAiConfig(editOutlet, aiForm);
      await refreshAiConfigs();
      show('ok', 'Override provider AI disimpan.');
      setEditOutlet('');
    } catch (e: any) { show('err', e.message); } finally { setAiBusy(false); }
  };

  const clearAi = async (outletId: string) => {
    setAiBusy(true);
    try {
      await deleteOutletAiConfig(outletId);
      await refreshAiConfigs();
      show('ok', 'Override dihapus (kembali ke provider global).');
    } catch (e: any) { show('err', e.message); } finally { setAiBusy(false); }
  };

  const set = (k: string, val: any) => setV((prev: any) => ({ ...prev, [k]: val }));
  const pd = v.provider_default ?? {};
  const setPd = (k: string, val: any) => set('provider_default', { ...pd, [k]: val });
  const it = v.internet_tool ?? {};
  const setIt = (k: string, val: any) => set('internet_tool', { ...it, [k]: val });
  const rl = v.rate_limit ?? {};
  const setRl = (k: string, val: any) => set('rate_limit', { ...rl, [k]: val });
  const sk: string[] = Array.isArray(v.skills) ? v.skills : [];
  const toggleSkill = (k: string) =>
    set('skills', sk.includes(k) ? sk.filter((s) => s !== k) : [...sk, k]);
  const [showPrompt, setShowPrompt] = useState(false);

  const resetPrompt = () => {
    const def = v.prompt_utama_default;
    if (!def) { show('err', 'Default prompt tidak tersedia.'); return; }
    set('prompt_utama', def);
    show('ok', 'Prompt dikembalikan ke default (belum disimpan).');
  };

  const save = async () => {
    setLoading(true);
    try {
      await saveConfig('business_doctor', v);
      show('ok', 'Konfigurasi Dokter Bisnis disimpan.');
    } catch (e: any) { show('err', e.message); } finally { setLoading(false); }
  };

  const probeProvider = async () => {
    setProbing(true);
    setProbe(null);
    try {
      const r = await testDoctorProvider(pd);
      setProbe(`${r.ok ? 'OK' : 'GAGAL'}: ${r.message}${r.sample ? ` (contoh: ${r.sample})` : ''}`);
      show(r.ok ? 'ok' : 'err', r.ok ? 'Provider terhubung.' : 'Provider gagal.');
    } catch (e: any) { setProbe(e.message); show('err', e.message); } finally { setProbing(false); }
  };

  const runObserve = async () => {
    setObserveBusy(true);
    setObserveOut(null);
    try {
      const { data, error } = await supabase.functions.invoke('doctor_observe', {
        body: observeOutlet ? { outlet_id: observeOutlet } : {},
      });
      if (error) throw error;
      setObserveOut(JSON.stringify(data, null, 1));
      show('ok', 'Observasi selesai.');
    } catch (e: any) { setObserveOut(e.message); show('err', e.message); } finally { setObserveBusy(false); }
  };

  const runChat = async () => {
    if (!testOutlet) { show('err', 'Pilih outlet dulu.'); return; }
    setChatBusy(true);
    setChatOut(null);
    try {
      const r = await testDoctorChat(testOutlet, testMsg);
      const texts = (r?.blocks ?? []).map((b: any) => b.title || b.text || b.label).filter(Boolean).join(' | ');
      setChatOut(`fallback=${r?.fallback ?? false} | phase=${r?.phase ?? '-'} | tokens=${r?.tokens ?? 0}\n${texts || r?.reply || '-'}`);
    } catch (e: any) { setChatOut(e.message); show('err', e.message); } finally { setChatBusy(false); }
  };

  return (
    <div className="space-y-3.5">
      <Card title="Dokter Bisnis AI" subtitle="Otak AI global: provider LLM, prompt, guardrails, dan internet tool. Semua tanpa ubah koding.">
        <div className="max-w-[760px] space-y-3.5">
          <label className="flex items-center gap-2 text-xs font-semibold text-slate-600">
            <input type="checkbox" checked={!!v.aktif} onChange={(e) => set('aktif', e.target.checked)} />
            Aktifkan Dokter Bisnis AI untuk semua outlet
          </label>
          <div>
            <label className={labelCls}>Bahasa</label>
            <input className={inputCls} value={v.bahasa ?? ''} placeholder="id" onChange={(e) => set('bahasa', e.target.value)} />
          </div>
          <div>
            <div className="flex items-center justify-between mb-1.5">
              <label className={`${labelCls} mb-0`}>Master Prompt Karakter & Skill</label>
              <div className="flex gap-2">
                <button type="button" onClick={() => setShowPrompt((s) => !s)} className="px-2.5 py-1 rounded-lg text-[11px] font-semibold border border-slate-200 bg-white hover:bg-slate-50 text-slate-700">
                  {showPrompt ? 'Sembunyikan' : 'Preview'}
                </button>
                <button type="button" onClick={resetPrompt} className="px-2.5 py-1 rounded-lg text-[11px] font-semibold border border-slate-200 bg-white hover:bg-slate-50 text-slate-700">
                  Reset ke Default
                </button>
              </div>
            </div>
            <textarea className={inputCls} rows={10} value={v.prompt_utama ?? ''} onChange={(e) => set('prompt_utama', e.target.value)} />
            <p className="text-[11px] text-slate-400 mt-1">Karakter + skill AI (BAGIAN 13.23). Dapat diubah tanpa koding.</p>
            {showPrompt && (
              <pre className="mt-2 max-h-72 overflow-auto whitespace-pre-wrap rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-[11px] text-slate-600">
                {v.prompt_utama || '(kosong)'}
              </pre>
            )}
          </div>
          <div>
            <label className={labelCls}>Daftar Skill (alat yang boleh dipakai AI)</label>
            <div className="flex flex-wrap gap-2">
              {DOCTOR_SKILLS.map((s) => (
                <button
                  key={s.key}
                  type="button"
                  onClick={() => toggleSkill(s.key)}
                  className={`px-3 py-1.5 rounded-full text-[11px] font-semibold border transition ${sk.includes(s.key) ? 'bg-gradient-to-r from-cyan-500 to-sky-600 text-white border-transparent' : 'bg-white text-slate-600 border-slate-200 hover:bg-slate-50'}`}
                >
                  {s.label}
                </button>
              ))}
            </div>
            <p className="text-[11px] text-slate-400 mt-1">Kosong = semua skill aktif. Tool diluar skill terpilih tidak dikirim ke AI.</p>
          </div>
          <div>
            <label className={labelCls}>Guardrails (pisahkan dengan koma)</label>
            <input
              className={inputCls}
              value={Array.isArray(v.guardrails) ? v.guardrails.join(', ') : v.guardrails ?? ''}
              onChange={(e) => set('guardrails', e.target.value.split(',').map((s) => s.trim()).filter(Boolean))}
            />
          </div>
          <label className="flex items-center gap-2 text-xs font-semibold text-slate-600">
            <input type="checkbox" checked={!!it.aktif} onChange={(e) => setIt('aktif', e.target.checked)} />
            Izinkan AI mengakses internet (web search)
          </label>

          <div className="pt-2 border-t border-slate-100">
            <p className="text-[11px] font-bold text-slate-500 uppercase tracking-wider mb-2">Batas Pemakaian Harian (per outlet)</p>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label className={labelCls}>Maks Pesan / Hari</label>
                <input className={inputCls} type="number" value={rl.messages_per_day ?? ''} placeholder="60" onChange={(e) => setRl('messages_per_day', Number(e.target.value))} />
              </div>
              <div>
                <label className={labelCls}>Maks Token / Hari</label>
                <input className={inputCls} type="number" value={rl.tokens_per_day ?? ''} placeholder="200000" onChange={(e) => setRl('tokens_per_day', Number(e.target.value))} />
              </div>
            </div>
          </div>

          <div className="pt-2 border-t border-slate-100">
            <p className="text-[11px] font-bold text-slate-500 uppercase tracking-wider mb-2">Provider Default</p>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div className="sm:col-span-2">
                <label className={labelCls}>Base URL</label>
                <input className={inputCls} value={pd.base_url ?? ''} placeholder="https://api.deepseek.com/v1" onChange={(e) => setPd('base_url', e.target.value)} />
              </div>
              <div className="sm:col-span-2">
                <label className={labelCls}>API Key</label>
                <input className={inputCls} type="password" value={pd.api_key ?? ''} placeholder="sk-..." onChange={(e) => setPd('api_key', e.target.value)} />
                <p className="text-[11px] text-slate-400 mt-1">Hanya disimpan di server (Edge Function). Tidak pernah dikirim ke aplikasi.</p>
              </div>
              <div>
                <label className={labelCls}>Model</label>
                <input className={inputCls} value={pd.model ?? ''} placeholder="deepseek-chat" onChange={(e) => setPd('model', e.target.value)} />
              </div>
              <div>
                <label className={labelCls}>Temperature</label>
                <input className={inputCls} type="number" step="0.1" value={pd.temperature ?? ''} onChange={(e) => setPd('temperature', Number(e.target.value))} />
              </div>
              <div>
                <label className={labelCls}>Maks Token</label>
                <input className={inputCls} type="number" value={pd.max_tokens ?? ''} onChange={(e) => setPd('max_tokens', Number(e.target.value))} />
              </div>
            </div>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <SaveButton loading={loading} onClick={save} />
            <button
              onClick={probeProvider}
              disabled={probing}
              className="flex items-center gap-2 px-4 py-2.5 rounded-xl font-semibold text-xs border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 transition"
            >
              {probing ? <RefreshCw className="w-4 h-4 animate-spin" /> : <Zap className="w-4 h-4" />}
              Tes Koneksi Provider
            </button>
          </div>
          {probe && <p className="text-[11px] text-slate-600 bg-slate-50 border border-slate-200 rounded-lg px-3 py-2">{probe}</p>}
        </div>
        <Toast msg={msg} />
      </Card>

      <Card title="Override Provider per Outlet" subtitle="Ganti provider LLM untuk outlet tertentu (mis. kunci/limit terpisah). Kunci hanya disimpan di server, tidak pernah ditampilkan kembali.">
        <div className="space-y-3">
          <div className="overflow-x-auto">
            <table className="w-full text-xs">
              <thead>
                <tr className="text-left text-slate-500 border-b border-slate-200">
                  <th className="py-2 pr-3 font-semibold">Outlet</th>
                  <th className="py-2 pr-3 font-semibold">Override</th>
                  <th className="py-2 pr-3 font-semibold">Status</th>
                  <th className="py-2 pr-3 font-semibold">Kunci</th>
                  <th className="py-2 pr-3 font-semibold">Kuota</th>
                  <th className="py-2 font-semibold">Aksi</th>
                </tr>
              </thead>
              <tbody>
                {aiConfigs.map((o) => (
                  <tr key={o.outlet_id} className="border-b border-slate-100">
                    <td className="py-2 pr-3 text-slate-800">{o.outlet_name ?? o.outlet_id}</td>
                    <td className="py-2 pr-3 text-slate-600">{o.has_config ? (o.model ?? o.provider ?? '-') : '-'}</td>
                    <td className="py-2 pr-3">
                      {o.has_config ? (
                        <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${o.is_active ? 'bg-emerald-50 text-emerald-700 border border-emerald-200' : 'bg-slate-100 text-slate-500 border border-slate-200'}`}>
                          {o.is_active ? 'Aktif' : 'Nonaktif'}
                        </span>
                      ) : <span className="text-slate-400">Global</span>}
                    </td>
                    <td className="py-2 pr-3 text-slate-500">{o.has_api_key ? 'Tersimpan' : '-'}</td>
                    <td className="py-2 pr-3 text-slate-500">
                      {o.unlimited_tokens ? 'Unlimited' : (o.token_quota ? o.token_quota.toLocaleString('id-ID') : 'Global')}
                    </td>
                    <td className="py-2">
                      <div className="flex gap-2">
                        <button onClick={() => openAiEdit(o)} className="px-2.5 py-1 rounded-lg text-[11px] font-semibold border border-slate-200 bg-white hover:bg-slate-50 text-slate-700">Atur</button>
                        {o.has_config && (
                          <button onClick={() => clearAi(o.outlet_id)} disabled={aiBusy} className="px-2.5 py-1 rounded-lg text-[11px] font-semibold border border-red-200 bg-red-50 hover:bg-red-100 text-red-600">Hapus</button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
                {aiConfigs.length === 0 && (
                  <tr><td colSpan={6} className="py-3 text-center text-slate-400">Memuat data outlet...</td></tr>
                )}
              </tbody>
            </table>
          </div>

          {editOutlet && (
            <div className="pt-2 border-t border-slate-100 max-w-[760px] space-y-3">
              <p className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">
                Atur Override: {aiConfigs.find((o) => o.outlet_id === editOutlet)?.outlet_name ?? editOutlet}
              </p>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div className="sm:col-span-2">
                  <label className={labelCls}>Base URL</label>
                  <input className={inputCls} value={aiForm.base_url ?? ''} placeholder="https://api.deepseek.com/v1" onChange={(e) => setAiForm({ ...aiForm, base_url: e.target.value })} />
                </div>
                <div className="sm:col-span-2">
                  <label className={labelCls}>API Key</label>
                  <input className={inputCls} type="password" value={aiForm.api_key ?? ''} placeholder="Kosongkan bila tidak diubah" onChange={(e) => setAiForm({ ...aiForm, api_key: e.target.value })} />
                </div>
                <div>
                  <label className={labelCls}>Model</label>
                  <input className={inputCls} value={aiForm.model ?? ''} placeholder="deepseek-chat" onChange={(e) => setAiForm({ ...aiForm, model: e.target.value })} />
                </div>
                <div>
                  <label className={labelCls}>Maks Token</label>
                  <input className={inputCls} type="number" value={aiForm.max_tokens ?? ''} onChange={(e) => setAiForm({ ...aiForm, max_tokens: Number(e.target.value) })} />
                </div>
              </div>
              <label className="flex items-center gap-2 text-xs font-semibold text-slate-600">
                <input type="checkbox" checked={!!aiForm.is_active} onChange={(e) => setAiForm({ ...aiForm, is_active: e.target.checked })} />
                Gunakan override ini untuk outlet tersebut
              </label>
              <label className="flex items-center gap-2 text-xs font-semibold text-slate-600">
                <input type="checkbox" checked={!!aiForm.unlimited_tokens} onChange={(e) => setAiForm({ ...aiForm, unlimited_tokens: e.target.checked })} />
                Unlimited token (lewati kuota; tetap dicatat)
              </label>
              {!aiForm.unlimited_tokens && (
                <div className="max-w-[240px]">
                  <label className={labelCls}>Kuota Token / Hari (kosong = global)</label>
                  <input className={inputCls} type="number" value={aiForm.token_quota ?? ''} placeholder="mis. 200000" onChange={(e) => setAiForm({ ...aiForm, token_quota: e.target.value })} />
                </div>
              )}
              <div className="flex flex-wrap gap-2">
                <button onClick={saveAi} disabled={aiBusy} className="flex items-center gap-2 px-4 py-2.5 rounded-xl font-semibold text-xs bg-gradient-to-r from-cyan-500 to-sky-600 hover:from-cyan-600 hover:to-sky-700 text-white shadow-md shadow-sky-500/25 transition active:scale-95">
                  {aiBusy ? <RefreshCw className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
                  Simpan Override
                </button>
                <button onClick={() => setEditOutlet('')} className="px-4 py-2.5 rounded-xl font-semibold text-xs border border-slate-200 bg-white hover:bg-slate-50 text-slate-700">Batal</button>
              </div>
            </div>
          )}
        </div>
      </Card>

      <Card title="Chat Uji" subtitle="Simulasikan percakapan Dokter Bisnis pada outlet nyata. Berguna memastikan prompt & tool berjalan.">
        <div className="max-w-[760px] space-y-3">
          <div>
            <label className={labelCls}>Outlet Uji</label>
            <select className={inputCls} value={testOutlet} onChange={(e) => setTestOutlet(e.target.value)}>
              {outlets.map((o) => <option key={o.outlet_id} value={o.outlet_id}>{o.outlet_name ?? o.outlet_id}</option>)}
            </select>
          </div>
          <div>
            <label className={labelCls}>Pesan Uji</label>
            <input className={inputCls} value={testMsg} onChange={(e) => setTestMsg(e.target.value)} />
          </div>
          <button
            onClick={runChat}
            disabled={chatBusy}
            className="flex items-center gap-2 px-4 py-2.5 rounded-xl font-semibold text-xs bg-gradient-to-r from-cyan-500 to-sky-600 hover:from-cyan-600 hover:to-sky-700 text-white shadow-md shadow-sky-500/25 transition active:scale-95"
          >
            {chatBusy ? <RefreshCw className="w-4 h-4 animate-spin" /> : <Activity className="w-4 h-4" />}
            Kirim Uji
          </button>
          {chatOut && <pre className="text-[11px] text-slate-700 bg-slate-50 border border-slate-200 rounded-lg px-3 py-2 whitespace-pre-wrap">{chatOut}</pre>}
        </div>
      </Card>

      <Card title="Observasi & Teguran Otomatis" subtitle="Evaluasi resep terbuka vs data nyata (omzet) dan keluarkan teguran bertingkat bila resep tidak dijalankan (anti-spam: maks 1/hari/outlet). Bisa dijadwalkan via Supabase Dashboard (Scheduled Functions).">
        <div className="max-w-[760px] space-y-3">
          <div>
            <label className={labelCls}>Outlet (kosong = semua outlet)</label>
            <select className={inputCls} value={observeOutlet} onChange={(e) => setObserveOutlet(e.target.value)}>
              <option value="">Semua outlet</option>
              {outlets.map((o) => <option key={o.outlet_id} value={o.outlet_id}>{o.outlet_name ?? o.outlet_id}</option>)}
            </select>
          </div>
          <button
            onClick={runObserve}
            disabled={observeBusy}
            className="flex items-center gap-2 px-4 py-2.5 rounded-xl font-semibold text-xs border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 transition"
          >
            {observeBusy ? <RefreshCw className="w-4 h-4 animate-spin" /> : <CalendarClock className="w-4 h-4" />}
            Jalankan Observasi
          </button>
          {observeOut && <pre className="text-[11px] text-slate-700 bg-slate-50 border border-slate-200 rounded-lg px-3 py-2 whitespace-pre-wrap">{observeOut}</pre>}
        </div>
      </Card>
    </div>
  );
}

// ===========================================================================
const DM_CHANNELS: { key: string; label: string }[] = [
  { key: 'fb', label: 'Facebook Page' },
  { key: 'fb_group', label: 'Grup Facebook' },
  { key: 'ig', label: 'Instagram' },
  { key: 'tiktok', label: 'TikTok' },
  { key: 'shopee', label: 'Shopee' },
  { key: 'meta_ads', label: 'Meta Ads' },
  { key: 'google_ads', label: 'Google Ads' },
  { key: 'tiktok_ads', label: 'TikTok Ads' },
  { key: 'shopee_ads', label: 'Shopee Ads' },
];

function SquadDmTab() {
  const [v, setV] = useState<any>({});
  const [loading, setLoading] = useState(false);
  const [probing, setProbing] = useState(false);
  const [probe, setProbe] = useState<string | null>(null);
  const [outlets, setOutlets] = useState<{ outlet_id: string; outlet_name: string | null }[]>([]);
  const [dmConfigs, setDmConfigs] = useState<OutletDmConfig[]>([]);
  const [editOutlet, setEditOutlet] = useState('');
  const [dmForm, setDmForm] = useState<Record<string, any>>({});
  const [dmBusy, setDmBusy] = useState(false);
  const [accounts, setAccounts] = useState<DmChannelAccount[]>([]);
  const [accOutlet, setAccOutlet] = useState('');
  const [accChannel, setAccChannel] = useState('fb');
  const [accName, setAccName] = useState('');
  const [accExternal, setAccExternal] = useState('');
  const [accToken, setAccToken] = useState('');
  const [accBusy, setAccBusy] = useState(false);
  const { msg, show } = useToast();

  useEffect(() => {
    loadConfig('digital_marketing_llm').then((d) => setV(d ?? {})).catch(() => {});
    platformOutletsList({ p_kyc: 'all', p_plan: 'all', p_limit: 200, p_offset: 0 })
      .then((r) => {
        const rows = (r?.rows ?? []).map((o) => ({ outlet_id: o.outlet_id, outlet_name: o.outlet_name }));
        setOutlets(rows);
        if (rows[0]) { setEditOutlet(''); setAccOutlet(rows[0].outlet_id); }
      })
      .catch(() => {});
    listOutletDmConfigs().then(setDmConfigs).catch(() => {});
    listDmChannelAccounts().then(setAccounts).catch(() => {});
  }, []);

  const refreshDmConfigs = () => listOutletDmConfigs().then(setDmConfigs).catch(() => {});
  const refreshAccounts = () => listDmChannelAccounts().then(setAccounts).catch(() => {});

  const set = (k: string, val: any) => setV((prev: any) => ({ ...prev, [k]: val }));
  const pd = v.provider_default ?? {};
  const setPd = (k: string, val: any) => set('provider_default', { ...pd, [k]: val });
  const rl = v.rate_limit ?? {};
  const setRl = (k: string, val: any) => set('rate_limit', { ...rl, [k]: val });

  const save = async () => {
    setLoading(true);
    try {
      await saveConfig('digital_marketing_llm', v);
      show('ok', 'Konfigurasi Squad Digital Marketing disimpan.');
    } catch (e: any) { show('err', e.message); } finally { setLoading(false); }
  };

  const probeProvider = async () => {
    setProbing(true);
    setProbe(null);
    try {
      const r = await testDmProvider(pd);
      setProbe(`${r.ok ? 'OK' : 'GAGAL'}: ${r.message}${r.sample ? ` (contoh: ${r.sample})` : ''}`);
      show(r.ok ? 'ok' : 'err', r.ok ? 'Provider terhubung.' : 'Provider gagal.');
    } catch (e: any) { setProbe(e.message); show('err', e.message); } finally { setProbing(false); }
  };

  const openDmEdit = (o: OutletDmConfig) => {
    setEditOutlet(o.outlet_id);
    setDmForm({
      provider: o.provider ?? '',
      base_url: o.base_url ?? '',
      model: o.model ?? '',
      temperature: o.temperature ?? 0.7,
      max_tokens: o.max_tokens ?? 4000,
      is_active: o.is_active,
      unlimited_tokens: o.unlimited_tokens ?? false,
      token_quota: o.token_quota ?? '',
      api_key: '',
    });
  };

  const saveDm = async () => {
    if (!editOutlet) { show('err', 'Pilih outlet dulu.'); return; }
    setDmBusy(true);
    try {
      await setOutletDmConfig(editOutlet, dmForm);
      await refreshDmConfigs();
      show('ok', 'Override provider DM disimpan.');
      setEditOutlet('');
    } catch (e: any) { show('err', e.message); } finally { setDmBusy(false); }
  };

  const clearDm = async (outletId: string) => {
    setDmBusy(true);
    try {
      await deleteOutletDmConfig(outletId);
      await refreshDmConfigs();
      show('ok', 'Override dihapus (kembali ke provider global).');
    } catch (e: any) { show('err', e.message); } finally { setDmBusy(false); }
  };

  const saveAccount = async () => {
    if (!accOutlet) { show('err', 'Pilih outlet dulu.'); return; }
    setAccBusy(true);
    try {
      await setDmChannelAccount(accOutlet, accChannel, {
        account_name: accName || null,
        external_id: accExternal || null,
        token: accToken || null,
        connected: true,
      });
      await refreshAccounts();
      setAccName(''); setAccExternal(''); setAccToken('');
      show('ok', 'Akun kanal tersimpan (token terenkripsi di server).');
    } catch (e: any) { show('err', e.message); } finally { setAccBusy(false); }
  };

  const clearAccount = async (outletId: string, channel: string) => {
    setAccBusy(true);
    try {
      await deleteDmChannelAccount(outletId, channel);
      await refreshAccounts();
      show('ok', 'Akun kanal dihapus.');
    } catch (e: any) { show('err', e.message); } finally { setAccBusy(false); }
  };

  const channelLabel = (k: string) => DM_CHANNELS.find((c) => c.key === k)?.label ?? k;

  return (
    <div className="space-y-3.5">
      <Card title="Squad Digital Marketing AI" subtitle="Otak AI global untuk tim Desain, Promosi & Iklan. Semua tanpa ubah koding.">
        <div className="max-w-[760px] space-y-3.5">
          <label className="flex items-center gap-2 text-xs font-semibold text-slate-600">
            <input type="checkbox" checked={!!v.aktif} onChange={(e) => set('aktif', e.target.checked)} />
            Aktifkan Squad Digital Marketing AI untuk semua outlet
          </label>
          <div>
            <label className={labelCls}>Mode Konfigurasi</label>
            <select className={inputCls} value={v.mode ?? 'central'} onChange={(e) => set('mode', e.target.value)}>
              <option value="central">Terpusat (satu provider untuk semua)</option>
              <option value="per_outlet">Per Outlet (override per outlet)</option>
            </select>
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className={labelCls}>Kuota Aset / Bulan (per outlet)</label>
              <input className={inputCls} type="number" value={v.asset_quota_per_month ?? ''} placeholder="60" onChange={(e) => set('asset_quota_per_month', Number(e.target.value))} />
            </div>
            <div>
              <label className={labelCls}>Batas Budget Iklan Global / Hari</label>
              <input className={inputCls} type="number" value={v.budget_global_daily ?? ''} placeholder="0" onChange={(e) => set('budget_global_daily', Number(e.target.value))} />
            </div>
            <div className="sm:col-span-2">
              <label className={labelCls}>Kata Terlarang (dipisah koma)</label>
              <input className={inputCls} value={(v.blocked_words ?? []).join(', ')} placeholder="judi, obat terlarang" onChange={(e) => set('blocked_words', e.target.value.split(',').map((s: string) => s.trim()).filter(Boolean))} />
            </div>
            <div className="sm:col-span-2">
              <label className={labelCls}>Watermark Default</label>
              <input className={inputCls} value={v.watermark_default ?? ''} placeholder="Nama toko / logo" onChange={(e) => set('watermark_default', e.target.value)} />
            </div>
          </div>

          <div className="pt-2 border-t border-slate-100">
            <p className="text-[11px] font-bold text-slate-500 uppercase tracking-wider mb-2">Batas Pemakaian Harian (per outlet)</p>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label className={labelCls}>Maks Aset / Hari</label>
                <input className={inputCls} type="number" value={rl.assets_per_day ?? ''} placeholder="20" onChange={(e) => setRl('assets_per_day', Number(e.target.value))} />
              </div>
              <div>
                <label className={labelCls}>Maks Token / Hari</label>
                <input className={inputCls} type="number" value={rl.tokens_per_day ?? ''} placeholder="150000" onChange={(e) => setRl('tokens_per_day', Number(e.target.value))} />
              </div>
            </div>
          </div>

          <div className="pt-2 border-t border-slate-100">
            <p className="text-[11px] font-bold text-slate-500 uppercase tracking-wider mb-2">Provider Default</p>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div className="sm:col-span-2">
                <label className={labelCls}>Base URL</label>
                <input className={inputCls} value={pd.base_url ?? ''} placeholder="https://api.deepseek.com/v1" onChange={(e) => setPd('base_url', e.target.value)} />
              </div>
              <div className="sm:col-span-2">
                <label className={labelCls}>API Key</label>
                <input className={inputCls} type="password" value={pd.api_key ?? ''} placeholder="sk-..." onChange={(e) => setPd('api_key', e.target.value)} />
                <p className="text-[11px] text-slate-400 mt-1">Hanya disimpan di server (Edge Function). Tidak pernah dikirim ke aplikasi.</p>
              </div>
              <div>
                <label className={labelCls}>Model</label>
                <input className={inputCls} value={pd.model ?? ''} placeholder="deepseek-chat" onChange={(e) => setPd('model', e.target.value)} />
              </div>
              <div>
                <label className={labelCls}>Temperature</label>
                <input className={inputCls} type="number" step="0.1" value={pd.temperature ?? ''} onChange={(e) => setPd('temperature', Number(e.target.value))} />
              </div>
              <div>
                <label className={labelCls}>Maks Token</label>
                <input className={inputCls} type="number" value={pd.max_tokens ?? ''} onChange={(e) => setPd('max_tokens', Number(e.target.value))} />
              </div>
            </div>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <SaveButton loading={loading} onClick={save} />
            <button
              onClick={probeProvider}
              disabled={probing}
              className="flex items-center gap-2 px-4 py-2.5 rounded-xl font-semibold text-xs border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 transition"
            >
              {probing ? <RefreshCw className="w-4 h-4 animate-spin" /> : <Zap className="w-4 h-4" />}
              Tes Koneksi Provider
            </button>
          </div>
          {probe && <p className="text-[11px] text-slate-600 bg-slate-50 border border-slate-200 rounded-lg px-3 py-2">{probe}</p>}
        </div>
        <Toast msg={msg} />
      </Card>

      <Card title="Override Provider per Outlet" subtitle="Ganti provider LLM untuk outlet tertentu. Kunci hanya disimpan di server, tidak pernah ditampilkan kembali.">
        <div className="space-y-3">
          <div className="overflow-x-auto">
            <table className="w-full text-xs">
              <thead>
                <tr className="text-left text-slate-500 border-b border-slate-200">
                  <th className="py-2 pr-3 font-semibold">Outlet</th>
                  <th className="py-2 pr-3 font-semibold">Override</th>
                  <th className="py-2 pr-3 font-semibold">Status</th>
                  <th className="py-2 pr-3 font-semibold">Kunci</th>
                  <th className="py-2 pr-3 font-semibold">Kuota</th>
                  <th className="py-2 font-semibold">Aksi</th>
                </tr>
              </thead>
              <tbody>
                {dmConfigs.map((o) => (
                  <tr key={o.outlet_id} className="border-b border-slate-100">
                    <td className="py-2 pr-3 text-slate-800">{o.outlet_name ?? o.outlet_id}</td>
                    <td className="py-2 pr-3 text-slate-600">{o.has_config ? (o.model ?? o.provider ?? '-') : '-'}</td>
                    <td className="py-2 pr-3">
                      {o.has_config ? (
                        <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${o.is_active ? 'bg-emerald-50 text-emerald-700 border border-emerald-200' : 'bg-slate-100 text-slate-500 border border-slate-200'}`}>
                          {o.is_active ? 'Aktif' : 'Nonaktif'}
                        </span>
                      ) : <span className="text-slate-400">Global</span>}
                    </td>
                    <td className="py-2 pr-3 text-slate-500">{o.has_api_key ? 'Tersimpan' : '-'}</td>
                    <td className="py-2 pr-3 text-slate-500">
                      {o.unlimited_tokens ? 'Unlimited' : (o.token_quota ? o.token_quota.toLocaleString('id-ID') : 'Global')}
                    </td>
                    <td className="py-2">
                      <div className="flex gap-2">
                        <button onClick={() => openDmEdit(o)} className="px-2.5 py-1 rounded-lg text-[11px] font-semibold border border-slate-200 bg-white hover:bg-slate-50 text-slate-700">Atur</button>
                        {o.has_config && (
                          <button onClick={() => clearDm(o.outlet_id)} disabled={dmBusy} className="px-2.5 py-1 rounded-lg text-[11px] font-semibold border border-red-200 bg-red-50 hover:bg-red-100 text-red-600">Hapus</button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
                {dmConfigs.length === 0 && (
                  <tr><td colSpan={6} className="py-3 text-center text-slate-400">Memuat data outlet...</td></tr>
                )}
              </tbody>
            </table>
          </div>

          {editOutlet && (
            <div className="pt-2 border-t border-slate-100 max-w-[760px] space-y-3">
              <p className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">
                Atur Override: {dmConfigs.find((o) => o.outlet_id === editOutlet)?.outlet_name ?? editOutlet}
              </p>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div className="sm:col-span-2">
                  <label className={labelCls}>Base URL</label>
                  <input className={inputCls} value={dmForm.base_url ?? ''} placeholder="https://api.deepseek.com/v1" onChange={(e) => setDmForm({ ...dmForm, base_url: e.target.value })} />
                </div>
                <div className="sm:col-span-2">
                  <label className={labelCls}>API Key</label>
                  <input className={inputCls} type="password" value={dmForm.api_key ?? ''} placeholder="Kosongkan bila tidak diubah" onChange={(e) => setDmForm({ ...dmForm, api_key: e.target.value })} />
                </div>
                <div>
                  <label className={labelCls}>Model</label>
                  <input className={inputCls} value={dmForm.model ?? ''} placeholder="deepseek-chat" onChange={(e) => setDmForm({ ...dmForm, model: e.target.value })} />
                </div>
                <div>
                  <label className={labelCls}>Maks Token</label>
                  <input className={inputCls} type="number" value={dmForm.max_tokens ?? ''} onChange={(e) => setDmForm({ ...dmForm, max_tokens: Number(e.target.value) })} />
                </div>
              </div>
              <label className="flex items-center gap-2 text-xs font-semibold text-slate-600">
                <input type="checkbox" checked={!!dmForm.is_active} onChange={(e) => setDmForm({ ...dmForm, is_active: e.target.checked })} />
                Gunakan override ini untuk outlet tersebut
              </label>
              <label className="flex items-center gap-2 text-xs font-semibold text-slate-600">
                <input type="checkbox" checked={!!dmForm.unlimited_tokens} onChange={(e) => setDmForm({ ...dmForm, unlimited_tokens: e.target.checked })} />
                Unlimited token (lewati kuota; tetap dicatat)
              </label>
              {!dmForm.unlimited_tokens && (
                <div className="max-w-[240px]">
                  <label className={labelCls}>Kuota Token / Hari (kosong = global)</label>
                  <input className={inputCls} type="number" value={dmForm.token_quota ?? ''} placeholder="mis. 150000" onChange={(e) => setDmForm({ ...dmForm, token_quota: e.target.value })} />
                </div>
              )}
              <div className="flex flex-wrap gap-2">
                <button onClick={saveDm} disabled={dmBusy} className="flex items-center gap-2 px-4 py-2.5 rounded-xl font-semibold text-xs bg-gradient-to-r from-cyan-500 to-sky-600 hover:from-cyan-600 hover:to-sky-700 text-white shadow-md shadow-sky-500/25 transition active:scale-95">
                  {dmBusy ? <RefreshCw className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
                  Simpan Override
                </button>
                <button onClick={() => setEditOutlet('')} className="px-4 py-2.5 rounded-xl font-semibold text-xs border border-slate-200 bg-white hover:bg-slate-50 text-slate-700">Batal</button>
              </div>
            </div>
          )}
        </div>
      </Card>

      <Card title="Akun Kanal Sosial & Iklan" subtitle="Hubungkan akun Facebook/Instagram/TikTok/Shopee/Ads per outlet. Token akses disimpan terenkripsi di server dan tidak pernah ditampilkan kembali.">
        <div className="space-y-3">
          <div className="overflow-x-auto">
            <table className="w-full text-xs">
              <thead>
                <tr className="text-left text-slate-500 border-b border-slate-200">
                  <th className="py-2 pr-3 font-semibold">Outlet</th>
                  <th className="py-2 pr-3 font-semibold">Kanal</th>
                  <th className="py-2 pr-3 font-semibold">Akun</th>
                  <th className="py-2 pr-3 font-semibold">ID Eksternal</th>
                  <th className="py-2 pr-3 font-semibold">Token</th>
                  <th className="py-2 pr-3 font-semibold">Status</th>
                  <th className="py-2 font-semibold">Aksi</th>
                </tr>
              </thead>
              <tbody>
                {accounts.map((a) => (
                  <tr key={`${a.outlet_id}-${a.channel}`} className="border-b border-slate-100">
                    <td className="py-2 pr-3 text-slate-800">{a.outlet_name ?? a.outlet_id}</td>
                    <td className="py-2 pr-3 text-slate-600">{channelLabel(a.channel)}</td>
                    <td className="py-2 pr-3 text-slate-600">{a.account_name ?? '-'}</td>
                    <td className="py-2 pr-3 text-slate-500">{a.external_id ?? '-'}</td>
                    <td className="py-2 pr-3 text-slate-500">{a.has_token ? 'Tersimpan' : '-'}</td>
                    <td className="py-2 pr-3">
                      <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${a.is_connected ? 'bg-emerald-50 text-emerald-700 border border-emerald-200' : 'bg-slate-100 text-slate-500 border border-slate-200'}`}>
                        {a.is_connected ? 'Terhubung' : 'Terputus'}
                      </span>
                    </td>
                    <td className="py-2">
                      <button onClick={() => clearAccount(a.outlet_id, a.channel)} disabled={accBusy} className="px-2.5 py-1 rounded-lg text-[11px] font-semibold border border-red-200 bg-red-50 hover:bg-red-100 text-red-600">Hapus</button>
                    </td>
                  </tr>
                ))}
                {accounts.length === 0 && (
                  <tr><td colSpan={7} className="py-3 text-center text-slate-400">Belum ada akun kanal terhubung.</td></tr>
                )}
              </tbody>
            </table>
          </div>

          <div className="pt-2 border-t border-slate-100 max-w-[760px] space-y-3">
            <p className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">Hubungkan Akun Kanal</p>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label className={labelCls}>Outlet</label>
                <select className={inputCls} value={accOutlet} onChange={(e) => setAccOutlet(e.target.value)}>
                  {outlets.map((o) => <option key={o.outlet_id} value={o.outlet_id}>{o.outlet_name ?? o.outlet_id}</option>)}
                </select>
              </div>
              <div>
                <label className={labelCls}>Kanal</label>
                <select className={inputCls} value={accChannel} onChange={(e) => setAccChannel(e.target.value)}>
                  {DM_CHANNELS.map((c) => <option key={c.key} value={c.key}>{c.label}</option>)}
                </select>
              </div>
              <div>
                <label className={labelCls}>Nama Akun</label>
                <input className={inputCls} value={accName} placeholder="mis. Toko Test Official" onChange={(e) => setAccName(e.target.value)} />
              </div>
              <div>
                <label className={labelCls}>ID Eksternal</label>
                <input className={inputCls} value={accExternal} placeholder="Page ID / Ad Account ID" onChange={(e) => setAccExternal(e.target.value)} />
              </div>
              <div className="sm:col-span-2">
                <label className={labelCls}>Token Akses</label>
                <input className={inputCls} type="password" value={accToken} placeholder="Kosongkan bila tidak diubah" onChange={(e) => setAccToken(e.target.value)} />
                <p className="text-[11px] text-slate-400 mt-1">Token hanya disimpan di server (terenkripsi). Owner tidak dapat melihatnya.</p>
              </div>
            </div>
            <button onClick={saveAccount} disabled={accBusy} className="flex items-center gap-2 px-4 py-2.5 rounded-xl font-semibold text-xs bg-gradient-to-r from-cyan-500 to-sky-600 hover:from-cyan-600 hover:to-sky-700 text-white shadow-md shadow-sky-500/25 transition active:scale-95">
              {accBusy ? <RefreshCw className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
              Simpan Akun Kanal
            </button>
          </div>
        </div>
      </Card>
    </div>
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
          {activeId === 'doctor' && <DoctorTab />}
          {activeId === 'squad_dm' && <SquadDmTab />}
          {activeId === 'report' && <StructuredConfigTab configKey="report" title="Laporan Otomatis" subtitle="Template, jadwal default, kanal, batas penerima, dan visibilitas laporan finansial." fields={[
            { key: 'default_period', label: 'Periode Default', type: 'text', options: ['daily', 'weekly', 'monthly'] },
            { key: 'default_time', label: 'Jam Default', type: 'text', placeholder: '21:00' },
            { key: 'max_recipients', label: 'Maks Penerima', type: 'number', hint: 'Jumlah maksimum penerima laporan.' },
            { key: 'channels', label: 'Kanal', type: 'list', placeholder: 'email, wa', hint: 'Pisahkan dengan koma.' },
            { key: 'show_ppob_report', label: 'Tampilkan Laporan PPOB', type: 'boolean', hint: 'Aktifkan untuk menampilkan kartu PPOB di Laporan Utama.' },
            { key: 'show_pg_report', label: 'Tampilkan Laporan Payment Gateway (QRIS)', type: 'boolean', hint: 'Aktifkan untuk menampilkan kartu PG/QRIS di Laporan Utama.' },
            { key: 'show_outlet_ppob', label: 'Tampilkan Stat PPOB/PG/B2B/Modal Usaha di Detail Outlet', type: 'boolean', hint: 'Aktifkan untuk menampilkan statistik fitur finansial di Laporan Outlet.' },
            { key: 'show_outlet_hist', label: 'Tampilkan Riwayat Transaksi PPOB/PG/B2B/Modal Usaha', type: 'boolean', hint: 'Aktifkan untuk menampilkan panel Riwayat Transaksi di Detail Outlet.' },
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
          {activeId === 'ppob' && <PpobTab />}
          {activeId === 'b2b' && <B2bTab />}
          {activeId === 'modal_usaha' && <ModalUsahaTab />}
          {activeId === 'affiliate' && <AffiliateTab />}
          {activeId === 'system' && <SystemIntegrationTab />}
          {activeId === 'override' && <OverrideTab />}
          {activeId === 'announcements' && <AnnouncementsTab />}
          {activeId === 'monitoring' && <MonitoringTab />}
          {activeId === 'admins' && <AdminsTab />}
          {activeId === 'audit' && <AuditTab />}
        </div>
      </div>
    </div>
  );
}