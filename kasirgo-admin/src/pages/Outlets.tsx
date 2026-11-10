import { useCallback, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Search, Eye, RefreshCw, ChevronLeft, ChevronRight, Pencil, KeyRound, X } from 'lucide-react';
import {
  fmtRp, fmtDate, platformOutletsList, platformAccountEdit,
  platformAccountResetPassword, type OutletsListResult, type OutletRow,
} from '../lib/adminApi';

const PAGE_SIZE = 25;

export function OutletsPage() {
  const navigate = useNavigate();
  const [search, setSearch] = useState('');
  const [kyc, setKyc] = useState('verified');
  const [plan, setPlan] = useState('all');
  const [page, setPage] = useState(0);
  const [data, setData] = useState<OutletsListResult | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [modal, setModal] = useState<{ mode: 'edit' | 'reset'; outlet: OutletRow } | null>(null);
  const [msg, setMsg] = useState<{ type: 'ok' | 'err'; text: string } | null>(null);

  const flash = (type: 'ok' | 'err', text: string) => {
    setMsg({ type, text });
    setTimeout(() => setMsg(null), 3000);
  };

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setData(await platformOutletsList({
        p_search: search.trim() || null, p_kyc: kyc, p_plan: plan,
        p_limit: PAGE_SIZE, p_offset: page * PAGE_SIZE,
      }));
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Gagal memuat outlet');
    } finally {
      setLoading(false);
    }
  }, [search, kyc, plan, page]);

  useEffect(() => {
    const t = setTimeout(load, 300);
    return () => clearTimeout(t);
  }, [load]);

  const total = data?.total ?? 0;
  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));

  return (
    <div className="p-3 sm:p-6 max-w-[1100px] mx-auto fade-in">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-6">
        <div>
          <h1 className="text-xl sm:text-2xl font-bold text-ink mb-1">Outlet Terdaftar</h1>
          <p className="text-xs sm:text-sm text-muted">Default hanya outlet KYC terverifikasi &bull; kelola paket, fitur, staf</p>
        </div>
        <button
          onClick={load}
          className="flex items-center gap-2 border border-border bg-surface px-4 py-2.5 rounded-xl text-xs font-semibold text-muted hover:bg-bg transition"
        >
          <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} /> Refresh
        </button>
      </div>

      <div className="bg-surface rounded-2xl p-4 sm:p-6 card-shadow border border-border/80 mb-6">
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3 sm:gap-4">
          <div className="relative flex-1">
            <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-muted" />
            <input
              type="text"
              value={search}
              onChange={(e) => { setSearch(e.target.value); setPage(0); }}
              placeholder="Cari outlet, nama pemilik, atau email..."
              className="w-full pl-12 pr-4 py-2.5 sm:py-3 text-sm bg-bg border border-border rounded-xl focus:ring-2 focus:ring-primary outline-none"
            />
          </div>
          <select
            value={kyc}
            onChange={(e) => { setKyc(e.target.value); setPage(0); }}
            className="border border-border rounded-xl px-4 py-2.5 sm:py-3 text-sm bg-surface text-gray-700"
          >
            <option value="verified">KYC Terverifikasi</option>
            <option value="pending">KYC Pending</option>
            <option value="rejected">KYC Ditolak</option>
            <option value="all">Semua KYC</option>
          </select>
          <select
            value={plan}
            onChange={(e) => { setPlan(e.target.value); setPage(0); }}
            className="border border-border rounded-xl px-4 py-2.5 sm:py-3 text-sm bg-surface text-gray-700"
          >
            <option value="all">Semua Paket</option>
            <option value="supporter">Pendukung</option>
            <option value="trial">Trial</option>
            <option value="free">Gratis</option>
          </select>
        </div>
      </div>

      {error && (
        <div className="bg-danger/10 border border-danger/30 rounded-2xl p-4 text-danger text-sm mb-6">{error}</div>
      )}

      <div className="bg-surface rounded-2xl card-shadow border border-border/80 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[760px]">
            <thead className="bg-bg border-b border-border/80">
              <tr>
                <th className="text-left px-4 sm:px-6 py-3.5 text-xs font-semibold text-muted uppercase tracking-wide">Outlet</th>
                <th className="text-left px-4 sm:px-6 py-3.5 text-xs font-semibold text-muted uppercase tracking-wide">Pemilik</th>
                <th className="text-left px-4 sm:px-6 py-3.5 text-xs font-semibold text-muted uppercase tracking-wide">Paket</th>
                <th className="text-left px-4 sm:px-6 py-3.5 text-xs font-semibold text-muted uppercase tracking-wide">Staf</th>
                <th className="text-left px-4 sm:px-6 py-3.5 text-xs font-semibold text-muted uppercase tracking-wide">Omzet</th>
                <th className="text-left px-4 sm:px-6 py-3.5 text-xs font-semibold text-muted uppercase tracking-wide">KYC</th>
                <th className="text-right px-4 sm:px-6 py-3.5 text-xs font-semibold text-muted uppercase tracking-wide">Aksi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {loading && (
                <tr><td colSpan={7} className="px-6 py-10 text-center text-xs text-muted">Memuat...</td></tr>
              )}
              {!loading && !data?.rows.length && (
                <tr><td colSpan={7} className="px-6 py-10 text-center text-xs text-muted">Tidak ada outlet cocok.</td></tr>
              )}
              {!loading && data?.rows.map((o) => (
                <tr key={o.outlet_id} className="hover:bg-bg/70 transition">
                  <td className="px-4 sm:px-6 py-3.5">
                    <p className="text-xs font-bold text-ink">{o.outlet_name ?? '(tanpa nama)'}</p>
                    <p className="text-[10px] text-muted capitalize">{o.outlet_type ?? '-'} &bull; daftar {fmtDate(o.created_at)}</p>
                  </td>
                  <td className="px-4 sm:px-6 py-3.5">
                    <p className="text-xs font-semibold text-ink">{o.owner_name || '-'}</p>
                    <p className="text-[10px] text-muted">{o.email}</p>
                  </td>
                  <td className="px-4 sm:px-6 py-3.5">
                    <span className={`px-2 py-0.5 rounded-full text-[9px] font-bold border ${
                      o.is_supporter ? 'bg-success/10 text-success border-success/30'
                        : o.on_trial ? 'bg-warning/10 text-warning border-warning/30'
                        : 'bg-bg text-muted border-border'
                    }`}>
                      {o.is_supporter ? 'PENDUKUNG' : o.on_trial ? 'TRIAL' : 'GRATIS'}
                    </span>
                  </td>
                  <td className="px-4 sm:px-6 py-3.5 text-xs font-semibold text-ink">{o.staff_count}</td>
                  <td className="px-4 sm:px-6 py-3.5 text-xs font-semibold text-ink">{fmtRp(o.omzet_total)}</td>
                  <td className="px-4 sm:px-6 py-3.5">
                    <span className={`px-2 py-0.5 rounded-full text-[9px] font-bold border ${
                      o.kyc_status === 'verified' ? 'bg-success/10 text-success border-success/30'
                        : o.kyc_status === 'rejected' ? 'bg-danger/10 text-danger border-danger/30'
                        : 'bg-warning/10 text-warning border-warning/30'
                    }`}>
                      {o.kyc_status === 'verified' ? 'TERVERIFIKASI' : o.kyc_status === 'rejected' ? 'DITOLAK' : 'PENDING'}
                    </span>
                  </td>
                  <td className="px-4 sm:px-6 py-3.5">
                    <div className="flex justify-end gap-1">
                      <button
                        onClick={() => navigate(`/outlets/${o.outlet_id}`)}
                        className="p-2 hover:bg-bg rounded-lg transition-colors text-primary"
                        title="Kelola Outlet"
                      >
                        <Eye className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => setModal({ mode: 'edit', outlet: o })}
                        className="p-2 hover:bg-bg rounded-lg transition-colors text-muted hover:text-primary"
                        title="Edit Akun"
                      >
                        <Pencil className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => setModal({ mode: 'reset', outlet: o })}
                        className="p-2 hover:bg-bg rounded-lg transition-colors text-muted hover:text-amber-600"
                        title="Reset Password"
                      >
                        <KeyRound className="w-4 h-4" />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div className="flex items-center justify-between border-t border-border px-4 sm:px-6 py-3">
          <p className="text-[11px] text-muted">
            Total {total} outlet &bull; halaman {page + 1} dari {totalPages}
          </p>
          <div className="flex gap-2">
            <button
              disabled={page === 0}
              onClick={() => setPage((p) => Math.max(0, p - 1))}
              className="p-2 rounded-lg border border-border disabled:opacity-40 hover:bg-bg"
            >
              <ChevronLeft className="w-4 h-4" />
            </button>
            <button
              disabled={page + 1 >= totalPages}
              onClick={() => setPage((p) => p + 1)}
              className="p-2 rounded-lg border border-border disabled:opacity-40 hover:bg-bg"
            >
              <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>

      {msg && (
        <div className={`fixed bottom-5 right-5 z-[60] px-4 py-2.5 rounded-xl text-xs font-semibold shadow-lg ${
          msg.type === 'ok' ? 'bg-success text-white' : 'bg-red-500 text-white'
        }`}>{msg.text}</div>
      )}

      {modal && (
        <AccountModal
          mode={modal.mode}
          outlet={modal.outlet}
          onClose={() => setModal(null)}
          onDone={(type, text) => {
            flash(type, text);
            setModal(null);
            load();
          }}
        />
      )}
    </div>
  );
}

