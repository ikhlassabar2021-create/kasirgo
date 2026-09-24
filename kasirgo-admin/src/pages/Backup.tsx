import { CloudUpload, CloudDownload, Database, FileText, Trash2 } from 'lucide-react';

const backups = [
  { id: 1, outlet: 'Warung Bakso Mbok Sum', date: '2024-01-15 14:30', size: '2.3 MB', type: 'Full Backup' },
  { id: 2, outlet: 'Kopi Senja Cafe', date: '2024-01-15 12:15', size: '1.8 MB', type: 'Incremental' },
  { id: 3, outlet: 'Minimarket Ceria', date: '2024-01-14 18:45', size: '5.2 MB', type: 'Full Backup' },
  { id: 4, outlet: 'Toko Elektronik', date: '2024-01-14 09:20', size: '3.1 MB', type: 'Quick Export' },
  { id: 5, outlet: 'Warteg Pak Joe', date: '2024-01-13 16:10', size: '1.5 MB', type: 'Incremental' },
];

export function BackupPage() {
  return (
    <div className="p-3 sm:p-6 max-w-[1100px] mx-auto fade-in">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-6">
        <div>
          <h1 className="text-xl sm:text-2xl font-bold text-slate-900 mb-1">Backup & Pemulihan Data</h1>
          <p className="text-xs sm:text-sm text-slate-500">Kelola snapshot database dan pemulihan data outlet</p>
        </div>
        
        <button 
          onClick={() => alert('Modal Buat Backup Baru')}
          className="bg-gradient-to-r from-cyan-500 to-sky-600 hover:from-cyan-600 hover:to-sky-700 text-white px-4 py-2.5 sm:px-5 sm:py-3 rounded-xl font-semibold text-xs sm:text-sm flex items-center justify-center gap-2 shadow-md shadow-sky-500/25 active:scale-95 transition self-start sm:self-auto"
        >
          <CloudUpload className="w-4 h-4" />
          Buat Backup Baru
        </button>
      </div>

      {/* Backup Options */}
      <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-4 sm:gap-6 mb-6">
        {[
          { title: 'Full Backup', desc: 'Ekspor database lengkap', icon: Database, color: 'blue' },
          { title: 'Inkremental', desc: 'Hanya perubahan data baru', icon: CloudUpload, color: 'green' },
          { title: 'Ekspor Cepat', desc: 'Snapshot ringkas transaksi', icon: FileText, color: 'purple' },
        ].map((option, index) => (
          <div key={index} className="bg-white rounded-2xl p-5 sm:p-6 card-shadow border border-slate-200/80">
            <div className={`w-11 h-11 rounded-xl ${getIconBg(option.color)} flex items-center justify-center mb-3 sm:mb-4`}>
              <option.icon className={`w-5 h-5 sm:w-6 sm:h-6 ${getTextColor(option.color)}`} />
            </div>
            <h3 className="text-base sm:text-lg font-bold text-slate-900 mb-1">{option.title}</h3>
            <p className="text-xs sm:text-sm text-slate-500 mb-4">{option.desc}</p>
            <button className="w-full bg-gradient-to-r from-cyan-500 to-sky-600 hover:from-cyan-600 hover:to-sky-700 text-white py-2.5 rounded-xl text-xs sm:text-sm font-semibold transition-colors active:scale-95">
              Mulai Backup
            </button>
          </div>
        ))}
      </div>

      {/* Backup List */}
      <div className="bg-white rounded-2xl card-shadow border border-slate-200/80 overflow-hidden">
        <div className="px-4 sm:px-6 py-3.5 border-b border-slate-100 flex flex-col sm:flex-row sm:items-center justify-between gap-2">
          <h3 className="text-xs sm:text-sm font-semibold text-slate-900">Riwayat Snapshot Backup</h3>
          <select className="border border-slate-200 rounded-lg px-3 py-1.5 text-xs bg-white text-slate-700">
            <option>Semua Outlet</option>
            <option>Semua Tipe</option>
          </select>
        </div>
        
        <div className="overflow-x-auto">
          <table className="w-full min-w-[580px]">
            <thead className="bg-slate-50 border-b border-slate-100">
              <tr>
                <th className="text-left px-4 sm:px-6 py-3 text-xs font-semibold text-slate-600 uppercase">Outlet</th>
                <th className="text-left px-4 sm:px-6 py-3 text-xs font-semibold text-slate-600 uppercase">Waktu Dibuat</th>
                <th className="text-left px-4 sm:px-6 py-3 text-xs font-semibold text-slate-600 uppercase">Tipe</th>
                <th className="text-right px-4 sm:px-6 py-3 text-xs font-semibold text-slate-600 uppercase">Ukuran</th>
                <th className="text-right px-4 sm:px-6 py-3 text-xs font-semibold text-slate-600 uppercase">Aksi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {backups.map((backup) => (
                <tr key={backup.id} className="hover:bg-slate-50">
                  <td className="px-4 sm:px-6 py-3.5">
                    <p className="font-medium text-xs sm:text-sm text-slate-900">{backup.outlet}</p>
                  </td>
                  <td className="px-4 sm:px-6 py-3.5 text-xs text-slate-500">{backup.date}</td>
                  <td className="px-4 sm:px-6 py-3.5">
                    <span className={`px-2.5 py-1 rounded-lg text-[11px] font-semibold ${getTypeBadge(backup.type)}`}>
                      {backup.type}
                    </span>
                  </td>
                  <td className="px-4 sm:px-6 py-3.5 text-right text-xs sm:text-sm font-medium text-slate-900">{backup.size}</td>
                  <td className="px-4 sm:px-6 py-3.5 text-right">
                    <div className="flex items-center justify-end gap-1 sm:gap-2">
                      <button 
                        onClick={() => alert(`Unduh backup: ${backup.outlet}`)}
                        className="p-1.5 sm:p-2 hover:bg-sky-50 rounded-lg transition-colors text-sky-600"
                        title="Unduh"
                      >
                        <CloudDownload className="w-4 h-4" />
                      </button>
                      <button 
                        onClick={() => alert(`Pulihkan data: ${backup.outlet}`)}
                        className="p-1.5 sm:p-2 hover:bg-emerald-50 rounded-lg transition-colors text-emerald-600"
                        title="Pulihkan"
                      >
                        <Database className="w-4 h-4" />
                      </button>
                      <button 
                        onClick={() => alert(`Hapus riwayat backup: ${backup.outlet}`)}
                        className="p-1.5 sm:p-2 hover:bg-rose-50 rounded-lg transition-colors text-rose-400"
                        title="Hapus"
                      >
                        <Trash2 className="w-4 h-4" />
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

function getIconBg(color: string) {
  const colors = {
    blue: 'bg-sky-50',
    green: 'bg-emerald-50',
    purple: 'bg-indigo-50',
  };
  return colors[color as keyof typeof colors] || 'bg-sky-50';
}

function getTextColor(color: string) {
  const colors = {
    blue: 'text-sky-600',
    green: 'text-emerald-600',
    purple: 'text-indigo-600',
  };
  return colors[color as keyof typeof colors] || 'text-sky-600';
}

function getTypeBadge(type: string) {
  if (type.includes('Full')) return 'bg-sky-50 text-sky-600';
  if (type.includes('Incremental')) return 'bg-emerald-50 text-emerald-600';
  return 'bg-indigo-50 text-indigo-600';
}
