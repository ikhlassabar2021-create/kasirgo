import React from 'react'
import { StatCard } from '../components/StatCard'
import { TrendingUp, QrCode, Ticket, Truck, PhoneCall, DollarSign } from 'lucide-react'

export const RevenuePage: React.FC = () => {
  const pipes = [
    {
      title: 'Dynamic QRIS Gateway (MDR 0.7%)',
      desc: 'Margin sharing dari volume transaksi QRIS bank & e-wallet.',
      estMonthly: 'Rp 42.000.000',
      share: '35%',
      icon: <QrCode size={20} />,
      color: 'from-blue-500 to-indigo-600',
    },
    {
      title: 'Kupon Sponsor FMCG (Struk Digital)',
      desc: 'Brand Unilever, Indofood, Wings pasang iklan/kupon di struk WA.',
      estMonthly: 'Rp 28.500.000',
      share: '24%',
      icon: <Ticket size={20} />,
      color: 'from-purple-500 to-pink-600',
    },
    {
      title: 'Embedded B2B Kulakan & Restock',
      desc: 'Komisi agregasi order restock warung ke distributor grosir (1.5%).',
      estMonthly: 'Rp 31.000.000',
      share: '26%',
      icon: <Truck size={20} />,
      color: 'from-cyan-500 to-teal-600',
    },
    {
      title: 'PPOB & Tagihan Mikro (PLN, Pulsa)',
      desc: 'Fee switching per transaksi token listrik & e-money dari kasir.',
      estMonthly: 'Rp 18.200.000',
      share: '15%',
      icon: <PhoneCall size={20} />,
      color: 'from-emerald-500 to-green-600',
    },
  ]

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-bold tracking-tight text-white">
          Arus Monetisasi 12 Pipa Pihak Ketiga
        </h1>
        <p className="text-sm text-slate-400">
          Model bisnis KasirGo 3.0: 100% Gratis untuk Warung, Pendapatan Murni dari Industri &
          Fintech.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-5 sm:grid-cols-3">
        <StatCard
          title="Total Run-rate Pipa"
          value="Rp 119,7 Jt/bln"
          subtitle="Agregasi 4 pipa utama"
          icon={<DollarSign size={22} />}
          trend="+41% YoY"
        />
        <StatCard
          title="Biaya Langganan Warung"
          value="Rp 0 (NOL RUPIAH)"
          subtitle="Zero friction akuisisi"
          icon={<TrendingUp size={22} />}
          trend="Permanen"
        />
        <StatCard
          title="Gross Margin Ekosistem"
          value="88.4%"
          subtitle="Infrastruktur server Rp0"
          icon={<TrendingUp size={22} />}
          trend="Serverless"
        />
      </div>

      {/* Grid of Pipes */}
      <div className="grid grid-cols-1 gap-5 md:grid-cols-2">
        {pipes.map((pipe) => (
          <div
            key={pipe.title}
            className="relative overflow-hidden rounded-2xl border border-slate-700/60 bg-[#1E293B]/70 p-6 backdrop-blur-md transition-all hover:border-[#06B6D4]/40"
          >
            <div className="flex items-start justify-between">
              <div
                className={`flex h-11 w-11 items-center justify-center rounded-xl bg-gradient-to-tr ${pipe.color} text-white shadow-md`}
              >
                {pipe.icon}
              </div>
              <span className="rounded-full bg-slate-800 px-3 py-1 text-[11px] font-bold text-[#06B6D4]">
                Kontribusi {pipe.share}
              </span>
            </div>

            <h3 className="mt-4 text-base font-bold text-white">{pipe.title}</h3>
            <p className="mt-1 text-xs text-slate-400">{pipe.desc}</p>

            <div className="mt-6 flex items-baseline justify-between border-t border-slate-800 pt-4">
              <span className="text-xs text-slate-400">Estimasi Run-rate:</span>
              <span className="text-lg font-bold text-emerald-400">{pipe.estMonthly}</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