type AccountModalProps = {
  mode: 'edit' | 'reset';
  outlet: OutletRow;
  onClose: () => void;
  onDone: (type: 'ok' | 'err', text: string) => void;
};

function AccountModal({ mode, outlet, onClose, onDone }: AccountModalProps) {
  const [busy, setBusy] = useState(false);
  const [name, setName] = useState(outlet.owner_name || '');
  const [email, setEmail] = useState(outlet.email || '');
  const [outletName, setOutletName] = useState(outlet.outlet_name || '');
  const [phone, setPhone] = useState(outlet.phone || '');
  const [password, setPassword] = useState('');

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (busy) return;
    setBusy(true);
    try {
      if (mode === 'reset') {
        if (password.length < 6) throw new Error('Password minimal 6 karakter');
        await platformAccountResetPassword(outlet.outlet_id, password);
        onDone('ok', `Password ${outlet.email} berhasil direset`);
      } else {
        await platformAccountEdit({
          outletId: outlet.outlet_id,
          name: name.trim() || null,
          email: email.trim() || null,
          outletName: outletName.trim() || null,
          phone: phone.trim() || null,
        });
        onDone('ok', 'Data akun diperbarui');
      }
    } catch (err) {
      onDone('err', err instanceof Error ? err.message : 'Aksi gagal');
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4" onClick={onClose}>
      <div
        className="bg-surface w-full max-w-md rounded-2xl border border-border shadow-xl p-5"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start justify-between mb-4">
          <div>
            <h2 className="text-sm font-bold text-ink">
              {mode === 'edit' ? 'Edit Akun' : 'Reset Password'}
            </h2>
            <p className="text-[11px] text-muted mt-0.5">{outlet.email}</p>
          </div>
          <button onClick={onClose} className="p-1.5 rounded-lg hover:bg-bg text-muted">
            <X className="w-4 h-4" />
          </button>
        </div>

        {mode === 'edit' ? (
          <form onSubmit={submit} className="space-y-3">
            <Field label="Nama Pemilik">
              <input value={name} onChange={(e) => setName(e.target.value)} className={inputCls} placeholder="Nama pemilik" />
            </Field>
            <Field label="Email">
              <input value={email} onChange={(e) => setEmail(e.target.value)} className={inputCls} type="email" placeholder="email@contoh.com" />
            </Field>
            <Field label="Nama Outlet">
              <input value={outletName} onChange={(e) => setOutletName(e.target.value)} className={inputCls} placeholder="Nama toko" />
            </Field>
            <Field label="Telepon">
              <input value={phone} onChange={(e) => setPhone(e.target.value)} className={inputCls} placeholder="08xx..." />
            </Field>
            <button
              disabled={busy}
              className="w-full py-2.5 rounded-xl bg-primary hover:bg-primary-light text-white text-xs font-bold disabled:opacity-50"
            >
              {busy ? 'Menyimpan...' : 'Simpan Perubahan'}
            </button>
          </form>
        ) : (
          <form onSubmit={submit} className="space-y-3">
            <Field label="Password Baru">
              <input
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className={inputCls}
                type="text"
                placeholder="Minimal 6 karakter"
              />
            </Field>
            <p className="text-[11px] text-muted">
              Pemilik akan login dengan email tetap <b className="text-ink">{outlet.email}</b> dan password baru ini.
            </p>
            <button
              disabled={busy}
              className="w-full py-2.5 rounded-xl bg-amber-500 hover:bg-amber-600 text-white text-xs font-bold disabled:opacity-50"
            >
              {busy ? 'Memproses...' : 'Reset Password'}
            </button>
          </form>
        )}
      </div>
    </div>
  );
}

const inputCls = 'w-full px-3 py-2.5 text-sm bg-bg border border-border rounded-xl focus:ring-2 focus:ring-primary outline-none';

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="block">
      <span className="block text-[11px] font-semibold text-muted mb-1">{label}</span>
      {children}
    </label>
  );
}