import { useCallback, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Search, Eye, RefreshCw, ChevronLeft, ChevronRight } from 'lucide-react';
import { fmtRp, fmtDate, platformOutletsList, type OutletsListResult } from '../lib/adminApi';

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
          <h1 className="text-xl sm:text-2xl font-bold text-slate-900 mb-1">Outlet Terdaftar</h1>
          <p className="text-xs sm:text-sm text-slate-500">Default hanya outlet KYC terverifikasi &bull; kelola paket, fitur, staf</p>
        </div>
        <button
          onClick={load}
          className="flex items-center gap-2 border border-slate-200 bg-white px-4 py-2.5 rounded-xl text-xs font-semibold text-slate-600 hover:bg-slate-50 transition"
        >
          <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} /> Refresh
        </button>
      </div>

      <div className="bg-white rounded-2xl p-4 sm:p-6 card-shadow border border-slate-200/80 mb-6">
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3 sm:gap-4">
          <div className="relative flex-1">
            <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-slate-400" />
            <input
              type="text"
              value={search}
              onChange={(e) => { setSearch(e.target.value); setPage(0); }}
              placeholder="Cari outlet, nama pemilik, atau email..."
              className="w-full pl-12 pr-4 py-2.5 sm:py-3 text-sm bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-sky-600 outline-none"
            />
          </div>
          <select
            value={kyc}
            onChange={(e) => { setKyc(e.target.value); setPage(0); }}
            className="border border-slate-200 rounded-xl px-4 py-2.5 sm:py-3 text-sm bg-white text-gray-700"
          >
            <option value="verified">KYC Terverifikasi</option>
            <option value="pending">KYC Pending</option>
            <option value="rejected">KYC Ditolak</option>
            <option value="all">Semua KYC</option>
          </select>
          <select
            value={plan}
            onChange={(e) => { setPlan(e.target.value); setPage(0); }}
            className="border border-slate-200 rounded-xl px-4 py-2.5 sm:py-3 text-sm bg-white text-gray-700"
          >
            <option value="all">Semua Paket</option>
            <option value="supporter">Pendukung</option>
            <option value="trial">Trial</option>
            <option value="free">Gratis</option>
          </select>
        </div>
      </div>

      {error && (
        <div className="bg-rose-50 border border-rose-200 rounded-2xl p-4 text-rose-700 text-sm mb-6">{error}</div>
      )}

      <div className="bg-white rounded-2xl card-shadow border border-slate-200/80 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[760px]">
            <thead className="bg-slate-50 border-b border-slate-200/80">
              <tr>
                <th className="text-left px-4 sm:px-6 py-3.5 text-xs font-semibold text-slate-600 uppercase tracking-wide">Outlet</th>
                <th className="text-left px-4 sm:px-6 py-3.5 text-xs font-semibold text-slate-600 uppercase tracking-wide">Pemilik</th>
                <th className="text-left px-4 sm:px-6 py-3.5 text-xs font-semibold text-slate-600 uppercase tracking-wide">Paket</th>
                <th className="text-left px-4 sm:px-6 py-3.5 text-xs font-semibold text-slate-600 uppercase tracking-wide">Staf</th>
                <th className="text-left px-4 sm:px-6 py-3.5 text-xs font-semibold text-slate-600 uppercase tracking-wide">Omzet</th>
                <th className="text-left px-4 sm:px-6 py-3.5 text-xs font-semibold text-slate-600 uppercase tracking-wide">KYC</th>
                <th className="text-right px-4 sm:px-6 py-3.5 text-xs font-semibold text-slate-600 uppercase tracking-wide">Aksi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {loading && (
                <tr><td colSpan={7} className="px-6 py-10 text-center text-xs text-slate-400">Memuat...</td></tr>
              )}
              {!loading && !data?.rows.length && (
                <tr><td colSpan={7} className="px-6 py-10 text-center text-xs text-slate-400">Tidak ada outlet cocok.</td></tr>
              )}
              {!loading && data?.rows.map((o) => (
                <tr key={o.outlet_id} className="hover:bg-slate-50/70 transition">
                  <td className="px-4 sm:px-6 py-3.5">
                    <p className="text-xs font-bold text-slate-800">{o.outlet_name ?? '(tanpa nama)'}</p>
                    <p className="text-[10px] text-slate-400 capitalize">{o.outlet_type ?? '-'} &bull; daftar {fmtDate(o.created_at)}</p>
                  </td>
                  <td className="px-4 sm:px-6 py-3.5">
                    <p className="text-xs font-semibold text-slate-700">{o.owner_name || '-'}</p>
                    <p className="text-[10px] text-slate-400">{o.email}</p>
                  </td>
                  <td className="px-4 sm:px-6 py-3.5">
                    <span className={`px-2 py-0.5 rounded-full text-[9px] font-bold border ${
                      o.is_supporter ? 'bg-emerald-50 text-emerald-600 border-emerald-200'
                        : o.on_trial ? 'bg-amber-50 text-amber-600 border-amber-200'
                        : 'bg-slate-50 text-slate-500 border-slate-200'
                    }`}>
                      {o.is_supporter ? 'PENDUKUNG' : o.on_trial ? 'TRIAL' : 'GRATIS'}
                    </span>
                  </td>
                  <td className="px-4 sm:px-6 py-3.5 text-xs font-semibold text-slate-700">{o.staff_count}</td>
                  <td className="px-4 sm:px-6 py-3.5 text-xs font-semibold text-slate-700">{fmtRp(o.omzet_total)}</td>
                  <td className="px-4 sm:px-6 py-3.5">
                    <span className={`px-2 py-0.5 rounded-full text-[9px] font-bold border ${
                      o.kyc_status === 'verified' ? 'bg-emerald-50 text-emerald-600 border-emerald-200'
                        : o.kyc_status === 'rejected' ? 'bg-rose-50 text-rose-600 border-rose-200'
                        : 'bg-amber-50 text-amber-600 border-amber-200'
                    }`}>
                      {o.kyc_status === 'verified' ? 'TERVERIFIKASI' : o.kyc_status === 'rejected' ? 'DITOLAK' : 'PENDING'}
                    </span>
                  </td>
                  <td className="px-4 sm:px-6 py-3.5">
                    <div className="flex justify-end">
                      <button
                        onClick={() => navigate(`/outlets/${o.outlet_id}`)}
                        className="p-2 hover:bg-slate-100 rounded-lg transition-colors text-sky-600"
                        title="Kelola Outlet"
                      >
                        <Eye className="w-4 h-4" />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div className="flex items-center justify-between border-t border-slate-100 px-4 sm:px-6 py-3">
          <p className="text-[11px] text-slate-500">
            Total {total} outlet &bull; halaman {page + 1} dari {totalPages}
          </p>
          <div className="flex gap-2">
            <button
              disabled={page === 0}
              onClick={() => setPage((p) => Math.max(0, p - 1))}
              className="p-2 rounded-lg border border-slate-200 disabled:opacity-40 hover:bg-slate-50"
            >
              <ChevronLeft className="w-4 h-4" />
            </button>
            <button
              disabled={page + 1 >= totalPages}
              onClick={() => setPage((p) => p + 1)}
              className="p-2 rounded-lg border border-slate-200 disabled:opacity-40 hover:bg-slate-50"
            >
              <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}