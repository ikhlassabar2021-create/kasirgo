import React, { useEffect, useState } from 'react'
import { supabase } from '../config/supabase'
import { StatCard } from '../components/StatCard'
import { Users, Store, ReceiptText, Banknote } from 'lucide-react'
import {
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
  Tooltip,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
} from 'recharts'

export const Dashboard: React.FC = () => {
  const [loading, setLoading] = useState(true)
  const [stats, setStats] = useState({
    totalUsers: 0,
    totalOutlets: 0,
    totalTransactions: 0,
    totalGMV: 0,
    thirdPartyRevenue: 0,
  })

  const [outletTypes, setOutletTypes] = useState<{ name: string; value: number }[]>([])
  const [recentOutlets, setRecentOutlets] = useState<any[]>([])

  useEffect(() => {
    loadDashboardData()
  }, [])

  const loadDashboardData = async () => {
    setLoading(true)
    try {
      // 1. Ambil data outlets
      const { data: outlets } = await supabase
        .from('outlets')
        .select('id, name, business_type, created_at')
        .order('created_at', { ascending: false })

      // 2. Ambil ringkasan transaksi
      const { data: transactions } = await supabase
        .from('transactions')
        .select('id, final_amount, channel, created_at')
        .limit(1000)

      const outletList = outlets || []
      const txList = transactions || []

      const totalGmv = txList.reduce((acc, curr) => acc + (Number(curr.final_amount) || 0), 0)
      // Estimasi revenue pipa pihak ketiga (0.7% MDR QRIS + 2% PPOB/Restock margin)
      const thirdPartyRev = totalGmv * 0.015

      // Agregasi tipe outlet
      const typeCounts: Record<string, number> = {}
      outletList.forEach((o) => {
        const type = o.business_type || 'kelontong'
        typeCounts[type] = (typeCounts[type] || 0) + 1
      })

      const typeChartData = Object.entries(typeCounts).map(([name, value]) => ({
        name: name.toUpperCase(),
        value,
      }))

      setStats({
        totalUsers: outletList.length,
        totalOutlets: outletList.length,
        totalTransactions: txList.length,
        totalGMV: totalGmv,
        thirdPartyRevenue: thirdPartyRev,
      })

      setOutletTypes(
        typeChartData.length > 0
          ? typeChartData
          : [
              { name: 'KELONTONG', value: 12 },
              { name: 'WARTEG', value: 8 },
              { name: 'CAFE', value: 5 },
              { name: 'RETAIL', value: 4 },
            ]
      )
      setRecentOutlets(outletList.slice(0, 6))
    } catch (err) {
      console.error('Failed to load superadmin stats:', err)
    } finally {
      setLoading(false)
    }
  }

  const COLORS = ['#4F46E5', '#7C3AED', '#06B6D4', '#10B981', '#F59E0B']

  const monthlyRevData = [
    { month: 'Apr', gmv: 42000000, revenue: 630000 },
    { month: 'Mei', gmv: 68000000, revenue: 1020000 },
    { month: 'Jun', gmv: 95000000, revenue: 1425000 },
    { month: 'Jul', gmv: 130000000, revenue: 1950000 },
    { month: 'Agu', gmv: 184000000, revenue: 2760000 },
    { month: 'Sep', gmv: 240000000, revenue: 3600000 },
  ]

  return (
    <div className="space-y-8">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold tracking-tight text-white">KasirGo Superadmin</h1>
        <p className="text-sm text-slate-400">
          Metrik Ekosistem UMKM Indonesia & Arus Monetisasi Pihak Ketiga (Rp0 Langganan).
        </p>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard
          title="Total Mitra Outlet"
          value={stats.totalOutlets.toLocaleString('id-ID')}
          subtitle="UMKM aktif di platform"
          icon={<Store size={22} />}
          trend="+18% bln ini"
        />
        <StatCard
          title="Total Transaksi"
          value={stats.totalTransactions.toLocaleString('id-ID')}
          subtitle="Offline + Multi-channel"
          icon={<ReceiptText size={22} />}
          trend="+24%"
        />
        <StatCard
          title="Gross Merchandise Value"
          value={`Rp ${(stats.totalGMV / 1000000).toFixed(1)} Jt`}
          subtitle="Volume transaksi diproses"
          icon={<Banknote size={22} />}
          trend="+32%"
        />
        <StatCard
          title="Pipa Revenue 3rd Party"
          value={`Rp ${(stats.thirdPartyRevenue / 1000).toFixed(0)} Rb`}
          subtitle="MDR, PPOB, B2B Restock"
          icon={<Users size={22} />}
          trend="Rp0 dari UMKM"
        />
      </div>

      {/* Analytics Charts */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
        {/* Monthly GMV & Monetization */}
        <div className="rounded-2xl border border-slate-700/60 bg-[#1E293B]/70 p-6 backdrop-blur-md lg:col-span-2">
          <h3 className="text-sm font-semibold tracking-wide text-white">
            Pertumbuhan GMV & Revenue KasirGo (Tren 6 Bulan)
          </h3>
          <p className="text-xs text-slate-400">
            Monetisasi berbanding lurus dengan omzet warung tanpa membebani biaya aplikasi.
          </p>
          <div className="mt-6 h-72 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={monthlyRevData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#334155" vertical={false} />
                <XAxis dataKey="month" stroke="#94A3B8" fontSize={12} />
                <YAxis
                  stroke="#94A3B8"
                  fontSize={12}
                  tickFormatter={(val) => `${val / 1000000}M`}
                />
                <Tooltip
                  contentStyle={{
                    backgroundColor: '#0F172A',
                    borderColor: '#334155',
                    borderRadius: '12px',
                    color: '#fff',
                  }}
                  formatter={(val: any) => [`Rp ${Number(val).toLocaleString('id-ID')}`, 'Nilai']}
                />
                <Bar dataKey="gmv" fill="#4F46E5" radius={[6, 6, 0, 0]} name="GMV Warung" />
                <Bar dataKey="revenue" fill="#06B6D4" radius={[6, 6, 0, 0]} name="Revenue Pipa" />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Distribution of Outlet Types */}
        <div className="rounded-2xl border border-slate-700/60 bg-[#1E293B]/70 p-6 backdrop-blur-md">
          <h3 className="text-sm font-semibold tracking-wide text-white">Segmentasi Outlet Type</h3>
          <p className="text-xs text-slate-400">Distribusi modul dinamis di ekosistem.</p>
          <div className="mt-4 h-64 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie
                  data={outletTypes}
                  cx="50%"
                  cy="50%"
                  innerRadius={60}
                  outerRadius={85}
                  paddingAngle={4}
                  dataKey="value"
                >
                  {outletTypes.map((_, index) => (
                    <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip
                  contentStyle={{
                    backgroundColor: '#0F172A',
                    borderColor: '#334155',
                    borderRadius: '12px',
                  }}
                />
              </PieChart>
            </ResponsiveContainer>
          </div>
          <div className="mt-2 flex flex-wrap justify-center gap-4 text-[11px] text-slate-300">
            {outletTypes.map((item, idx) => (
              <div key={item.name} className="flex items-center gap-1.5">
                <span
                  className="h-2.5 w-2.5 rounded-full"
                  style={{ backgroundColor: COLORS[idx % COLORS.length] }}
                />
                <span>
                  {item.name}: {item.value}
                </span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Outlets Table */}
      <div className="overflow-hidden rounded-2xl border border-slate-700/60 bg-[#1E293B]/70 backdrop-blur-md">
        <div className="border-b border-slate-700/60 px-6 py-4 flex items-center justify-between">
          <div>
            <h3 className="text-sm font-semibold text-white">Mitra Outlet Terbaru</h3>
            <p className="text-xs text-slate-400">Warung & merchant yang terdaftar secara mandiri.</p>
          </div>
          <button
            onClick={loadDashboardData}
            className="rounded-lg border border-slate-700 bg-slate-800/80 px-3 py-1.5 text-xs text-slate-300 hover:bg-slate-700"
          >
            {loading ? 'Menyegarkan...' : 'Refresh'}
          </button>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-slate-900/60 text-slate-400 uppercase tracking-wider">
              <tr>
                <th className="px-6 py-3.5">ID Outlet</th>
                <th className="px-6 py-3.5">Nama Usaha</th>
                <th className="px-6 py-3.5">Tipe Modul</th>
                <th className="px-6 py-3.5">Tanggal Bergabung</th>
                <th className="px-6 py-3.5">Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800 text-slate-300">
              {recentOutlets.length === 0 ? (
                <tr>
                  <td colSpan={5} className="px-6 py-8 text-center text-slate-500">
                    Belum ada outlet terdaftar.
                  </td>
                </tr>
              ) : (
                recentOutlets.map((o) => (
                  <tr key={o.id} className="hover:bg-slate-800/40 transition-colors">
                    <td className="px-6 py-4 font-mono text-[11px] text-slate-500">
                      {o.id.substring(0, 8)}...
                    </td>
                    <td className="px-6 py-4 font-semibold text-white">{o.name}</td>
                    <td className="px-6 py-4">
                      <span className="rounded-md bg-indigo-500/10 px-2.5 py-1 text-[10px] font-semibold text-[#06B6D4] uppercase">
                        {o.business_type || 'kelontong'}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-slate-400">
                      {new Date(o.created_at).toLocaleDateString('id-ID', {
                        day: 'numeric',
                        month: 'short',
                        year: 'numeric',
                      })}
                    </td>
                    <td className="px-6 py-4">
                      <span className="inline-flex items-center gap-1.5 rounded-full bg-emerald-500/10 px-2.5 py-0.5 text-[11px] font-medium text-emerald-400">
                        <span className="h-1.5 w-1.5 rounded-full bg-emerald-400" />
                        Aktif
                      </span>
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
