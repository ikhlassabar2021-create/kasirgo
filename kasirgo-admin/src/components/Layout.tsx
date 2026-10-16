import { useState } from 'react';
import { Outlet, useLocation } from 'react-router-dom'
import { Menu, LayoutDashboard } from 'lucide-react'
import { StarAdminSidebar } from './StarAdminSidebar'

interface LayoutProps {
  onLogout: () => void
  role?: string
}

export const Layout: React.FC<LayoutProps> = ({ onLogout, role = 'superadmin' }) => {
  const [sidebarOpen, setSidebarOpen] = useState(false)
  const location = useLocation()

  // Title header for mobile bar
  const getPageTitle = () => {
    switch (location.pathname) {
      case '/superadmin': return 'Laporan Utama';
      case '/outlets': return 'Outlet Terdaftar';
      case '/features': return 'Fitur Utama';
      case '/affiliates': return 'Afiliasi & Referral';
      case '/control-plane': return 'Control Plane';
      default:
        if (location.pathname.startsWith('/outlets/')) return 'Detail Outlet';
        return 'KasirGo Superadmin';
    }
  }

  return (
    <div className="min-h-screen bg-bg text-ink flex flex-col font-sans">
      {/* Mobile Top App Bar - selaras dengan header owner (60px) */}
      <header className="lg:hidden sticky top-0 z-40 h-[60px] bg-surface/95 backdrop-blur-md border-b border-border px-4 flex items-center justify-between">
        <div className="flex items-center gap-2.5">
          <button 
            onClick={() => setSidebarOpen(true)}
            aria-label="Open navigation menu"
            className="w-9 h-9 bg-bg hover:bg-border/60 active:bg-border/60 rounded-lg flex items-center justify-center text-ink border border-border"
          >
            <Menu className="w-4 h-4" />
          </button>
          <div>
            <div className="text-[10px] font-bold uppercase tracking-wider text-primary flex items-center gap-1">
              <LayoutDashboard className="w-3 h-3" /> KasirGo Superadmin
            </div>
            <h1 className="text-xs sm:text-sm font-bold text-ink truncate max-w-[190px]">
              {getPageTitle()}
            </h1>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <div className="bubble-glass w-8 h-8 rounded-xl text-white font-bold text-xs flex items-center justify-center">
            SA
          </div>
        </div>
      </header>

      {/* Sidebar with Centennial Theme */}
      <StarAdminSidebar
        isOpen={sidebarOpen}
        onClose={() => setSidebarOpen(false)}
        onLogout={onLogout}
        role={role}
      />

      {/* Main Content Area - konten maxWidth 1100 (selaras owner) */}
      <main className="lg:ml-60 flex-1 p-3 sm:p-5 lg:p-6 min-h-[calc(100vh-60px)] lg:min-h-screen bg-bg">
        <div className="mx-auto max-w-[1100px]">
          <Outlet />
        </div>
      </main>
    </div>
  )
}
