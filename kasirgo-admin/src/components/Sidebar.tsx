import React from 'react'
import { NavLink } from 'react-router-dom'
import {
  LayoutDashboard,
  Users,
  Share2,
  Database,
  TrendingUp,
  LogOut,
  ShieldCheck,
} from 'lucide-react'
import { supabase } from '../config/supabase'

interface SidebarProps {
  onLogout: () => void
}

export const Sidebar: React.FC<SidebarProps> = ({ onLogout }) => {
  const navItems = [
    { to: '/', label: 'Dashboard', icon: <LayoutDashboard size={20} /> },
    { to: '/users', label: 'User & Outlets', icon: <Users size={20} /> },
    { to: '/affiliates', label: 'Affiliates', icon: <Share2 size={20} /> },
    { to: '/revenue', label: 'Revenue Pipa 3rd Party', icon: <TrendingUp size={20} /> },
    { to: '/backup', label: 'Backup & Cloud R2', icon: <Database size={20} /> },
  ]

  return (
    <aside className="fixed left-0 top-0 z-30 flex h-screen w-64 flex-col border-r border-slate-700/60 bg-[#0F172A]/90 p-5 backdrop-blur-xl">
      {/* Brand */}
      <div className="flex items-center gap-3 px-2 py-4">
        <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-gradient-to-tr from-[#4F46E5] via-[#7C3AED] to-[#06B6D4] text-white shadow-md shadow-indigo-500/20">
          <ShieldCheck size={24} />
        </div>
        <div>
          <h1 className="text-lg font-bold tracking-tight text-white">KasirGo</h1>
          <p className="text-[11px] font-medium tracking-wide text-[#06B6D4]">SUPERADMIN</p>
        </div>
      </div>

      {/* Navigation */}
      <nav className="mt-8 flex flex-1 flex-col gap-1.5">
        {navItems.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.to === '/'}
            className={({ isActive }) =>
              `flex items-center gap-3.5 rounded-xl px-4 py-3 text-sm font-medium transition-all ${
                isActive
                  ? 'bg-gradient-to-r from-[#4F46E5] to-[#7C3AED] text-white shadow-md shadow-indigo-500/25'
                  : 'text-slate-400 hover:bg-[#1E293B]/60 hover:text-white'
              }`
            }
          >
            {item.icon}
            <span>{item.label}</span>
          </NavLink>
        ))}
      </nav>

      {/* Footer / Logout */}
      <div className="border-t border-slate-800 pt-4">
        <button
          onClick={async () => {
            await supabase.auth.signOut()
            onLogout()
          }}
          className="flex w-full items-center gap-3 rounded-xl px-4 py-3 text-sm font-medium text-rose-400 transition-all hover:bg-rose-500/10"
        >
          <LogOut size={20} />
          <span>Keluar Superadmin</span>
        </button>
      </div>
    </aside>
  )
}
