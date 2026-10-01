import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  BarChart3, Users, Store, TrendingUp, AlertTriangle,
  HeartHandshake, RefreshCw,
} from 'lucide-react';
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend,
} from 'recharts';
import {
  rp, fmtRp, fmtDate, REVENUE_ENGINES, RevenueRow,
} from '../lib/adminApi';

type SupportersSummary = {
  active: number; trial: number; mrr: number;
  revenue_30d: number; expired: number;
};
type PartnerSummary = {
  fintech: { leads_total: number; leads_apply: number; leads_approved: number; amount_requested: number };
};

export function Dashboard() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [granularity, setGranularity] = useState<'day' | 'month'>('day');
  const [series, setSeries] = useState<RevenueRow[]>([]);
  const [supporters, setSupporters] = useState<SupportersSummary | null>(null);
  const [partners, setPartners] = useState<PartnerSummary | null>(null);
  const [totalUsers, setTotalUsers] = useState<number>(0);
  const [totalOutlets, setTotalOutlets] = useState<number>(0);

  const load = async (gran: 'day' | 'month') => {
    setLoading(true);
    setError(null);
    try {
      const [rev, sup, part, users] = await Promise.all([
        rp<RevenueRow[]>('platform_revenue_series', {
          p_days: gran === 'month' ? 180 : 30, p_granularity: gran,
        }),
        rp<SupportersSummary>('platform_supporters_summary'),
        rp<PartnerSummary>('platform_revenue_summary'),
        rp<{ total: number }>('platform_users_list', { p_limit: 1, p_offset: 0 }),
      ]);
      setSeries(rev ?? []);
      setSupporters(sup);
      setPartners(part);
      setTotalUsers(users?.total ?? 0);
      setTotalOutlets(users?.total ?? 0);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Gagal memuat data');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(granularity); /* eslint-disable-next-line react-hooks/exhaustive-deps */ }, [granularity]);

  // Pivot series -> [{ bucket, pendukung, ppob_margin, ... }]
  const chartData = useMemo(() => {
    const map = new Map<string, Record<string, number | string>>();
    for (const row of series) {
      const cur: Record<string, number | string> = map.get(row.bucket) ?? {};
      cur[row.engine] = ((cur[row.engine] as number) ?? 0) + Number(row.amount ?? 0);
      cur.bucket = row.bucket;
      map.set(row.bucket, cur);
    }
    return Array.from(map.values()).map((r) => ({
      ...r,
      bucket: formatBucket(String(r.bucket), granularity),
    }));
  }, [series, granularity]);

  const totalRevenue = useMemo(
    () => series.reduce((s, r) => s + Number(r.amount ?? 0), 0),
    [series],
  );
  const engineTotals = useMemo(() => {
    const t: Record<string, number> = {};
    for (const row of series) t[row.engine] = (t[row.engine] ?? 0) + Number(row.amount ?? 0);
    return t;
  }, [series]);

  const metrics = [
    { title: 'TOTAL USERS', value: String(totalUsers), icon: Users, color: 'text-sky-600', bg: 'bg-sky-50' },
    { title: 'OUTLETS', value: String(totalOutlets), icon: Store, color: 'text-blue-600', bg: 'bg-blue-50' },
    {
      title: 'PENDAPATAN ' + (granularity === 'month' ? '6 BLN' : '30 HARI'),
      value: fmtRp(totalRevenue),
      icon: BarChart3, color: 'text-cyan-600', bg: 'bg-cyan-50',
    },
    {
      title: 'MRR PENDUKUNG',
      value: fmtRp(supporters?.mrr ?? 0),
      icon: HeartHandshake, color: 'text-emerald-600', bg: 'bg-emerald-50',
    },
  ];

  return (
    <div className="space-y-4 max-w-[1100px] mx-auto text-slate-800">
      {/* Header */}
      <div className="bg-white p-4 sm:p-5 rounded-2xl border border-slate-200/80 shadow-sm flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <div className="w-11 h-11 rounded-xl bg-gradient-to-br from-cyan-500 to-sky-600 p-0.5 shadow-md shadow-sky-500/20">
            <div className="w-full h-full bg-white rounded-[10px] flex items-center justify-center text-sky-600 font-extrabold">KG</div>
          </div>
          <div>
            <h1 className="text-base sm:text-lg font-bold text-slate-900 tracking-tight">Dashboard Revenue Superadmin</h1>
            <p className="text-slate-500 text-xs mt-0.5">12 Revenue Engine &bull; data real-time Supabase</p>
          </div>
        </div>
        <button
          onClick={() => load(granularity)}
          className="flex items-center gap-2 px-3 py-2 rounded-xl border border-slate-200 text-xs font-semibold text-slate-600 hover:bg-slate-50 transition"
        >
          <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} /> Refresh
        </button>
      </div>

      {error && (
        <div className="bg-rose-50 border border-rose-200 rounded-2xl p-4 flex items-center gap-2 text-rose-700 text-sm">
          <AlertTriangle className="w-4 h-4" /> {error}
        </div>
      )}

      {/* Metric cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        {metrics.map((m) => (
          <div key={m.title} className="bg-white rounded-2xl border border-slate-200/80 shadow-sm p-4">
            <div className={`w-9 h-9 rounded-xl ${m.bg} ${m.color} flex items-center justify-center mb-3`}>
              <m.icon className="w-4 h-4" />
            </div>
            <p className="text-[10px] font-bold tracking-wide text-slate-400">{m.title}</p>
            <p className="text-lg font-extrabold text-slate-900 mt-0.5">{m.value}</p>
          </div>
        ))}
      </div>

      {/* 12 revenue engine chart */}
      <section className="bg-white rounded-2xl border border-slate-200/80 shadow-sm p-4 sm:p-5">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 mb-4">
          <div>
            <h2 className="text-sm font-bold text-slate-900">12 Revenue Engine</h2>
            <p className="text-[11px] text-slate-500">Pendapatan platform per engine (data nyata)</p>
          </div>
          <div className="flex gap-1 bg-slate-100 rounded-xl p-1">
            {(['day', 'month'] as const).map((g) => (
              <button
                key={g}
                onClick={() => setGranularity(g)}
                className={`px-3 py-1.5 rounded-lg text-[11px] font-bold transition ${
                  granularity === g ? 'bg-white text-sky-700 shadow-sm' : 'text-slate-500'
                }`}
              >
                {g === 'day' ? 'Harian (30d)' : 'Bulanan (6bln)'}
              </button>
            ))}
          </div>
        </div>
        {loading ? (
          <div className="h-72 flex items-center justify-center text-xs text-slate-400">Memuat grafik...</div>
        ) : (
          <ResponsiveContainer width="100%" height={288}>
            <BarChart data={chartData} margin={{ top: 4, right: 4, left: -12, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#E2E8F0" vertical={false} />
              <XAxis dataKey="bucket" tick={{ fontSize: 10, fill: '#64748B' }} tickLine={false} axisLine={{ stroke: '#E2E8F0' }} />
              <YAxis tick={{ fontSize: 10, fill: '#64748B' }} tickLine={false} axisLine={false} tickFormatter={(v: number) => fmtRp(v)} />
              <Tooltip
                contentStyle={{ borderRadius: 12, border: '1px solid #E2E8F0', fontSize: 11 }}
                formatter={(v: number | string) => fmtRp(Number(v))}
              />
              <Legend wrapperStyle={{ fontSize: 10 }} />
              {REVENUE_ENGINES.map((e) => (
                <Bar key={e.key} dataKey={e.key} name={e.label} stackId="rev" fill={e.color} radius={[0, 0, 0, 0]} />
              ))}
            </BarChart>
          </ResponsiveContainer>
        )}
        {/* Per-engine totals */}
        <div className="grid grid-cols-3 sm:grid-cols-6 gap-2 mt-4">
          {REVENUE_ENGINES.map((e) => (
            <div key={e.key} className="rounded-xl border border-slate-100 bg-slate-50/60 p-2">
              <div className="flex items-center gap-1.5">
                <span className="w-2 h-2 rounded-full" style={{ background: e.color }} />
                <p className="text-[10px] font-bold text-slate-500 truncate">{e.label}</p>
              </div>
              <p className="text-xs font-extrabold text-slate-800 mt-0.5">{fmtRp(engineTotals[e.key] ?? 0)}</p>
            </div>
          ))}
        </div>
      </section>

      {/* Supporters + Partner leads */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <section className="bg-white rounded-2xl border border-slate-200/80 shadow-sm p-4 sm:p-5">
          <h2 className="text-sm font-bold text-slate-900 mb-1">Program Pendukung</h2>
          <p className="text-[11px] text-slate-500 mb-4">Langganan Rp50.000/bulan per outlet</p>
          <div className="grid grid-cols-2 gap-3">
            <SupporterStat label="Aktif" value={String(supporters?.active ?? 0)} tone="text-emerald-600" />
            <SupporterStat label="Trial" value={String(supporters?.trial ?? 0)} tone="text-amber-600" />
            <SupporterStat label="MRR" value={fmtRp(supporters?.mrr ?? 0)} tone="text-sky-700" />
            <SupporterStat label="Pendapatan 30 hari" value={fmtRp(supporters?.revenue_30d ?? 0)} tone="text-cyan-700" />
          </div>
        </section>

        <section className="bg-white rounded-2xl border border-slate-200/80 shadow-sm p-4 sm:p-5">
          <h2 className="text-sm font-bold text-slate-900 mb-1">Partner Leads</h2>
          <p className="text-[11px] text-slate-500 mb-4">Modal usaha</p>
          <div className="space-y-2">
            <Link to="/users" className="flex items-center justify-between rounded-xl border border-slate-100 bg-slate-50/60 p-3 hover:bg-sky-50/60 transition">
              <div className="flex items-center gap-2.5">
                <TrendingUp className="w-4 h-4 text-indigo-600" />
                <div>
                  <p className="text-xs font-bold text-slate-800">Fintech (Modal Usaha)</p>
                  <p className="text-[10px] text-slate-500">
                    {partners?.fintech?.leads_total ?? 0} lead &bull; {partners?.fintech?.leads_approved ?? 0} disetujui
                  </p>
                </div>
              </div>
              <span className="text-xs font-extrabold text-indigo-700">{fmtRp(partners?.fintech?.amount_requested ?? 0)}</span>
            </Link>
          </div>
        </section>
      </div>

      {/* Latest outlets quick list */}
      <section className="bg-white rounded-2xl border border-slate-200/80 shadow-sm p-4 sm:p-5">
        <div className="flex items-center justify-between mb-3">
          <h2 className="text-sm font-bold text-slate-900">Outlet Terbaru</h2>
          <Link to="/users" className="text-[11px] font-bold text-sky-700 hover:underline">Kelola pengguna &rarr;</Link>
        </div>
        <OutletPreview />
      </section>
    </div>
  );
}

function SupporterStat({ label, value, tone }: { label: string; value: string; tone: string }) {
  return (
    <div className="rounded-xl border border-slate-100 bg-slate-50/60 p-3">
      <p className="text-[10px] font-bold text-slate-400">{label}</p>
      <p className={`text-sm font-extrabold ${tone} mt-0.5`}>{value}</p>
    </div>
  );
}

function formatBucket(bucket: string, granularity: 'day' | 'month'): string {
  const d = new Date(bucket);
  if (granularity === 'month') {
    return d.toLocaleDateString('id-ID', { month: 'short' });
  }
  return d.toLocaleDateString('id-ID', { day: '2-digit', month: 'short' });
}

function OutletPreview() {
  const [rows, setRows] = useState<{ user_id: string; name: string; outlet_name: string | null; outlet_type: string | null; kyc_status: string; payment_status: string; created_at: string }[]>([]);
  const [err, setErr] = useState(false);

  useEffect(() => {
    rp<{ rows: typeof rows }>('platform_users_list', { p_limit: 5, p_offset: 0 })
      .then((r) => setRows(r.rows ?? []))
      .catch(() => setErr(true));
  }, []);

  if (err) return <p className="text-xs text-slate-400">Gagal memuat outlet.</p>;
  if (!rows.length) return <p className="text-xs text-slate-400">Belum ada outlet terdaftar.</p>;
  return (
    <div className="space-y-2">
      {rows.map((r) => (
        <div key={r.user_id} className="flex items-center justify-between rounded-xl border border-slate-100 p-3">
          <div className="min-w-0">
            <p className="text-xs font-bold text-slate-800 truncate">{r.outlet_name ?? r.name ?? '(tanpa nama)'}</p>
            <p className="text-[10px] text-slate-400 truncate">
              {r.outlet_type ?? '-'} &bull; daftar {fmtDate(r.created_at)}
            </p>
          </div>
          <div className="flex gap-1.5 shrink-0">
            <Badge ok={r.kyc_status === 'verified'} label={r.kyc_status === 'verified' ? 'KYC OK' : 'KYC ' + r.kyc_status} />
            <Badge ok={r.payment_status === 'active'} label={r.payment_status === 'active' ? 'Bayar OK' : 'Free'} />
          </div>
        </div>
      ))}
    </div>
  );
}

function Badge({ ok, label }: { ok: boolean; label: string }) {
  return (
    <span className={`px-2 py-0.5 rounded-full text-[9px] font-bold border ${
      ok ? 'bg-emerald-50 text-emerald-600 border-emerald-200' : 'bg-amber-50 text-amber-600 border-amber-200'
    }`}>
      {label}
    </span>
  );
}
