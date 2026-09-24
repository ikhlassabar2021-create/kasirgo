import { useNavigate, useParams } from 'react-router-dom';
import {
  ArrowLeft,
  Mail,
  Store,
  ShieldCheck,
  ShieldAlert,
  UserCheck,
  UserX,
  Fingerprint,
  KeyRound,
  Receipt,
  TrendingUp,
  Users,
  BadgeCheck,
  Clock,
} from 'lucide-react';

const userDirectory: Record<string, {
  name: string;
  email: string;
  outlet: string;
  outletType: string;
  location: string;
  role: string;
  tier: string;
  status: string;
  kyc: 'verified' | 'pending' | 'rejected';
  kycSubmitted: string;
  transactions: number;
  revenue: string;
  staff: number;
}> = {
  '1': { name: 'Budi Santoso', email: 'budi@warung.com', outlet: 'Warung Bakso Mbok Sum', outletType: 'Kelontong', location: 'Jakarta Selatan', role: 'Owner', tier: 'Basic', status: 'active', kyc: 'verified', kycSubmitted: '2024-01-08 09:12', transactions: 847, revenue: 'Rp 12.4M', staff: 5 },
  '2': { name: 'Siti Aminah', email: 'siti@warteg.com', outlet: 'Warteg Pak Joe', outletType: 'Warteg', location: 'Bandung', role: 'Owner', tier: 'Premium', status: 'active', kyc: 'verified', kycSubmitted: '2024-01-05 14:40', transactions: 1234, revenue: 'Rp 21.8M', staff: 8 },
  '3': { name: 'Ahmad Rizki', email: 'ahmad@cafe.com', outlet: 'Kopi Senja Cafe', outletType: 'Cafe', location: 'Bandung', role: 'Admin', tier: 'Pro', status: 'active', kyc: 'pending', kycSubmitted: '2024-01-14 11:05', transactions: 567, revenue: 'Rp 9.1M', staff: 6 },
  '4': { name: 'Dewi Lestari', email: 'dewi@retail.com', outlet: 'Minimarket Ceria', outletType: 'Retail', location: 'Yogyakarta', role: 'Owner', tier: 'Basic', status: 'suspended', kyc: 'rejected', kycSubmitted: '2024-01-02 08:30', transactions: 234, revenue: 'Rp 4.2M', staff: 7 },
  '5': { name: 'Eko Prasetyo', email: 'eko@shop.com', outlet: 'Toko Elektronik', outletType: 'Retail', location: 'Surabaya', role: 'Owner', tier: 'Premium', status: 'active', kyc: 'verified', kycSubmitted: '2024-01-10 16:55', transactions: 890, revenue: 'Rp 15.7M', staff: 9 },
};

const recentTransactions = [
  { id: 'TRX-8842', date: '2024-01-15 14:30', total: 'Rp 145.000', method: 'QRIS', status: 'success' },
  { id: 'TRX-8841', date: '2024-01-15 13:12', total: 'Rp 62.500', method: 'Tunai', status: 'success' },
  { id: 'TRX-8840', date: '2024-01-15 11:48', total: 'Rp 210.000', method: 'QRIS', status: 'success' },
  { id: 'TRX-8839', date: '2024-01-14 19:02', total: 'Rp 38.000', method: 'Tunai', status: 'refund' },
];

const kycBadge = {
  verified: { label: 'Terverifikasi', className: 'bg-emerald-50 text-emerald-600', icon: BadgeCheck },
  pending: { label: 'Menunggu Verifikasi', className: 'bg-amber-50 text-amber-600', icon: Clock },
  rejected: { label: 'Ditolak', className: 'bg-rose-50 text-rose-600', icon: ShieldAlert },
};

