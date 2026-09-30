import { useEffect, useState } from 'react';
import {
  LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid,
} from 'recharts';
import { RefreshCw, TrendingUp, Users, AlertTriangle, Timer } from 'lucide-react';
import { rp, fmtRp, fmtDate, IntelligenceResult } from '../lib/adminApi';

export function IntelligencePage() {
  const [data, setData] = useState<IntelligenceResult | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = async () => {
    setLoading(true);
    setError(null);
    try {
      setData(await rp<IntelligenceResult>('platform_intelligence'));
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Gagal memuat intelijen platform');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, []);

  const trend = (data?.trend ?? []).map((t) => ({
    ...t,
    label: new Date(t.day).toLocaleDateString('id-ID', { day: '2-digit', month: 'short' }),
  }));

  return (
    <div className="p-3 sm:p-6 max-w-[1100px] mx-auto fade-in">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-6">
        <div>
          <h1 className="text-xl sm:text-2xl font-bold text-slate-900 mb-1">Intelijen Platform</h1>
          <p className="text-xs sm:text-sm text-slate-500">Tren, retensi, churn risk, anomali &mdash; agregat tanpa data pribadi</p>
        </div>
        <button onClick={load} className="flex items-center gap-2 border border-slate-200 bg-white px-4 py-2.5 rounded-xl text-xs font-semibold text-slate-600 hover:bg-slate-50 transition">
          <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} /> Refresh
        </button>
      </div>

      {error && <div className="bg-rose-50 border border-rose-200 rounded-2xl p-4 text-rose-700 text-sm mb-6">{error}</div>}
      {loading && !data && <div className="text-center text-xs text-slate-400 py-10">Memuat...</div>}

      {data && (
        <>
          {/* KPI */}
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 mb-6">
            <Kpi icon={Users} label="Total outlet" value={String(data.kpis.total_outlets)} />
            <Kpi icon={TrendingUp} label="Aktif 30 hari" value={String(data.kpis.active_30d)} />
            <Kpi icon={Timer} label="Outlet baru 30 hari" value={String(data.kpis.new_30d)} />
            <Kpi icon={TrendingUp} label="Rata-rata TX/outlet/30h" value={String(data.kpis.avg_tx_per_outlet_30d)} />
          </div>

          {/* Tren harian */}
          <div className="bg-white rounded-2xl card-shadow border border-slate-200/80 p-4 sm:p-6 mb-6">
            <h2 className="text-sm font-bold text-slate-900 mb-4">Transaksi Harian (30 hari)</h2>
            {trend.length ? (
              <div className="h-64">
                <ResponsiveContainer width="100%" height="100%">
                  <LineChart data={trend} margin={{ top: 5, right: 10, left: -10, bottom: 0 }}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#E2E8F0" vertical={false} />
                    <XAxis dataKey="label" tick={{ fontSize: 10, fill: '#64748B' }} interval="preserveStartEnd" />
                    <YAxis tick={{ fontSize: 10, fill: '#64748B' }} allowDecimals={false} />
                    <Tooltip
                      contentStyle={{ borderRadius: 12, border: '1px solid #E2E8F0', fontSize: 12 }}
                      formatter={(v: number, name: string) => [name === 'omzet' ? fmtRp(v) : v, name === 'omzet' ? 'Omzet' : 'Transaksi']}
                    />
                    <Line type="monotone" dataKey="tx" stroke="#0284C7" strokeWidth={2} dot={false} name="Transaksi" />
                    <Line type="monotone" dataKey="omzet" stroke="#10B981" strokeWidth={2} dot={false} hide={trend.every((t) => t.omzet === 0)} name="Omzet" />
                  </LineChart>
                </ResponsiveContainer>
              </div>
            ) : (
              <p className="text-xs text-slate-400">Belum ada transaksi 30 hari terakhir.</p>
            )}
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 mb-6">
            {/* Churn risk */}
            <div className="bg-white rounded-2xl card-shadow border border-slate-200/80 p-4 sm:p-5">
              <h2 className="text-sm font-bold text-slate-900 mb-1 flex items-center gap-2">
                <Timer className="w-4 h-4 text-amber-500" /> Risiko Churn
              </h2>
              <p className="text-[10px] text-slate-400 mb-3">Outlet aktif sebelumnya, tanpa transaksi &ge; 14 hari</p>
              {data.churn_risk.length ? (
                <div className="space-y-2">
                  {data.churn_risk.map((c) => (
                    <div key={c.outlet_id} className="flex items-center justify-between bg-slate-50 rounded-xl px-3 py-2.5">
                      <div className="min-w-0">
                        <p className="text-xs font-bold text-slate-800 truncate">{c.outlet_name}</p>
                        <p className="text-[10px] text-slate-400">Transaksi seumur hidup: {c.tx_total}</p>
                      </div>
                      <div className="text-right shrink-0">
                        <p className="text-[10px] font-bold text-amber-600">idle {Math.floor((Date.now() - new Date(c.last_tx_at).getTime()) / 86400000)} hari</p>
                        <p className="text-[10px] text-slate-400">TX terakhir {fmtDate(c.last_tx_at)}</p>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-xs text-slate-400">Tidak ada outlet berisiko churn.</p>
              )}
            </div>

            {/* Anomali */}
            <div className="bg-white rounded-2xl card-shadow border border-slate-200/80 p-4 sm:p-5">
              <h2 className="text-sm font-bold text-slate-900 mb-1 flex items-center gap-2">
                <AlertTriangle className="w-4 h-4 text-rose-500" /> Anomali Volume (z &gt; 2,5)
              </h2>
              <p className="text-[10px] text-slate-400 mb-3">Hari dengan jumlah transaksi menyimpang jauh dari rata-rata</p>
              {data.anomaly.length ? (
                <div className="space-y-2">
                  {data.anomaly.map((a) => (
                    <div key={a.day} className="flex items-center justify-between bg-slate-50 rounded-xl px-3 py-2.5">
                      <p className="text-xs font-bold text-slate-800">{fmtDate(a.day)}</p>
                      <p className="text-[10px] text-slate-500">{a.tx} TX &bull; z = {a.z}</p>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-xs text-slate-400">Tidak ada anomali terdeteksi.</p>
              )}
            </div>
          </div>

          {/* Retensi mingguan */}
          <div className="bg-white rounded-2xl card-shadow border border-slate-200/80 p-4 sm:p-5">
            <h2 className="text-sm font-bold text-slate-900 mb-3">Outlet Aktif per Minggu (retensi)</h2>
            {data.weekly_active.length ? (
              <div className="h-48">
                <ResponsiveContainer width="100%" height="100%">
                  <LineChart data={data.weekly_active.map((w) => ({
                    ...w,
                    label: new Date(w.week).toLocaleDateString('id-ID', { day: '2-digit', month: 'short' }),
                  }))} margin={{ top: 5, right: 10, left: -10, bottom: 0 }}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#E2E8F0" vertical={false} />
                    <XAxis dataKey="label" tick={{ fontSize: 10, fill: '#64748B' }} />
                    <YAxis tick={{ fontSize: 10, fill: '#64748B' }} allowDecimals={false} />
                    <Tooltip contentStyle={{ borderRadius: 12, border: '1px solid #E2E8F0', fontSize: 12 }} />
                    <Line type="monotone" dataKey="outlets" stroke="#06B6D4" strokeWidth={2} dot={{ r: 3 }} name="Outlet aktif" />
                  </LineChart>
                </ResponsiveContainer>
              </div>
            ) : (
              <p className="text-xs text-slate-400">Belum ada data mingguan.</p>
            )}
          </div>
        </>
      )}
    </div>
  );
}

function Kpi({ icon: Icon, label, value }: { icon: typeof Users; label: string; value: string }) {
  return (
    <div className="bg-white rounded-2xl card-shadow border border-slate-200/80 p-4">
      <div className="flex items-center gap-2 mb-1.5">
        <Icon className="w-4 h-4 text-sky-600" />
        <p className="text-[9px] font-bold text-slate-400 uppercase">{label}</p>
      </div>
      <p className="text-lg font-extrabold text-slate-900">{value}</p>
    </div>
  );
}
