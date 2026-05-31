import { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { AlertTriangle, Clock, Key, Users, Share2, CheckCircle2, LogOut } from 'lucide-react';
import toast from 'react-hot-toast';
import api from '@/api/client';
import { useAuthStore } from '@/store/authStore';
import { decryptCredentialData } from '@/lib/vault';
import { credentialTypeLabel, credentialTypeIcon, formatDate } from '@/lib/utils';
import { cn } from '@/lib/utils';

interface ExpiryAlert {
  credentialId: string;
  encryptedData: string;
  dataIv: string;
  encryptedCredentialKey: string;
  type: string;
  expiryDate: string;
  daysUntilExpiry: number;
}

interface DashboardData {
  totalCredentials: number;
  sharedWithMe: number;
  groupCount: number;
  expiredCredentials: ExpiryAlert[];
  expiringCredentials: ExpiryAlert[];
  recentActivity: Array<{ action: string; resourceType: string; detail: string; timestamp: string }>;
}

interface DecryptedAlert extends ExpiryAlert { name: string }

export default function DashboardPage() {
  const navigate = useNavigate();
  const { privateKey, user, logout, refreshToken } = useAuthStore();
  const [data, setData] = useState<DashboardData | null>(null);
  const [decryptedExpired, setDecryptedExpired] = useState<DecryptedAlert[]>([]);
  const [decryptedExpiring, setDecryptedExpiring] = useState<DecryptedAlert[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const load = async () => {
      try {
        const res = await api.get('/dashboard');
        const d: DashboardData = res.data.data;
        setData(d);
        if (!privateKey) return;

        const decryptAlerts = async (alerts: ExpiryAlert[]): Promise<DecryptedAlert[]> =>
          Promise.all(alerts.map(async a => {
            try {
              const fields = await decryptCredentialData(a.encryptedData, a.dataIv, a.encryptedCredentialKey, privateKey);
              return { ...a, name: fields.name ?? credentialTypeLabel(a.type) };
            } catch {
              return { ...a, name: credentialTypeLabel(a.type) };
            }
          }));

        setDecryptedExpired(await decryptAlerts(d.expiredCredentials));
        setDecryptedExpiring(await decryptAlerts(d.expiringCredentials));
      } catch {
        // swallow
      } finally {
        setLoading(false);
      }
    };
    load();
  }, [privateKey]);

  const handleLogout = async () => {
    try {
      if (refreshToken) await api.post('/auth/logout', { refreshToken });
    } catch {}
    logout();
    toast.success('Logged out securely.');
    navigate('/login');
  };

  if (loading) {
    return <div className="flex justify-center items-center h-full"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600" /></div>;
  }

  return (
    <div className="p-6 max-w-5xl mx-auto">
      {/* Page header with logout */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Dashboard</h1>
          <p className="text-slate-500 text-sm">Welcome back, <span className="font-medium text-slate-700">{user?.username}</span>. Your vault is encrypted and secure.</p>
        </div>
        <button
          onClick={handleLogout}
          className="flex items-center gap-2 px-4 py-2 border border-slate-200 rounded-lg text-sm font-medium text-slate-600 hover:bg-red-50 hover:text-red-600 hover:border-red-200 transition-colors"
        >
          <LogOut className="w-4 h-4" />
          Sign Out
        </button>
      </div>

      <div className="grid grid-cols-3 gap-4 mb-6">
        <StatCard icon={<Key className="w-5 h-5 text-indigo-600" />} label="Total Credentials" value={data?.totalCredentials ?? 0} bg="bg-indigo-50" />
        <StatCard icon={<Share2 className="w-5 h-5 text-emerald-600" />} label="Shared With Me" value={data?.sharedWithMe ?? 0} bg="bg-emerald-50" />
        <StatCard icon={<Users className="w-5 h-5 text-violet-600" />} label="Groups" value={data?.groupCount ?? 0} bg="bg-violet-50" />
      </div>

      {decryptedExpired.length > 0 && (
        <AlertSection title="Expired Credentials" icon={<AlertTriangle className="w-4 h-4 text-red-500" />} items={decryptedExpired} variant="red" />
      )}
      {decryptedExpiring.length > 0 && (
        <AlertSection title="Expiring Soon" icon={<Clock className="w-4 h-4 text-amber-500" />} items={decryptedExpiring} variant="amber" />
      )}
      {decryptedExpired.length === 0 && decryptedExpiring.length === 0 && (
        <div className="bg-emerald-50 border border-emerald-200 rounded-xl p-4 flex items-center gap-3 mb-6">
          <CheckCircle2 className="w-5 h-5 text-emerald-600 shrink-0" />
          <p className="text-sm text-emerald-700 font-medium">No expired or expiring credentials. All good!</p>
        </div>
      )}

      {data?.recentActivity && data.recentActivity.length > 0 && (
        <div className="bg-white rounded-xl border border-slate-200 overflow-hidden">
          <div className="px-5 py-4 border-b border-slate-100">
            <h2 className="font-semibold text-slate-800">Recent Activity</h2>
          </div>
          <div className="divide-y divide-slate-50">
            {data.recentActivity.map((a, i) => (
              <div key={i} className="px-5 py-3 flex items-center justify-between">
                <div>
                  <p className="text-sm text-slate-800 font-medium">{formatAction(a.action)}</p>
                  {a.detail && <p className="text-xs text-slate-400">{a.detail}</p>}
                </div>
                <p className="text-xs text-slate-400 shrink-0 ml-4">{formatDate(a.timestamp)}</p>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

function StatCard({ icon, label, value, bg }: { icon: React.ReactNode; label: string; value: number; bg: string }) {
  return (
    <div className="bg-white rounded-xl border border-slate-200 p-5">
      <div className={cn('w-10 h-10 rounded-lg flex items-center justify-center mb-3', bg)}>{icon}</div>
      <p className="text-2xl font-bold text-slate-900">{value}</p>
      <p className="text-sm text-slate-500 mt-0.5">{label}</p>
    </div>
  );
}

function AlertSection({ title, icon, items, variant }: { title: string; icon: React.ReactNode; items: DecryptedAlert[]; variant: 'red' | 'amber' }) {
  const c = variant === 'red'
    ? { wrap: 'bg-red-50 border-red-200', badge: 'bg-red-100 text-red-700', title: 'text-red-800' }
    : { wrap: 'bg-amber-50 border-amber-200', badge: 'bg-amber-100 text-amber-700', title: 'text-amber-800' };
  return (
    <div className={cn('rounded-xl border p-4 mb-4', c.wrap)}>
      <div className="flex items-center gap-2 mb-3">
        {icon}
        <h2 className={cn('font-semibold text-sm', c.title)}>{title} ({items.length})</h2>
      </div>
      <div className="space-y-2">
        {items.map(item => (
          <Link key={item.credentialId} to={`/credentials/${item.credentialId}`}
            className="flex items-center justify-between bg-white rounded-lg px-4 py-2.5 hover:shadow-sm transition-shadow">
            <div className="flex items-center gap-3">
              <span className="text-lg">{credentialTypeIcon(item.type)}</span>
              <div>
                <p className="text-sm font-medium text-slate-800">{item.name}</p>
                <p className="text-xs text-slate-400">{credentialTypeLabel(item.type)}</p>
              </div>
            </div>
            <span className={cn('text-xs font-medium px-2 py-1 rounded-full', c.badge)}>
              {item.daysUntilExpiry < 0 ? `Expired ${Math.abs(item.daysUntilExpiry)}d ago` : item.daysUntilExpiry === 0 ? 'Expires today' : `${item.daysUntilExpiry}d left`}
            </span>
          </Link>
        ))}
      </div>
    </div>
  );
}

function formatAction(action: string) {
  const map: Record<string, string> = {
    LoginSuccess: 'Signed in', CredentialCreated: 'Created a credential',
    CredentialViewed: 'Viewed a credential', CredentialCopied: 'Copied a credential field',
    CredentialUpdated: 'Updated a credential', CredentialDeleted: 'Deleted a credential',
    ShareCreated: 'Shared a credential', ShareRevoked: 'Revoked a share',
  };
  return map[action] ?? action;
}