export function UserDetailPage() {
  const { id = '1' } = useParams();
  const navigate = useNavigate();
  const user = userDirectory[id] ?? userDirectory['1'];
  const kyc = kycBadge[user.kyc];
  const KycIcon = kyc.icon;

  return (
    <div className="space-y-4 max-w-[1100px] mx-auto text-slate-800 fade-in">
      <button
        onClick={() => navigate('/users')}
        className="flex items-center gap-1.5 text-xs font-semibold text-slate-500 hover:text-sky-600 transition"
      >
        <ArrowLeft className="w-4 h-4" /> Kembali ke Pengguna
      </button>

      <div className="bg-white p-4 sm:p-5 rounded-2xl border border-slate-200/80 shadow-sm flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-cyan-500 to-sky-600 p-0.5 shadow-md shadow-sky-500/20 shrink-0">
            <div className="w-full h-full bg-white rounded-[10px] flex items-center justify-center text-sky-600 font-extrabold text-lg">
              {user.name.split(' ').map((n) => n[0]).join('').slice(0, 2)}
            </div>
          </div>
          <div className="min-w-0">
            <div className="flex items-center gap-2 flex-wrap">
              <h1 className="text-base sm:text-lg font-bold text-slate-900 truncate">{user.name}</h1>
              <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${
                user.status === 'active'
                  ? 'bg-emerald-50 text-emerald-600'
                  : 'bg-rose-50 text-rose-600'
              }`}>
                {user.status === 'active' ? 'AKTIF' : 'DITANGGUHKAN'}
              </span>
            </div>
            <p className="text-slate-500 text-xs mt-0.5 flex items-center gap-1.5 truncate">
              <Mail className="w-3.5 h-3.5" /> {user.email}
            </p>
          </div>
        </div>

        <div className="grid grid-cols-3 sm:flex sm:items-center gap-2">
          <button
            onClick={() => alert(`Impersonate sebagai ${user.name}`)}
            className="flex items-center justify-center gap-1.5 px-3 py-2 rounded-xl bg-gradient-to-r from-cyan-500 to-sky-600 hover:from-cyan-600 hover:to-sky-700 text-white font-semibold text-xs shadow-md shadow-sky-500/25 transition active:scale-95"
          >
            <Fingerprint className="w-3.5 h-3.5" /> <span className="truncate">Impersonate</span>
          </button>
          <button
            onClick={() => alert(`Reset password untuk ${user.name}`)}
            className="flex items-center justify-center gap-1.5 px-3 py-2 rounded-xl border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 font-semibold text-xs transition active:scale-95"
          >
            <KeyRound className="w-3.5 h-3.5 text-sky-600" /> <span className="truncate">Reset</span>
          </button>
          <button
            onClick={() => alert(`Ubah status akun ${user.name}`)}
            className={`flex items-center justify-center gap-1.5 px-3 py-2 rounded-xl border font-semibold text-xs transition active:scale-95 ${
              user.status === 'active'
                ? 'bg-rose-50 hover:bg-rose-100 border-rose-200 text-rose-700'
                : 'bg-emerald-50 hover:bg-emerald-100 border-emerald-200 text-emerald-700'
            }`}
          >
            {user.status === 'active' ? <UserX className="w-3.5 h-3.5" /> : <UserCheck className="w-3.5 h-3.5" />}
            <span className="truncate">{user.status === 'active' ? 'Suspend' : 'Aktifkan'}</span>
          </button>
        </div>
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-2.5 sm:gap-3.5">
        {[
          { label: 'Total Transaksi', value: user.transactions.toLocaleString(), icon: Receipt },
          { label: 'Omset', value: user.revenue, icon: TrendingUp },
          { label: 'Jumlah Staf', value: `${user.staff} Orang`, icon: Users },
          { label: 'Peran', value: user.role, icon: ShieldCheck },
        ].map((m) => (
          <div key={m.label} className="bg-white p-3.5 sm:p-4 rounded-xl border border-slate-200/80 shadow-sm">
            <div className="flex items-center justify-between mb-1.5">
              <span className="text-[10px] font-bold tracking-wider text-slate-400 uppercase">{m.label}</span>
              <div className="w-7 h-7 rounded-lg bg-gradient-to-br from-cyan-500 to-sky-600 text-white flex items-center justify-center shrink-0 shadow-sm">
                <m.icon className="w-3.5 h-3.5" />
              </div>
            </div>
            <div className="text-lg sm:text-xl font-extrabold text-slate-900 tracking-tight">{m.value}</div>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-3.5 sm:gap-4">
        <div className="bg-white p-4 sm:p-5 rounded-2xl border border-slate-200/80 shadow-sm">
          <h2 className="text-sm font-bold text-slate-900 mb-3">Status KYC</h2>
          <span className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold ${kyc.className}`}>
            <KycIcon className="w-3.5 h-3.5" /> {kyc.label}
          </span>
          <dl className="mt-4 space-y-2.5 text-xs">
            <div className="flex items-center justify-between">
              <dt className="text-slate-500">Diajukan</dt>
              <dd className="font-semibold text-slate-800">{user.kycSubmitted}</dd>
            </div>
            <div className="flex items-center justify-between">
              <dt className="text-slate-500">Dokumen KTP</dt>
              <dd className="font-semibold text-slate-800">{user.kyc === 'rejected' ? 'Perlu Upload Ulang' : 'Lengkap'}</dd>
            </div>
            <div className="flex items-center justify-between">
              <dt className="text-slate-500">Selfie Verifikasi</dt>
              <dd className="font-semibold text-slate-800">{user.kyc === 'pending' ? 'Menunggu' : 'Lengkap'}</dd>
            </div>
          </dl>
        </div>

        <div className="bg-white p-4 sm:p-5 rounded-2xl border border-slate-200/80 shadow-sm lg:col-span-2">
          <h2 className="text-sm font-bold text-slate-900 mb-3">Informasi Outlet</h2>
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 rounded-xl bg-sky-50 text-sky-600 flex items-center justify-center shrink-0">
              <Store className="w-5 h-5" />
            </div>
            <div className="min-w-0">
              <h3 className="text-sm font-bold text-slate-800 truncate">{user.outlet}</h3>
              <p className="text-xs text-slate-500 truncate">{user.outletType} • {user.location}</p>
            </div>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5 text-xs">
            {[
              { label: 'Tipe Usaha', value: user.outletType },
              { label: 'Lokasi', value: user.location },
              { label: 'Paket', value: user.tier },
              { label: 'Peran', value: user.role },
            ].map((row) => (
              <div key={row.label} className="bg-slate-50 border border-slate-100 rounded-xl p-2.5">
                <p className="text-slate-400 font-medium">{row.label}</p>
                <p className="text-slate-800 font-semibold mt-0.5 truncate">{row.value}</p>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="bg-white rounded-2xl border border-slate-200/80 shadow-sm overflow-hidden">
        <div className="px-4 sm:px-5 py-3.5 border-b border-slate-100">
          <h2 className="text-sm font-bold text-slate-900">Transaksi Terakhir</h2>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full min-w-[560px]">
            <thead className="bg-slate-50 border-b border-slate-100">
              <tr>
                <th className="text-left px-4 sm:px-6 py-3 text-xs font-semibold text-slate-600 uppercase">ID</th>
                <th className="text-left px-4 sm:px-6 py-3 text-xs font-semibold text-slate-600 uppercase">Waktu</th>
                <th className="text-left px-4 sm:px-6 py-3 text-xs font-semibold text-slate-600 uppercase">Metode</th>
                <th className="text-right px-4 sm:px-6 py-3 text-xs font-semibold text-slate-600 uppercase">Total</th>
                <th className="text-center px-4 sm:px-6 py-3 text-xs font-semibold text-slate-600 uppercase">Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {recentTransactions.map((trx) => (
                <tr key={trx.id} className="hover:bg-slate-50">
                  <td className="px-4 sm:px-6 py-3.5 text-xs font-mono font-semibold text-sky-600">{trx.id}</td>
                  <td className="px-4 sm:px-6 py-3.5 text-xs text-slate-600">{trx.date}</td>
                  <td className="px-4 sm:px-6 py-3.5 text-xs text-slate-600">{trx.method}</td>
                  <td className="px-4 sm:px-6 py-3.5 text-xs sm:text-sm text-right font-semibold text-slate-800">{trx.total}</td>
                  <td className="px-4 sm:px-6 py-3.5 text-center">
                    <span className={`inline-flex px-2.5 py-1 rounded-full text-[11px] font-semibold ${
                      trx.status === 'success' ? 'bg-emerald-50 text-emerald-600' : 'bg-amber-50 text-amber-600'
                    }`}>
                      {trx.status === 'success' ? 'Sukses' : 'Refund'}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
