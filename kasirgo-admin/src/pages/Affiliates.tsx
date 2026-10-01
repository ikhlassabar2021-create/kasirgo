import { useEffect, useState } from 'react';
import { Search, Plus, Copy, ExternalLink, UserCheck, TrendingUp, DollarSign, Percent, Banknote, X, Loader2 } from 'lucide-react';
import {
  platformAffiliatesList,
  platformAffiliateUpsert,
  platformAffiliateDelete,
  platformAffiliateSetPayout,
  platformAffiliatePayoutRun,
  platformAffiliateSetStatus,
} from '../lib/adminApi';
import type { AffiliateRow } from '../lib/adminApi';

type Toast = { kind: 'ok' | 'err'; text: string } | null;

const fmtRp = (v: number) =>
  'Rp ' + Number(v ?? 0).toLocaleString('id-ID', { maximumFractionDigits: 0 });

const emptyForm = {
  id: null as string | null,
  name: '',
  email: '',
  phone: '',
  user_id: '',
  commission_percent: 10,
  referral_code: '',
  status: 'active',
};

export function AffiliatesPage() {
  const [rows, setRows] = useState<AffiliateRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [toast, setToast] = useState<Toast>(null);
  const [form, setForm] = useState<typeof emptyForm | null>(null);
  const [saving, setSaving] = useState(false);
  const [payoutFor, setPayoutFor] = useState<AffiliateRow | null>(null);
  const [running, setRunning] = useState(false);

  const flash = (kind: 'ok' | 'err', text: string) => {
    setToast({ kind, text });
    setTimeout(() => setToast(null), 3500);
  };

  const load = async (q?: string) => {
    setLoading(true);
    try {
      const res = await platformAffiliatesList(q?.trim() || null, 200, 0);
      setRows(res.rows ?? []);
    } catch (e: any) {
      flash('err', e.message);
      setRows([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); /* eslint-disable-next-line */ }, []);

  const totals = rows.reduce(
    (acc, r) => {
      acc.earned += Number(r.commission_total ?? 0);
      acc.unpaid += Number(r.unpaid_total ?? 0);
      acc.referrals += Number(r.referral_count ?? 0);
      if (r.status === 'active') acc.active += 1;
      if (r.status === 'pending') acc.pending += 1;
      return acc;
    },
    { earned: 0, unpaid: 0, referrals: 0, active: 0, pending: 0 },
  );
  const avgCommission = rows.length
    ? rows.reduce((s, r) => s + Number(r.commission_percent ?? 0), 0) / rows.length
    : 0;

  const save = async () => {
    if (!form) return;
    if (!form.name.trim()) return flash('err', 'Nama afiliasi wajib diisi.');
    setSaving(true);
    try {
      await platformAffiliateUpsert({
        id: form.id,
        name: form.name.trim(),
        email: form.email.trim() || null,
        phone: form.phone.trim() || null,
        user_id: form.user_id.trim() || null,
        commission_percent: Number(form.commission_percent) || 0,
        referral_code: form.referral_code.trim() || null,
        status: form.status,
      });
      flash('ok', form.id ? 'Afiliasi diperbarui.' : 'Afiliasi ditambahkan.');
      setForm(null);
      load(search);
    } catch (e: any) {
      flash('err', e.message);
    } finally {
      setSaving(false);
    }
  };

  const remove = async (a: AffiliateRow) => {
    if (!window.confirm(`Hapus afiliasi "${a.name}"?`)) return;
    try {
      await platformAffiliateDelete(a.id);
      flash('ok', 'Afiliasi dihapus.');
      load(search);
    } catch (e: any) {
      flash('err', e.message);
    }
  };

  const setStatus = async (a: AffiliateRow, status: string) => {
    try {
      await platformAffiliateSetStatus(a.id, status);
      flash('ok', status === 'active' ? `Afiliasi "${a.name}" disetujui.` : `Status "${a.name}" diubah ke ${status}.`);
      load(search);
    } catch (e: any) {
      flash('err', e.message);
    }
  };

  const runPayout = async (id?: string) => {
    setRunning(true);
    try {
      const res = await platformAffiliatePayoutRun(id ?? null);
      flash('ok', `Payout dijalankan: ${res.paid_affiliates} afiliasi, total ${fmtRp(res.total_amount)}.`);
      setPayoutFor(null);
      load(search);
    } catch (e: any) {
      flash('err', e.message);
    } finally {
      setRunning(false);
    }
  };

  return (
    <div className="p-3 sm:p-6 max-w-[1100px] mx-auto fade-in">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-6">
        <div>
          <h1 className="text-xl sm:text-2xl font-bold text-slate-900 mb-1">Program Afiliasi & Referral</h1>
          <p className="text-xs sm:text-sm text-slate-500">Kelola agen referral, komisi, jadwal payout, dan rekening bank.</p>
        </div>
        <div className="flex items-center gap-2 self-start sm:self-auto">
          <button
            onClick={() => runPayout()}
            disabled={running}
            className="border border-slate-200 bg-white text-slate-700 px-4 py-2.5 rounded-xl font-semibold text-xs sm:text-sm flex items-center gap-2 hover:bg-slate-50 active:scale-95 transition disabled:opacity-60"
          >
            {running ? <Loader2 className="w-4 h-4 animate-spin" /> : <Banknote className="w-4 h-4" />}
            Jalankan Payout
          </button>
          <button
            onClick={() => setForm({ ...emptyForm })}
            className="bg-gradient-to-r from-cyan-500 to-sky-600 hover:from-cyan-600 hover:to-sky-700 text-white px-4 py-2.5 sm:px-5 sm:py-3 rounded-xl font-semibold text-xs sm:text-sm flex items-center justify-center gap-2 shadow-md shadow-sky-500/25 active:scale-95 transition"
          >
            <Plus className="w-4 h-4" />
            Tambah Afiliasi
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4 mb-6">
        {[
          { label: 'Total Afiliasi', value: rows.length, icon: UserCheck, color: 'blue' },
          { label: 'Afiliasi Aktif', value: totals.active, icon: TrendingUp, color: 'green' },
          { label: 'Menunggu Persetujuan', value: totals.pending, icon: Percent, color: 'orange' },
          { label: 'Komisi Terkumpul', value: fmtRp(totals.earned), icon: DollarSign, color: 'purple' },
          { label: 'Rata-rata Komisi', value: `${avgCommission.toFixed(1)}%`, icon: Percent, color: 'orange' },
        ].map((stat, index) => {
          const Icon = stat.icon;
          return (
            <div key={index} className="bg-white rounded-2xl p-4 sm:p-6 card-shadow border border-slate-200/80">
              <div className="flex items-center justify-between mb-2">
                <Icon className={`w-5 h-5 sm:w-6 sm:h-6 ${getStatColor(stat.color)}`} />
              </div>
              <p className="text-xs text-slate-500">{stat.label}</p>
              <p className="metric-number text-2xl sm:text-3xl font-black text-slate-900">{stat.value}</p>
            </div>
          );
        })}
      </div>

      <div className="bg-white rounded-2xl p-4 sm:p-6 card-shadow border border-slate-200/80 mb-6">
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3 sm:gap-4">
          <div className="relative flex-1">
            <Search className="absolute left-4 top-1/2 transform -translate-y-1/2 w-5 h-5 text-slate-400" />
            <input
              type="text"
              placeholder="Cari afiliasi atau kode referral..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && load(search)}
              className="w-full pl-12 pr-4 py-2.5 sm:py-3 text-sm bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-sky-500 outline-none"
            />
          </div>
          <button
            onClick={() => load(search)}
            className="px-4 py-2.5 sm:py-3 text-sm font-semibold rounded-xl bg-slate-100 text-slate-700 hover:bg-slate-200"
          >
            Cari
          </button>
        </div>
      </div>

      <div className="bg-white rounded-2xl card-shadow border border-slate-200/80 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[760px]">
            <thead className="bg-slate-50 border-b border-slate-100">
              <tr>
                <th className="text-left px-4 sm:px-6 py-3.5 text-xs font-semibold text-slate-600 uppercase">Afiliasi</th>
                <th className="text-left px-4 sm:px-6 py-3.5 text-xs font-semibold text-slate-600 uppercase">Kode</th>
                <th className="text-right px-4 sm:px-6 py-3.5 text-xs font-semibold text-slate-600 uppercase">Referral</th>
                <th className="text-right px-4 sm:px-6 py-3.5 text-xs font-semibold text-slate-600 uppercase">Komisi</th>
                <th className="text-left px-4 sm:px-6 py-3.5 text-xs font-semibold text-slate-600 uppercase">Status</th>
                <th className="text-right px-4 sm:px-6 py-3.5 text-xs font-semibold text-slate-600 uppercase">Aksi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {loading && (
                <tr><td colSpan={6} className="px-6 py-8 text-center text-sm text-slate-400">Memuat...</td></tr>
              )}
              {!loading && rows.length === 0 && (
                <tr><td colSpan={6} className="px-6 py-8 text-center text-sm text-slate-400">Belum ada afiliasi.</td></tr>
              )}
              {!loading && rows.map((a) => (
                <tr key={a.id} className="hover:bg-slate-50">
                  <td className="px-4 sm:px-6 py-4">
                    <div>
                      <p className="font-medium text-sm text-slate-900">{a.name}</p>
                      <p className="text-xs text-slate-400">{a.email || a.phone || '-'}</p>
                    </div>
                  </td>
                  <td className="px-4 sm:px-6 py-4">
                    <span className="font-mono text-xs text-sky-600 bg-sky-50 px-2 py-1 rounded font-bold">{a.referral_code}</span>
                  </td>
                  <td className="px-4 sm:px-6 py-4 text-right text-xs sm:text-sm font-semibold text-slate-700">{a.referral_count}</td>
                  <td className="px-4 sm:px-6 py-4 text-right">
                    <p className="text-xs sm:text-sm font-bold text-emerald-600">{fmtRp(a.commission_total)}</p>
                    {Number(a.unpaid_total) > 0 && (
                      <p className="text-[10px] text-amber-600">Belum cair {fmtRp(a.unpaid_total)}</p>
                    )}
                    <p className="text-[10px] text-slate-400">{a.commission_percent}%</p>
                  </td>
                  <td className="px-4 sm:px-6 py-4">
                    <span className={`inline-flex px-2.5 py-1 rounded-full text-xs font-semibold ${
                      a.status === 'active' ? 'bg-emerald-50 text-emerald-600' :
                      a.status === 'pending' ? 'bg-amber-50 text-amber-600' :
                      'bg-rose-50 text-rose-600'
                    }`}>
                      {a.status}
                    </span>
                  </td>
                  <td className="px-4 sm:px-6 py-4 text-right">
                    <div className="flex items-center justify-end gap-1 sm:gap-2">
                      {a.status === 'pending' && (
                        <button
                          onClick={() => setStatus(a, 'active')}
                          className="px-2 py-1 rounded-lg bg-emerald-50 text-emerald-700 text-[10px] font-bold hover:bg-emerald-100"
                          title="Setujui pendaftaran"
                        >
                          Setujui
                        </button>
                      )}
                      {a.status === 'active' && (
                        <button
                          onClick={() => setStatus(a, 'suspended')}
                          className="px-2 py-1 rounded-lg bg-amber-50 text-amber-700 text-[10px] font-bold hover:bg-amber-100"
                          title="Tangguhkan"
                        >
                          Tangguhkan
                        </button>
                      )}
                      <button
                        onClick={() => { navigator.clipboard?.writeText(a.referral_code); flash('ok', `Kode ${a.referral_code} disalin.`); }}
                        className="p-1.5 sm:p-2 hover:bg-slate-100 rounded-lg transition-colors text-slate-600"
                        title="Salin Kode"
                      >
                        <Copy className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => setPayoutFor(a)}
                        className="p-1.5 sm:p-2 hover:bg-slate-100 rounded-lg transition-colors text-emerald-600"
                        title="Jadwal Payout & Rekening"
                      >
                        <Banknote className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => setForm({
                          id: a.id, name: a.name, email: a.email ?? '', phone: a.phone ?? '',
                          user_id: a.user_id ?? '', commission_percent: a.commission_percent,
                          referral_code: a.referral_code, status: a.status,
                        })}
                        className="p-1.5 sm:p-2 hover:bg-slate-100 rounded-lg transition-colors text-sky-600"
                        title="Edit"
                      >
                        <ExternalLink className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => remove(a)}
                        className="p-1.5 sm:p-2 hover:bg-rose-50 rounded-lg transition-colors text-rose-600"
                        title="Hapus"
                      >
                        <X className="w-4 h-4" />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {form && (
        <Modal title={form.id ? 'Edit Afiliasi' : 'Tambah Afiliasi'} onClose={() => setForm(null)}>
          <div className="space-y-3.5">
            <Field label="Nama">
              <input className={inputCls} value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
            </Field>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <Field label="Email">
                <input className={inputCls} value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} />
              </Field>
              <Field label="No. HP / WA">
                <input className={inputCls} value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} placeholder="628..." />
              </Field>
            </div>
            <Field label="User ID (opsional, untuk portal affiliate)">
              <input className={inputCls} value={form.user_id} onChange={(e) => setForm({ ...form, user_id: e.target.value })} placeholder="uuid auth.users" />
            </Field>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <Field label="Komisi (%)">
                <input type="number" step="0.1" className={inputCls} value={form.commission_percent} onChange={(e) => setForm({ ...form, commission_percent: Number(e.target.value) })} />
              </Field>
              <Field label="Kode Referral">
                <input className={inputCls} value={form.referral_code} onChange={(e) => setForm({ ...form, referral_code: e.target.value })} placeholder="otomatis bila kosong" />
              </Field>
            </div>
            <Field label="Status">
              <select className={inputCls} value={form.status} onChange={(e) => setForm({ ...form, status: e.target.value })}>
                <option value="active">Active</option>
                <option value="pending">Pending</option>
                <option value="suspended">Suspended</option>
              </select>
            </Field>
            <div className="flex justify-end gap-2 pt-1">
              <button onClick={() => setForm(null)} className="px-4 py-2.5 rounded-xl text-sm font-semibold text-slate-600 hover:bg-slate-100">Batal</button>
              <button onClick={save} disabled={saving}
                className="px-5 py-2.5 rounded-xl text-sm font-semibold bg-gradient-to-r from-cyan-500 to-sky-600 text-white shadow-md shadow-sky-500/25 disabled:opacity-60 flex items-center gap-2">
                {saving && <Loader2 className="w-4 h-4 animate-spin" />}
                Simpan
              </button>
            </div>
          </div>
        </Modal>
      )}

      {payoutFor && (
        <PayoutModal
          affiliate={payoutFor}
          running={running}
          onClose={() => setPayoutFor(null)}
          onSave={async (payload) => {
            setSaving(true);
            try {
              await platformAffiliateSetPayout({ id: payoutFor.id, ...payload });
              flash('ok', 'Jadwal payout & rekening disimpan.');
              setPayoutFor(null);
              load(search);
            } catch (e: any) {
              flash('err', e.message);
            } finally {
              setSaving(false);
            }
          }}
          onRun={() => runPayout(payoutFor.id)}
          saving={saving}
        />
      )}

      {toast && (
        <div className={`fixed bottom-5 right-5 z-50 px-4 py-3 rounded-xl text-xs font-semibold shadow-lg ${
          toast.kind === 'ok' ? 'bg-emerald-600 text-white' : 'bg-rose-600 text-white'
        }`}>
          {toast.text}
        </div>
      )}
    </div>
  );
}

