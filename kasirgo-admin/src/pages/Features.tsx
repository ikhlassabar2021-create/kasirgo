import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { RefreshCw, Search, SlidersHorizontal } from 'lucide-react';
import { platformOutletsList, type OutletRow } from '../lib/adminApi';
import { FeatureToggleList } from '../components/FeatureToggleList';

export function FeaturesPage() {
  const [rows, setRows] = useState<OutletRow[]>([]);
  const [search, setSearch] = useState('');
  const [selected, setSelected] = useState<OutletRow | null>(null);
  const [loading, setLoading] = useState(true);

  const load = async () => {
    setLoading(true);
    try {
      const res = await platformOutletsList({
        p_search: search.trim() || null, p_kyc: 'all', p_plan: 'all', p_limit: 100, p_offset: 0,
      });
      setRows(res.rows ?? []);
      if (!selected && res.rows?.length) setSelected(res.rows[0]);
    } catch { /* ignore */ } finally { setLoading(false); }
  };

  useEffect(() => { load(); /* eslint-disable-next-line react-hooks/exhaustive-deps */ }, []);

  return (
    <div className="space-y-4 max-w-[1100px] mx-auto fade-in">
      <div className="bg-white p-4 sm:p-5 rounded-2xl border border-slate-200/80 shadow-sm flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <div className="w-11 h-11 rounded-xl bg-gradient-to-br from-indigo-500 to-sky-600 p-0.5 shadow-md shadow-sky-500/20">
            <div className="w-full h-full bg-white rounded-[10px] flex items-center justify-center text-indigo-600">
              <SlidersHorizontal className="w-5 h-5" />
            </div>
          </div>
          <div>
            <h1 className="text-base sm:text-lg font-bold text-slate-900 tracking-tight">Fitur Utama</h1>
            <p className="text-slate-500 text-xs mt-0.5">Nyalakan/matikan fitur untuk tiap outlet dari superadmin</p>
          </div>
        </div>
        <button
          onClick={load}
          className="flex items-center gap-2 px-3 py-2 rounded-xl border border-slate-200 text-xs font-semibold text-slate-600 hover:bg-slate-50 transition"
        >
          <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} /> Refresh
        </button>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <section className="bg-white rounded-2xl border border-slate-200/80 shadow-sm p-3 lg:col-span-1">
          <div className="relative mb-3">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && load()}
              placeholder="Cari outlet..."
              className="w-full pl-9 pr-3 py-2.5 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-sky-600 outline-none"
            />
          </div>
          <div className="max-h-[560px] overflow-y-auto divide-y divide-slate-100">
            {loading && <p className="text-xs text-slate-400 py-6 text-center">Memuat...</p>}
            {!loading && rows.length === 0 && (
              <p className="text-xs text-slate-400 py-6 text-center">Tidak ada outlet.</p>
            )}
            {rows.map((o) => (
              <button
                key={o.outlet_id}
                onClick={() => setSelected(o)}
                className={`w-full text-left px-3 py-2.5 rounded-lg transition ${
                  selected?.outlet_id === o.outlet_id ? 'bg-sky-50' : 'hover:bg-slate-50'
                }`}
              >
                <p className="text-xs font-bold text-slate-800 truncate">{o.outlet_name ?? '(tanpa nama)'}</p>
                <p className="text-[10px] text-slate-400 capitalize truncate">{o.outlet_type ?? '-'} &bull; {o.email}</p>
              </button>
            ))}
          </div>
        </section>

        <section className="bg-white rounded-2xl border border-slate-200/80 shadow-sm p-4 sm:p-5 lg:col-span-2">
          {!selected ? (
            <p className="text-xs text-slate-400 py-10 text-center">Pilih outlet untuk mengatur fitur.</p>
          ) : (
            <>
              <div className="flex items-center justify-between gap-3 pb-3 mb-4 border-b border-slate-100">
                <div>
                  <h2 className="text-sm font-bold text-slate-900">{selected.outlet_name ?? '(tanpa nama)'}</h2>
                  <p className="text-[11px] text-slate-500 capitalize">{selected.outlet_type ?? '-'}</p>
                </div>
                <Link to={`/outlets/${selected.outlet_id}`} className="text-[11px] font-bold text-sky-700 hover:underline">
                  Kelola outlet &rarr;
                </Link>
              </div>
              <FeatureToggleList outletId={selected.outlet_id} />
            </>
          )}
        </section>
      </div>
    </div>
  );
}