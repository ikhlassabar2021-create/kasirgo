import { useState } from 'react';
import { 
  TrendingUp, 
  Receipt, 
  Package, 
  Plus, 
  QrCode, 
  Sparkles, 
  ChevronRight, 
  AlertTriangle,
  ArrowUpRight,
  ShieldCheck,
  Zap,
  Users
} from 'lucide-react';
import { ResponsiveContainer, AreaChart, Area, XAxis, YAxis, Tooltip, CartesianGrid } from 'recharts';

const hourlySales = [
  { time: '08:00', total: 120000 },
  { time: '10:00', total: 450000 },
  { time: '12:00', total: 980000 },
  { time: '14:00', total: 620000 },
  { time: '16:00', total: 840000 },
  { time: '18:00', total: 1450000 },
  { time: '20:00', total: 1100000 },
];

const topProducts = [
  { name: 'Kopi Susu Gula Aren', category: 'Minuman', sold: 142, revenue: 'Rp 2.550.000', stock: 45 },
  { name: 'Bakso Super Urat', category: 'Makanan', sold: 98, revenue: 'Rp 2.450.000', stock: 12 },
  { name: 'Es Teh Manis Jumbo', category: 'Minuman', sold: 215, revenue: 'Rp 1.075.000', stock: 80 },
  { name: 'Mie Ayam Pangsit', category: 'Makanan', sold: 76, revenue: 'Rp 1.368.000', stock: 8 },
];