function PayoutModal({
  affiliate, onClose, onSave, onRun, running, saving,
}: {
  affiliate: AffiliateRow
  onClose: () => void
  onSave: (p: { frequency: string; weekday: number | null; dayOfMonth: number | null; mode: string; minPayout: number; bankName: string; bankAccountName: string; bankAccountNumber: string }) => void
  onRun: () => void
  running: boolean
  saving: boolean
}) {
  const [frequency, setFrequency] = useState(affiliate.payout_frequency ?? 'monthly');
  const [weekday, setWeekday] = useState<number | null>(affiliate.payout_weekday ?? 1);
  const [dayOfMonth, setDayOfMonth] = useState<number | null>(affiliate.payout_day_of_month ?? 1);
  const [mode, setMode] = useState(affiliate.payout_mode ?? 'manual');
  const [minPayout, setMinPayout] = useState(affiliate.min_payout ?? 0);
  const [bankName, setBankName] = useState(affiliate.bank_name ?? '');
  const [bankAccountName, setBankAccountName] = useState(affiliate.bank_account_name ?? '');
  const [bankAccountNumber, setBankAccountNumber] = useState(affiliate.bank_account_number ?? '');

  return (
    <Modal title={`Payout - ${affiliate.name}`} onClose={onClose}>
      <div className="space-y-3.5">
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <Field label="Frekuensi">
            <select className={inputCls} value={frequency} onChange={(e) => setFrequency(e.target.value)}>
              <option value="weekly">Mingguan</option>
              <option value="monthly">Bulanan</option>
            </select>
          </Field>
          <Field label="Mode">
            <select className={inputCls} value={mode} onChange={(e) => setMode(e.target.value)}>
              <option value="auto">Otomatis</option>
              <option value="manual">Manual</option>
            </select>
          </Field>
        </div>
        {frequency === 'weekly' ? (
          <Field label="Hari (1=Senin ... 7=Minggu)">
            <input type="number" min={1} max={7} className={inputCls} value={weekday ?? 1} onChange={(e) => setWeekday(Number(e.target.value))} />
          </Field>
        ) : (
          <Field label="Tanggal (1-28)">
            <input type="number" min={1} max={28} className={inputCls} value={dayOfMonth ?? 1} onChange={(e) => setDayOfMonth(Number(e.target.value))} />
          </Field>
        )}
        <Field label="Minimum Payout (Rp)">
          <input type="number" step="1000" className={inputCls} value={minPayout} onChange={(e) => setMinPayout(Number(e.target.value))} />
        </Field>
        <div className="pt-1 border-t border-slate-100" />
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <Field label="Nama Bank">
            <input className={inputCls} value={bankName} onChange={(e) => setBankName(e.target.value)} placeholder="BCA / BRI / Mandiri" />
          </Field>
          <Field label="Nama Pemilik Rekening">
            <input className={inputCls} value={bankAccountName} onChange={(e) => setBankAccountName(e.target.value)} />
          </Field>
        </div>
        <Field label="Nomor Rekening">
          <input className={inputCls} value={bankAccountNumber} onChange={(e) => setBankAccountNumber(e.target.value)} />
        </Field>
        <div className="flex flex-wrap justify-end gap-2 pt-1">
          <button onClick={onRun} disabled={running}
            className="px-4 py-2.5 rounded-xl text-sm font-semibold border border-emerald-200 text-emerald-700 hover:bg-emerald-50 disabled:opacity-60 flex items-center gap-2">
            {running ? <Loader2 className="w-4 h-4 animate-spin" /> : <Banknote className="w-4 h-4" />}
            Payout Sekarang
          </button>
          <button onClick={() => onSave({ frequency, weekday, dayOfMonth, mode, minPayout, bankName, bankAccountName, bankAccountNumber })} disabled={saving}
            className="px-5 py-2.5 rounded-xl text-sm font-semibold bg-gradient-to-r from-cyan-500 to-sky-600 text-white shadow-md shadow-sky-500/25 disabled:opacity-60 flex items-center gap-2">
            {saving && <Loader2 className="w-4 h-4 animate-spin" />}
            Simpan
          </button>
        </div>
      </div>
    </Modal>
  );
}

