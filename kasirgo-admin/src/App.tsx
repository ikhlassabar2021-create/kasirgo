import { useState, useEffect, type ReactElement } from 'react'
import { HashRouter, Routes, Route, Navigate, useLocation } from 'react-router-dom'
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
import { checkAdminRole } from './lib/adminApi'

// ST11-4 RBAC: halaman per role (superadmin = semua).
const ROLE_ROUTES: Record<string, string[]> = {
  superadmin: ['*'],
  finance: ['/superadmin', '/revenue', '/intelligence', '/audit', '/owner'],
  support: ['/superadmin', '/users', '/outlets', '/backup', '/intelligence', '/audit', '/owner'],
  ops: ['/superadmin', '/users', '/outlets', '/control-plane', '/settings', '/intelligence', '/audit', '/owner'],
}

const routeAllowed = (path: string, role: string): boolean => {
  const allowed = ROLE_ROUTES[role] ?? ROLE_ROUTES.superadmin
  if (allowed.includes('*')) return true
  if (allowed.includes(path)) return true
  // /users/<id> diperbolehkan bila /users diizinkan.
  if (path.startsWith('/users/')) return allowed.includes('/users')
  return false
}

function Forbidden() {
  return (
    <div className="min-h-[60vh] flex flex-col items-center justify-center text-center p-6">
      <div className="w-14 h-14 rounded-2xl bg-rose-50 border border-rose-200 flex items-center justify-center mb-4">
        <span className="text-rose-500 text-2xl font-black">!</span>
      </div>
      <h1 className="text-lg font-bold text-slate-900 mb-1">Akses Ditolak</h1>
      <p className="text-xs text-slate-500 max-w-xs">
        Role admin Anda tidak memiliki izin untuk halaman ini. Hubungi superadmin.
      </p>
    </div>
  )
}

export default function App() {
  const [session, setSession] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const [role, setRole] = useState<string | null>(null)

  const checkAuth = async () => {
    try {
      const { data: { session } } = await supabase.auth.getSession()
      setSession(session ?? null)
      if (session) {
        const admin = await checkAdminRole()
        setRole(admin?.role ?? null)
      } else {
        setRole(null)
      }
    } catch (err) {
      console.warn('Supabase session lookup failed:', err)
      setSession(null)
      setRole(null)
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
        setRole(null)
      } else if (session) {
        setSession(session)
        checkAdminRole().then((admin) => setRole(admin?.role ?? null))
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
    setRole(null)
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

  // Guard RBAC per role: element dibungkus cek izin path aktif.
  const guard = (el: ReactElement) => <RoleGuard role={role} element={el} />

  return (
    <HashRouter>
      <Routes>
        <Route path="/login" element={!session ? <Login /> : <Navigate to="/" replace />} />

        {/* Protected Dashboard Area */}
        <Route path="/" element={session ? <Layout onLogout={handleLogout} role={role ?? 'superadmin'} /> : <Navigate to="/login" replace />}>
          <Route index element={<Navigate to="/owner" replace />} />
          <Route path="owner" element={guard(<OwnerDashboard />)} />
          <Route path="superadmin" element={guard(<Dashboard />)} />
          <Route path="users" element={guard(<UsersPage />)} />
          <Route path="users/:id" element={guard(<UserDetailPage />)} />
          <Route path="outlets" element={guard(<UsersPage />)} />
          <Route path="transactions" element={guard(<RevenuePage />)} />
          <Route path="revenue" element={guard(<RevenuePage />)} />
          <Route path="affiliates" element={guard(<AffiliatesPage />)} />
          <Route path="backup" element={guard(<BackupPage />)} />
          <Route path="audit" element={guard(<AuditPage />)} />
          <Route path="intelligence" element={guard(<IntelligencePage />)} />
          <Route path="settings" element={guard(<ControlPlanePage />)} />
          <Route path="control-plane" element={guard(<ControlPlanePage />)} />
        </Route>

        <Route path="*" element={<Navigate to={session ? "/" : "/login"} replace />} />
      </Routes>
    </HashRouter>
  )
}

function RoleGuard({ role, element }: { role: string | null; element: ReactElement }) {
  const location = useLocation()
  if (role === null) return <Forbidden />
  if (!routeAllowed(location.pathname, role)) return <Forbidden />
  return element
}