export function OwnerDashboard() {
  const [_activeTab, _setActiveTab] = useState<'ringkasan' | 'produk' | 'ai'>('ringkasan');

  return (
    <div className="space-y-4 max-w-[1100px] mx-auto text-ink">
      {/* Header Profile Outlet - Centennial Clean White & Ocean Blue Gradient */}
      <div className="bg-surface p-4 sm:p-5 rounded-2xl border border-border/80 shadow-sm flex flex-col sm:flex-row sm:items-center justify-between gap-3 relative overflow-hidden">
        <div className="flex items-center gap-3 relative z-10">
          <div className="w-11 h-11 sm:w-12 sm:h-12 rounded-xl ocean-gradient p-0.5 shadow-md shadow-primary/20 shrink-0">
            <div className="w-full h-full bg-surface rounded-[10px] flex items-center justify-center text-primary font-extrabold text-base sm:text-lg">
              KS
            </div>
          </div>
          <div className="min-w-0">
            <div className="flex items-center gap-2 flex-wrap">
              <h1 className="text-base sm:text-lg font-bold text-ink tracking-tight truncate">
                Kopi Senja & Resto
              </h1>
              <span className="px-2 py-0.5 bg-primary/10 text-primary border border-primary/30 rounded-full text-[10px] font-bold tracking-wide shrink-0">
                OUTLET AKTIF
              </span>
            </div>
            <p className="text-muted text-xs mt-0.5 truncate">
              Cabang Utama Bandung • Mode Owner Centennial
            </p>
          </div>
        </div>

        {/* Action POS Buttons - Gradasi Biru Laut */}
        <div className="grid grid-cols-2 sm:flex sm:items-center gap-2 w-full sm:w-auto relative z-10">
          <button 
            onClick={() => alert('Buka Scanner QRIS')}
            className="flex items-center justify-center gap-1.5 px-3 py-2 rounded-xl border border-border bg-surface hover:bg-bg text-ink font-semibold text-xs transition active:scale-95 shadow-sm"
          >
            <QrCode className="w-3.5 h-3.5 text-primary shrink-0" />
            <span>QRIS Statis</span>
          </button>
          <button 
            onClick={() => alert('Mode Kasir POS Terbuka')}
            className="flex items-center justify-center gap-1.5 px-3.5 py-2 rounded-xl ocean-gradient hover:opacity-90 text-white font-semibold text-xs shadow-md shadow-primary/25 transition active:scale-95"
          >
            <Plus className="w-3.5 h-3.5 shrink-0" />
            <span>Buka Kasir POS</span>
          </button>
        </div>
      </div>

      {/* AI Co-Pilot Alert Banner */}
      <div className="bg-primary/10 border border-primary/30 p-3.5 sm:p-4 rounded-xl flex flex-col sm:flex-row items-start sm:items-center justify-between gap-2.5">
        <div className="flex items-start sm:items-center gap-2.5">
          <div className="w-8 h-8 rounded-lg ocean-gradient flex items-center justify-center text-white shrink-0 shadow-sm">
            <Sparkles className="w-4 h-4 animate-pulse" />
          </div>
          <div>
            <div className="flex items-center gap-1.5">
              <h3 className="font-bold text-xs text-primary">AI Co-Pilot Rekomendasi</h3>
              <span className="text-[9px] uppercase font-bold tracking-wider px-1.5 py-0.2 bg-primary/20 text-primary rounded">Auto-Alert</span>
            </div>
            <p className="text-[11px] text-muted mt-0.5 leading-relaxed">
              Stok Mie Ayam Pangsit menipis (sisa 8 porsi). Estimasi jam 18:00 - 20:00 penjualan naik 35%.
            </p>
          </div>
        </div>
        <button 
          onClick={() => alert('AI Co-Pilot Detail: Disarankan restock 20 porsi mie sebelum jam 17:00')}
          className="text-xs font-semibold bg-surface hover:bg-primary/10 border border-primary/40 px-3 py-1.5 rounded-lg text-primary transition flex items-center gap-1 shrink-0 w-full sm:w-auto justify-center shadow-sm"
        >
          Lihat Analisis <ChevronRight className="w-3 h-3 text-primary" />
        </button>
      </div>

      {/* Metric Cards Grid - Background Putih & Gradasi Biru Laut */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-2.5 sm:gap-3.5">
        {/* Omset Card */}
        <div className="bg-surface p-3.5 sm:p-4 rounded-xl border border-border/80 shadow-sm hover:border-primary/40 transition duration-150">
          <div className="flex items-center justify-between mb-1.5">
            <span className="text-[10px] font-bold tracking-wider text-muted uppercase">Omset Hari Ini</span>
            <div className="w-7 h-7 rounded-lg ocean-gradient text-white flex items-center justify-center shrink-0 shadow-sm">
              <TrendingUp className="w-3.5 h-3.5" />
            </div>
          </div>
          <div className="text-lg sm:text-xl font-extrabold text-ink tracking-tight">Rp 5.560.000</div>
          <div className="flex items-center gap-1 mt-1 text-[11px] text-success font-semibold">
            <ArrowUpRight className="w-3 h-3" />
            <span>+18.4%</span>
            <span className="text-muted font-normal">kemarin</span>
          </div>
        </div>

        {/* Transaksi Card */}
        <div className="bg-surface p-3.5 sm:p-4 rounded-xl border border-border/80 shadow-sm hover:border-primary/40 transition duration-150">
          <div className="flex items-center justify-between mb-1.5">
            <span className="text-[10px] font-bold tracking-wider text-muted uppercase">Transaksi Sukses</span>
            <div className="w-7 h-7 rounded-lg ocean-gradient text-white flex items-center justify-center shrink-0 shadow-sm">
              <Receipt className="w-3.5 h-3.5" />
            </div>
          </div>
          <div className="text-lg sm:text-xl font-extrabold text-ink tracking-tight">128 TX</div>
          <div className="flex items-center gap-1 mt-1 text-[11px] text-primary font-medium truncate">
            <span>Rata-rata:</span>
            <span className="text-muted">Rp 43k/tx</span>
          </div>
        </div>

        {/* Produk Aktif */}
        <div className="bg-surface p-3.5 sm:p-4 rounded-xl border border-border/80 shadow-sm hover:border-primary/40 transition duration-150">
          <div className="flex items-center justify-between mb-1.5">
            <span className="text-[10px] font-bold tracking-wider text-muted uppercase">Produk Aktif</span>
            <div className="w-7 h-7 rounded-lg ocean-gradient text-white flex items-center justify-center shrink-0 shadow-sm">
              <Package className="w-3.5 h-3.5" />
            </div>
          </div>
          <div className="text-lg sm:text-xl font-extrabold text-ink tracking-tight">48 Menu</div>
          <div className="flex items-center gap-1 mt-1 text-[11px] text-warning font-semibold truncate">
            <AlertTriangle className="w-3 h-3 shrink-0" />
            <span>2 menipis</span>
          </div>
        </div>

        {/* Pelanggan Baru */}
        <div className="bg-surface p-3.5 sm:p-4 rounded-xl border border-border/80 shadow-sm hover:border-primary/40 transition duration-150">
          <div className="flex items-center justify-between mb-1.5">
            <span className="text-[10px] font-bold tracking-wider text-muted uppercase">Pelanggan</span>
            <div className="w-7 h-7 rounded-lg bg-success text-white flex items-center justify-center shrink-0 shadow-sm">
              <Users className="w-3.5 h-3.5" />
            </div>
          </div>
          <div className="text-lg sm:text-xl font-extrabold text-ink tracking-tight">342 Org</div>
          <div className="flex items-center gap-1 mt-1 text-[11px] text-success font-semibold truncate">
            <Zap className="w-3 h-3 shrink-0" />
            <span>+14 member</span>
          </div>
        </div>
      </div>

      {/* Charts & Top Product Section */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-3.5 sm:gap-4">
        {/* Sales Trend Chart */}
        <div className="lg:col-span-2 bg-surface p-4 sm:p-5 rounded-2xl border border-border/80 shadow-sm">
          <div className="flex items-center justify-between mb-3">
            <div>
              <h2 className="text-sm sm:text-base font-bold text-ink">Tren Jam Penjualan</h2>
              <p className="text-xs text-muted">Lonjakan jam sibuk penjualan warung</p>
            </div>
            <span className="text-[11px] font-bold px-2.5 py-0.5 rounded-full bg-primary/10 text-primary border border-primary/30">
              Hari Ini
            </span>
          </div>

          <div className="h-56 sm:h-64 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={hourlySales} margin={{ top: 10, right: 10, left: -25, bottom: 0 }}>
                <defs>
                  <linearGradient id="oceanGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="var(--color-primary)" stopOpacity={0.25}/>
                    <stop offset="95%" stopColor="var(--color-primary-light)" stopOpacity={0.0}/>
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="var(--color-border)" vertical={false} />
                <XAxis dataKey="time" stroke="var(--color-muted)" fontSize={10} tickLine={false} />
                <YAxis stroke="var(--color-muted)" fontSize={10} tickLine={false} tickFormatter={(v) => `${v / 1000}k`} />
                <Tooltip 
                  contentStyle={{ 
                    backgroundColor: 'var(--color-ink)', 
                    borderRadius: '10px',
                    color: 'var(--color-surface)',
                    fontSize: '11px',
                    border: 'none',
                    boxShadow: '0 4px 12px rgba(0,0,0,0.15)'
                  }}
                  formatter={(value: any) => [`Rp ${Number(value).toLocaleString('id-ID')}`, 'Omset']}
                />
                <Area 
                  type="monotone" 
                  dataKey="total" 
                  stroke="var(--color-primary)" 
                  strokeWidth={2.5} 
                  fillOpacity={1} 
                  fill="url(#oceanGradient)" 
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Top Product List */}
        <div className="bg-surface p-4 sm:p-5 rounded-2xl border border-border/80 shadow-sm flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between mb-3">
              <h2 className="text-sm sm:text-base font-bold text-ink">Menu Terlaris</h2>
              <span className="text-xs text-primary font-semibold cursor-pointer hover:underline">
                Lihat Semua
              </span>
            </div>

            <div className="space-y-2">
              {topProducts.map((p, idx) => (
                <div key={idx} className="p-2.5 rounded-xl bg-bg/70 border border-border flex items-center justify-between gap-2.5">
                  <div className="min-w-0">
                    <div className="font-semibold text-xs text-ink truncate">
                      {p.name}
                    </div>
                    <div className="text-[10px] text-muted flex items-center gap-1.5 mt-0.5">
                      <span>{p.category}</span>
                      <span>•</span>
                      <span className="text-primary font-medium">{p.sold} terjual</span>
                    </div>
                  </div>
                  <div className="text-right shrink-0">
                    <div className="font-bold text-xs text-success">{p.revenue}</div>
                    <div className="text-[10px] text-muted">Stok: {p.stock}</div>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="mt-3 pt-3 border-t border-border flex items-center justify-between text-xs text-muted">
            <span className="flex items-center gap-1 text-[11px]">
              <ShieldCheck className="w-3.5 h-3.5 text-primary" /> Auto-sync SQLite
            </span>
            <span className="text-primary font-mono text-[11px] font-semibold">100% Offline-First</span>
          </div>
        </div>
      </div>
    </div>
  );
}
