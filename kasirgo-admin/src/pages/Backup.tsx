import React, { useState } from 'react'
import { Database, Download, CloudUpload, HardDrive, CheckCircle2 } from 'lucide-react'

export const BackupPage: React.FC = () => {
  const [running, setRunning] = useState(false)
  const [lastBackup, setLastBackup] = useState('2026-09-19 14:30 WIB')

  const handleTriggerBackup = () => {
    setRunning(true)
    setTimeout(() => {
      setRunning(false)
      setLastBackup(new Date().toLocaleString('id-ID'))
      alert('Snapshot Database Supabase & Cold Storage R2 berhasil disinkronkan!')
    }, 2000)
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight text-white">
          Penyimpanan, Cloudflare R2 & Backup
        </h1>
        <p className="text-sm text-slate-400">
          Kebijakan Rp0 Penyimpanan: Foto produk lokal di HP, cold storage R2 arsip, transaksi Supabase.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-5 sm:grid-cols-3">
        <div className="rounded-2xl border border-slate-700/60 bg-[#1E293B]/70 p-6 backdrop-blur-md">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold uppercase text-slate-400">Supabase DB Size</span>
            <Database size={20} className="text-[#06B6D4]" />
          </div>
          <p className="mt-3 text-2xl font-bold text-white">48.2 MB</p>
          <p className="mt-1 text-xs text-slate-400">Teks & metadata saja (Limit 500MB)</p>
        </div>

        <div className="rounded-2xl border border-slate-700/60 bg-[#1E293B]/70 p-6 backdrop-blur-md">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold uppercase text-slate-400">Cloudflare R2 Bucket</span>
            <CloudUpload size={20} className="text-emerald-400" />
          </div>
          <p className="mt-3 text-2xl font-bold text-white">1.82 GB</p>
          <p className="mt-1 text-xs text-slate-400">WebP opt-in & cold archive (Free 10GB)</p>
        </div>

        <div className="rounded-2xl border border-slate-700/60 bg-[#1E293B]/70 p-6 backdrop-blur-md">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold uppercase text-slate-400">Penyimpanan HP Mitra</span>
            <HardDrive size={20} className="text-purple-400" />
          </div>
          <p className="mt-3 text-2xl font-bold text-white">~12 MB/HP</p>
          <p className="mt-1 text-xs text-slate-400">Foto original disimpan lokal di memori HP</p>
        </div>
      </div>

      <div className="rounded-2xl border border-slate-700/60 bg-[#1E293B]/70 p-6 backdrop-blur-md">
        <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h3 className="text-base font-bold text-white">Snapshot Database Terjadwal</h3>
            <p className="text-xs text-slate-400">
              Terakhir dieksekusi: <span className="text-emerald-400 font-semibold">{lastBackup}</span>
            </p>
          </div>
          <div className="flex items-center gap-3">
            <button
              onClick={handleTriggerBackup}
              disabled={running}
              className="flex items-center gap-2 rounded-xl bg-gradient-to-r from-[#4F46E5] to-[#7C3AED] px-4 py-2.5 text-xs font-semibold text-white shadow-md hover:opacity-90 disabled:opacity-50"
            >
              <Download size={15} />
              {running ? 'Membuat Snapshot...' : 'Jalankan Snapshot Sekarang'}
            </button>
          </div>
        </div>

        <div className="mt-6 space-y-3">
          {[
            {
              title: 'Foto Produk Lokal Mandiri (Strict Zero-Storage Cost)',
              status: 'Aktif & Terisolasi',
              desc: 'Foto fisik produk warung tidak pernah diunggah ke storage developer. Nol rupiah tagihan egress.',
            },
            {
              title: 'Cloudflare R2 Cold Archiving (Transaksi > 30 Hari)',
              status: 'Terhubung ke Bucket',
              desc: 'Data transaksi lampau diarsipkan ke R2 JSON kompresi untuk menghemat ruang kuota Supabase.',
            },
            {
              title: 'Enkripsi Database SQLite SQLCipher & Secure Storage',
              status: 'Terenkripsi AES-256',
              desc: 'Integritas data lokal warung terlindungi dari eksfiltrasi file.',
            },
          ].map((item) => (
            <div
              key={item.title}
              className="flex items-start gap-3.5 rounded-xl border border-slate-800 bg-slate-900/50 p-4"
            >
              <CheckCircle2 size={18} className="mt-0.5 shrink-0 text-emerald-400" />
              <div>
                <div className="flex items-center gap-2">
                  <span className="text-xs font-bold text-white">{item.title}</span>
                  <span className="rounded bg-emerald-500/10 px-2 py-0.5 text-[10px] font-semibold text-emerald-400">
                    {item.status}
                  </span>
                </div>
                <p className="mt-1 text-xs text-slate-400">{item.desc}</p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
