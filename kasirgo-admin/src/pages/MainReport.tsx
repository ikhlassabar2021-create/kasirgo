import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  BarChart3, Users, Store, TrendingUp, Layers3, PhoneCall, RefreshCw, AlertTriangle,
} from 'lucide-react';
import { fmtRp, platformMainReport, platformReportVisibility, type MainReportResult, type ReportVisibility } from '../lib/adminApi';

export function MainReportPage() {
  const [days, setDays] = useState(30);
  const [data, setData] = useState<MainReportResult | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [vis, setVis] = useState<ReportVisibility>({
    show_ppob_report: false,
    show_pg_report: false,
    show_outlet_ppob: false,
    show_outlet_hist: false,
  });

  const load = async (d: number) => {
    setLoading(true);
    setError(null);
    try {
      setData(await platformMainReport(d));
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Gagal memuat laporan');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load(days);
    platformReportVisibility().then(setVis).catch(() => {});
    /* eslint-disable-next-line react-hooks/exhaustive-deps */
  }, [days]);

  const totalPlans =
    (data?.plans.trial ?? 0) + (data?.plans.free ?? 0) + (data?.plans.pendukung ?? 0);

  const metrics = [
    { title: 'OUTLET GRATIS', value: String(data?.plans.free ?? 0), icon: Store, color: 'text-muted', bg: 'bg-bg' },
    { title: 'OUTLET TRIAL', value: String(data?.plans.trial ?? 0), icon: Layers3, color: 'text-warning', bg: 'bg-warning/10' },
    { title: 'OUTLET PENDUKUNG', value: String(data?.plans.pendukung ?? 0), icon: Users, color: 'text-success', bg: 'bg-success/10' },
    { title: 'TOTAL OUTLET', value: String(totalPlans), icon: BarChart3, color: 'text-primary', bg: 'bg-primary/10' },
  ];

  return (
    <div className="space-y-4 max-w-[1100px] mx-auto text-ink">
      <div className="bg-surface p-4 sm:p-5 rounded-2xl border border-border/80 shadow-sm flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <div className="w-11 h-11 rounded-xl ocean-gradient p-0.5 shadow-md shadow-primary/20">
            <div className="w-full h-full bg-surface rounded-[10px] flex items-center justify-center text-primary font-extrabold">KG</div>
          </div>
          <div>
            <h1 className="text-base sm:text-lg font-bold text-ink tracking-tight">Laporan Utama Platform</h1>
            <p className="text-muted text-xs mt-0.5">Jumlah paket, keuntungan Pendukung, PPOB &amp; Payment Gateway</p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <div className="flex gap-1 bg-bg rounded-xl p-1">
            {[7, 30, 90].map((d) => (
              <button
                key={d}
                onClick={() => setDays(d)}
                className={`px-3 py-1.5 rounded-lg text-[11px] font-bold transition ${
                  days === d ? 'bg-surface text-primary shadow-sm' : 'text-muted'
                }`}
              >
                {d} hari
              </button>
            ))}
          </div>
          <button
            onClick={() => load(days)}
            className="flex items-center gap-2 px-3 py-2 rounded-xl border border-border text-xs font-semibold text-muted hover:bg-bg transition"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} /> Refresh
          </button>
        </div>
      </div>

      {error && (
        <div className="bg-danger/10 border border-danger/30 rounded-2xl p-4 flex items-center gap-2 text-danger text-sm">
          <AlertTriangle className="w-4 h-4" /> {error}
        </div>
      )}

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        {metrics.map((m) => (
          <div key={m.title} className="bg-surface rounded-2xl border border-border/80 shadow-sm p-4">
            <div className={`w-9 h-9 rounded-xl ${m.bg} ${m.color} flex items-center justify-center mb-3`}>
              <m.icon className="w-4 h-4" />
            </div>
            <p className="text-[10px] font-bold tracking-wide text-muted">{m.title}</p>
            <p className="text-lg font-extrabold text-ink mt-0.5">{m.value}</p>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <section className="bg-surface rounded-2xl border border-border/80 shadow-sm p-4 sm:p-5">
          <div className="flex items-center gap-2 mb-3">
            <TrendingUp className="w-4 h-4 text-success" />
            <h2 className="text-sm font-bold text-ink">Program Pendukung</h2>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <Stat label="Pendukung Aktif" value={String(data?.pendukung.active ?? 0)} tone="text-success" />
            <Stat label="MRR" value={fmtRp(data?.pendukung.mrr ?? 0)} tone="text-primary" />
            <Stat label={`Keuntungan ${days} hari`} value={fmtRp(data?.pendukung.revenue_period ?? 0)} tone="text-primary" />
            <Stat label="Harga / bulan" value={fmtRp(50000)} tone="text-ink" />
          </div>
        </section>

        {vis.show_ppob_report && (
        <section className="bg-surface rounded-2xl border border-border/80 shadow-sm p-4 sm:p-5">
          <div className="flex items-center gap-2 mb-3">
            <PhoneCall className="w-4 h-4 text-primary" />
            <h2 className="text-sm font-bold text-ink">PPOB</h2>
          </div>
          <div className="grid grid-cols-3 gap-3">
            <Stat label="Omzet" value={fmtRp(data?.ppob.omzet ?? 0)} tone="text-primary" />
            <Stat label="Untung" value={fmtRp(data?.ppob.untung ?? 0)} tone="text-success" />
            <Stat label="Transaksi" value={String(data?.ppob.count ?? 0)} tone="text-ink" />
          </div>
        </section>
        )}
      </div>

      {vis.show_pg_report && (
      <section className="bg-surface rounded-2xl border border-border/80 shadow-sm p-4 sm:p-5">
        <div className="flex items-center gap-2 mb-3">
          <BarChart3 className="w-4 h-4 text-red-500" />
          <h2 className="text-sm font-bold text-ink">Payment Gateway (QRIS)</h2>
        </div>
        <div className="grid grid-cols-2 gap-3 max-w-sm">
          <Stat label="Keuntungan" value={fmtRp(data?.pg.untung ?? 0)} tone="text-success" />
          <Stat label="Transaksi" value={String(data?.pg.count ?? 0)} tone="text-ink" />
        </div>
      </section>
      )}

      <section className="bg-surface rounded-2xl border border-border/80 shadow-sm p-4 sm:p-5 flex items-center justify-between">
        <div>
          <h2 className="text-sm font-bold text-ink">Kelola Outlet Terdaftar</h2>
          <p className="text-[11px] text-muted mt-0.5">Verifikasi, paket, fitur, staf, dan laporan per outlet.</p>
        </div>
        <Link to="/outlets" className="text-xs font-bold text-primary hover:underline">Buka &rarr;</Link>
      </section>
    </div>
  );
}

function Stat({ label, value, tone }: { label: string; value: string; tone: string }) {
  return (
    <div className="rounded-xl border border-border bg-bg/60 p-3">
      <p className="text-[10px] font-bold text-muted">{label}</p>
      <p className={`text-sm font-extrabold ${tone} mt-0.5`}>{value}</p>
    </div>
  );
}