import { useEffect, useState } from 'react';
import { supabase } from '../config/supabase';
import { affiliateMe, affiliateUpdateProfile, affiliateRegister } from '../lib/adminApi';
import type { AffiliateMeResult } from '../lib/adminApi';
import { Wallet, LogOut, Loader2, Save, TrendingUp, DollarSign, Users, Banknote } from 'lucide-react';

const fmtRp = (v: number) =>
  'Rp ' + Number(v ?? 0).toLocaleString('id-ID', { maximumFractionDigits: 0 });

const fmtDate = (v?: string) =>
  v ? new Date(v).toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' }) : '-';

type AuthMode = 'login' | 'register';

export function AffiliatePortalPage() {
  const [session, setSession] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [data, setData] = useState<AffiliateMeResult | null>(null);
  const [mode, setMode] = useState<AuthMode>('login');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [regName, setRegName] = useState('');
  const [regPhone, setRegPhone] = useState('');
  const [regReferral, setRegReferral] = useState('');
  const [authErr, setAuthErr] = useState('');
  const [authMsg, setAuthMsg] = useState('');
  const [signingIn, setSigningIn] = useState(false);
  const [saving, setSaving] = useState(false);
  const [toast, setToast] = useState('');

  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [bankName, setBankName] = useState('');
  const [bankAccountName, setBankAccountName] = useState('');
  const [bankAccountNumber, setBankAccountNumber] = useState('');

  const loadData = async () => {
    try {
      const res = await affiliateMe();
      setData(res);
      const a = res.affiliate;
      if (a) {
        setName(a.name ?? '');
        setPhone(a.phone ?? '');
        setBankName(a.bank_name ?? '');
        setBankAccountName(a.bank_account_name ?? '');
        setBankAccountNumber(a.bank_account_number ?? '');
      }
    } catch (e: any) {
      setData({ found: false });
    }
  };

  useEffect(() => {
    supabase.auth.getSession().then(async ({ data: { session } }) => {
      setSession(session ?? null);
      if (session) await loadData();
      setLoading(false);
    });
    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (_e, s) => {
      setSession(s ?? null);
      if (s) await loadData();
    });
    return () => subscription.unsubscribe();
    // eslint-disable-next-line
  }, []);

  const signIn = async () => {
    setAuthErr('');
    setSigningIn(true);
    try {
      const { error } = await supabase.auth.signInWithPassword({ email, password });
      if (error) throw error;
    } catch (e: any) {
      setAuthErr(e.message ?? 'Gagal masuk.');
    } finally {
      setSigningIn(false);
    }
  };

  const register = async () => {
    setAuthErr('');
    setAuthMsg('');
    if (!email.trim() || password.length < 6) {
      setAuthErr('Email wajib diisi dan kata sandi minimal 6 karakter.');
      return;
    }
    setSigningIn(true);
    try {
      // signUp dengan metadata signup_kind=affiliate -> trigger handle_new_user
      // membuat baris affiliates tanpa membuat outlet/user_roles.
      const { data: su, error } = await supabase.auth.signUp({
        email: email.trim(),
        password,
        options: {
          data: {
            signup_kind: 'affiliate',
            full_name: regName.trim(),
            phone: regPhone.trim(),
          },
        },
      });
      if (error) throw error;

      // Bila langsung dapat sesi (konfirmasi email OFF), pastikan baris afiliasi
      // terbentuk (idempotent) dan catat kode referral bila diisi.
      if (su.session) {
        try {
          await affiliateRegister({
            name: regName.trim() || null,
            phone: regPhone.trim() || null,
            referralCode: regReferral.trim() || null,
          });
        } catch { /* trigger sudah membuat baris; abaikan bila RPC gagal */ }
      } else {
        setAuthMsg('Pendaftaran berhasil. Cek email untuk konfirmasi, lalu masuk kembali.');
        setMode('login');
      }
    } catch (e: any) {
      setAuthErr(e.message ?? 'Gagal mendaftar.');
    } finally {
      setSigningIn(false);
    }
  };

  const save = async () => {
    setSaving(true);
    try {
      await affiliateUpdateProfile({ name, phone, bankName, bankAccountName, bankAccountNumber });
      setToast('Profil & rekening disimpan.');
      setTimeout(() => setToast(''), 3000);
      await loadData();
    } catch (e: any) {
      setToast(e.message);
    } finally {
      setSaving(false);
    }
  };

  const logout = async () => {
    await supabase.auth.signOut();
    setData(null);
  };

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-bg">
        <Loader2 className="w-8 h-8 animate-spin text-primary" />
      </div>
    );
  }

  if (!session) {
    return (
      <div className="min-h-screen flex items-center justify-center ocean-gradient p-4">
        <div className="bg-surface rounded-2xl shadow-xl w-full max-w-sm p-6">
          <div className="flex items-center gap-2 mb-5">
            <div className="w-9 h-9 rounded-xl ocean-gradient flex items-center justify-center">
              <Wallet className="w-5 h-5 text-white" />
            </div>
            <div>
              <h1 className="font-bold text-ink text-sm">Portal Afiliasi</h1>
              <p className="text-[11px] text-muted">KasirGo Partner</p>
            </div>
          </div>
          <div className="space-y-3">
            {authMsg && <p className="text-[11px] text-success">{authMsg}</p>}

            {mode === 'login' ? (
              <>
                <input
                  type="email"
                  placeholder="Email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className={inputCls}
                />
                <input
                  type="password"
                  placeholder="Kata sandi"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  onKeyDown={(e) => e.key === 'Enter' && signIn()}
                  className={inputCls}
                />
                {authErr && <p className="text-[11px] text-danger">{authErr}</p>}
                <button
                  onClick={signIn}
                  disabled={signingIn}
                  className="w-full py-2.5 rounded-xl text-sm font-semibold ocean-gradient text-white shadow-md shadow-primary/25 disabled:opacity-60 flex items-center justify-center gap-2"
                >
                  {signingIn && <Loader2 className="w-4 h-4 animate-spin" />}
                  Masuk
                </button>
                <p className="text-[11px] text-muted text-center pt-1">
                  Belum punya akun afiliasi?{' '}
                  <button onClick={() => { setMode('register'); setAuthErr(''); setAuthMsg(''); }} className="text-primary font-semibold hover:underline">
                    Daftar sekarang
                  </button>
                </p>
              </>
            ) : (
              <>
                <input
                  type="text"
                  placeholder="Nama lengkap"
                  value={regName}
                  onChange={(e) => setRegName(e.target.value)}
                  className={inputCls}
                />
                <input
                  type="email"
                  placeholder="Email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className={inputCls}
                />
                <input
                  type="password"
                  placeholder="Kata sandi (min. 6 karakter)"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className={inputCls}
                />
                <input
                  type="tel"
                  placeholder="No. HP / WA (opsional)"
                  value={regPhone}
                  onChange={(e) => setRegPhone(e.target.value)}
                  className={inputCls}
                />
                <input
                  type="text"
                  placeholder="Kode afiliasi pengenal (opsional)"
                  value={regReferral}
                  onChange={(e) => setRegReferral(e.target.value)}
                  className={inputCls}
                />
                {authErr && <p className="text-[11px] text-danger">{authErr}</p>}
                <button
                  onClick={register}
                  disabled={signingIn}
                  className="w-full py-2.5 rounded-xl text-sm font-semibold ocean-gradient text-white shadow-md shadow-primary/25 disabled:opacity-60 flex items-center justify-center gap-2"
                >
                  {signingIn && <Loader2 className="w-4 h-4 animate-spin" />}
                  Daftar
                </button>
                <p className="text-[11px] text-muted text-center pt-1">
                  Sudah punya akun?{' '}
                  <button onClick={() => { setMode('login'); setAuthErr(''); setAuthMsg(''); }} className="text-primary font-semibold hover:underline">
                    Masuk di sini
                  </button>
                </p>
              </>
            )}
          </div>
        </div>
      </div>
    );
  }

  const a = data?.affiliate;
  const summary = data?.summary;

  return (
    <div className="min-h-screen bg-bg">
      <header className="bg-surface border-b border-border px-4 sm:px-6 py-3.5 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-xl ocean-gradient flex items-center justify-center">
            <Wallet className="w-4 h-4 text-white" />
          </div>
          <div>
            <h1 className="font-bold text-ink text-sm">Portal Afiliasi</h1>
            <p className="text-[10px] text-muted">{session.user?.email}</p>
          </div>
        </div>
        <button onClick={logout} className="flex items-center gap-1.5 text-xs font-semibold text-muted hover:text-danger">
          <LogOut className="w-4 h-4" /> Keluar
        </button>
      </header>

      <main className="p-4 sm:p-6 max-w-[900px] mx-auto space-y-4">
        {!a && (
          <div className="bg-warning/10 border border-warning/30 text-warning rounded-2xl p-4 text-xs">
            Akun ini belum terdaftar sebagai afiliasi. Hubungi superadmin KasirGo untuk dihubungkan.
          </div>
        )}

        {a && a.status !== 'active' && (
          <div className="bg-warning/10 border border-warning/30 text-warning rounded-2xl p-4 text-xs">
            {a.status === 'pending'
              ? 'Pendaftaran Anda sedang menunggu persetujuan superadmin KasirGo. Anda akan dapat mulai mereferensikan setelah disetujui.'
              : `Status akun afiliasi Anda: ${a.status}. Hubungi superadmin KasirGo untuk informasi lebih lanjut.`}
          </div>
        )}

        {a && (
          <>
            <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
              <StatCard label="Kode Referral" value={a.referral_code} icon={Wallet} mono />
              <StatCard label="Total Referral" value={String(summary?.referral_count ?? a.referral_count ?? 0)} icon={Users} />
              <StatCard label="Komisi Terkumpul" value={fmtRp(summary?.commission_total ?? a.commission_total ?? 0)} icon={DollarSign} />
              <StatCard label="Belum Dicairkan" value={fmtRp(summary?.unpaid_total ?? a.unpaid_total ?? 0)} icon={TrendingUp} />
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
              <div className="bg-surface rounded-2xl border border-border/80 card-shadow p-5">
                <h2 className="font-bold text-ink text-sm mb-3 flex items-center gap-2">
                  <Banknote className="w-4 h-4 text-success" /> Riwayat Closing
                </h2>
                <div className="space-y-2 max-h-[320px] overflow-y-auto">
                  {(data?.closings ?? []).length === 0 && <p className="text-xs text-muted">Belum ada komisi.</p>}
                  {(data?.closings ?? []).map((c: any, i) => (
                    <div key={c.id ?? i} className="flex items-center justify-between p-2.5 rounded-xl border border-border bg-bg/50 text-xs">
                      <div>
                        <p className="font-semibold text-ink">{c.outlet_name ?? 'Komisi referral'}</p>
                        <p className="text-[10px] text-muted">{fmtDate(c.created_at)} · {c.status ?? '-'}</p>
                      </div>
                      <p className="font-bold text-success">{fmtRp(c.commission_amount ?? c.amount ?? 0)}</p>
                    </div>
                  ))}
                </div>
              </div>

              <div className="bg-surface rounded-2xl border border-border/80 card-shadow p-5">
                <h2 className="font-bold text-ink text-sm mb-3 flex items-center gap-2">
                  <Banknote className="w-4 h-4 text-primary" /> Riwayat Payout
                </h2>
                <div className="space-y-2 max-h-[320px] overflow-y-auto">
                  {(data?.payouts ?? []).length === 0 && <p className="text-xs text-muted">Belum ada payout.</p>}
                  {(data?.payouts ?? []).map((p: any, i) => (
                    <div key={p.id ?? i} className="flex items-center justify-between p-2.5 rounded-xl border border-border bg-bg/50 text-xs">
                      <div>
                        <p className="font-semibold text-ink">{p.method ?? 'Transfer'} · {p.status ?? '-'}</p>
                        <p className="text-[10px] text-muted">
                          {fmtDate(p.paid_at ?? p.created_at)}
                          {p.period_start && p.period_end ? ` · ${fmtDate(p.period_start)} - ${fmtDate(p.period_end)}` : ''}
                        </p>
                        {p.note && <p className="text-[10px] text-muted">{p.note}</p>}
                      </div>
                      <p className="font-bold text-primary">{fmtRp(p.amount ?? 0)}</p>
                    </div>
                  ))}
                </div>
              </div>
            </div>

            <div className="bg-surface rounded-2xl border border-border/80 card-shadow p-5">
              <h2 className="font-bold text-ink text-sm mb-3">Pengaturan Data & Rekening</h2>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <Field label="Nama"><input className={inputCls} value={name} onChange={(e) => setName(e.target.value)} /></Field>
                <Field label="No. HP / WA"><input className={inputCls} value={phone} onChange={(e) => setPhone(e.target.value)} /></Field>
                <Field label="Nama Bank"><input className={inputCls} value={bankName} onChange={(e) => setBankName(e.target.value)} /></Field>
                <Field label="Nama Pemilik Rekening"><input className={inputCls} value={bankAccountName} onChange={(e) => setBankAccountName(e.target.value)} /></Field>
                <Field label="Nomor Rekening"><input className={inputCls} value={bankAccountNumber} onChange={(e) => setBankAccountNumber(e.target.value)} /></Field>
              </div>
              <button
                onClick={save}
                disabled={saving}
                className="mt-4 px-5 py-2.5 rounded-xl text-sm font-semibold ocean-gradient text-white shadow-md shadow-primary/25 disabled:opacity-60 flex items-center gap-2"
              >
                {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
                Simpan
              </button>
            </div>
          </>
        )}
      </main>

      {toast && (
        <div className="fixed bottom-5 right-5 z-50 px-4 py-3 rounded-xl text-xs font-semibold shadow-lg bg-ink text-white">
          {toast}
        </div>
      )}
    </div>
  );
}

const inputCls =
  'w-full px-3.5 py-2.5 rounded-xl border border-border bg-bg/50 hover:bg-surface focus:bg-surface text-xs text-ink placeholder:text-muted focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary transition';
const labelCls = 'block text-[11px] font-bold text-muted uppercase tracking-wider mb-1.5';

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <label className={labelCls}>{label}</label>
      {children}
    </div>
  );
}

function StatCard({ label, value, icon: Icon, mono }: { label: string; value: string; icon: any; mono?: boolean }) {
  return (
    <div className="bg-surface rounded-2xl border border-border/80 card-shadow p-4">
      <Icon className="w-4 h-4 text-primary mb-2" />
      <p className="text-[10px] text-muted uppercase tracking-wide">{label}</p>
      <p className={`font-black text-ink ${mono ? 'font-mono text-sm' : 'text-lg'}`}>{value}</p>
    </div>
  );
}
