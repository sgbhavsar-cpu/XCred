import { Link, useLocation, useNavigate } from 'react-router-dom';
import { ShieldCheck, LayoutDashboard, Key, FolderOpen, Users, Tag, Settings, LogOut, Shield, Share2 } from 'lucide-react';
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
  { to: '/groups', icon: Users, label: 'Groups' },
  { to: '/tags', icon: Tag, label: 'Tags' },
];

export default function AppLayout({ children }: { children: React.ReactNode }) {
  const location = useLocation();
  const navigate = useNavigate();
  const { user, logout, refreshToken, isAdmin } = useAuthStore();

  useSessionTimeout();

  const handleLogout = async () => {
    try {
      await api.post('/auth/logout', { refreshToken });
    } catch {}
    logout();
    toast.success('Logged out securely.');
    navigate('/login');
  };

  return (
    <div className="flex h-screen bg-slate-50">
      {/* Sidebar */}
      <aside className="w-60 bg-slate-900 flex flex-col">
        <div className="flex items-center gap-2.5 px-5 py-5 border-b border-slate-700">
          <div className="bg-indigo-600 rounded-lg p-1.5">
            <ShieldCheck className="w-5 h-5 text-white" />
          </div>
          <span className="text-white font-semibold text-lg tracking-tight">XCred</span>
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
              <p className="text-white text-xs font-medium truncate">{user?.username}</p>
              <p className="text-slate-500 text-xs truncate">{user?.role}</p>
            </div>
            <button onClick={handleLogout} title="Sign out"
              className="text-slate-500 hover:text-red-400 transition-colors">
              <LogOut className="w-4 h-4" />
            </button>
          </div>
        </div>
      </aside>

      {/* Main content */}
      <main className="flex-1 overflow-auto">
        {children}
      </main>
    </div>
  );
}
