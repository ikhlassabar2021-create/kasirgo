import { useState } from 'react';
import { Outlet, useLocation } from 'react-router-dom'
import { Menu, LayoutDashboard } from 'lucide-react'
import { StarAdminSidebar } from './StarAdminSidebar'

interface LayoutProps {
  onLogout: () => void
}

export const Layout: React.FC<LayoutProps> = ({ onLogout }) => {
  const [sidebarOpen, setSidebarOpen] = useState(false)
  const location = useLocation()

  // Title header for mobile bar
  const getPageTitle = () => {
    switch (location.pathname) {
      case '/owner': return 'Dashboard Owner';
      case '/users': return 'Kelola Pengguna';
      case '/outlets': return 'Daftar Outlet';
      case '/revenue': return 'Pendapatan & Transaksi';
      case '/affiliates': return 'Afiliasi & Referral';
      case '/backup': return 'Backup & Pulihkan';
      case '/control-plane': return 'Control Plane';
      case '/settings': return 'Control Plane';
      default:
        if (location.pathname.startsWith('/users/')) return 'Detail Pengguna';
        return 'KasirGo Superadmin';
    }
  }

  return (
    <div className="min-h-screen bg-slate-50 text-slate-800 flex flex-col font-sans">
      {/* Mobile Top App Bar */}
      <header className="lg:hidden sticky top-0 z-40 h-[60px] bg-white/95 backdrop-blur-md border-b border-slate-200/80 shadow-xs px-4 flex items-center justify-between">
        <div className="flex items-center gap-2.5">
          <button 
            onClick={() => setSidebarOpen(true)}
            aria-label="Open navigation menu"
            className="w-9 h-9 bg-slate-100 hover:bg-slate-200 active:bg-slate-200 rounded-lg flex items-center justify-center text-slate-700 border border-slate-200"
          >
            <Menu className="w-4 h-4" />
          </button>
          <div>
            <div className="text-[10px] font-bold uppercase tracking-wider text-sky-600 flex items-center gap-1">
              <LayoutDashboard className="w-3 h-3" /> KasirGo Centennial
            </div>
            <h1 className="text-xs sm:text-sm font-bold text-slate-900 truncate max-w-[190px]">
              {getPageTitle()}
            </h1>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <div className="w-7 h-7 rounded-lg bg-gradient-to-tr from-cyan-500 to-blue-600 text-white font-bold text-xs flex items-center justify-center shadow-xs">
            SA
          </div>
        </div>
      </header>

      {/* Sidebar with Centennial Theme */}
      <StarAdminSidebar 
        isOpen={sidebarOpen} 
        onClose={() => setSidebarOpen(false)}
        onLogout={onLogout}
      />

      {/* Main Content Area - White clean container */}
      <main className="lg:ml-60 flex-1 p-3 sm:p-5 lg:p-6 min-h-[calc(100vh-60px)] lg:min-h-screen bg-slate-50">
        <div className="mx-auto max-w-[1100px]">
          <Outlet />
        </div>
      </main>
    </div>
  )
}
