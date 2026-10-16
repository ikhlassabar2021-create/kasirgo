import { useCallback, useEffect, useState } from 'react';
import {
  CloudUpload, CloudDownload, Database, RefreshCw, CalendarClock, CheckCircle2, XCircle,
} from 'lucide-react';
import {
  rp, fmtDate, fmtBytes,
  UsersListResult, BackupListResult,
} from '../lib/adminApi';

type ScheduleState = Record<string, { enabled: boolean; cadence: string }>;

export function BackupPage() {
  const [outlets, setOutlets] = useState<UsersListResult['rows']>([]);
  const [runs, setRuns] = useState<BackupListResult['rows']>([]);
  const [schedules, setSchedules] = useState<ScheduleState>({});
  const [selected, setSelected] = useState('');
  const [kind, setKind] = useState<'full' | 'quick'>('quick');
  const [busy, setBusy] = useState<string | null>(null);
  const [msg, setMsg] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      const [users, list] = await Promise.all([
        rp<UsersListResult>('platform_users_list', { p_limit: 100, p_offset: 0 }),
        rp<BackupListResult>('platform_backup_list'),
      ]);
      setOutlets(users.rows);
      setRuns(list.rows);
      if (!selected && users.rows.length) setSelected(users.rows[0].outlet_id ?? '');
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Gagal memuat data backup');
    }
  }, [selected]);

  // Run due schedules (backup terjadwal tanpa cron; dipicu saat halaman dibuka).
  useEffect(() => {
    (async () => {
      try {
        const n = await rp<number>('platform_backup_run_due');
        if (n > 0) setMsg(`${n} backup terjadwal dijalankan.`);
      } catch { /* biarkan halaman tetap terbuka */ }
    })();
  }, []);

  useEffect(() => { load(); }, [load]);

  const createBackup = async () => {
    if (!selected) return;
    setBusy('create');
    setError(null);
    try {
      const res = await rp<{ id: string; row_count: number; size_bytes: number }>(
        'platform_backup_create', { p_outlet_id: selected, p_kind: kind },
      );
      setMsg(`Backup dibuat: ${res.row_count} baris (${fmtBytes(res.size_bytes)}).`);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Gagal membuat backup');
    } finally {
      setBusy(null);
    }
  };

  const download = async (id: string, name: string) => {
    setBusy(id);
    try {
      const row = await rp<{ data: Record<string, unknown>; created_at: string }>(
        'platform_backup_get', { p_id: id });
      const blob = new Blob([JSON.stringify(row.data, null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `kasirgo-backup-${name.replace(/\s+/g, '-').toLowerCase()}-${row.created_at.slice(0, 10)}.json`;
      a.click();
      URL.revokeObjectURL(url);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Gagal mengunduh backup');
    } finally {
      setBusy(null);
    }
  };

  const restore = async (id: string, name: string) => {
    if (!window.confirm(
      `Pulihkan data outlet "${name}"?\nHanya produk/varian/pelanggan yang HILANG yang akan diisi ulang. Transaksi TIDAK dipulihkan agar keuangan tidak dobel.`)) return;
    setBusy(id);
    try {
      const res = await rp<{ products: number; variants: number; customers: number }>(
        'platform_backup_restore', { p_id: id });
      setMsg(`Pulihkan selesai: ${res.products} produk, ${res.variants} varian, ${res.customers} pelanggan.`);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Gagal memulihkan');
    } finally {
      setBusy(null);
    }
  };

  const setSchedule = async (outletId: string, enabled: boolean, cadence: string) => {
    setBusy(`sched-${outletId}`);
    try {
      await rp('platform_backup_schedule_set', {
        p_outlet_id: outletId, p_enabled: enabled, p_cadence: cadence,
      });
      setSchedules((s) => ({ ...s, [outletId]: { enabled, cadence } }));
      setMsg(enabled ? 'Jadwal backup disimpan (dijalankan otomatis saat halaman ini dibuka).' : 'Jadwal backup dimatikan.');
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Gagal menyimpan jadwal');
    } finally {
      setBusy(null);
    }
  };

  return (
    <div className="p-3 sm:p-6 max-w-[1100px] mx-auto fade-in">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-6">
        <div>
          <h1 className="text-xl sm:text-2xl font-bold text-ink mb-1">Backup &amp; Pemulihan Data</h1>
          <p className="text-xs sm:text-sm text-muted">
            Snapshot JSON per outlet &bull; pulihkan hanya data hilang &bull; semua aksi tercatat di audit
          </p>
        </div>
        <button onClick={load} className="flex items-center gap-2 border border-border bg-surface px-4 py-2.5 rounded-xl text-xs font-semibold text-muted hover:bg-bg transition">
          <RefreshCw className="w-4 h-4" /> Refresh
        </button>
      </div>

      {msg && (
        <div className="mb-4 flex items-center gap-2 bg-success/10 border border-success/30 text-success rounded-xl px-4 py-3 text-xs font-semibold">
          <CheckCircle2 className="w-4 h-4" /> {msg}
        </div>
      )}
      {error && (
        <div className="mb-4 flex items-center gap-2 bg-danger/10 border border-danger/30 text-danger rounded-xl px-4 py-3 text-xs font-semibold">
          <XCircle className="w-4 h-4" /> {error}
        </div>
      )}

      {/* Buat backup */}
      <div className="bg-surface rounded-2xl card-shadow border border-border/80 p-4 sm:p-6 mb-6">
        <h2 className="text-sm font-bold text-ink mb-3 flex items-center gap-2">
          <CloudUpload className="w-4 h-4 text-primary" /> Buat Backup Baru
        </h2>
        <div className="flex flex-col sm:flex-row gap-3 sm:items-end">
          <div className="flex-1">
            <label className="text-[10px] font-bold text-muted uppercase">Outlet</label>
            <select
              value={selected}
              onChange={(e) => setSelected(e.target.value)}
              className="mt-1 w-full border border-border rounded-xl px-4 py-2.5 text-sm bg-surface text-ink"
            >
              <option value="">Pilih outlet...</option>
              {outlets.map((o) => (
                <option key={o.user_id} value={o.outlet_id ?? ''}>
                  {o.outlet_name ?? o.email}
                </option>
              ))}
            </select>
          </div>
          <div>
            <label className="text-[10px] font-bold text-muted uppercase">Tipe</label>
            <select
              value={kind}
              onChange={(e) => setKind(e.target.value as 'full' | 'quick')}
              className="mt-1 w-full sm:w-44 border border-border rounded-xl px-4 py-2.5 text-sm bg-surface text-ink"
            >
              <option value="quick">Cepat (master data)</option>
              <option value="full">Penuh (+transaksi 90 hari)</option>
            </select>
          </div>
          <button
            onClick={createBackup}
            disabled={!selected || busy === 'create'}
            className="ocean-gradient text-white px-5 py-2.5 rounded-xl font-semibold text-xs shadow-md shadow-primary/25 active:scale-95 transition disabled:opacity-50"
          >
            {busy === 'create' ? 'Menyimpan...' : 'Buat Backup'}
          </button>
        </div>

        {/* Jadwal */}
        <div className="mt-4 pt-4 border-t border-border flex flex-col sm:flex-row sm:items-center gap-3">
          <div className="flex items-center gap-2 text-xs font-semibold text-muted">
            <CalendarClock className="w-4 h-4 text-primary" /> Backup terjadwal outlet terpilih:
          </div>
          <select
            value={schedules[selected]?.cadence ?? 'daily'}
            onChange={(e) => selected && setSchedule(selected, true, e.target.value)}
            disabled={!selected}
            className="border border-border rounded-xl px-3 py-2 text-xs bg-surface"
          >
            <option value="daily">Harian</option>
            <option value="weekly">Mingguan</option>
            <option value="monthly">Bulanan</option>
          </select>
          <button
            onClick={() => selected && setSchedule(selected, true, schedules[selected]?.cadence ?? 'daily')}
            disabled={!selected || busy === `sched-${selected}`}
            className="border border-primary/30 bg-primary/10 text-primary px-4 py-2 rounded-xl text-xs font-semibold hover:bg-primary/15 disabled:opacity-50"
          >
            Aktifkan
          </button>
          <button
            onClick={() => selected && setSchedule(selected, false, 'daily')}
            disabled={!selected || busy === `sched-${selected}`}
            className="border border-border text-muted px-4 py-2 rounded-xl text-xs font-semibold hover:bg-bg disabled:opacity-50"
          >
            Matikan
          </button>
        </div>
      </div>

      {/* Riwayat */}
      <div className="bg-surface rounded-2xl card-shadow border border-border/80 overflow-hidden">
        <div className="px-4 sm:px-6 py-3.5 border-b border-border flex items-center justify-between">
          <h3 className="text-xs sm:text-sm font-semibold text-ink">Riwayat Snapshot (100 terakhir)</h3>
          <Database className="w-4 h-4 text-muted" />
        </div>
        <div className="overflow-x-auto">
          <table className="w-full min-w-[640px]">
            <thead className="bg-bg border-b border-border">
              <tr>
                <th className="text-left px-4 sm:px-6 py-3 text-[10px] font-bold text-muted uppercase">Outlet</th>
                <th className="text-left px-4 sm:px-6 py-3 text-[10px] font-bold text-muted uppercase">Waktu</th>
                <th className="text-left px-4 sm:px-6 py-3 text-[10px] font-bold text-muted uppercase">Tipe</th>
                <th className="text-left px-4 sm:px-6 py-3 text-[10px] font-bold text-muted uppercase">Status</th>
                <th className="text-left px-4 sm:px-6 py-3 text-[10px] font-bold text-muted uppercase">Baris</th>
                <th className="text-left px-4 sm:px-6 py-3 text-[10px] font-bold text-muted uppercase">Ukuran</th>
                <th className="text-right px-4 sm:px-6 py-3 text-[10px] font-bold text-muted uppercase">Aksi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {!runs.length && (
                <tr><td colSpan={7} className="px-6 py-10 text-center text-xs text-muted">Belum ada backup.</td></tr>
              )}
              {runs.map((b) => (
                <tr key={b.id} className="hover:bg-bg">
                  <td className="px-4 sm:px-6 py-3.5 text-xs font-semibold text-ink">{b.outlet_name ?? b.outlet_id.slice(0, 8)}</td>
                  <td className="px-4 sm:px-6 py-3.5 text-xs text-muted">{fmtDate(b.created_at)}</td>
                  <td className="px-4 sm:px-6 py-3.5">
                    <span className={`px-2 py-0.5 rounded-full text-[9px] font-bold border ${
                      b.kind === 'full' ? 'bg-primary/10 text-primary border-primary/30' : 'bg-primary/10 text-primary border-primary/30'
                    }`}>{b.kind === 'full' ? 'PENUH' : 'CEPAT'}</span>
                  </td>
                  <td className="px-4 sm:px-6 py-3.5 text-xs text-muted">{b.status}</td>
                  <td className="px-4 sm:px-6 py-3.5 text-xs text-muted">{b.row_count}</td>
                  <td className="px-4 sm:px-6 py-3.5 text-xs text-muted">{fmtBytes(b.size_bytes)}</td>
                  <td className="px-4 sm:px-6 py-3.5">
                    <div className="flex items-center justify-end gap-1">
                      <button
                        onClick={() => download(b.id, b.outlet_name ?? 'outlet')}
                        disabled={busy === b.id}
                        className="p-2 hover:bg-primary/10 rounded-lg transition-colors text-primary disabled:opacity-40"
                        title="Unduh JSON"
                      >
                        <CloudDownload className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => restore(b.id, b.outlet_name ?? 'outlet')}
                        disabled={busy === b.id}
                        className="p-2 hover:bg-success/10 rounded-lg transition-colors text-success disabled:opacity-40"
                        title="Pulihkan data hilang"
                      >
                        <Database className="w-4 h-4" />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div className="px-4 sm:px-6 py-3 border-t border-border text-[10px] text-muted">
          Pulihkan hanya mengisi baris yang hilang (id sama = dilewati). Transaksi tidak dipulihkan agar laporan tidak dobel. Foto produk tersimpan lokal di HP dan tidak termasuk snapshot.
        </div>
      </div>
    </div>
  );
}
