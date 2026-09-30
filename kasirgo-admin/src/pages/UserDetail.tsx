import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import {
  ArrowLeft, ShieldAlert, BadgeCheck, Clock, AlertTriangle, RefreshCw, Eye,
} from 'lucide-react';
import { rp, fmtRp, fmtDate, UserDetailResult } from '../lib/adminApi';

const KYC_BADGE: Record<string, { label: string; className: string; icon: typeof BadgeCheck }> = {
  verified: { label: 'Terverifikasi', className: 'bg-emerald-50 text-emerald-600', icon: BadgeCheck },
  rejected: { label: 'Ditolak', className: 'bg-rose-50 text-rose-600', icon: ShieldAlert },
  pending: { label: 'Menunggu Verifikasi', className: 'bg-amber-50 text-amber-600', icon: Clock },
  belum: { label: 'Belum Diajukan', className: 'bg-slate-50 text-slate-500', icon: Clock },
};

export function UserDetailPage() {
  const { id = '' } = useParams();
  const navigate = useNavigate();
  const [data, setData] = useState<UserDetailResult | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = async () => {
    setLoading(true);
    setError(null);
    try {
      setData(await rp<UserDetailResult>('platform_user_detail', { p_user_id: id }));
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Gagal memuat detail');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { if (id) load(); /* eslint-disable-next-line react-hooks/exhaustive-deps */ }, [id]);

  if (loading) {
    return (
      <div className="p-6 max-w-[1100px] mx-auto text-center text-xs text-slate-400">Memuat detail...</div>
    );
  }
  if (error || !data?.user) {
    return (
      <div className="p-6 max-w-[1100px] mx-auto">
        <button onClick={() => navigate('/users')} className="flex items-center gap-1.5 text-xs font-semibold text-slate-500 hover:text-sky-600 mb-4">
          <ArrowLeft className="w-4 h-4" /> Kembali
        </button>
        <div className="bg-rose-50 border border-rose-200 rounded-2xl p-4 flex items-center gap-2 text-rose-700 text-sm">
          <AlertTriangle className="w-4 h-4" /> {error ?? 'Pengguna tidak ditemukan.'}
        </div>
      </div>
    );
  }

  const user = data.user;
  const outlet = data.outlet;
  const kycKey = (data.kyc as { status?: string } | null)?.status ?? 'belum';
  const kyc = KYC_BADGE[kycKey] ?? KYC_BADGE.belum;
  const KycIcon = kyc.icon;
  const stats = data.stats ?? {};
  const sub = data.subscription as { status?: string; amount?: number; tier?: string } | null;

  return (
    <div className="space-y-4 max-w-[1100px] mx-auto text-slate-800 fade-in">
      <button onClick={() => navigate('/users')} className="flex items-center gap-1.5 text-xs font-semibold text-slate-500 hover:text-sky-600 transition">
        <ArrowLeft className="w-4 h-4" /> Kembali ke Pengguna
      </button>

      {/* Header */}
      <div className="bg-white p-4 sm:p-5 rounded-2xl border border-slate-200/80 shadow-sm flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-cyan-500 to-sky-600 p-0.5 shadow-md shadow-sky-500/20">
            <div className="w-full h-full bg-white rounded-[10px] flex items-center justify-center text-sky-600 font-extrabold text-lg">
              {(user.name || user.email || '?').slice(0, 2).toUpperCase()}
            </div>
          </div>
          <div className="min-w-0">
            <div className="flex items-center gap-2 flex-wrap">
              <h1 className="text-base sm:text-lg font-bold text-slate-900 truncate">{user.name || '(tanpa nama)'}</h1>
              <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold flex items-center gap-1 ${kyc.className}`}>
                <KycIcon className="w-3 h-3" /> {kyc.label}
              </span>
            </div>
            <p className="text-slate-500 text-xs mt-0.5 truncate">{user.email}</p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          {sub?.status === 'active' && (
            <span className="px-2.5 py-1 bg-emerald-50 text-emerald-600 border border-emerald-200 rounded-full text-[10px] font-bold">
              PENDUKUNG {sub.tier ? sub.tier.toUpperCase() : ''}
            </span>
          )}
          <button onClick={load} className="p-2 rounded-lg border border-slate-200 hover:bg-slate-50">
            <RefreshCw className="w-4 h-4 text-slate-500" />
          </button>
        </div>
      </div>

      {/* Outlet + tier/kyc status */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div className="lg:col-span-2 bg-white rounded-2xl border border-slate-200/80 shadow-sm p-4 sm:p-5">
          <h2 className="text-sm font-bold text-slate-900 mb-3">Outlet</h2>
          {outlet ? (
            <div className="grid grid-cols-2 gap-3 text-xs">
              <Info label="Nama" value={outlet.name} />
              <Info label="Tipe" value={outlet.type} />
              <Info label="Telepon" value={outlet.phone ?? '-'} />
              <Info label="Daftar" value={fmtDate(outlet.created_at)} />
              <div className="col-span-2">
                <Info label="Alamat" value={outlet.address ?? '-'} />
              </div>
            </div>
          ) : (
            <p className="text-xs text-slate-400">Outlet tidak ditemukan untuk user ini.</p>
          )}
        </div>
        <div className="bg-white rounded-2xl border border-slate-200/80 shadow-sm p-4 sm:p-5">
          <h2 className="text-sm font-bold text-slate-900 mb-3">Status</h2>
          <div className="space-y-2 text-xs">
            <Row label="KYC" value={kyc.label} />
            <Row label="Pembayaran" value={sub?.status === 'active' ? `Aktif (${fmtRp(sub.amount)})` : sub?.status === 'trial' ? 'Trial' : 'Gratis'} />
            <Row label="Ad-free" value={data.entitlements ? String((data.entitlements as { ad_free?: boolean }).ad_free ?? false) : 'false'} />
            <Row label="Lead fintech" value={String(data.leads?.fintech ?? 0)} />
            <Row label="Lead asuransi" value={String(data.leads?.insurance ?? 0)} />
            <Row label="Restock B2B" value={String(data.leads?.restock ?? 0)} />
          </div>
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 sm:grid-cols-5 gap-3">
        <StatCard label="Transaksi" value={String(stats.tx_count ?? 0)} />
        <StatCard label="Transaksi 30 hari" value={String(stats.tx_30d ?? 0)} />
        <StatCard label="Omzet 30 hari" value={fmtRp(stats.omzet_30d ?? 0)} />
        <StatCard label="Produk" value={String(stats.product_count ?? 0)} />
        <StatCard label="Staf" value={String(stats.staff_count ?? 0)} />
      </div>

      {/* Recent transactions */}
      <div className="bg-white rounded-2xl border border-slate-200/80 shadow-sm p-4 sm:p-5">
        <h2 className="text-sm font-bold text-slate-900 mb-3">Transaksi Terakhir</h2>
        {data.recent_transactions?.length ? (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[480px]">
              <thead>
                <tr className="border-b border-slate-100">
                  <th className="text-left py-2 text-[10px] font-bold text-slate-400 uppercase">ID</th>
                  <th className="text-left py-2 text-[10px] font-bold text-slate-400 uppercase">Tanggal</th>
                  <th className="text-left py-2 text-[10px] font-bold text-slate-400 uppercase">Metode</th>
                  <th className="text-left py-2 text-[10px] font-bold text-slate-400 uppercase">Status</th>
                  <th className="text-right py-2 text-[10px] font-bold text-slate-400 uppercase">Total</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-50">
                {data.recent_transactions.map((t) => (
                  <tr key={t.id}>
                    <td className="py-2.5 text-[11px] font-mono text-slate-500">{t.id.slice(0, 8)}</td>
                    <td className="py-2.5 text-[11px] text-slate-600">{fmtDate(t.created_at)}</td>
                    <td className="py-2.5 text-[11px] text-slate-600">{t.payment_method}</td>
                    <td className="py-2.5 text-[11px]">
                      <span className={`px-2 py-0.5 rounded-full text-[9px] font-bold ${
                        t.order_status === 'batal' ? 'bg-rose-50 text-rose-600' : 'bg-emerald-50 text-emerald-600'
                      }`}>{t.order_status}</span>
                    </td>
                    <td className="py-2.5 text-right text-[11px] font-bold text-slate-800">{fmtRp(t.final_amount)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <p className="text-xs text-slate-400">Belum ada transaksi.</p>
        )}
      </div>

      <div className="flex items-center gap-2 text-[10px] text-slate-400">
        <Eye className="w-3 h-3" /> Data dibaca via RPC read-only; seluruh akses admin tercatat di audit_logs.
      </div>
    </div>
  );
}

function Info({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <p className="text-[10px] font-bold text-slate-400 uppercase">{label}</p>
      <p className="text-xs font-semibold text-slate-800 mt-0.5 break-words">{value}</p>
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between">
      <span className="text-slate-500">{label}</span>
      <span className="font-bold text-slate-800">{value}</span>
    </div>
  );
}

function StatCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="bg-white rounded-2xl border border-slate-200/80 shadow-sm p-3">
      <p className="text-[9px] font-bold text-slate-400 uppercase">{label}</p>
      <p className="text-sm font-extrabold text-slate-900 mt-0.5">{value}</p>
    </div>
  );
}
