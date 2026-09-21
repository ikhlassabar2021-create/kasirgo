import { TrendingUp, TrendingDown, ArrowUpRight, ArrowDownRight } from 'lucide-react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts';

const revenueData = [
  { month: 'Jan', revenue: 4500, transactions: 120 },
  { month: 'Feb', revenue: 5200, transactions: 145 },
  { month: 'Mar', revenue: 4800, transactions: 132 },
  { month: 'Apr', revenue: 6200, transactions: 167 },
  { month: 'May', revenue: 5800, transactions: 154 },
  { month: 'Jun', revenue: 6700, transactions: 189 },
  { month: 'Jul', revenue: 7200, transactions: 201 },
];

const tierDistribution = [
  { name: 'Free', value: 45, color: '#94a3b8' },
  { name: 'Basic', value: 30, color: '#3b82f6' },
  { name: 'Premium', value: 15, color: '#8b5cf6' },
  { name: 'Pro', value: 10, color: '#f59e0b' },
];

export function RevenuePage() {
  const metrics = [
    { title: 'Total Pendapatan', value: 'Rp 38.4M', change: '+12.5%', isPositive: true },
    { title: 'Rata-rata Nota', value: 'Rp 45K', change: '+5.2%', isPositive: true },
    { title: 'Langganan Aktif', value: '847', change: '+156', isPositive: true },
    { title: 'Churn Rate', value: '3.2%', change: '-0.8%', isPositive: true },
  ];

  return (
    <div className="p-3 sm:p-6 max-w-[1920px] mx-auto fade-in">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-6">
        <div>
          <h1 className="text-xl sm:text-2xl font-bold text-gray-800 mb-1">Analisis Finansial & Omset</h1>
          <p className="text-xs sm:text-sm text-gray-500">Pantau performa pendapatan platform & outlet mitra</p>
        </div>
        
        <select className="border border-gray-200 rounded-xl px-3 py-2 text-xs sm:text-sm bg-white hover:border-gray-300 focus:outline-none self-start sm:self-auto">
          <option>7 Hari Terakhir</option>
          <option>30 Hari Terakhir</option>
          <option>90 Hari Terakhir</option>
          <option>Tahun Ini</option>
        </select>
      </div>

      {/* Metrics Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4 mb-6">
        {metrics.map((metric, index) => (
          <div key={index} className="bg-white rounded-[20px] sm:rounded-[24px] p-4 sm:p-6 card-shadow border border-gray-100">
            <div className="flex items-center justify-between mb-2">
              <p className="text-xs text-gray-500">{metric.title}</p>
              <span className={`flex items-center gap-1 text-xs font-semibold ${
                metric.isPositive ? 'text-green-600' : 'text-red-600'
              }`}>
                {metric.isPositive ? <TrendingUp className="w-3.5 h-3.5" /> : <TrendingDown className="w-3.5 h-3.5" />}
                {metric.change}
              </span>
            </div>
            <p className="metric-number text-2xl sm:text-3xl font-black text-gray-800">{metric.value}</p>
          </div>
        ))}
      </div>

      {/* Charts Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4 sm:gap-6 mb-6">
        {/* Revenue Line Chart */}
        <div className="lg:col-span-2 bg-white rounded-[20px] sm:rounded-[24px] p-4 sm:p-6 card-shadow border border-gray-100">
          <h3 className="text-xs sm:text-sm font-semibold text-gray-800 mb-4">Tren Pertumbuhan Pendapatan</h3>
          <div className="h-[240px] sm:h-[300px]">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={revenueData} margin={{ top: 10, right: 10, left: -25, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" vertical={false} />
                <XAxis dataKey="month" stroke="#94a3b8" fontSize={11} tickLine={false} />
                <YAxis stroke="#94a3b8" fontSize={11} tickLine={false} tickFormatter={(v) => `${v / 1000}k`} />
                <Tooltip 
                  contentStyle={{ backgroundColor: '#fff', border: '1px solid #e2e8f0', borderRadius: '12px', fontSize: '12px' }}
                  formatter={(value: number) => [`Rp ${value}K`, 'Revenue']}
                />
                <Line type="monotone" dataKey="revenue" stroke="#0284c7" strokeWidth={3} dot={{ fill: '#0284c7', r: 3 }} />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Tier Distribution Pie Chart */}
        <div className="bg-white rounded-[20px] sm:rounded-[24px] p-4 sm:p-6 card-shadow border border-gray-100">
          <h3 className="text-xs sm:text-sm font-semibold text-gray-800 mb-4">Distribusi Paket Pelanggan</h3>
          <div className="h-[200px] sm:h-[240px]">
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie
                  data={tierDistribution}
                  cx="50%"
                  cy="50%"
                  innerRadius={50}
                  outerRadius={85}
                  paddingAngle={5}
                  dataKey="value"
                >
                  {tierDistribution.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={entry.color} />
                  ))}
                </Pie>
                <Tooltip contentStyle={{ borderRadius: '12px', fontSize: '12px' }} />
              </PieChart>
            </ResponsiveContainer>
          </div>
          <div className="mt-3 space-y-1.5">
            {tierDistribution.map((tier) => (
              <div key={tier.name} className="flex items-center justify-between text-xs sm:text-sm">
                <div className="flex items-center gap-2">
                  <div className="w-2.5 h-2.5 rounded-full" style={{ backgroundColor: tier.color }} />
                  <span className="text-gray-600">{tier.name}</span>
                </div>
                <span className="font-semibold text-gray-800">{tier.value}%</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Monthly Breakdown Table */}
      <div className="bg-white rounded-[20px] sm:rounded-[24px] card-shadow border border-gray-100 overflow-hidden">
        <div className="px-4 sm:px-6 py-3.5 border-b border-gray-100">
          <h3 className="text-xs sm:text-sm font-semibold text-gray-800">Rincian Bulanan</h3>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full min-w-[520px]">
            <thead className="bg-gray-50 border-b border-gray-100">
              <tr>
                <th className="text-left px-4 sm:px-6 py-3 text-xs font-semibold text-gray-600 uppercase">Bulan</th>
                <th className="text-right px-4 sm:px-6 py-3 text-xs font-semibold text-gray-600 uppercase">Pendapatan</th>
                <th className="text-right px-4 sm:px-6 py-3 text-xs font-semibold text-gray-600 uppercase">Transaksi</th>
                <th className="text-right px-4 sm:px-6 py-3 text-xs font-semibold text-gray-600 uppercase">Rata-rata</th>
                <th className="text-center px-4 sm:px-6 py-3 text-xs font-semibold text-gray-600 uppercase">Pertumbuhan</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {revenueData.slice().reverse().map((data, index) => {
                const growth = index === revenueData.length - 1 ? null : 
                  ((data.revenue - revenueData[index + 1].revenue) / revenueData[index + 1].revenue * 100);
                
                return (
                  <tr key={index} className="hover:bg-gray-50">
                    <td className="px-4 sm:px-6 py-3.5 text-xs sm:text-sm font-medium text-gray-800">{data.month}</td>
                    <td className="px-4 sm:px-6 py-3.5 text-xs sm:text-sm text-right font-semibold text-gray-800">Rp {(data.revenue / 1000).toFixed(1)}K</td>
                    <td className="px-4 sm:px-6 py-3.5 text-xs sm:text-sm text-right text-gray-600">{data.transactions}</td>
                    <td className="px-4 sm:px-6 py-3.5 text-xs sm:text-sm text-right text-gray-600">Rp {(data.revenue / data.transactions).toFixed(0)}</td>
                    <td className="px-4 sm:px-6 py-3.5 text-center">
                      {growth !== null && (
                        <span className={`inline-flex items-center gap-1 text-xs font-semibold ${growth >= 0 ? 'text-green-600' : 'text-red-600'}`}>
                          {growth >= 0 ? <ArrowUpRight className="w-3 h-3" /> : <ArrowDownRight className="w-3 h-3" />}
                          {Math.abs(growth).toFixed(1)}%
                        </span>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