const inputCls =
  'w-full px-3.5 py-2.5 rounded-xl border border-slate-200 bg-slate-50/50 hover:bg-white focus:bg-white text-xs text-slate-800 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-sky-500/30 focus:border-sky-500 transition';
const labelCls = 'block text-[11px] font-bold text-slate-600 uppercase tracking-wider mb-1.5';

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <label className={labelCls}>{label}</label>
      {children}
    </div>
  );
}

function Modal({ title, children, onClose }: { title: string; children: React.ReactNode; onClose: () => void }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-sm" onClick={onClose}>
      <div className="bg-white rounded-2xl shadow-xl w-full max-w-lg max-h-[90vh] overflow-y-auto" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between px-5 py-4 border-b border-slate-100">
          <h3 className="font-bold text-slate-900 text-sm">{title}</h3>
          <button onClick={onClose} className="p-1.5 rounded-lg hover:bg-slate-100 text-slate-500">
            <X className="w-4 h-4" />
          </button>
        </div>
        <div className="p-5">{children}</div>
      </div>
    </div>
  );
}

function getStatColor(color: string) {
  const colors = {
    blue: 'text-sky-600',
    green: 'text-emerald-600',
    purple: 'text-indigo-600',
    orange: 'text-amber-500',
  };
  return colors[color as keyof typeof colors] || 'text-sky-600';
}
