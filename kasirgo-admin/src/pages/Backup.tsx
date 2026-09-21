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
    <div className="p-3 sm:p-6 max-w-[1920px] mx-auto fade-in">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-6">
        <div>
          <h1 className="text-xl sm:text-2xl font-bold text-gray-800 mb-1">Backup & Pemulihan Data</h1>
          <p className="text-xs sm:text-sm text-gray-500">Kelola snapshot database dan pemulihan data outlet</p>
        </div>
        
        <button 
          onClick={() => alert('Modal Buat Backup Baru')}
          className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2.5 sm:px-5 sm:py-3 rounded-xl font-semibold text-xs sm:text-sm flex items-center justify-center gap-2 shadow-md shadow-blue-600/20 active:scale-95 transition self-start sm:self-auto"
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
          <div key={index} className={`bg-gradient-to-br ${getGradient(option.color)} rounded-[20px] sm:rounded-[24px] p-5 sm:p-6 card-shadow`}>
            <option.icon className={`w-8 h-8 sm:w-10 sm:h-10 mb-3 sm:mb-4 ${getTextColor(option.color)}`} />
            <h3 className="text-base sm:text-lg font-bold text-gray-800 mb-1">{option.title}</h3>
            <p className="text-xs sm:text-sm text-gray-600 mb-4">{option.desc}</p>
            <button className={`w-full ${getButtonClass(option.color)} py-2.5 rounded-xl text-xs sm:text-sm font-semibold transition-colors active:scale-95`}>
              Mulai Backup
            </button>
          </div>
        ))}
      </div>

      {/* Backup List */}
      <div className="bg-white rounded-[20px] sm:rounded-[24px] card-shadow border border-gray-100 overflow-hidden">
        <div className="px-4 sm:px-6 py-3.5 border-b border-gray-100 flex flex-col sm:flex-row sm:items-center justify-between gap-2">
          <h3 className="text-xs sm:text-sm font-semibold text-gray-800">Riwayat Snapshot Backup</h3>
          <select className="border border-gray-200 rounded-lg px-3 py-1.5 text-xs bg-white">
            <option>Semua Outlet</option>
            <option>Semua Tipe</option>
          </select>
        </div>
        
        <div className="overflow-x-auto">
          <table className="w-full min-w-[580px]">
            <thead className="bg-gray-50 border-b border-gray-100">
              <tr>
                <th className="text-left px-4 sm:px-6 py-3 text-xs font-semibold text-gray-600 uppercase">Outlet</th>
                <th className="text-left px-4 sm:px-6 py-3 text-xs font-semibold text-gray-600 uppercase">Waktu Dibuat</th>
                <th className="text-left px-4 sm:px-6 py-3 text-xs font-semibold text-gray-600 uppercase">Tipe</th>
                <th className="text-right px-4 sm:px-6 py-3 text-xs font-semibold text-gray-600 uppercase">Ukuran</th>
                <th className="text-right px-4 sm:px-6 py-3 text-xs font-semibold text-gray-600 uppercase">Aksi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {backups.map((backup) => (
                <tr key={backup.id} className="hover:bg-gray-50">
                  <td className="px-4 sm:px-6 py-3.5">
                    <p className="font-medium text-xs sm:text-sm text-gray-800">{backup.outlet}</p>
                  </td>
                  <td className="px-4 sm:px-6 py-3.5 text-xs text-gray-600">{backup.date}</td>
                  <td className="px-4 sm:px-6 py-3.5">
                    <span className={`px-2.5 py-1 rounded-lg text-[11px] font-semibold ${getTypeBadge(backup.type)}`}>
                      {backup.type}
                    </span>
                  </td>
                  <td className="px-4 sm:px-6 py-3.5 text-right text-xs sm:text-sm font-medium text-gray-800">{backup.size}</td>
                  <td className="px-4 sm:px-6 py-3.5 text-right">
                    <div className="flex items-center justify-end gap-1 sm:gap-2">
                      <button 
                        onClick={() => alert(`Unduh backup: ${backup.outlet}`)}
                        className="p-1.5 sm:p-2 hover:bg-blue-50 rounded-lg transition-colors text-blue-600"
                        title="Unduh"
                      >
                        <CloudDownload className="w-4 h-4" />
                      </button>
                      <button 
                        onClick={() => alert(`Pulihkan data: ${backup.outlet}`)}
                        className="p-1.5 sm:p-2 hover:bg-green-50 rounded-lg transition-colors text-green-600"
                        title="Pulihkan"
                      >
                        <Database className="w-4 h-4" />
                      </button>
                      <button 
                        onClick={() => alert(`Hapus riwayat backup: ${backup.outlet}`)}
                        className="p-1.5 sm:p-2 hover:bg-red-50 rounded-lg transition-colors text-red-400"
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

function getGradient(color: string) {
  const gradients = {
    blue: 'from-blue-500 to-blue-600',
    green: 'from-green-500 to-green-600',
    purple: 'from-purple-500 to-purple-600',
  };
  return gradients[color as keyof typeof gradients] || 'from-blue-500 to-blue-600';
}

function getTextColor(color: string) {
  const colors = {
    blue: 'text-white',
    green: 'text-white',
    purple: 'text-white',
  };
  return colors[color as keyof typeof colors] || 'text-white';
}

function getButtonClass(color: string) {
  const buttons = {
    blue: 'bg-white text-blue-600 hover:bg-blue-50',
    green: 'bg-white text-green-600 hover:bg-green-50',
    purple: 'bg-white text-purple-600 hover:bg-purple-50',
  };
  return buttons[color as keyof typeof buttons] || 'bg-white text-blue-600 hover:bg-blue-50';
}

function getTypeBadge(type: string) {
  if (type.includes('Full')) return 'bg-blue-50 text-blue-600';
  if (type.includes('Incremental')) return 'bg-green-50 text-green-600';
  return 'bg-purple-50 text-purple-600';
}
