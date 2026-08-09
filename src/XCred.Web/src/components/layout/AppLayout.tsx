import { useEffect, useState } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { ShieldCheck, LayoutDashboard, Key, FolderOpen, Users, Tag, Settings, LogOut, Shield, Share2, Menu, X } from 'lucide-react';
import { useAuthStore } from '@/store/authStore';
import { useSessionTimeout } from '@/hooks/useSessionTimeout';
import api from '@/api/client';
import toast from 'react-hot-toast';
import { cn } from '@/lib/utils';

const navItems = [
  { to: '/dashboard', icon: LayoutDashboard, label: 'Dashboard' },
  { to: '/credentials', icon: Key, label: 'Credentials' },
  { to: '/shares', icon: Share2, label: 'Shared' },
  { to: '/folders', icon: FolderOpen, label: 'Folders' },
  { to: '/groups', icon: Users, label: 'Teams' },
  { to: '/tags', icon: Tag, label: 'Tags' },
];

export default function AppLayout({ children }: { children: React.ReactNode }) {
  const location = useLocation();
  const navigate = useNavigate();
  const { user, logout, refreshToken, isAdmin, setOrgSettings } = useAuthStore();
  const [mobileNavOpen, setMobileNavOpen] = useState(false);

  useSessionTimeout();

  // Load admin-configurable org settings (session timeout, attachment size cap, etc.)
  // once per session so pages that need them don't each hardcode the server's defaults.
  useEffect(() => {
    api.get('/dashboard').then(res => setOrgSettings(res.data.data.orgSettings)).catch(() => {});
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Close the drawer automatically whenever the route changes, so picking a
  // nav item on mobile doesn't leave the overlay sitting open.
  useEffect(() => {
    setMobileNavOpen(false);
  }, [location.pathname]);

  const handleLogout = async () => {
    try {
      await api.post('/auth/logout', { refreshToken });
    } catch {}
    logout();
    toast.success('Logged out securely.');
    navigate('/login');
  };

  return (
    <div className="flex flex-col md:flex-row h-screen bg-slate-50">
      {/* Mobile top bar — hidden from md: up, where the sidebar is always visible instead */}
      <div className="md:hidden flex items-center justify-between px-4 py-3 bg-slate-900 border-b border-slate-700 shrink-0">
        <div className="flex items-center gap-2.5">
          <div className="bg-indigo-600 rounded-lg p-1.5">
            <ShieldCheck className="w-5 h-5 text-white" />
          </div>
          <span className="text-white font-semibold text-lg tracking-tight">XCred</span>
        </div>
        <button onClick={() => setMobileNavOpen(true)} aria-label="Open menu"
          className="text-white p-1.5 -mr-1.5 hover:bg-slate-800 rounded-lg transition-colors">
          <Menu className="w-5 h-5" />
        </button>
      </div>

      {/* Backdrop, mobile only, closes the drawer on outside click */}
      {mobileNavOpen && (
        <div className="fixed inset-0 bg-black/50 z-40 md:hidden" onClick={() => setMobileNavOpen(false)} />
      )}

      {/* Sidebar — an off-canvas drawer below md:, a static column from md: up */}
      <aside className={cn(
        'fixed md:static inset-y-0 left-0 z-50 w-60 bg-slate-900 flex flex-col',
        'transform transition-transform duration-200 md:translate-x-0 md:transition-none',
        mobileNavOpen ? 'translate-x-0' : '-translate-x-full'
      )}>
        <div className="flex items-center justify-between gap-2.5 px-5 py-5 border-b border-slate-700">
          <div className="flex items-center gap-2.5">
            <div className="bg-indigo-600 rounded-lg p-1.5">
              <ShieldCheck className="w-5 h-5 text-white" />
            </div>
            <span className="text-white font-semibold text-lg tracking-tight">XCred</span>
          </div>
          <button onClick={() => setMobileNavOpen(false)} aria-label="Close menu"
            className="md:hidden text-slate-400 hover:text-white transition-colors">
            <X className="w-5 h-5" />
          </button>
        </div>

        <nav className="flex-1 px-3 py-4 space-y-0.5">
          {navItems.map(({ to, icon: Icon, label }) => (
            <Link key={to} to={to}
              className={cn(
                'flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors',
                location.pathname.startsWith(to)
                  ? 'bg-indigo-600 text-white'
                  : 'text-slate-400 hover:text-white hover:bg-slate-800'
              )}>
              <Icon className="w-4 h-4" />
              {label}
            </Link>
          ))}

          {isAdmin() && (
            <Link to="/admin"
              className={cn(
                'flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors mt-2',
                location.pathname.startsWith('/admin')
                  ? 'bg-indigo-600 text-white'
                  : 'text-slate-400 hover:text-white hover:bg-slate-800'
              )}>
              <Shield className="w-4 h-4" />
              Admin
            </Link>
          )}
        </nav>

        <div className="px-3 py-3 border-t border-slate-700 space-y-0.5">
          <Link to="/settings"
            className={cn(
              'flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors',
              location.pathname === '/settings'
                ? 'bg-indigo-600 text-white'
                : 'text-slate-400 hover:text-white hover:bg-slate-800'
            )}>
            <Settings className="w-4 h-4" />
            Settings
          </Link>

          <div className="flex items-center gap-2 px-3 py-2">
            <div className="w-7 h-7 rounded-full bg-indigo-600 flex items-center justify-center text-white text-xs font-semibold shrink-0">
              {user?.username?.[0]?.toUpperCase()}
            </div>
            <div className="flex-1 min-w-0">
              <p data-testid="current-username" className="text-white text-xs font-medium truncate">{user?.username}</p>
              <p data-testid="current-role" className="text-slate-500 text-xs truncate">{user?.role}</p>
            </div>
            <button onClick={handleLogout} title="Sign out"
              className="text-slate-500 hover:text-red-400 transition-colors">
              <LogOut className="w-4 h-4" />
            </button>
          </div>
        </div>
      </aside>

      {/* Main content */}
      <main className="flex-1 min-w-0 overflow-auto">
        {children}
      </main>
    </div>
  );
}
