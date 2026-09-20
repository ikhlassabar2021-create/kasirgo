import React, { useState } from 'react'
import { StatCard } from '../components/StatCard'
import { Share2, Users, Wallet, Copy, Check } from 'lucide-react'

export const AffiliatesPage: React.FC = () => {
  const [copied, setCopied] = useState<string | null>(null)

  const affiliates = [
    {
      id: 'aff_01',
      name: 'Budi Santoso',
      code: 'WARUNGBUDI',
      referrals: 38,
      activeOutlets: 32,
      commissionEarned: 1900000,
      status: 'active',
    },
    {
      id: 'aff_02',
      name: 'Komunitas UMKM Madura',
      code: 'MADURAJAYA',
      referrals: 114,
      activeOutlets: 98,
      commissionEarned: 5700000,
      status: 'active',
    },
    {
      id: 'aff_03',
      name: 'Rian Kuliner BDG',
      code: 'WARTEGBDG',
      referrals: 22,
      activeOutlets: 19,
      commissionEarned: 1100000,
      status: 'active',
    },
  ]

  const handleCopy = (code: string) => {
    navigator.clipboard.writeText(`https://kasirgo.online/join?ref=${code}`)
    setCopied(code)
    setTimeout(() => setCopied(null), 2000)
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight text-white">Program Afiliasi KasirGo</h1>
        <p className="text-sm text-slate-400">
          Insentif komisi mitra & komunitas untuk percepatan ekspansi akuisisi warung Rp0.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-5 sm:grid-cols-3">
        <StatCard
          title="Total Afiliator Aktif"
          value="48 Mitra"
          subtitle="Komunitas & pegiat UMKM"
          icon={<Share2 size={22} />}
          trend="+8 bln ini"
        />
        <StatCard
          title="Warung Terakuisisi"
          value="412 Warung"
          subtitle="Via kode referral unik"
          icon={<Users size={22} />}
          trend="82% Retensi 30h"
        />
        <StatCard
          title="Komisi Dibayarkan"
          value="Rp 24,6 Jt"
          subtitle="Bagi hasil transaksi pipa"
          icon={<Wallet size={22} />}
          trend="Siklus Bulanan"
        />
      </div>

      <div className="overflow-hidden rounded-2xl border border-slate-700/60 bg-[#1E293B]/70 backdrop-blur-md">
        <div className="border-b border-slate-700/60 px-6 py-4 flex items-center justify-between">
          <h3 className="text-sm font-semibold text-white">Daftar Partner Afiliasi</h3>
          <button
            onClick={() => alert('Form pendaftaran afiliator baru dibuka')}
            className="flex items-center gap-1.5 rounded-lg bg-[#4F46E5] px-3.5 py-1.5 text-xs font-semibold text-white shadow-sm hover:bg-indigo-600"
          >
            + Tambah Afiliator
          </button>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-slate-900/60 text-slate-400 uppercase tracking-wider">
              <tr>
                <th className="px-6 py-4">Nama Mitra</th>
                <th className="px-6 py-4">Kode Referral</th>
                <th className="px-6 py-4">Referral Warung</th>
                <th className="px-6 py-4">Total Komisi</th>
                <th className="px-6 py-4">Status</th>
                <th className="px-6 py-4 text-right">Link</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800 text-slate-300">
              {affiliates.map((a) => (
                <tr key={a.id} className="hover:bg-slate-800/40 transition-colors">
                  <td className="px-6 py-4 font-semibold text-white">{a.name}</td>
                  <td className="px-6 py-4">
                    <span className="rounded-md bg-indigo-500/10 px-2 py-1 font-mono text-[11px] font-bold text-[#06B6D4]">
                      {a.code}
                    </span>
                  </td>
                  <td className="px-6 py-4">
                    {a.referrals} diajak ({a.activeOutlets} aktif)
                  </td>
                  <td className="px-6 py-4 font-semibold text-emerald-400">
                    Rp {a.commissionEarned.toLocaleString('id-ID')}
                  </td>
                  <td className="px-6 py-4">
                    <span className="rounded-full bg-emerald-500/10 px-2 py-0.5 text-[10px] font-semibold text-emerald-400">
                      Aktif
                    </span>
                  </td>
                  <td className="px-6 py-4 text-right">
                    <button
                      onClick={() => handleCopy(a.code)}
                      className="inline-flex items-center gap-1 rounded-lg border border-slate-700 bg-slate-800/80 px-2.5 py-1 text-[11px] text-slate-300 hover:text-white"
                    >
                      {copied === a.code ? <Check size={12} className="text-emerald-400" /> : <Copy size={12} />}
                      {copied === a.code ? 'Tersalin' : 'Copy Link'}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}
