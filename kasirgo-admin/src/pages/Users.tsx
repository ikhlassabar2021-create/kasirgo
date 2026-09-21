import { useState } from 'react';
import { Search, Plus, Edit2, Trash2, Eye, Shield, UserX } from 'lucide-react';

const mockUsers = [
  { id: 1, name: 'Budi Santoso', email: 'budi@warung.com', outlet: 'Warung Bakso Mbok Sum', tier: 'Basic', status: 'active', transactions: 847 },
  { id: 2, name: 'Siti Aminah', email: 'siti@warteg.com', outlet: 'Warteg Pak Joe', tier: 'Premium', status: 'active', transactions: 1234 },
  { id: 3, name: 'Ahmad Rizki', email: 'ahmad@cafe.com', outlet: 'Kopi Senja Cafe', tier: 'Pro', status: 'active', transactions: 567 },
  { id: 4, name: 'Dewi Lestari', email: 'dewi@retail.com', outlet: 'Minimarket Ceria', tier: 'Basic', status: 'suspended', transactions: 234 },
  { id: 5, name: 'Eko Prasetyo', email: 'eko@shop.com', outlet: 'Toko Elektronik', tier: 'Premium', status: 'active', transactions: 890 },
];

export function UsersPage() {
  const [searchTerm, setSearchTerm] = useState('');
  
  const filteredUsers = mockUsers.filter(user =>
    user.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    user.email.toLowerCase().includes(searchTerm.toLowerCase()) ||
    user.outlet.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="p-3 sm:p-6 max-w-[1920px] mx-auto fade-in">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-6">
        <div>
          <h1 className="text-xl sm:text-2xl font-bold text-gray-800 mb-1">Manajemen Pengguna & Staf</h1>
          <p className="text-xs sm:text-sm text-gray-500">Kelola akun pemilik outlet, kasir, dan hak akses staf</p>
        </div>
        
        <button 
          onClick={() => alert('Form Tambah Pengguna Baru')}
          className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2.5 sm:px-5 sm:py-3 rounded-xl font-semibold text-xs sm:text-sm flex items-center justify-center gap-2 shadow-md shadow-blue-600/20 active:scale-95 transition self-start sm:self-auto"
        >
          <Plus className="w-4 h-4" />
          Tambah Pengguna
        </button>
      </div>

      {/* Search & Filter */}
      <div className="bg-white rounded-[20px] sm:rounded-[24px] p-4 sm:p-6 card-shadow border border-gray-100 mb-6">
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3 sm:gap-4">
          <div className="relative flex-1">
            <Search className="absolute left-4 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
            <input
              type="text"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              placeholder="Cari nama, email, atau warung..."
              className="w-full pl-12 pr-4 py-2.5 sm:py-3 text-sm bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-600 outline-none"
            />
          </div>
          
          <select className="border border-gray-200 rounded-xl px-4 py-2.5 sm:py-3 text-sm bg-white text-gray-700">
            <option>Semua Status</option>
            <option>Aktif</option>
            <option>Ditangguhkan</option>
          </select>
        </div>
      </div>

      {/* Users Table */}
      <div className="bg-white rounded-[20px] sm:rounded-[24px] card-shadow border border-gray-100 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[640px]">
            <thead className="bg-gray-50 border-b border-gray-100">
              <tr>
                <th className="text-left px-4 sm:px-6 py-3.5 text-xs font-semibold text-gray-600 uppercase tracking-wide">Pengguna</th>
                <th className="text-left px-4 sm:px-6 py-3.5 text-xs font-semibold text-gray-600 uppercase tracking-wide">Outlet</th>
                <th className="text-left px-4 sm:px-6 py-3.5 text-xs font-semibold text-gray-600 uppercase tracking-wide">Tier</th>
                <th className="text-left px-4 sm:px-6 py-3.5 text-xs font-semibold text-gray-600 uppercase tracking-wide">Transaksi</th>
                <th className="text-left px-4 sm:px-6 py-3.5 text-xs font-semibold text-gray-600 uppercase tracking-wide">Status</th>
                <th className="text-right px-4 sm:px-6 py-3.5 text-xs font-semibold text-gray-600 uppercase tracking-wide">Aksi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {filteredUsers.map((user) => (
                <tr key={user.id} className="hover:bg-gray-50 transition-colors">
                  <td className="px-4 sm:px-6 py-4">
                    <div className="flex items-center gap-3">
                      <div className="w-9 h-9 sm:w-10 sm:h-10 bg-blue-100 rounded-full flex items-center justify-center shrink-0">
                        <span className="text-xs sm:text-sm font-semibold text-blue-600">
                          {user.name.split(' ').map(n => n[0]).join('').slice(0, 2)}
                        </span>
                      </div>
                      <div className="min-w-0">
                        <p className="font-medium text-sm text-gray-800 truncate">{user.name}</p>
                        <p className="text-xs text-gray-400 truncate">{user.email}</p>
                      </div>
                    </div>
                  </td>
                  <td className="px-4 sm:px-6 py-4 text-xs sm:text-sm text-gray-600">{user.outlet}</td>
                  <td className="px-4 sm:px-6 py-4">
                    <span className={`px-2.5 py-1 rounded-lg text-xs font-semibold ${
                      user.tier === 'Free' ? 'bg-gray-100 text-gray-600' :
                      user.tier === 'Basic' ? 'bg-blue-50 text-blue-600' :
                      user.tier === 'Premium' ? 'bg-purple-50 text-purple-600' :
                      'bg-orange-50 text-orange-600'
                    }`}>
                      {user.tier}
                    </span>
                  </td>
                  <td className="px-4 sm:px-6 py-4 text-xs sm:text-sm text-gray-600">{user.transactions.toLocaleString()}</td>
                  <td className="px-4 sm:px-6 py-4">
                    <span className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold ${
                      user.status === 'active' 
                        ? 'bg-green-50 text-green-600' 
                        : 'bg-red-50 text-red-600'
                    }`}>
                      <span className={`w-1.5 h-1.5 rounded-full ${
                        user.status === 'active' ? 'bg-green-500' : 'bg-red-500'
                      }`} />
                      {user.status === 'active' ? 'Active' : 'Suspended'}
                    </span>
                  </td>
                  <td className="px-4 sm:px-6 py-4 text-right">
                    <div className="flex items-center justify-end gap-1 sm:gap-2">
                      <button 
                        onClick={() => alert(`Detail Pengguna: ${user.name}`)}
                        className="p-1.5 sm:p-2 hover:bg-gray-100 rounded-lg transition-colors text-blue-600"
                        title="Lihat Detail"
                      >
                        <Eye className="w-4 h-4" />
                      </button>
                      <button 
                        onClick={() => alert(`Edit: ${user.name}`)}
                        className="p-1.5 sm:p-2 hover:bg-gray-100 rounded-lg transition-colors text-gray-600"
                        title="Ubah"
                      >
                        <Edit2 className="w-4 h-4" />
                      </button>
                      <button 
                        onClick={() => alert(`Tangguhkan: ${user.name}`)}
                        className="p-1.5 sm:p-2 hover:bg-red-50 rounded-lg transition-colors text-red-600"
                        title="Tangguhkan"
                      >
                        {user.status === 'active' ? <Shield className="w-4 h-4" /> : <UserX className="w-4 h-4" />}
                      </button>
                      <button 
                        onClick={() => alert(`Hapus: ${user.name}`)}
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
