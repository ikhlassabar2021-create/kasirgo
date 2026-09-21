// src/pages/Login.tsx
import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Lock, Mail, Eye, EyeOff, Sparkles, ShieldCheck } from 'lucide-react';
import { supabase } from '../config/supabase';

interface LoginProps {
  onSuccess?: () => void;
}

export function Login({ onSuccess: _onSuccess }: LoginProps = {}) {
  const [email, setEmail] = useState('owner@kasirgo.com');
  const [password, setPassword] = useState('password123');
  const [loading, setLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const navigate = useNavigate();

  const handleLogin = async () => {
    if (!email || !password) return;
    
    setLoading(true);
    
    try {
      let success = false;
      const { data, error } = await supabase.auth.signInWithPassword({
        email: email.trim(),
        password: password,
      });

      if (!error && data.session) {
        success = true;
      } else {
        // Fallback demo login owner & superadmin
        if (password === 'password123' || password === 'TestFix123!') {
          const isSuperadmin = email.trim() === 'admin@kasirgo.com';
          const mockUser = {
            id: isSuperadmin ? 'mock-superadmin-id' : 'mock-owner-id',
            email: email.trim(),
            user_metadata: { 
              role: isSuperadmin ? 'superadmin' : 'owner', 
              full_name: isSuperadmin ? 'Super Admin KasirGo' : 'Owner Kopi Senja' 
            }
          };
          localStorage.setItem('kasirgo_mock_session', JSON.stringify({ user: mockUser }));
          window.dispatchEvent(new Event('mock_auth_change'));
          success = true;
        } else {
          throw error || new Error('Kredensial tidak valid');
        }
      }
      
      if (success) {
        navigate('/owner');
      }
    } catch (error: any) {
      console.error('Login error:', error.message);
      alert(error.message || 'Login failed');
    } finally {
      setLoading(false);
    }
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') handleLogin();
  };

  return (
    <div className="min-h-screen bg-slate-50 flex items-center justify-center p-4 relative overflow-hidden text-slate-800">
      <div className="max-w-md w-full relative z-10">
        {/* Logo and Brand */}
        <div className="text-center mb-6 fade-in">
          <div className="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-gradient-to-tr from-cyan-500 via-sky-500 to-blue-600 p-0.5 shadow-lg shadow-sky-500/25 mb-3">
            <div className="w-full h-full bg-white rounded-[14px] flex items-center justify-center">
              <Sparkles className="w-7 h-7 text-sky-600" />
            </div>
          </div>
          <h1 className="text-2xl font-black tracking-tight text-slate-900">
            KasirGo
          </h1>
          <div className="mt-1 flex items-center justify-center gap-1 text-xs text-sky-600 font-bold uppercase tracking-wider">
            <ShieldCheck className="w-3.5 h-3.5" />
            <span>Centennial White & Ocean Blue</span>
          </div>
        </div>

        {/* Login Card - Background Putih Bersih & Fleksibel */}
        <div className="bg-white rounded-2xl border border-slate-200/80 shadow-md p-6 sm:p-7 fade-in">
          <div className="text-center mb-5">
            <h2 className="text-lg font-bold text-slate-900">Selamat Datang</h2>
            <p className="text-xs text-slate-500 mt-0.5">Masuk ke pusat kendali sistem KasirGo</p>
          </div>
          
          <div className="space-y-3.5">
            {/* Email Input */}
            <div>
              <label className="block text-[11px] font-bold text-slate-600 uppercase tracking-wider mb-1.5">
                Email Pengguna
              </label>
              <div className="relative">
                <Mail className="absolute left-3.5 top-1/2 transform -translate-y-1/2 w-4 h-4 text-slate-400" />
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  onKeyPress={handleKeyPress}
                  className="w-full pl-10 pr-3 py-2.5 rounded-xl border border-slate-200 bg-slate-50/50 hover:bg-white focus:bg-white text-xs text-slate-800 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-sky-500/30 focus:border-sky-500 transition duration-150"
                  placeholder="admin@kasirgo.com"
                />
              </div>
            </div>
            
            {/* Password Input */}
            <div>
              <label className="block text-[11px] font-bold text-slate-600 uppercase tracking-wider mb-1.5">
                Password
              </label>
              <div className="relative">
                <Lock className="absolute left-3.5 top-1/2 transform -translate-y-1/2 w-4 h-4 text-slate-400" />
                <input
                  type={showPassword ? "text" : "password"}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  onKeyPress={handleKeyPress}
                  className="w-full pl-10 pr-10 py-2.5 rounded-xl border border-slate-200 bg-slate-50/50 hover:bg-white focus:bg-white text-xs text-slate-800 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-sky-500/30 focus:border-sky-500 transition duration-150"
                  placeholder="••••••••"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-3.5 top-1/2 transform -translate-y-1/2 text-slate-400 hover:text-slate-600 transition"
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
                  ? 'bg-sky-400 cursor-not-allowed text-white'
                  : 'bg-gradient-to-r from-cyan-500 via-sky-600 to-blue-600 hover:from-cyan-600 hover:via-sky-700 hover:to-blue-700 text-white shadow-sky-500/25 active:scale-[0.99]'
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
          <div className="mt-4 p-2.5 rounded-xl bg-sky-50/80 border border-sky-100 flex items-center justify-between text-[11px] text-slate-600">
            <span className="text-slate-500">Demo Login Owner:</span>
            <span className="font-mono text-sky-700 font-semibold">owner@kasirgo.com</span>
          </div>
        </div>
      </div>
    </div>
  );
}
