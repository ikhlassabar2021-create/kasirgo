import { useState, useEffect } from 'react'
import { HashRouter, Routes, Route, Navigate } from 'react-router-dom'
import { supabase } from './config/supabase'
import { Layout } from './components/Layout'
import { Login } from './pages/Login'
import { Dashboard } from './pages/Dashboard'
import { UsersPage } from './pages/Users'
import { UserDetailPage } from './pages/UserDetail'
import { ControlPlanePage } from './pages/ControlPlane'
import { AffiliatesPage } from './pages/Affiliates'
import { RevenuePage } from './pages/Revenue'
import { BackupPage } from './pages/Backup'
import { AuditPage } from './pages/Audit'
import { IntelligencePage } from './pages/Intelligence'
import { OwnerDashboard } from './pages/OwnerDashboard'

export default function App() {
  const [session, setSession] = useState<any>(null)
  const [loading, setLoading] = useState(true)

  const checkAuth = async () => {
    try {
      const { data: { session } } = await supabase.auth.getSession()
      setSession(session ?? null)
    } catch (err) {
      console.warn('Supabase session lookup failed:', err)
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
        setSession(null)
      } else if (session) {
        setSession(session)
      }
      setLoading(false)
    })

    return () => {
      subscription.unsubscribe()
    }
  }, [])

  const handleLogout = async () => {
    try {
      await supabase.auth.signOut()
    } catch (e) {
      console.warn(e)
    }
    setSession(null)
  }

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-cyan-500 to-sky-600">
        <div className="text-center text-white">
          <div className="h-12 w-12 animate-spin rounded-full border-4 border-white border-t-transparent mx-auto mb-4" />
          <p className="text-lg font-medium">Memuat KasirGo...</p>
        </div>
      </div>
    )
  }

  return (
    <HashRouter>
      <Routes>
        <Route path="/login" element={!session ? <Login /> : <Navigate to="/" replace />} />
        
        {/* Protected Dashboard Area */}
        <Route path="/" element={session ? <Layout onLogout={handleLogout} /> : <Navigate to="/login" replace />}>
          <Route index element={<Navigate to="/owner" replace />} />
          <Route path="owner" element={<OwnerDashboard />} />
          <Route path="superadmin" element={<Dashboard />} />
          <Route path="users" element={<UsersPage />} />
          <Route path="users/:id" element={<UserDetailPage />} />
          <Route path="outlets" element={<UsersPage />} />
          <Route path="transactions" element={<RevenuePage />} />
          <Route path="revenue" element={<RevenuePage />} />
          <Route path="affiliates" element={<AffiliatesPage />} />
          <Route path="backup" element={<BackupPage />} />
          <Route path="audit" element={<AuditPage />} />
          <Route path="intelligence" element={<IntelligencePage />} />
          <Route path="settings" element={<ControlPlanePage />} />
          <Route path="control-plane" element={<ControlPlanePage />} />
        </Route>
        
        <Route path="*" element={<Navigate to={session ? "/" : "/login"} replace />} />
      </Routes>
    </HashRouter>
  )
}
