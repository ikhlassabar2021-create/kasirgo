import React, { useEffect, useState } from 'react'
import { supabase } from '../config/supabase'
import { Search, UserCheck, ShieldAlert, LogIn } from 'lucide-react'

export const UsersPage: React.FC = () => {
  const [outlets, setOutlets] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [selectedType, setSelectedType] = useState('ALL')

  useEffect(() => {
    fetchUsers()
  }, [])

  const fetchUsers = async () => {
    setLoading(true)
    try {
      const { data } = await supabase
        .from('outlets')
        .select('id, name, business_type, address, phone, created_at')
        .order('created_at', { ascending: false })

      setOutlets(data || [])
    } catch (err) {
      console.error('Failed to fetch outlets:', err)
    } finally {
      setLoading(false)
    }
  }

  const handleImpersonate = (outlet: any) => {
    alert(
      `Mode Penyamaran (Impersonate):\nAnda masuk ke session outlet: ${outlet.name} (ID: ${outlet.id})\nRedirecting ke mobile POS dashboard...`
    )
    window.open(`https://8080-efbfe193ef269dd3.monkeycode-ai.live/owner`, '_blank')
  }

  const filtered = outlets.filter((o) => {
    const matchSearch =
      o.name?.toLowerCase().includes(search.toLowerCase()) ||
      o.phone?.includes(search) ||
      o.id?.includes(search)

    const matchType =
      selectedType === 'ALL' ||
      (o.business_type || 'kelontong').toLowerCase() === selectedType.toLowerCase()

    return matchSearch && matchType
  })

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-white">Kelola Mitra & Outlets</h1>
          <p className="text-sm text-slate-400">
            Daftar seluruh outlet UMKM di KasirGo OS beserta akses impersonate superadmin.
          </p>
        </div>
        <div className="flex items-center gap-3">
          <span className="rounded-xl border border-slate-700 bg-[#1E293B] px-4 py-2 text-xs font-semibold text-slate-300">
            Total: {outlets.length} Merchant
          </span>
        </div>
      </div>

      {/* Filter & Search Bar */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="relative w-full sm:w-80">
          <Search className="absolute left-3.5 top-3 text-slate-500" size={16} />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Cari nama warung, telepon, atau ID..."
            className="w-full rounded-xl border border-slate-700/80 bg-[#1E293B]/70 py-2.5 pl-10 pr-4 text-xs text-white placeholder-slate-500 focus:border-[#4F46E5] focus:outline-none"
          />
        </div>

        <div className="flex items-center gap-2 overflow-x-auto">
          {['ALL', 'kelontong', 'warteg', 'cafe', 'retail'].map((type) => (
            <button
              key={type}
              onClick={() => setSelectedType(type)}
              className={`rounded-lg px-3 py-1.5 text-xs font-medium transition-all ${
                selectedType === type
                  ? 'bg-[#4F46E5] text-white shadow-sm'
                  : 'border border-slate-700 bg-[#1E293B]/60 text-slate-400 hover:text-white'
              }`}
            >
              {type.toUpperCase()}
            </button>
          ))}
        </div>
      </div>

      {/* Table */}
      <div className="overflow-hidden rounded-2xl border border-slate-700/60 bg-[#1E293B]/70 backdrop-blur-md">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-slate-900/60 text-slate-400 uppercase tracking-wider">
              <tr>
                <th className="px-6 py-4">Nama Usaha</th>
                <th className="px-6 py-4">Tipe Modul</th>
                <th className="px-6 py-4">Telepon / Kontak</th>
                <th className="px-6 py-4">Tier Akses</th>
                <th className="px-6 py-4">Bergabung</th>
                <th className="px-6 py-4 text-right">Aksi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800 text-slate-300">
              {loading ? (
                <tr>
                  <td colSpan={6} className="px-6 py-12 text-center text-slate-500">
                    Memuat data mitra...
                  </td>
                </tr>
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={6} className="px-6 py-12 text-center text-slate-500">
                    Tidak ditemukan outlet yang cocok.
                  </td>
                </tr>
              ) : (
                filtered.map((o) => (
                  <tr key={o.id} className="hover:bg-slate-800/40 transition-colors">
                    <td className="px-6 py-4">
                      <div className="font-semibold text-white">{o.name}</div>
                      <div className="font-mono text-[10px] text-slate-500">{o.id}</div>
                    </td>
                    <td className="px-6 py-4">
                      <span className="rounded-md bg-indigo-500/10 px-2.5 py-1 text-[10px] font-semibold uppercase text-[#06B6D4]">
                        {o.business_type || 'kelontong'}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-slate-400">{o.phone || '-'}</td>
                    <td className="px-6 py-4">
                      <span className="inline-flex items-center gap-1 rounded-full bg-emerald-500/10 px-2.5 py-0.5 text-[10px] font-semibold text-emerald-400">
                        <UserCheck size={12} />
                        Gratis Selamanya
                      </span>
                    </td>
                    <td className="px-6 py-4 text-slate-400">
                      {new Date(o.created_at).toLocaleDateString('id-ID', {
                        day: 'numeric',
                        month: 'short',
                        year: 'numeric',
                      })}
                    </td>
                    <td className="px-6 py-4 text-right">
                      <div className="flex items-center justify-end gap-2">
                        <button
                          onClick={() => handleImpersonate(o)}
                          className="flex items-center gap-1.5 rounded-lg bg-indigo-600/80 px-3 py-1.5 text-[11px] font-semibold text-white transition-all hover:bg-indigo-600"
                        >
                          <LogIn size={13} />
                          Impersonate
                        </button>
                        <button
                          onClick={() => alert(`Status outlet ${o.name} diamankan.`)}
                          className="rounded-lg border border-slate-700 bg-slate-800 p-1.5 text-slate-400 hover:text-rose-400"
                          title="Suspend/Inspect"
                        >
                          <ShieldAlert size={14} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}
