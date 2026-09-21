import { useState, useEffect } from 'react'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { supabase } from './config/supabase'
import { Layout } from './components/Layout'
import { Login } from './pages/Login'
import { Dashboard } from './pages/Dashboard'
import { UsersPage } from './pages/Users'
import { AffiliatesPage } from './pages/Affiliates'
import { RevenuePage } from './pages/Revenue'
import { BackupPage } from './pages/Backup'
import { OwnerDashboard } from './pages/OwnerDashboard'

export default function App() {
  const [session, setSession] = useState<any>(null)
  const [loading, setLoading] = useState(true)

  const checkAuth = async () => {
    try {
      const mockStr = localStorage.getItem('kasirgo_mock_session')
      if (mockStr) {
        setSession(JSON.parse(mockStr))
        return
      }

      const { data: { session } } = await supabase.auth.getSession()
      setSession(session ?? null)
    } catch (err) {
      console.warn('Supabase session lookup failed, falling back to unauthenticated state:', err)
      setSession(null)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    checkAuth()

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((event, session) => {
      if (event === 'SIGNED_OUT') {
        localStorage.removeItem('kasirgo_mock_session')
        setSession(null)
      } else if (session) {
        setSession(session)
      }
      setLoading(false)
    })

    const handleMockChange = () => {
      checkAuth()
    }
    window.addEventListener('mock_auth_change', handleMockChange)

    return () => {
      subscription.unsubscribe()
      window.removeEventListener('mock_auth_change', handleMockChange)
    }
  }, [])

  const handleLogout = async () => {
    localStorage.removeItem('kasirgo_mock_session')
    try {
      await supabase.auth.signOut()
    } catch (e) {
      console.warn(e)
    }
    setSession(null)
  }

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-blue-600 via-purple-600 to-cyan-500">
        <div className="text-center text-white">
          <div className="h-12 w-12 animate-spin rounded-full border-4 border-white border-t-transparent mx-auto mb-4" />
          <p className="text-lg font-medium">Memuat KasirGo...</p>
        </div>
      </div>
    )
  }

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={!session ? <Login /> : <Navigate to="/" replace />} />
        
        {/* Protected Dashboard Area */}
        <Route path="/" element={session ? <Layout onLogout={handleLogout} /> : <Navigate to="/login" replace />}>
          <Route index element={<Navigate to="/owner" replace />} />
          <Route path="owner" element={<OwnerDashboard />} />
          <Route path="superadmin" element={<Dashboard />} />
          <Route path="users" element={<UsersPage />} />
          <Route path="outlets" element={<UsersPage />} />
          <Route path="transactions" element={<RevenuePage />} />
          <Route path="revenue" element={<RevenuePage />} />
          <Route path="affiliates" element={<AffiliatesPage />} />
          <Route path="backup" element={<BackupPage />} />
          <Route path="settings" element={
            <div className="p-6 max-w-[1920px] mx-auto">
              <h1 className="text-2xl font-bold text-gray-800 mb-4">Pengaturan Sistem</h1>
              <div className="bg-white rounded-[24px] p-8 card-shadow border border-gray-100">
                <p className="text-gray-500">Pengaturan StarAdmin & Outlet UMKM terhubung.</p>
              </div>
            </div>
          } />
        </Route>
        
        <Route path="*" element={<Navigate to={session ? "/" : "/login"} replace />} />
      </Routes>
    </BrowserRouter>
  )
}
