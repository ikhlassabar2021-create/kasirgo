import { useState } from 'react';
import { Search, Plus, Copy, ExternalLink, UserCheck, TrendingUp, DollarSign, Percent } from 'lucide-react';

const affiliates = [
  { id: 1, name: 'Ahmad Fauzi', email: 'ahmad@affiliate.com', code: 'AHMAD2024', referrals: 45, earned: 'Rp 2.3M', status: 'active' },
  { id: 2, name: 'Sari Dewi', email: 'sari@partner.com', code: 'SARI123', referrals: 32, earned: 'Rp 1.6M', status: 'active' },
  { id: 3, name: 'Budi Utama', email: 'budi@guru.com', code: 'BUDI456', referrals: 28, earned: 'Rp 1.4M', status: 'pending' },
  { id: 4, name: 'Lina Marlina', email: 'lina@promoter.com', code: 'LINA789', referrals: 19, earned: 'Rp 950K', status: 'active' },
  { id: 5, name: 'Rudi Hartono', email: 'rudi@kaskus.com', code: 'RUDI000', referrals: 12, earned: 'Rp 600K', status: 'suspended' },
];

export function AffiliatesPage() {
  const [searchTerm, setSearchTerm] = useState('');

  return (
    <div className="p-3 sm:p-6 max-w-[1100px] mx-auto fade-in">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-6">
        <div>
          <h1 className="text-xl sm:text-2xl font-bold text-slate-900 mb-1">Program Afiliasi & Referral</h1>
          <p className="text-xs sm:text-sm text-slate-500">Kelola komisi pendaftaran outlet baru dari agen referral</p>
        </div>
        
        <button 
          onClick={() => alert('Modal Tambah Afiliasi')}
          className="bg-gradient-to-r from-cyan-500 to-sky-600 hover:from-cyan-600 hover:to-sky-700 text-white px-4 py-2.5 sm:px-5 sm:py-3 rounded-xl font-semibold text-xs sm:text-sm flex items-center justify-center gap-2 shadow-md shadow-sky-500/25 active:scale-95 transition self-start sm:self-auto"
        >
          <Plus className="w-4 h-4" />
          Tambah Afiliasi
        </button>
      </div>

      {/* Statistics Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4 mb-6">
        {[
          { label: 'Total Afiliasi', value: affiliates.length, icon: UserCheck, color: 'blue' },
          { label: 'Program Aktif', value: '89%', icon: TrendingUp, color: 'green' },
          { label: 'Komisi Dibayarkan', value: 'Rp 6.8M', icon: DollarSign, color: 'purple' },
          { label: 'Rata-rata Komisi', value: '12.5%', icon: Percent, color: 'orange' },
        ].map((stat, index) => {
          const Icon = stat.icon;
          return (
            <div key={index} className="bg-white rounded-2xl p-4 sm:p-6 card-shadow border border-slate-200/80">
              <div className="flex items-center justify-between mb-2">
                <Icon className={`w-5 h-5 sm:w-6 sm:h-6 ${getStatColor(stat.color)}`} />
              </div>
              <p className="text-xs text-slate-500">{stat.label}</p>
              <p className="metric-number text-2xl sm:text-3xl font-black text-slate-900">{stat.value}</p>
            </div>
          );
        })}
      </div>

      {/* Search & Filter */}
      <div className="bg-white rounded-2xl p-4 sm:p-6 card-shadow border border-slate-200/80 mb-6">
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3 sm:gap-4">
          <div className="relative flex-1">
            <Search className="absolute left-4 top-1/2 transform -translate-y-1/2 w-5 h-5 text-slate-400" />
            <input
              type="text"
              placeholder="Cari afiliasi atau kode referral..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-12 pr-4 py-2.5 sm:py-3 text-sm bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-sky-500 outline-none"
            />
          </div>
          
          <select className="border border-slate-200 rounded-xl px-4 py-2.5 sm:py-3 text-sm bg-white text-slate-700">
            <option>Semua Status</option>
            <option>Aktif</option>
            <option>Menunggu</option>
            <option>Ditangguhkan</option>
          </select>
        </div>
      </div>

      {/* Affiliates Table */}
      <div className="bg-white rounded-2xl card-shadow border border-slate-200/80 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[620px]">
            <thead className="bg-slate-50 border-b border-slate-100">
              <tr>
                <th className="text-left px-4 sm:px-6 py-3.5 text-xs font-semibold text-slate-600 uppercase">Afiliasi</th>
                <th className="text-left px-4 sm:px-6 py-3.5 text-xs font-semibold text-slate-600 uppercase">Kode Referral</th>
                <th className="text-right px-4 sm:px-6 py-3.5 text-xs font-semibold text-slate-600 uppercase">Referral</th>
                <th className="text-right px-4 sm:px-6 py-3.5 text-xs font-semibold text-slate-600 uppercase">Komisi</th>
                <th className="text-left px-4 sm:px-6 py-3.5 text-xs font-semibold text-slate-600 uppercase">Status</th>
                <th className="text-right px-4 sm:px-6 py-3.5 text-xs font-semibold text-slate-600 uppercase">Aksi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {affiliates.map((affiliate) => (
                <tr key={affiliate.id} className="hover:bg-slate-50">
                  <td className="px-4 sm:px-6 py-4">
                    <div>
                      <p className="font-medium text-sm text-slate-900">{affiliate.name}</p>
                      <p className="text-xs text-slate-400">{affiliate.email}</p>
                    </div>
                  </td>
                  <td className="px-4 sm:px-6 py-4">
                    <span className="font-mono text-xs text-sky-600 bg-sky-50 px-2 py-1 rounded font-bold">{affiliate.code}</span>
                  </td>
                  <td className="px-4 sm:px-6 py-4 text-right text-xs sm:text-sm font-semibold text-slate-700">{affiliate.referrals}</td>
                  <td className="px-4 sm:px-6 py-4 text-right text-xs sm:text-sm font-bold text-emerald-600">{affiliate.earned}</td>
                  <td className="px-4 sm:px-6 py-4">
                    <span className={`inline-flex px-2.5 py-1 rounded-full text-xs font-semibold ${
                      affiliate.status === 'active' ? 'bg-emerald-50 text-emerald-600' :
                      affiliate.status === 'pending' ? 'bg-amber-50 text-amber-600' :
                      'bg-rose-50 text-rose-600'
                    }`}>
                      {affiliate.status}
                    </span>
                  </td>
                  <td className="px-4 sm:px-6 py-4 text-right">
                    <div className="flex items-center justify-end gap-1 sm:gap-2">
                      <button 
                        onClick={() => alert(`Salin link referral: ${affiliate.code}`)}
                        className="p-1.5 sm:p-2 hover:bg-slate-100 rounded-lg transition-colors text-slate-600"
                        title="Salin Link"
                      >
                        <Copy className="w-4 h-4" />
                      </button>
                      <button 
                        onClick={() => alert(`Buka profil: ${affiliate.name}`)}
                        className="p-1.5 sm:p-2 hover:bg-slate-100 rounded-lg transition-colors text-sky-600"
                        title="Buka Profil"
                      >
                        <ExternalLink className="w-4 h-4" />
                      </button>
                    </div>
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

function getStatColor(color: string) {
  const colors = {
    blue: 'text-sky-600',
    green: 'text-emerald-600',
    purple: 'text-indigo-600',
    orange: 'text-amber-500',
  };
  return colors[color as keyof typeof colors] || 'text-sky-600';
}
