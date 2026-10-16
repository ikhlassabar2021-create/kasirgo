import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import {
  ArrowLeft, ShieldAlert, BadgeCheck, Clock, AlertTriangle, RefreshCw, Eye, LogIn, X,
} from 'lucide-react';
import { rp, fmtRp, fmtDate, UserDetailResult, ImpersonateResult } from '../lib/adminApi';

const KYC_BADGE: Record<string, { label: string; className: string; icon: typeof BadgeCheck }> = {
  verified: { label: 'Terverifikasi', className: 'bg-success/10 text-success', icon: BadgeCheck },
  rejected: { label: 'Ditolak', className: 'bg-danger/10 text-danger', icon: ShieldAlert },
  pending: { label: 'Menunggu Verifikasi', className: 'bg-warning/10 text-warning', icon: Clock },
  belum: { label: 'Belum Diajukan', className: 'bg-bg text-muted', icon: Clock },
};

export function UserDetailPage() {
  const { id = '' } = useParams();
  const navigate = useNavigate();
  const [data, setData] = useState<UserDetailResult | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [imp, setImp] = useState<ImpersonateResult | null>(null);
  const [impLoading, setImpLoading] = useState(false);
  const [impError, setImpError] = useState<string | null>(null);

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

  const openImpersonate = async () => {
    setImpLoading(true);
    setImpError(null);
    try {
      setImp(await rp<ImpersonateResult>('platform_impersonate_view', { p_user_id: id }));
    } catch (e) {
      setImpError(e instanceof Error ? e.message : 'Gagal membuka snapshot outlet');
    } finally {
      setImpLoading(false);
    }
  };

  useEffect(() => { if (id) load(); /* eslint-disable-next-line react-hooks/exhaustive-deps */ }, [id]);

  if (loading) {
    return (
      <div className="p-6 max-w-[1100px] mx-auto text-center text-xs text-muted">Memuat detail...</div>
    );
  }
  if (error || !data?.user) {
    return (
      <div className="p-6 max-w-[1100px] mx-auto">
        <button onClick={() => navigate('/users')} className="flex items-center gap-1.5 text-xs font-semibold text-muted hover:text-primary mb-4">
          <ArrowLeft className="w-4 h-4" /> Kembali
        </button>
        <div className="bg-danger/10 border border-danger/30 rounded-2xl p-4 flex items-center gap-2 text-danger text-sm">
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
    <div className="space-y-4 max-w-[1100px] mx-auto text-ink fade-in">
      <button onClick={() => navigate('/users')} className="flex items-center gap-1.5 text-xs font-semibold text-muted hover:text-primary transition">
        <ArrowLeft className="w-4 h-4" /> Kembali ke Pengguna
      </button>

      {/* Header */}
      <div className="bg-surface p-4 sm:p-5 rounded-2xl border border-border/80 shadow-sm flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <div className="w-12 h-12 rounded-xl ocean-gradient p-0.5 shadow-md shadow-primary/20">
            <div className="w-full h-full bg-surface rounded-[10px] flex items-center justify-center text-primary font-extrabold text-lg">
              {(user.name || user.email || '?').slice(0, 2).toUpperCase()}
            </div>
          </div>
          <div className="min-w-0">
            <div className="flex items-center gap-2 flex-wrap">
              <h1 className="text-base sm:text-lg font-bold text-ink truncate">{user.name || '(tanpa nama)'}</h1>
              <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold flex items-center gap-1 ${kyc.className}`}>
                <KycIcon className="w-3 h-3" /> {kyc.label}
              </span>
            </div>
            <p className="text-muted text-xs mt-0.5 truncate">{user.email}</p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          {sub?.status === 'active' && (
            <span className="px-2.5 py-1 bg-success/10 text-success border border-success/30 rounded-full text-[10px] font-bold">
              PENDUKUNG {sub.tier ? sub.tier.toUpperCase() : ''}
            </span>
          )}
          <button
            onClick={openImpersonate}
            disabled={impLoading || !data.outlet}
            className="flex items-center gap-1.5 ocean-gradient text-white px-3.5 py-2 rounded-xl text-xs font-bold shadow-md shadow-primary/25 active:scale-95 transition disabled:opacity-50"
            title="Lihat outlet dalam mode baca-saja (tercatat di audit)"
          >
            <LogIn className="w-3.5 h-3.5" /> {impLoading ? 'Membuka...' : 'Impersonate (Read-Only)'}
          </button>
          <button onClick={load} className="p-2 rounded-lg border border-border hover:bg-bg">
            <RefreshCw className="w-4 h-4 text-muted" />
          </button>
        </div>
      </div>

      {/* Outlet + tier/kyc status */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div className="lg:col-span-2 bg-surface rounded-2xl border border-border/80 shadow-sm p-4 sm:p-5">
          <h2 className="text-sm font-bold text-ink mb-3">Outlet</h2>
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
            <p className="text-xs text-muted">Outlet tidak ditemukan untuk user ini.</p>
          )}
        </div>
        <div className="bg-surface rounded-2xl border border-border/80 shadow-sm p-4 sm:p-5">
          <h2 className="text-sm font-bold text-ink mb-3">Status</h2>
          <div className="space-y-2 text-xs">
            <Row label="KYC" value={kyc.label} />
            <Row label="Pembayaran" value={sub?.status === 'active' ? `Aktif (${fmtRp(sub.amount)})` : sub?.status === 'trial' ? 'Trial' : 'Gratis'} />
            <Row label="Ad-free" value={data.entitlements ? String((data.entitlements as { ad_free?: boolean }).ad_free ?? false) : 'false'} />
            <Row label="Lead fintech" value={String(data.leads?.fintech ?? 0)} />
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
      <div className="bg-surface rounded-2xl border border-border/80 shadow-sm p-4 sm:p-5">
        <h2 className="text-sm font-bold text-ink mb-3">Transaksi Terakhir</h2>
        {data.recent_transactions?.length ? (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[480px]">
              <thead>
                <tr className="border-b border-border">
                  <th className="text-left py-2 text-[10px] font-bold text-muted uppercase">ID</th>
                  <th className="text-left py-2 text-[10px] font-bold text-muted uppercase">Tanggal</th>
                  <th className="text-left py-2 text-[10px] font-bold text-muted uppercase">Metode</th>
                  <th className="text-left py-2 text-[10px] font-bold text-muted uppercase">Status</th>
                  <th className="text-right py-2 text-[10px] font-bold text-muted uppercase">Total</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {data.recent_transactions.map((t) => (
                  <tr key={t.id}>
                    <td className="py-2.5 text-[11px] font-mono text-muted">{t.id.slice(0, 8)}</td>
                    <td className="py-2.5 text-[11px] text-muted">{fmtDate(t.created_at)}</td>
                    <td className="py-2.5 text-[11px] text-muted">{t.payment_method}</td>
                    <td className="py-2.5 text-[11px]">
                      <span className={`px-2 py-0.5 rounded-full text-[9px] font-bold ${
                        t.order_status === 'batal' ? 'bg-danger/10 text-danger' : 'bg-success/10 text-success'
                      }`}>{t.order_status}</span>
                    </td>
                    <td className="py-2.5 text-right text-[11px] font-bold text-ink">{fmtRp(t.final_amount)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <p className="text-xs text-muted">Belum ada transaksi.</p>
        )}
      </div>

      <div className="flex items-center gap-2 text-[10px] text-muted">
        <Eye className="w-3 h-3" /> Data dibaca via RPC read-only; seluruh akses admin tercatat di audit_logs.
      </div>

      {/* Modal Impersonate (read-only snapshot) */}
      {imp && (
        <div className="fixed inset-0 z-50 bg-ink/50 backdrop-blur-sm flex items-end sm:items-center justify-center p-0 sm:p-6" onClick={() => setImp(null)}>
          <div
            className="bg-bg w-full sm:max-w-2xl max-h-[88vh] overflow-y-auto rounded-t-2xl sm:rounded-2xl shadow-2xl"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="sticky top-0 bg-surface/95 backdrop-blur border-b border-border/80 px-5 py-4 flex items-center justify-between">
              <div>
                <h3 className="text-sm font-bold text-ink flex items-center gap-2">
                  <LogIn className="w-4 h-4 text-primary" /> {imp.outlet?.name ?? 'Outlet'}
                </h3>
                <p className="text-[10px] text-muted">Mode baca-saja &bull; aksi ini tercatat di audit</p>
              </div>
              <button onClick={() => setImp(null)} className="p-2 hover:bg-bg rounded-lg">
                <X className="w-4 h-4 text-muted" />
              </button>
            </div>

            {impError && <div className="mx-5 mt-4 bg-danger/10 border border-danger/30 rounded-xl p-3 text-danger text-xs">{impError}</div>}

            <div className="p-5 space-y-4">
              <div className="grid grid-cols-3 gap-3">
                <Stat label="Transaksi hari ini" value={String(imp.summary?.tx_today ?? 0)} />
                <Stat label="Omzet hari ini" value={fmtRp(imp.summary?.omzet_today ?? 0)} />
                <Stat label="Omzet 30 hari" value={fmtRp(imp.summary?.omzet_30d ?? 0)} />
                <Stat label="Produk" value={String(imp.summary?.product_count ?? 0)} />
                <Stat label="Pelanggan" value={String(imp.summary?.customer_count ?? 0)} />
                <Stat label="Staf" value={String(imp.summary?.staff_count ?? 0)} />
              </div>

              {imp.last7d?.length ? (
                <div>
                  <h4 className="text-[10px] font-bold text-muted uppercase mb-2">7 Hari Terakhir</h4>
                  <div className="flex gap-1.5 overflow-x-auto pb-1">
                    {imp.last7d.map((d) => (
                      <div key={d.day} className="bg-surface border border-border/80 rounded-xl px-3 py-2 text-center min-w-[74px]">
                        <p className="text-[9px] text-muted">{fmtDate(d.day)}</p>
                        <p className="text-xs font-extrabold text-ink">{d.tx} TX</p>
                        <p className="text-[9px] text-muted">{fmtRp(d.omzet)}</p>
                      </div>
                    ))}
                  </div>
                </div>
              ) : null}

              {imp.top_products?.length ? (
                <div>
                  <h4 className="text-[10px] font-bold text-muted uppercase mb-2">Produk Terlaris 30 Hari</h4>
                  <div className="bg-surface border border-border/80 rounded-xl divide-y divide-border">
                    {imp.top_products.map((p, i) => (
                      <div key={`${p.product_name}-${i}`} className="flex items-center justify-between px-3 py-2">
                        <p className="text-xs font-semibold text-ink truncate">{p.product_name}</p>
                        <p className="text-[10px] text-muted shrink-0 ml-2">{p.qty}x &bull; {fmtRp(p.omzet)}</p>
                      </div>
                    ))}
                  </div>
                </div>
              ) : null}

              {imp.recent_transactions?.length ? (
                <div>
                  <h4 className="text-[10px] font-bold text-muted uppercase mb-2">Transaksi Terakhir</h4>
                  <div className="bg-surface border border-border/80 rounded-xl divide-y divide-border">
                    {imp.recent_transactions.map((t) => (
                      <div key={t.id} className="flex items-center justify-between px-3 py-2">
                        <div>
                          <p className="text-[10px] text-muted">{fmtDate(t.created_at)} &bull; {t.payment_method}</p>
                          <p className="text-[9px] text-muted">{t.order_status}</p>
                        </div>
                        <p className="text-xs font-bold text-ink">{fmtRp(t.final_amount)}</p>
                      </div>
                    ))}
                  </div>
                </div>
              ) : null}

              {imp.staff?.length ? (
                <div>
                  <h4 className="text-[10px] font-bold text-muted uppercase mb-2">Staf</h4>
                  <div className="bg-surface border border-border/80 rounded-xl divide-y divide-border">
                    {imp.staff.map((s, i) => (
                      <div key={`${s.email}-${i}`} className="flex items-center justify-between px-3 py-2">
                        <p className="text-xs text-ink truncate">{s.email ?? '(tanpa email)'}</p>
                        <span className={`px-2 py-0.5 rounded-full text-[9px] font-bold ${s.is_active ? 'bg-success/10 text-success' : 'bg-bg text-muted'}`}>
                          {s.role}
                        </span>
                      </div>
                    ))}
                  </div>
                </div>
              ) : null}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function Info({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <p className="text-[10px] font-bold text-muted uppercase">{label}</p>
      <p className="text-xs font-semibold text-ink mt-0.5 break-words">{value}</p>
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between">
      <span className="text-muted">{label}</span>
      <span className="font-bold text-ink">{value}</span>
    </div>
  );
}

function StatCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="bg-surface rounded-2xl border border-border/80 shadow-sm p-3">
      <p className="text-[9px] font-bold text-muted uppercase">{label}</p>
      <p className="text-sm font-extrabold text-ink mt-0.5">{value}</p>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="bg-surface rounded-xl border border-border/80 p-3">
      <p className="text-[9px] font-bold text-muted uppercase">{label}</p>
      <p className="text-sm font-extrabold text-ink mt-0.5">{value}</p>
    </div>
  );
}
