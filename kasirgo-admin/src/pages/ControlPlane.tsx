import { useState } from 'react';
import {
  CreditCard,
  Wallet,
  Boxes,
  Users,
  Landmark,
  HardDrive,
  MessageSquare,
  Database,
  Save,
  SlidersHorizontal,
} from 'lucide-react';

type Field = {
  key: string;
  label: string;
  type?: 'text' | 'password' | 'number';
  suffix?: string;
  placeholder?: string;
  hint?: string;
};

type Group = {
  id: string;
  name: string;
  icon: typeof CreditCard;
  description: string;
  fields: Field[];
};

const groups: Group[] = [
  {
    id: 'payment',
    name: 'Payment Gateway',
    icon: CreditCard,
    description: 'Duitku & margin QRIS, termasuk jadwal pencairan dana outlet.',
    fields: [
      { key: 'duitku_merchant', label: 'Merchant Code', placeholder: 'D1234' },
      { key: 'duitku_api_key', label: 'API Key', type: 'password', placeholder: '••••••••' },
      { key: 'qris_margin', label: 'Margin QRIS', type: 'number', suffix: '%', hint: 'Margin platform per transaksi QRIS.' },
      { key: 'settlement_cycle', label: 'Siklus Pencairan', placeholder: 'H+1', hint: 'Dana diteruskan ke outlet.' },
    ],
  },
  {
    id: 'ppob',
    name: 'PPOB',
    icon: Wallet,
    description: 'Harga modal & margin pulsa, token, dan tagihan.',
    fields: [
      { key: 'ppob_api_key', label: 'API Key Provider', type: 'password', placeholder: '••••••••' },
      { key: 'ppob_base_price', label: 'Harga Modal Default', type: 'number', suffix: 'Rp', placeholder: '0' },
      { key: 'ppob_margin', label: 'Margin Persen', type: 'number', suffix: '%', hint: 'Harga jual dihitung otomatis dari modal + margin.' },
    ],
  },
  {
    id: 'b2b',
    name: 'B2B Kulakan',
    icon: Boxes,
    description: 'Link affiliate distributor untuk restock otomatis.',
    fields: [
      { key: 'b2b_distributor_link', label: 'Link Distributor', placeholder: 'https://distributor.example.com/ref/kasirgo' },
      { key: 'b2b_commission', label: 'Komisi Restock', type: 'number', suffix: '%', placeholder: '2' },
    ],
  },
  {
    id: 'affiliate',
    name: 'Affiliate',
    icon: Users,
    description: 'Komisi upgrade outlet & pencairan otomatis.',
    fields: [
      { key: 'affiliate_upgrade_commission', label: 'Komisi Upgrade', type: 'number', suffix: '%', placeholder: '20' },
      { key: 'affiliate_min_payout', label: 'Minimal Pencairan', type: 'number', suffix: 'Rp', placeholder: '50000' },
      { key: 'affiliate_auto_payout', label: 'Pencairan Otomatis', placeholder: 'Aktif', hint: 'Nilai: Aktif / Nonaktif.' },
    ],
  },
  {
    id: 'fintech',
    name: 'Fintech',
    icon: Landmark,
    description: 'Link partner pembiayaan & pinjaman modal UMKM.',
    fields: [
      { key: 'fintech_partner_link', label: 'Link Partner', placeholder: 'https://partner.example.com/kasirgo' },
      { key: 'fintech_rate', label: 'Estimasi Bunga', type: 'number', suffix: '%/tahun', placeholder: '12' },
    ],
  },
  {
    id: 'storage',
    name: 'Storage',
    icon: HardDrive,
    description: 'Cloudflare R2 untuk arsip & thumbnail publikasi.',
    fields: [
      { key: 'r2_bucket', label: 'Bucket', placeholder: 'kasirgo-thumbs' },
      { key: 'r2_endpoint', label: 'Endpoint', placeholder: 'https://<account>.r2.cloudflarestorage.com' },
      { key: 'r2_access_key', label: 'Access Key', type: 'password', placeholder: '••••••••' },
      { key: 'r2_secret_key', label: 'Secret Key', type: 'password', placeholder: '••••••••' },
    ],
  },
  {
    id: 'whatsapp',
    name: 'WA Bisnis',
    icon: MessageSquare,
    description: 'API WhatsApp Business untuk broadcast & notifikasi.',
    fields: [
      { key: 'wa_api_key', label: 'API Key', type: 'password', placeholder: '••••••••' },
      { key: 'wa_phone_id', label: 'Phone Number ID', placeholder: '1234567890' },
    ],
  },
  {
    id: 'database',
    name: 'Database',
    icon: Database,
    description: 'Koneksi Supabase untuk sinkronisasi cloud.',
    fields: [
      { key: 'db_url', label: 'Supabase URL', placeholder: 'https://xxxx.supabase.co' },
      { key: 'db_anon_key', label: 'Anon Key', type: 'password', placeholder: '••••••••' },
      { key: 'db_service_key', label: 'Service Key', type: 'password', placeholder: '••••••••' },
    ],
  },
];

