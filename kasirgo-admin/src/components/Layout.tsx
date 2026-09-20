import React from 'react'
import { Outlet } from 'react-router-dom'
import { Sidebar } from './Sidebar'

interface LayoutProps {
  onLogout: () => void
}

export const Layout: React.FC<LayoutProps> = ({ onLogout }) => {
  return (
    <div className="min-h-screen bg-[#0F172A] text-slate-100 flex">
      <Sidebar onLogout={onLogout} />
      <main className="ml-64 flex-1 p-8 overflow-y-auto min-h-screen">
        <div className="mx-auto max-w-7xl">
          <Outlet />
        </div>
      </main>
    </div>
  )
}
