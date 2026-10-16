import { useEffect, useState } from 'react';
import { RefreshCw } from 'lucide-react';
import {
  MODULE_LABELS, platformOutletFeatures, platformOutletSetFeature,
} from '../lib/adminApi';

// Daftar toggle modul per outlet (Fitur Utama). effective = kondisi saat ini,
// overrides = paksa on/off khusus outlet ini (prioritas tertinggi).
export function FeatureToggleList({ outletId }: { outletId: string }) {
  const [effective, setEffective] = useState<Record<string, boolean>>({});
  const [overrides, setOverrides] = useState<Record<string, boolean>>({});
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);

  const load = async () => {
    setLoading(true);
    setErr(null);
    try {
      const res = await platformOutletFeatures(outletId);
      setEffective(res.effective ?? {});
      setOverrides(res.overrides ?? {});
    } catch (e) {
      setErr(e instanceof Error ? e.message : 'Gagal memuat fitur');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); /* eslint-disable-next-line react-hooks/exhaustive-deps */ }, [outletId]);

  const toggle = async (key: string, current: boolean) => {
    setBusy(key);
    try {
      await platformOutletSetFeature(outletId, key, !current);
      setOverrides((o) => ({ ...o, [key]: !current }));
      setEffective((e) => ({ ...e, [key]: !current }));
    } catch (e) {
      setErr(e instanceof Error ? e.message : 'Gagal menyimpan');
    } finally {
      setBusy(null);
    }
  };

  if (loading) {
    return <div className="py-6 text-center text-xs text-muted">Memuat fitur...</div>;
  }

  return (
    <div>
      {err && <p className="text-xs text-danger mb-3">{err}</p>}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
        {MODULE_LABELS.map((m) => {
          const on = effective[m.key] === true;
          const forced = Object.prototype.hasOwnProperty.call(overrides, m.key);
          return (
            <button
              key={m.key}
              onClick={() => toggle(m.key, on)}
              disabled={busy === m.key}
              className={`flex items-center justify-between gap-3 rounded-xl border px-3.5 py-2.5 text-left transition ${
                on ? 'border-success/30 bg-success/10' : 'border-border bg-surface hover:bg-bg'
              }`}
            >
              <div className="min-w-0">
                <p className="text-xs font-bold text-ink truncate">{m.label}</p>
                <p className="text-[10px] text-muted">
                  {forced ? 'Diatur khusus outlet ini' : 'Mengikuti aturan tipe/global'}
                </p>
              </div>
              <span className={`shrink-0 w-9 h-5 rounded-full p-0.5 transition ${on ? 'bg-success/100' : 'bg-border'}`}>
                <span className={`block w-4 h-4 bg-surface rounded-full shadow transition-transform ${on ? 'translate-x-4' : ''}`} />
              </span>
            </button>
          );
        })}
      </div>
      <div className="flex justify-end mt-3">
        <button
          onClick={load}
          className="flex items-center gap-1.5 text-[11px] font-semibold text-muted hover:text-ink"
        >
          <RefreshCw className="w-3.5 h-3.5" /> Muat ulang
        </button>
      </div>
    </div>
  );
}