import { NavLink } from 'react-router-dom';
import {
  LayoutDashboard,
  BarChart3,
  Store,
  Settings,
  CreditCard,
  SlidersHorizontal,
  X,
  LogOut,
  LifeBuoy
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
  finance: ['/superadmin', '/outlets', '/control-plane', '/support'],
  support: ['/superadmin', '/outlets', '/control-plane', '/support'],
  ops: ['/superadmin', '/outlets', '/features', '/control-plane', '/support'],
};

export function StarAdminSidebar({ isOpen, onClose, onLogout, role = 'superadmin' }: StarAdminSidebarProps) {
  const allowed = ROLE_NAV[role] ?? ROLE_NAV.superadmin;
  const navigation = [
    { name: 'Laporan Utama', href: '/superadmin', icon: BarChart3 },
    { name: 'Outlet Terdaftar', href: '/outlets', icon: Store },
    { name: 'Fitur Utama', href: '/features', icon: SlidersHorizontal },
    { name: 'Affiliates', href: '/affiliates', icon: CreditCard },
    { name: 'Tiket Support', href: '/support', icon: LifeBuoy },
    { name: 'Control Plane', href: '/control-plane', icon: Settings },
  ].filter((item) => allowed.includes('*') || allowed.includes(item.href));

  return (
    <>
      {/* Mobile Overlay */}
      {isOpen && (
        <div 
          className="fixed inset-0 bg-ink/40 backdrop-blur-xs z-40 lg:hidden"
          onClick={onClose}
        />
      )}

      {/* Sidebar Container - selaras owner: putih, border v3, brand bubble glass */}
      <aside 
        className={`
          fixed top-0 left-0 z-50 h-screen w-60 bg-surface border-r border-border transform transition-transform duration-300 ease-in-out flex flex-col text-ink
          ${isOpen ? 'translate-x-0' : '-translate-x-full'}
          lg:translate-x-0
        `}
      >
        {/* Logo Section */}
        <div className="p-4 border-b border-border shrink-0">
          <div className="flex items-center gap-2.5">
            <div className="bubble-glass w-9 h-9 rounded-xl flex items-center justify-center text-white">
              <LayoutDashboard className="w-4 h-4" />
            </div>
            <div>
              <h2 className="text-base font-extrabold text-ink tracking-tight">KasirGo</h2>
              <p className="text-[10px] font-bold text-primary tracking-wider uppercase">Superadmin</p>
            </div>
            <button 
              onClick={onClose}
              aria-label="Tutup menu"
              className="lg:hidden ml-auto text-muted hover:text-ink p-1"
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
                  `flex items-center gap-2.5 px-3 py-2.5 rounded-xl text-xs font-semibold transition-all duration-150 ${
                    isActive
                      ? 'bg-primary text-white shadow-sm'
                      : 'text-muted hover:bg-bg hover:text-ink'
                  }`
                }
              >
                {({ isActive }) => (
                  <>
                    <Icon className={`w-4 h-4 shrink-0 ${isActive ? 'text-white' : 'text-muted'}`} />
                    <span className="truncate">{item.name}</span>
                    {isActive && (
                      <div className="ml-auto w-1.5 h-1.5 bg-surface rounded-full shrink-0" />
                    )}
                  </>
                )}
              </NavLink>
            );
          })}
        </nav>

        {/* User Profile & Logout */}
        <div className="p-3 border-t border-border shrink-0">
          <div className="bg-bg border border-border rounded-xl p-2.5 mb-2">
            <div className="flex items-center gap-2.5">
              <div className="bubble-glass w-8 h-8 rounded-lg flex items-center justify-center font-bold text-white text-xs shrink-0">
                SA
              </div>
              <div className="flex-1 min-w-0">
                <h3 className="text-xs font-bold text-ink truncate">Admin</h3>
                <p className="text-[10px] text-muted truncate">{role}</p>
              </div>
            </div>
          </div>
          
          <button
            onClick={onLogout}
            className="w-full flex items-center justify-center gap-1.5 bg-danger/10 hover:bg-danger/15 border border-danger/25 text-danger active:scale-[0.98] py-2 rounded-xl text-xs font-semibold transition-colors"
          >
            <LogOut className="w-3.5 h-3.5" />
            <span>Logout</span>
          </button>
        </div>
      </aside>
    </>
  );
}
