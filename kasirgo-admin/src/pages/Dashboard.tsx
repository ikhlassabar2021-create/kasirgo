import { BarChart3, Users, Store, Receipt, Sparkles, TrendingUp, ChevronRight } from 'lucide-react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';

const mockRevenueData = [
  { month: 'Jan', value: 4500 },
  { month: 'Feb', value: 5200 },
  { month: 'Mar', value: 4800 },
  { month: 'Apr', value: 6200 },
  { month: 'May', value: 5800 },
  { month: 'Jun', value: 6700 },
  { month: 'Jul', value: 7200 },
];

export function Dashboard() {
  const metrics = [
    {
      title: 'TOTAL USERS',
      value: '1,284',
      percentage: '+12.5%',
      isPositive: true,
      icon: Users,
      iconColor: 'text-sky-600',
      bgColor: 'bg-sky-50',
    },
    {
      title: 'ACTIVE OUTLETS',
      value: '847',
      percentage: '+8.2%',
      isPositive: true,
      icon: Store,
      iconColor: 'text-blue-600',
      bgColor: 'bg-blue-50',
    },
    {
      title: 'TRANSACTIONS',
      value: '12,847',
      percentage: '-3.4%',
      isPositive: false,
      icon: Receipt,
      iconColor: 'text-rose-600',
      bgColor: 'bg-rose-50',
    },
    {
      title: 'REVENUE',
      value: 'Rp 128J',
      percentage: '+21.4%',
      isPositive: true,
      icon: BarChart3,
      iconColor: 'text-cyan-600',
      bgColor: 'bg-cyan-50',
    },
  ];

  return (
    <div className="space-y-4 max-w-[1100px] mx-auto text-slate-800">
      {/* Header Profile Outlet / Superadmin - Centennial Clean White & Ocean Blue Gradient */}
      <div className="bg-white p-4 sm:p-5 rounded-2xl border border-slate-200/80 shadow-sm flex flex-col sm:flex-row sm:items-center justify-between gap-3 relative overflow-hidden">
        <div className="flex items-center gap-3 relative z-10">
          <div className="w-11 h-11 sm:w-12 sm:h-12 rounded-xl bg-gradient-to-br from-cyan-500 to-sky-600 p-0.5 shadow-md shadow-sky-500/20 shrink-0">
            <div className="w-full h-full bg-white rounded-[10px] flex items-center justify-center text-sky-600 font-extrabold text-base sm:text-lg">
              KG
            </div>
          </div>
          <div className="min-w-0">
            <div className="flex items-center gap-2 flex-wrap">
              <h1 className="text-base sm:text-lg font-bold text-slate-900 tracking-tight truncate">
                KasirGo Ekosistem Superadmin
              </h1>
              <span className="px-2 py-0.5 bg-sky-50 text-sky-700 border border-sky-200/80 rounded-full text-[10px] font-bold tracking-wide shrink-0">
                SISTEM ONLINE
              </span>
            </div>
            <p className="text-slate-500 text-xs mt-0.5 truncate">
              Pusat Kendali Pengguna & Merchant • Desain Centennial
            </p>
          </div>
        </div>

        {/* Quick Actions Header */}
        <div className="flex items-center gap-2">
          <a 
            href="/owner" 
            className="flex items-center justify-center gap-1.5 px-3.5 py-2 rounded-xl bg-gradient-to-r from-cyan-500 to-sky-600 hover:from-cyan-600 hover:to-sky-700 text-white font-semibold text-xs shadow-md shadow-sky-500/25 transition active:scale-95"
          >
            <Store className="w-3.5 h-3.5 shrink-0" />
            <span>Lihat Mode Owner</span>
          </a>
        </div>
      </div>

      {/* AI Co-Pilot Alert Banner */}
      <div className="bg-sky-50/60 border border-sky-200/70 p-3.5 sm:p-4 rounded-xl flex flex-col sm:flex-row items-start sm:items-center justify-between gap-2.5">
        <div className="flex items-start sm:items-center gap-2.5">
          <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-cyan-500 to-sky-600 flex items-center justify-center text-white shrink-0 shadow-sm">
            <Sparkles className="w-4 h-4 animate-pulse" />
          </div>
          <div>
            <div className="flex items-center gap-1.5">
              <h3 className="font-bold text-xs text-sky-950">Status Server & Pertumbuhan</h3>
              <span className="text-[9px] uppercase font-bold tracking-wider px-1.5 py-0.2 bg-sky-200/60 text-sky-800 rounded">Centennial Live</span>
            </div>
            <p className="text-[11px] text-slate-600 mt-0.5 leading-relaxed">
              Semua 847 outlet aktif berjalan normal dengan sinkronisasi SQLite lokal ke Supabase.
            </p>
          </div>
        </div>
        <button 
          onClick={() => alert('Semua integrasi database & API dalam kondisi prima.')}
          className="text-xs font-semibold bg-white hover:bg-sky-50 border border-sky-300/80 px-3 py-1.5 rounded-lg text-sky-800 transition flex items-center gap-1 shrink-0 w-full sm:w-auto justify-center shadow-sm"
        >
          Cek Kesehatan <ChevronRight className="w-3 h-3 text-sky-600" />
        </button>
      </div>

      {/* Market Overview Section - Ringkas & Fleksibel */}
      <section>
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-2.5 sm:gap-3.5">
          {metrics.map((metric, index) => (
            <div key={index} className="bg-white p-3.5 sm:p-4 rounded-xl border border-slate-200/80 shadow-sm hover:border-sky-300 transition duration-150">
              <div className="flex items-center justify-between mb-1.5">
                <span className="text-[10px] font-bold tracking-wider text-slate-400 uppercase">{metric.title}</span>
                <div className={`w-7 h-7 rounded-lg bg-gradient-to-br from-cyan-500 to-sky-600 text-white flex items-center justify-center shrink-0 shadow-sm`}>
                  <metric.icon className="w-3.5 h-3.5" />
                </div>
              </div>
              <div className="text-lg sm:text-xl font-extrabold text-slate-900 tracking-tight">{metric.value}</div>
              <div className="flex items-center gap-1 mt-1 text-[11px] font-semibold">
                <span className={metric.isPositive ? "text-emerald-600" : "text-rose-600"}>{metric.percentage}</span>
                <span className="text-slate-400 font-normal">vs bulan lalu</span>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* Quick Actions Section */}
      <section className="bg-white p-3.5 sm:p-4 rounded-2xl border border-slate-200/80 shadow-sm">
        <h2 className="text-xs font-bold text-slate-900 uppercase tracking-wider mb-2.5">AKSI CEPAT</h2>
        <div className="flex gap-2 overflow-x-auto pb-1 no-scrollbar">
          {[
            { label: 'Kelola Pengguna', icon: Users, href: '/users' },
            { label: 'Daftar Outlet', icon: Store, href: '/outlets' },
            { label: 'Laporan Revenue', icon: BarChart3, href: '/revenue' },
            { label: 'Program Referral', icon: TrendingUp, href: '/affiliates' },
          ].map((action, index) => {
            const Icon = action.icon;
            return (
              <a
                key={index}
                href={action.href}
                className="whitespace-nowrap px-3 py-2 rounded-xl bg-slate-50 hover:bg-sky-50 border border-slate-200 hover:border-sky-300 text-slate-700 hover:text-sky-700 transition duration-150 flex items-center gap-1.5 text-xs font-semibold active:scale-95 shrink-0"
              >
                <Icon className="w-3.5 h-3.5 text-sky-600" />
                {action.label}
              </a>
            );
          })}
        </div>
      </section>

      {/* Revenue Analytics Chart */}
      <section className="bg-white p-4 sm:p-5 rounded-2xl border border-slate-200/80 shadow-sm">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 mb-3">
          <div>
            <h2 className="text-sm sm:text-base font-bold text-slate-900">Tren Pendapatan Nasional</h2>
            <p className="text-xs text-slate-500">Pertumbuhan omset seluruh outlet KasirGo</p>
          </div>
          <select className="border border-slate-200 rounded-lg px-2.5 py-1 text-xs text-slate-700 bg-white hover:border-slate-300 focus:outline-none focus:ring-2 focus:ring-sky-500 self-start sm:self-auto">
            <option>7 Hari Terakhir</option>
            <option>30 Hari Terakhir</option>
            <option>90 Hari Terakhir</option>
          </select>
        </div>
        <div className="h-56 sm:h-64 w-full">
          <ResponsiveContainer width="100%" height="100%">
            <LineChart data={mockRevenueData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#e2e8f0" vertical={false} />
              <XAxis 
                dataKey="month" 
                stroke="#64748b"
                fontSize={10}
                tickMargin={8}
                tickLine={false}
              />
              <YAxis 
                stroke="#64748b"
                fontSize={10}
                tickLine={false}
                tickFormatter={(value) => `${value / 1000}k`}
              />
              <Tooltip 
                contentStyle={{
                  backgroundColor: '#0f172a',
                  border: 'none',
                  borderRadius: '10px',
                  color: '#fff',
                  boxShadow: '0 4px 12px rgba(0,0,0,0.15)',
                  fontSize: '11px'
                }}
                formatter={(value: any) => [`Rp ${value}K`, 'Revenue']}
              />
              <Line
                type="monotone"
                dataKey="value"
                stroke="#0284c7"
                strokeWidth={2.5}
                dot={{ fill: '#0284c7', r: 3 }}
                activeDot={{ r: 5 }}
              />
            </LineChart>
          </ResponsiveContainer>
        </div>
      </section>

      {/* Recent Outlets Grid */}
      <section>
        <div className="flex items-center justify-between mb-3">
          <h2 className="text-xs sm:text-sm font-bold text-slate-800 uppercase tracking-wider">OUTLET TERDAFTAR</h2>
          <a href="/outlets" className="text-sky-600 text-xs sm:text-sm font-semibold hover:underline cursor-pointer flex items-center gap-1">
            Lihat Semua
          </a>
        </div>
        
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-2.5 sm:gap-3.5">
          {[
            { name: 'Warung Bakso Mbok Sum', type: 'Kelontong', location: 'Jakarta Selatan', users: 5, progress: 75 },
            { name: 'Kopi Senja Cafe', type: 'Cafe', location: 'Bandung', users: 8, progress: 62 },
            { name: 'Tukang Bangunan Jaya', type: 'Retail', location: 'Surabaya', users: 12, progress: 88 },
            { name: 'Minimarket Ceria', type: 'Kelontong', location: 'Yogyakarta', users: 7, progress: 54 },
            { name: 'Indomaret Cabang 001', type: 'Retail', location: 'Medan', users: 9, progress: 71 },
            { name: 'Alfamart Pusat', type: 'Retail', location: 'Semarang', users: 11, progress: 67 },
          ].map((outlet, index) => (
            <div
              key={index}
              onClick={() => alert(`Detail outlet: ${outlet.name}`)}
              className="bg-white rounded-xl p-3.5 sm:p-4 border border-slate-200/80 hover:border-sky-300 shadow-sm transition-all duration-150 active:scale-[0.99] cursor-pointer"
            >
              <div className="flex items-center gap-2.5 mb-2.5">
                <div className={`w-9 h-9 rounded-xl flex items-center justify-center shrink-0 ${
                  outlet.type === 'Kelontong' ? 'bg-sky-50 text-sky-600' :
                  outlet.type === 'Cafe' ? 'bg-emerald-50 text-emerald-600' :
                  'bg-cyan-50 text-cyan-600'
                }`}>
                  <Store className="w-4 h-4" />
                </div>
                <div className="flex-1 min-w-0">
                  <h3 className="text-xs sm:text-sm font-bold text-slate-800 truncate">{outlet.name}</h3>
                  <p className="text-[11px] text-slate-400 truncate">{outlet.type} • {outlet.location}</p>
                </div>
              </div>
              
              <div className="space-y-1">
                <div className="flex justify-between text-[11px]">
                  <span className="text-slate-500">Staf Aktif</span>
                  <span className="font-semibold text-slate-800">{outlet.users} Staf</span>
                </div>
                <div className="w-full bg-slate-100 rounded-lg h-1.5 overflow-hidden">
                  <div 
                    className={`h-1.5 rounded-full ${
                      outlet.progress >= 80 ? 'bg-emerald-500' :
                      outlet.progress >= 60 ? 'bg-sky-500' :
                      'bg-cyan-500'
                    }`}
                    style={{ width: `${outlet.progress}%` }}
                  />
                </div>
              </div>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}
