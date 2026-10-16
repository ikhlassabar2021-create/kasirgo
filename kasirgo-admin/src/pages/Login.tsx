// src/pages/Login.tsx
import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Lock, Mail, Eye, EyeOff, Sparkles, ShieldCheck } from 'lucide-react';
import { supabase } from '../config/supabase';

interface LoginProps {
  onSuccess?: () => void;
}

export function Login({ onSuccess: _onSuccess }: LoginProps = {}) {
  const [email, setEmail] = useState('superadmin@kasirgo.com');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const navigate = useNavigate();

  const handleLogin = async () => {
    if (!email || !password) return;
    
    setLoading(true);
    
    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email: email.trim(),
        password: password,
      });

      if (error || !data.session) {
        throw error || new Error('Kredensial tidak valid');
      }

      navigate('/owner');
    } catch (error: any) {
      console.error('Login error:', error.message);
      alert(error.message || 'Login gagal');
    } finally {
      setLoading(false);
    }
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') handleLogin();
  };

  return (
    <div className="min-h-screen bg-bg flex items-center justify-center p-4 relative overflow-hidden text-ink">
      <div className="max-w-md w-full relative z-10">
        {/* Logo and Brand */}
        <div className="text-center mb-6 fade-in">
          <div className="inline-flex items-center justify-center w-14 h-14 rounded-2xl ocean-gradient p-0.5 shadow-lg shadow-primary/25 mb-3">
            <div className="w-full h-full bg-surface rounded-[14px] flex items-center justify-center">
              <Sparkles className="w-7 h-7 text-primary" />
            </div>
          </div>
          <h1 className="text-2xl font-black tracking-tight text-ink">
            KasirGo
          </h1>
          <div className="mt-1 flex items-center justify-center gap-1 text-xs text-primary font-bold uppercase tracking-wider">
            <ShieldCheck className="w-3.5 h-3.5" />
            <span>Centennial White & Ocean Blue</span>
          </div>
        </div>

        {/* Login Card - Background Putih Bersih & Fleksibel */}
        <div className="bg-surface rounded-2xl border border-border/80 shadow-md p-6 sm:p-7 fade-in">
          <div className="text-center mb-5">
            <h2 className="text-lg font-bold text-ink">Selamat Datang</h2>
            <p className="text-xs text-muted mt-0.5">Masuk ke pusat kendali sistem KasirGo</p>
          </div>
          
          <div className="space-y-3.5">
            {/* Email Input */}
            <div>
              <label className="block text-[11px] font-bold text-muted uppercase tracking-wider mb-1.5">
                Email Pengguna
              </label>
              <div className="relative">
                <Mail className="absolute left-3.5 top-1/2 transform -translate-y-1/2 w-4 h-4 text-muted" />
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  onKeyPress={handleKeyPress}
                  className="w-full pl-10 pr-3 py-2.5 rounded-xl border border-border bg-bg/50 hover:bg-surface focus:bg-surface text-xs text-ink placeholder:text-muted focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary transition duration-150"
                  placeholder="admin@kasirgo.com"
                />
              </div>
            </div>
            
            {/* Password Input */}
            <div>
              <label className="block text-[11px] font-bold text-muted uppercase tracking-wider mb-1.5">
                Password
              </label>
              <div className="relative">
                <Lock className="absolute left-3.5 top-1/2 transform -translate-y-1/2 w-4 h-4 text-muted" />
                <input
                  type={showPassword ? "text" : "password"}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  onKeyPress={handleKeyPress}
                  className="w-full pl-10 pr-10 py-2.5 rounded-xl border border-border bg-bg/50 hover:bg-surface focus:bg-surface text-xs text-ink placeholder:text-muted focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary transition duration-150"
                  placeholder="••••••••"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-3.5 top-1/2 transform -translate-y-1/2 text-muted hover:text-ink transition"
                  aria-label="Toggle password visibility"
                >
                  {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
            </div>
            
            {/* Submit Button - Gradasi Biru Laut */}
            <button
              onClick={handleLogin}
              disabled={loading}
              className={`w-full mt-2 py-2.5 rounded-xl font-bold text-xs tracking-wide transition-all duration-150 shadow-md ${
                loading
                  ? 'bg-primary/50 cursor-not-allowed text-white'
                  : 'ocean-gradient hover:opacity-90 text-white shadow-primary/25 active:scale-[0.99]'
              }`}
            >
              {loading ? (
                <div className="flex items-center justify-center gap-2">
                  <div className="w-3.5 h-3.5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                  MEMPROSES...
                </div>
              ) : (
                'MASUK KE DASHBOARD'
              )}
            </button>
          </div>

          {/* Quick Demo Info */}
          <div className="mt-4 p-2.5 rounded-xl bg-primary/10 border border-primary/20 flex items-center justify-between text-[11px] text-muted">
            <span className="text-muted">Akun Superadmin:</span>
            <span className="font-mono text-primary font-semibold">superadmin@kasirgo.com</span>
          </div>
        </div>
      </div>
    </div>
  );
}
