import { useCallback, useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import {
  ArrowLeft, RefreshCw, ShieldCheck, ShieldX, Clock, Trash2, UserMinus,
  AlertTriangle, Download, Upload,
} from 'lucide-react';
import {
  fmtRp, fmtDate, rp,
  platformOutletsList, platformSetVerification, platformSetPlan,
  platformOutletStaff, platformOutletRemoveStaff, platformOutletDeleteAccount,
  platformOutletReport, type OutletRow, type OutletStaffRow, type OutletReportResult,
} from '../lib/adminApi';
import { FeatureToggleList } from '../components/FeatureToggleList';

type Period = 1 | 7 | 30 | 90;

export function OutletDetailPage() {
  const { id = '' } = useParams();
  const [outlet, setOutlet] = useState<OutletRow | null>(null);
  const [staff, setStaff] = useState<OutletStaffRow[]>([]);
  const [report, setReport] = useState<OutletReportResult | null>(null);
  const [period, setPeriod] = useState<Period>(30);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ type: 'ok' | 'err'; text: string } | null>(null);

  const flash = (type: 'ok' | 'err', text: string) => {
    setMsg({ type, text });
    setTimeout(() => setMsg(null), 3000);
  };

  const loadInfo = useCallback(async () => {
    setLoading(true);
    try {
      const res = await platformOutletsList({ p_search: null, p_kyc: 'all', p_plan: 'all', p_limit: 100, p_offset: 0 });
      setOutlet(res.rows.find((r) => r.outlet_id === id) ?? null);
      const st = await platformOutletStaff(id);
      setStaff(st.rows ?? []);
    } catch (e) {
      flash('err', e instanceof Error ? e.message : 'Gagal memuat outlet');
    } finally {
      setLoading(false);
    }
  }, [id]);

  const loadReport = useCallback(async (p: Period) => {
    try {
      const end = new Date();
      const start = new Date(end.getTime() - p * 24 * 3600 * 1000);
      setReport(await platformOutletReport(id, start.toISOString(), end.toISOString()));
    } catch (e) {
      flash('err', e instanceof Error ? e.message : 'Gagal memuat laporan');
    }
  }, [id]);

  useEffect(() => { loadInfo(); }, [loadInfo]);
  useEffect(() => { loadReport(period); }, [loadReport, period]);

  const act = async (fn: () => Promise<void>, okText: string) => {
    setBusy(true);
    try {
      await fn();
      flash('ok', okText);
      await loadInfo();
    } catch (e) {
      flash('err', e instanceof Error ? e.message : 'Aksi gagal');
    } finally {
      setBusy(false);
    }
  };

  const currentPlan = outlet?.is_supporter ? 'pendukung' : outlet?.on_trial ? 'trial' : 'free';

  if (loading) {
    return <div className="p-10 text-center text-sm text-slate-400">Memuat data outlet...</div>;
  }
  if (!outlet) {
    return (
      <div className="p-10 text-center">
        <p className="text-sm text-slate-500 mb-3">Outlet tidak ditemukan.</p>
        <Link to="/outlets" className="text-xs font-bold text-sky-700 hover:underline">Kembali ke Outlet Terdaftar</Link>
      </div>
    );
  }

  return (
    <div className="space-y-4 max-w-[1100px] mx-auto fade-in">
      {msg && (
        <div className={`fixed bottom-5 right-5 z-50 px-4 py-2.5 rounded-xl text-xs font-semibold shadow-lg ${
          msg.type === 'ok' ? 'bg-emerald-500 text-white' : 'bg-red-500 text-white'
        }`}>{msg.text}</div>
      )}

      <div className="bg-white p-4 sm:p-5 rounded-2xl border border-slate-200/80 shadow-sm flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <Link to="/outlets" className="p-2 rounded-lg hover:bg-slate-100 text-slate-500">
            <ArrowLeft className="w-4 h-4" />
          </Link>
          <div>
            <h1 className="text-base sm:text-lg font-bold text-slate-900 tracking-tight">{outlet.outlet_name ?? '(tanpa nama)'}</h1>
            <p className="text-slate-500 text-xs mt-0.5 capitalize">
              {outlet.outlet_type ?? '-'} &bull; {outlet.owner_name || '-'} &bull; {outlet.email}
            </p>
          </div>
        </div>
        <button
          onClick={() => { loadInfo(); loadReport(period); }}
          className="flex items-center gap-2 px-3 py-2 rounded-xl border border-slate-200 text-xs font-semibold text-slate-600 hover:bg-slate-50 transition"
        >
          <RefreshCw className="w-4 h-4" /> Refresh
        </button>
      </div>

      {/* Verifikasi & Paket */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <Card title="Verifikasi KYC" subtitle="Putuskan status verifikasi outlet secara manual">
          <div className="flex items-center gap-2 mb-4">
            <Badge
              tone={outlet.kyc_status === 'verified' ? 'ok' : outlet.kyc_status === 'rejected' ? 'bad' : 'warn'}
              label={outlet.kyc_status === 'verified' ? 'Terverifikasi' : outlet.kyc_status === 'rejected' ? 'Ditolak' : 'Pending'}
            />
            {outlet.auto_verified && <span className="text-[10px] text-slate-400">auto-verify</span>}
          </div>
          {outlet.reject_reason && (
            <p className="text-[11px] text-rose-600 mb-3">Alasan: {outlet.reject_reason}</p>
          )}
          <div className="flex flex-wrap gap-2">
            <button
              disabled={busy}
              onClick={() => act(() => platformSetVerification(id, 'verified'), 'Outlet diverifikasi')}
              className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-emerald-500 hover:bg-emerald-600 text-white text-xs font-bold disabled:opacity-50"
            >
              <ShieldCheck className="w-4 h-4" /> Verifikasi
            </button>
            <button
              disabled={busy}
              onClick={() => {
                const reason = window.prompt('Alasan penolakan (opsional):') ?? '';
                act(() => platformSetVerification(id, 'rejected', reason || null), 'Outlet ditolak');
              }}
              className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-rose-50 text-rose-600 border border-rose-200 hover:bg-rose-100 text-xs font-bold disabled:opacity-50"
            >
              <ShieldX className="w-4 h-4" /> Tolak
            </button>
            <button
              disabled={busy}
              onClick={() => act(() => platformSetVerification(id, 'pending_review'), 'Status diubah ke pending')}
              className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-amber-50 text-amber-700 border border-amber-200 hover:bg-amber-100 text-xs font-bold disabled:opacity-50"
            >
              <Clock className="w-4 h-4" /> Pending
            </button>
          </div>
        </Card>

        <Card title="Paket Langganan" subtitle="Default otomatis: Gratis, atau Trial/Pendukung">
          <div className="flex gap-2 mb-4">
            {(['free', 'trial', 'pendukung'] as const).map((p) => (
              <button
                key={p}
                disabled={busy}
                onClick={() => act(() => platformSetPlan(id, p), `Paket diubah ke ${p}`)}
                className={`flex-1 px-3 py-2.5 rounded-xl text-xs font-bold border transition ${
                  currentPlan === p
                    ? 'bg-sky-600 text-white border-sky-600'
                    : 'bg-white text-slate-600 border-slate-200 hover:bg-slate-50'
                }`}
              >
                {p === 'free' ? 'Gratis' : p === 'trial' ? 'Trial' : 'Pendukung'}
              </button>
            ))}
          </div>
          <p className="text-[11px] text-slate-500">
            Pendukung Rp50.000/bulan &bull; aktif: {fmtDate(outlet.trial_ends_at)}
          </p>
        </Card>
      </div>

      {/* Fitur Utama */}
      <Card title="Fitur Utama (per outlet)" subtitle="Nyalakan/matikan modul khusus outlet ini">
        <FeatureToggleList outletId={id} />
      </Card>

      {/* Laporan per outlet */}
      <Card
        title="Laporan Outlet"
        subtitle="Omset & untung dari POS, PPOB, Payment Gateway, B2B, asuransi, modal usaha"
        action={
          <div className="flex gap-1 bg-slate-100 rounded-xl p-1">
            {([1, 7, 30, 90] as Period[]).map((p) => (
              <button
                key={p}
                onClick={() => setPeriod(p)}
                className={`px-2.5 py-1.5 rounded-lg text-[11px] font-bold transition ${
                  period === p ? 'bg-white text-sky-700 shadow-sm' : 'text-slate-500'
                }`}
              >
                {p}h
              </button>
            ))}
          </div>
        }
      >
        {!report ? (
          <p className="text-xs text-slate-400 py-4 text-center">Memuat laporan...</p>
        ) : (
          <>
            <div className="grid grid-cols-3 gap-3 mb-4">
              <Stat label="Omset Total" value={fmtRp(report.omzet_total)} tone="text-sky-700" />
              <Stat label="Untung Platform" value={fmtRp(report.untung_total)} tone="text-emerald-600" />
              <Stat label="Jumlah Transaksi" value={String(report.count_total)} tone="text-slate-700" />
            </div>
            <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
              <Stat label="POS Omzet" value={fmtRp(report.pos.omzet)} tone="text-slate-700" />
              <Stat label="POS Transaksi" value={String(report.pos.count)} tone="text-slate-500" />
              <Stat label="PPOB Omzet" value={fmtRp(report.ppob.omzet)} tone="text-cyan-700" />
              <Stat label="PPOB Untung" value={fmtRp(report.ppob.untung)} tone="text-emerald-600" />
              <Stat label="PG Untung" value={fmtRp(report.pg.untung)} tone="text-emerald-600" />
              <Stat label="B2B Komisi" value={fmtRp(report.b2b.komisi)} tone="text-emerald-600" />
              <Stat label="Asuransi Komisi" value={fmtRp(report.insurance.komisi)} tone="text-amber-600" />
              <Stat label="Modal Usaha" value={fmtRp(report.fintech.pengajuan)} tone="text-indigo-600" />
              <Stat label="Total Transaksi" value={String(report.count_total)} tone="text-slate-500" />
            </div>
          </>
        )}
      </Card>

      {/* Staf */}
      <Card title="Kelola Staf" subtitle="Akun admin & kasir pada outlet ini">
        {staff.length === 0 ? (
          <p className="text-xs text-slate-400 py-4 text-center">Belum ada staf.</p>
        ) : (
          <div className="divide-y divide-slate-100">
            {staff.map((s) => (
              <div key={s.user_id} className="flex items-center justify-between py-2.5">
                <div>
                  <p className="text-xs font-bold text-slate-800">{s.email}</p>
                  <p className="text-[10px] text-slate-400 capitalize">{s.role} &bull; {fmtDate(s.created_at)}</p>
                </div>
                <button
                  disabled={busy}
                  onClick={() => {
                    if (window.confirm(`Hapus staf ${s.email}?`)) {
                      act(() => platformOutletRemoveStaff(id, s.user_id), 'Staf dihapus');
                    }
                  }}
                  className="flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-rose-600 hover:bg-rose-50 text-[11px] font-bold"
                >
                  <UserMinus className="w-3.5 h-3.5" /> Hapus
                </button>
              </div>
            ))}
          </div>
        )}
      </Card>

      {/* Backup / Restore */}
      <Card title="Backup & Restore" subtitle="Snapshot data outlet">
        <BackupPanel outletId={id} onFlash={flash} />
      </Card>

      {/* Hapus akun */}
      <div className="bg-rose-50 border border-rose-200 rounded-2xl p-4 sm:p-5">
        <div className="flex items-center gap-2 mb-2">
          <AlertTriangle className="w-4 h-4 text-rose-600" />
          <h2 className="text-sm font-bold text-rose-700">Zona Berbahaya</h2>
        </div>
        <p className="text-[11px] text-rose-600 mb-3">
          Menghapus akun akan menghapus outlet beserta seluruh data dan akun owner. Tindakan ini permanen.
        </p>
        <button
          disabled={busy}
          onClick={() => {
            if (window.confirm(`HAPUS PERMANEN outlet "${outlet.outlet_name}" dan akun ${outlet.email}?`)) {
              act(() => platformOutletDeleteAccount(id), 'Akun & outlet dihapus').then(() => {
                window.location.hash = '#/outlets';
              });
            }
          }}
          className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-rose-600 hover:bg-rose-700 text-white text-xs font-bold disabled:opacity-50"
        >
          <Trash2 className="w-4 h-4" /> Hapus Akun & Outlet
        </button>
      </div>
    </div>
  );
}

function BackupPanel({
  outletId, onFlash,
}: { outletId: string; onFlash: (t: 'ok' | 'err', s: string) => void }) {
  const [runs, setRuns] = useState<any[]>([]);
  const [sched, setSched] = useState<{ enabled: boolean; cadence: string }>({ enabled: false, cadence: 'daily' });
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    try {
      const res = await rp<{ rows: any[] }>('platform_backup_list');
      setRuns((res.rows ?? []).filter((r) => r.outlet_id === outletId));
    } catch { /* ignore */ }
  }, [outletId]);

  useEffect(() => { load(); }, [load]);

  const create = async (kind: 'full' | 'quick') => {
    setBusy(true);
    try {
      await rp('platform_backup_create', { p_outlet_id: outletId, p_kind: kind });
      onFlash('ok', 'Backup dibuat');
      await load();
    } catch (e) {
      onFlash('err', e instanceof Error ? e.message : 'Backup gagal');
    } finally { setBusy(false); }
  };

  const restore = async (id: string) => {
    if (!window.confirm('Pulihkan data dari backup ini? Data saat ini akan ditimpa.')) return;
    setBusy(true);
    try {
      await rp('platform_backup_restore', { p_id: id });
      onFlash('ok', 'Data dipulihkan');
      await load();
    } catch (e) {
      onFlash('err', e instanceof Error ? e.message : 'Restore gagal');
    } finally { setBusy(false); }
  };

  const setSchedule = async () => {
    setBusy(true);
    try {
      await rp('platform_backup_schedule_set', {
        p_outlet_id: outletId, p_enabled: !sched.enabled, p_cadence: sched.cadence,
      });
      setSched((s) => ({ ...s, enabled: !s.enabled }));
      onFlash('ok', 'Jadwal backup diperbarui');
    } catch (e) {
      onFlash('err', e instanceof Error ? e.message : 'Gagal set jadwal');
    } finally { setBusy(false); }
  };

  return (
    <div>
      <div className="flex flex-wrap gap-2 mb-4">
        <button
          disabled={busy}
          onClick={() => create('full')}
          className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-sky-600 hover:bg-sky-700 text-white text-xs font-bold disabled:opacity-50"
        >
          <Download className="w-4 h-4" /> Backup Penuh
        </button>
        <button
          disabled={busy}
          onClick={() => create('quick')}
          className="flex items-center gap-1.5 px-3 py-2 rounded-xl border border-slate-200 text-slate-600 hover:bg-slate-50 text-xs font-bold disabled:opacity-50"
        >
          <Download className="w-4 h-4" /> Backup Cepat
        </button>
        <button
          disabled={busy}
          onClick={setSchedule}
          className="flex items-center gap-1.5 px-3 py-2 rounded-xl border border-slate-200 text-slate-600 hover:bg-slate-50 text-xs font-bold disabled:opacity-50"
        >
          <Clock className="w-4 h-4" /> {sched.enabled ? 'Matikan Jadwal' : 'Jadwalkan Harian'}
        </button>
      </div>
      {runs.length === 0 ? (
        <p className="text-xs text-slate-400">Belum ada backup untuk outlet ini.</p>
      ) : (
        <div className="divide-y divide-slate-100">
          {runs.map((r) => (
            <div key={r.id} className="flex items-center justify-between py-2.5">
              <div>
                <p className="text-xs font-bold text-slate-800">{r.kind === 'full' ? 'Backup Penuh' : 'Backup Cepat'}</p>
                <p className="text-[10px] text-slate-400">{fmtDate(r.created_at)} &bull; {r.row_count ?? 0} baris &bull; {r.status}</p>
              </div>
              <button
                disabled={busy}
                onClick={() => restore(r.id)}
                className="flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-sky-700 hover:bg-sky-50 text-[11px] font-bold"
              >
                <Upload className="w-3.5 h-3.5" /> Restore
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function Card({ title, subtitle, children, action }: any) {
  return (
    <section className="bg-white p-4 sm:p-5 rounded-2xl border border-slate-200/80 shadow-sm">
      <div className="flex items-start justify-between gap-3 pb-3 mb-4 border-b border-slate-100">
        <div>
          <h2 className="text-sm font-bold text-slate-900">{title}</h2>
          {subtitle && <p className="text-[11px] text-slate-500 mt-0.5">{subtitle}</p>}
        </div>
        {action}
      </div>
      {children}
    </section>
  );
}

function Stat({ label, value, tone }: { label: string; value: string; tone: string }) {
  return (
    <div className="rounded-xl border border-slate-100 bg-slate-50/60 p-3">
      <p className="text-[10px] font-bold text-slate-400">{label}</p>
      <p className={`text-sm font-extrabold ${tone} mt-0.5`}>{value}</p>
    </div>
  );
}

function Badge({ tone, label }: { tone: 'ok' | 'bad' | 'warn'; label: string }) {
  const cls = tone === 'ok'
    ? 'bg-emerald-50 text-emerald-600 border-emerald-200'
    : tone === 'bad'
      ? 'bg-rose-50 text-rose-600 border-rose-200'
      : 'bg-amber-50 text-amber-600 border-amber-200';
  return <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold border ${cls}`}>{label}</span>;
}