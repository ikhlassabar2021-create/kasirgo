import { NavLink } from 'react-router-dom';
import {
  LayoutDashboard,
  BarChart3,
  Store,
  Settings,
  CreditCard,
  SlidersHorizontal,
  X,
  LogOut
} from 'lucide-react';

interface StarAdminSidebarProps {
  isOpen: boolean;
  onClose: () => void;
  onLogout: () => void;
  role?: string;
}

// RBAC: nav per role (superadmin melihat semua).
const ROLE_NAV: Record<string, string[]> = {
  superadmin: ['*'],
  finance: ['/superadmin', '/outlets', '/control-plane'],
  support: ['/superadmin', '/outlets', '/control-plane'],
  ops: ['/superadmin', '/outlets', '/features', '/control-plane'],
};

export function StarAdminSidebar({ isOpen, onClose, onLogout, role = 'superadmin' }: StarAdminSidebarProps) {
  const allowed = ROLE_NAV[role] ?? ROLE_NAV.superadmin;
  const navigation = [
    { name: 'Laporan Utama', href: '/superadmin', icon: BarChart3 },
    { name: 'Outlet Terdaftar', href: '/outlets', icon: Store },
    { name: 'Fitur Utama', href: '/features', icon: SlidersHorizontal },
    { name: 'Affiliates', href: '/affiliates', icon: CreditCard },
    { name: 'Control Plane', href: '/control-plane', icon: Settings },
  ].filter((item) => allowed.includes('*') || allowed.includes(item.href));

  return (
    <>
      {/* Mobile Overlay */}
      {isOpen && (
        <div 
          className="fixed inset-0 bg-slate-900/40 backdrop-blur-xs z-40 lg:hidden"
          onClick={onClose}
        />
      )}

      {/* Sidebar Container - Clean White & Ocean Blue Gradient Centennial */}
      <aside 
        className={`
          fixed top-0 left-0 z-50 h-screen w-60 bg-white border-r border-slate-200/80 shadow-sm transform transition-transform duration-300 ease-in-out flex flex-col text-slate-700
          ${isOpen ? 'translate-x-0' : '-translate-x-full'}
          lg:translate-x-0
        `}
      >
        {/* Logo Section */}
        <div className="p-4 border-b border-slate-100 shrink-0">
          <div className="flex items-center gap-2.5">
            <div className="w-9 h-9 rounded-xl bg-gradient-to-tr from-cyan-500 via-sky-500 to-blue-600 p-0.5 shadow-sm shadow-sky-500/20">
              <div className="w-full h-full bg-white rounded-[9px] flex items-center justify-center text-sky-600">
                <LayoutDashboard className="w-4 h-4" />
              </div>
            </div>
            <div>
              <h2 className="text-base font-extrabold text-slate-900 tracking-tight">KasirGo</h2>
              <p className="text-[10px] font-bold text-sky-600 tracking-wider uppercase">Centennial UI</p>
            </div>
            <button 
              onClick={onClose}
              aria-label="Tutup menu"
              className="lg:hidden ml-auto text-slate-400 hover:text-slate-600 p-1"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        </div>

        {/* Navigation Links */}
        <nav className="p-2.5 space-y-1 overflow-y-auto flex-1">
          {navigation.map((item) => {
            const Icon = item.icon;
            
            return (
              <NavLink
                key={item.name}
                to={item.href}
                end={item.href === '/'}
                onClick={() => window.innerWidth < 1024 && onClose()}
                className={({ isActive }) =>
                  `flex items-center gap-2.5 px-3 py-2 rounded-xl text-xs font-semibold transition-all duration-150 ${
                    isActive
                      ? 'bg-gradient-to-r from-sky-500 to-blue-600 text-white shadow-sm shadow-sky-500/25'
                      : 'text-slate-600 hover:bg-slate-100 hover:text-slate-900'
                  }`
                }
              >
                {({ isActive }) => (
                  <>
                    <Icon className={`w-4 h-4 shrink-0 ${isActive ? 'text-white' : 'text-slate-500'}`} />
                    <span className="truncate">{item.name}</span>
                    {isActive && (
                      <div className="ml-auto w-1.5 h-1.5 bg-white rounded-full shrink-0" />
                    )}
                  </>
                )}
              </NavLink>
            );
          })}
        </nav>

        {/* User Profile & Logout */}
        <div className="p-3 border-t border-slate-100 shrink-0">
          <div className="bg-slate-50 border border-slate-200/70 rounded-xl p-2.5 mb-2">
            <div className="flex items-center gap-2.5">
              <div className="w-8 h-8 rounded-lg bg-gradient-to-tr from-cyan-500 to-blue-600 flex items-center justify-center font-bold text-white text-xs shadow-xs shrink-0">
                SA
              </div>
              <div className="flex-1 min-w-0">
                <h3 className="text-xs font-bold text-slate-900 truncate">Admin</h3>
                <p className="text-[10px] text-slate-500 truncate">{role}</p>
              </div>
            </div>
          </div>
          
          <button
            onClick={onLogout}
            className="w-full flex items-center justify-center gap-1.5 bg-rose-50 hover:bg-rose-100 border border-rose-200 text-rose-700 active:scale-[0.98] py-1.5 rounded-lg text-xs font-semibold transition-colors"
          >
            <LogOut className="w-3.5 h-3.5" />
            <span>Logout</span>
          </button>
        </div>
      </aside>
    </>
  );
}