export function ControlPlanePage() {
  const [activeId, setActiveId] = useState(groups[0].id);
  const [values, setValues] = useState<Record<string, string>>({
    qris_margin: '0.7',
    settlement_cycle: 'H+1',
    ppob_margin: '5',
    b2b_commission: '2',
    affiliate_upgrade_commission: '20',
    affiliate_min_payout: '50000',
    affiliate_auto_payout: 'Aktif',
  });

  const activeGroup = groups.find((g) => g.id === activeId) ?? groups[0];
  const ActiveIcon = activeGroup.icon;

  return (
    <div className="space-y-4 max-w-[1100px] mx-auto text-slate-800 fade-in">
      <div className="bg-white p-4 sm:p-5 rounded-2xl border border-slate-200/80 shadow-sm flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <div className="w-11 h-11 rounded-xl bg-gradient-to-br from-cyan-500 to-sky-600 p-0.5 shadow-md shadow-sky-500/20 shrink-0">
            <div className="w-full h-full bg-white rounded-[10px] flex items-center justify-center text-sky-600">
              <SlidersHorizontal className="w-5 h-5" />
            </div>
          </div>
          <div className="min-w-0">
            <h1 className="text-base sm:text-lg font-bold text-slate-900 tracking-tight">Control Plane</h1>
            <p className="text-slate-500 text-xs mt-0.5">
              Atur semua integrasi & margin tanpa mengubah koding.
            </p>
          </div>
        </div>
        <span className="px-2.5 py-1 bg-sky-50 text-sky-700 border border-sky-200/80 rounded-full text-[10px] font-bold tracking-wide self-start sm:self-auto">
          KONFIGURASI PLATFORM
        </span>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-[240px_1fr] gap-3.5 sm:gap-4">
        <aside className="bg-white p-2.5 rounded-2xl border border-slate-200/80 shadow-sm h-max lg:sticky lg:top-4">
          <nav className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-1 gap-1">
            {groups.map((group) => {
              const Icon = group.icon;
              const isActive = group.id === activeId;
              return (
                <button
                  key={group.id}
                  onClick={() => setActiveId(group.id)}
                  className={`flex items-center gap-2.5 px-3 py-2.5 rounded-xl text-xs font-semibold transition ${
                    isActive
                      ? 'bg-gradient-to-r from-cyan-500 to-sky-600 text-white shadow-sm shadow-sky-500/25'
                      : 'text-slate-600 hover:bg-slate-100 hover:text-slate-900'
                  }`}
                >
                  <Icon className={`w-4 h-4 shrink-0 ${isActive ? 'text-white' : 'text-slate-500'}`} />
                  <span className="truncate">{group.name}</span>
                </button>
              );
            })}
          </nav>
        </aside>

        <div className="bg-white p-4 sm:p-6 rounded-2xl border border-slate-200/80 shadow-sm">
          <div className="flex items-start gap-3 pb-4 mb-4 border-b border-slate-100">
            <div className="w-10 h-10 rounded-xl bg-sky-50 text-sky-600 flex items-center justify-center shrink-0">
              <ActiveIcon className="w-5 h-5" />
            </div>
            <div>
              <h2 className="text-sm sm:text-base font-bold text-slate-900">{activeGroup.name}</h2>
              <p className="text-xs text-slate-500 mt-0.5">{activeGroup.description}</p>
            </div>
          </div>

          <div className="max-w-[760px] space-y-3.5">
            {activeGroup.fields.map((field) => (
              <div key={field.key}>
                <label className="block text-[11px] font-bold text-slate-600 uppercase tracking-wider mb-1.5">
                  {field.label}
                </label>
                <div className="relative">
                  <input
                    type={field.type ?? 'text'}
                    value={values[field.key] ?? ''}
                    onChange={(e) => setValues((prev) => ({ ...prev, [field.key]: e.target.value }))}
                    placeholder={field.placeholder}
                    className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 bg-slate-50/50 hover:bg-white focus:bg-white text-xs text-slate-800 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-sky-500/30 focus:border-sky-500 transition duration-150"
                  />
                  {field.suffix && (
                    <span className="absolute right-3.5 top-1/2 -translate-y-1/2 text-xs font-semibold text-slate-400">
                      {field.suffix}
                    </span>
                  )}
                </div>
                {field.hint && <p className="text-[11px] text-slate-400 mt-1">{field.hint}</p>}
              </div>
            ))}

            <button
              onClick={() => alert(`Konfigurasi ${activeGroup.name} disimpan.`)}
              className="mt-2 flex items-center justify-center gap-2 bg-gradient-to-r from-cyan-500 to-sky-600 hover:from-cyan-600 hover:to-sky-700 text-white px-4 py-2.5 rounded-xl font-semibold text-xs shadow-md shadow-sky-500/25 active:scale-95 transition"
            >
              <Save className="w-4 h-4" /> Simpan Konfigurasi
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
