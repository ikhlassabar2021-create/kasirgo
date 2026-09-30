import { useCallback, useEffect, useState } from 'react';
import { RefreshCw, ChevronLeft, ChevronRight, ShieldCheck } from 'lucide-react';
import { rp, fmtDate, AuditListResult } from '../lib/adminApi';

const PAGE_SIZE = 25;

const ACTION_COLOR: Record<string, string> = {
  impersonate_view: 'bg-amber-50 text-amber-600 border-amber-200',
  backup_create: 'bg-sky-50 text-sky-600 border-sky-200',
  backup_restore: 'bg-rose-50 text-rose-600 border-rose-200',
  backup_download: 'bg-indigo-50 text-indigo-600 border-indigo-200',
  backup_schedule_set: 'bg-emerald-50 text-emerald-600 border-emerald-200',
};

export function AuditPage() {
  const [page, setPage] = useState(0);
  const [data, setData] = useState<AuditListResult | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setData(await rp<AuditListResult>('platform_audit_list', {
        p_limit: PAGE_SIZE, p_offset: page * PAGE_SIZE,
      }));
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Gagal memuat audit');
    } finally {
      setLoading(false);
    }
  }, [page]);

  useEffect(() => { load(); }, [load]);

  const total = data?.total ?? 0;
  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));

  return (
    <div className="p-3 sm:p-6 max-w-[1100px] mx-auto fade-in">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-6">
        <div>
          <h1 className="text-xl sm:text-2xl font-bold text-slate-900 mb-1">Jejak Audit</h1>
          <p className="text-xs sm:text-sm text-slate-500">Semua aksi admin tercatat &bull; read-only</p>
        </div>
        <button onClick={load} className="flex items-center gap-2 border border-slate-200 bg-white px-4 py-2.5 rounded-xl text-xs font-semibold text-slate-600 hover:bg-slate-50 transition">
          <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} /> Refresh
        </button>
      </div>

      {error && <div className="bg-rose-50 border border-rose-200 rounded-2xl p-4 text-rose-700 text-sm mb-6">{error}</div>}

      <div className="bg-white rounded-2xl card-shadow border border-slate-200/80 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[680px]">
            <thead className="bg-slate-50 border-b border-slate-100">
              <tr>
                <th className="text-left px-4 sm:px-6 py-3 text-[10px] font-bold text-slate-400 uppercase">Waktu</th>
                <th className="text-left px-4 sm:px-6 py-3 text-[10px] font-bold text-slate-400 uppercase">Aktor</th>
                <th className="text-left px-4 sm:px-6 py-3 text-[10px] font-bold text-slate-400 uppercase">Aksi</th>
                <th className="text-left px-4 sm:px-6 py-3 text-[10px] font-bold text-slate-400 uppercase">Target</th>
                <th className="text-left px-4 sm:px-6 py-3 text-[10px] font-bold text-slate-400 uppercase">Detail</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {loading && <tr><td colSpan={5} className="px-6 py-10 text-center text-xs text-slate-400">Memuat...</td></tr>}
              {!loading && !data?.rows.length && (
                <tr><td colSpan={5} className="px-6 py-10 text-center text-xs text-slate-400">Belum ada aktivitas.</td></tr>
              )}
              {!loading && data?.rows.map((a) => (
                <tr key={a.id} className="hover:bg-slate-50">
                  <td className="px-4 sm:px-6 py-3 text-xs text-slate-500 whitespace-nowrap">
                    {fmtDate(a.created_at)}<br />
                    <span className="text-[10px] text-slate-400">
                      {new Date(a.created_at).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })}
                    </span>
                  </td>
                  <td className="px-4 sm:px-6 py-3 text-xs">
                    <p className="font-semibold text-slate-700 truncate max-w-[160px]">{a.actor_email}</p>
                    <p className="text-[10px] text-slate-400">{a.actor_role ?? '-'}</p>
                  </td>
                  <td className="px-4 sm:px-6 py-3">
                    <span className={`px-2 py-0.5 rounded-full text-[9px] font-bold border whitespace-nowrap ${
                      ACTION_COLOR[a.action] ?? 'bg-slate-50 text-slate-500 border-slate-200'
                    }`}>{a.action}</span>
                  </td>
                  <td className="px-4 sm:px-6 py-3 text-[11px] text-slate-500 font-mono truncate max-w-[140px]">{a.target ?? '-'}</td>
                  <td className="px-4 sm:px-6 py-3 text-[10px] text-slate-400 font-mono truncate max-w-[220px]">
                    {a.meta && Object.keys(a.meta).length ? JSON.stringify(a.meta) : '-'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div className="flex items-center justify-between border-t border-slate-100 px-4 sm:px-6 py-3">
          <p className="text-[11px] text-slate-500 flex items-center gap-1.5">
            <ShieldCheck className="w-3.5 h-3.5 text-emerald-500" />
            Total {total} entri &bull; halaman {page + 1}/{totalPages}
          </p>
          <div className="flex gap-2">
            <button disabled={page === 0} onClick={() => setPage((p) => Math.max(0, p - 1))}
              className="p-2 rounded-lg border border-slate-200 disabled:opacity-40 hover:bg-slate-50">
              <ChevronLeft className="w-4 h-4" />
            </button>
            <button disabled={page + 1 >= totalPages} onClick={() => setPage((p) => p + 1)}
              className="p-2 rounded-lg border border-slate-200 disabled:opacity-40 hover:bg-slate-50">
              <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
