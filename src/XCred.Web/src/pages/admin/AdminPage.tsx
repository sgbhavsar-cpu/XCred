import { useEffect, useRef, useState } from 'react';
import { UserCheck, UserX, Shield, Users, Activity, Settings, Save, Send, HardDrive, Download, Upload, AlertTriangle, CheckCircle2 } from 'lucide-react';
import api from '@/api/client';
import toast from 'react-hot-toast';
import { formatDateTime } from '@/lib/utils';
import { cn } from '@/lib/utils';

interface AdminUser {
  id: string; username: string; email: string; role: string;
  isActive: boolean; isApproved: boolean; createdAt: string; lastLoginAt: string | null;
}

type Tab = 'users' | 'pending' | 'audit' | 'settings' | 'system-backup';

export default function AdminPage() {
  const [tab, setTab] = useState<Tab>('users');
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [pending, setPending] = useState<AdminUser[]>([]);
  const [auditLogs, setAuditLogs] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  const loadData = async () => {
    setLoading(true);
    try {
      const [allRes, pendingRes] = await Promise.all([
        api.get('/admin/users'),
        api.get('/admin/users?pendingOnly=true'),
      ]);
      setUsers(allRes.data.data);
      setPending(pendingRes.data.data.filter((u: AdminUser) => !u.isApproved));
    } catch { toast.error('Failed to load users.'); }
    finally { setLoading(false); }
  };

  const loadAudit = async () => {
    try {
      const res = await api.get('/admin/audit-log');
      setAuditLogs(res.data.data.items);
    } catch {}
  };

  useEffect(() => { loadData(); }, []);
  useEffect(() => { if (tab === 'audit') loadAudit(); }, [tab]);

  const approve = async (id: string) => { await api.post(`/admin/users/${id}/approve`); toast.success('User approved.'); await loadData(); };
  const deactivate = async (id: string) => { if (!confirm('Deactivate this user?')) return; await api.post(`/admin/users/${id}/deactivate`); toast.success('Deactivated.'); await loadData(); };
  const activate = async (id: string) => { await api.post(`/admin/users/${id}/activate`); toast.success('Activated.'); await loadData(); };
  const setRole = async (id: string, role: string) => { await api.post(`/admin/users/${id}/role`, { role }); toast.success(`Role → ${role}`); await loadData(); };

  const tabs: Array<{ key: Tab; label: string; icon: React.ReactNode; badge?: number }> = [
    { key: 'users', label: 'All Users', icon: <Users className="w-4 h-4" /> },
    { key: 'pending', label: 'Pending Approval', icon: <UserCheck className="w-4 h-4" />, badge: pending.length },
    { key: 'audit', label: 'Audit Log', icon: <Activity className="w-4 h-4" /> },
    { key: 'settings', label: 'Org Settings', icon: <Settings className="w-4 h-4" /> },
    { key: 'system-backup', label: 'System Backup', icon: <HardDrive className="w-4 h-4" /> },
  ];

  return (
    <div className="p-6 max-w-5xl mx-auto">
      <div className="flex items-center gap-3 mb-6">
        <div className="bg-indigo-600 rounded-lg p-2">
          <Shield className="w-5 h-5 text-white" />
        </div>
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Admin Panel</h1>
          <p className="text-slate-500 text-sm">Manage users, audit logs, and organisation settings</p>
        </div>
      </div>

      <div className="flex gap-1 bg-slate-100 rounded-xl p-1 mb-6 flex-wrap">
        {tabs.map(t => (
          <button key={t.key} onClick={() => setTab(t.key)}
            className={cn(
              'flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition-colors',
              tab === t.key ? 'bg-white text-slate-900 shadow-sm' : 'text-slate-500 hover:text-slate-700'
            )}>
            {t.icon} {t.label}
            {t.badge != null && t.badge > 0 && (
              <span className="bg-red-500 text-white text-xs rounded-full px-1.5 py-0.5 min-w-[18px] text-center">{t.badge}</span>
            )}
          </button>
        ))}
      </div>

      {loading && tab !== 'settings' && tab !== 'system-backup' ? (
        <div className="flex justify-center py-16"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600" /></div>
      ) : tab === 'pending' ? (
        <PendingTab users={pending} onApprove={approve} />
      ) : tab === 'audit' ? (
        <AuditTab logs={auditLogs} />
      ) : tab === 'settings' ? (
        <OrgSettingsTab />
      ) : tab === 'system-backup' ? (
        <SystemBackupTab />
      ) : (
        <UsersTab users={users} onDeactivate={deactivate} onActivate={activate} onSetRole={setRole} />
      )}
    </div>
  );
}

function PendingTab({ users, onApprove }: { users: AdminUser[]; onApprove: (id: string) => void }) {
  if (users.length === 0) return (
    <div className="text-center py-16 text-slate-400">
      <UserCheck className="w-10 h-10 mx-auto mb-3 opacity-30" />
      <p className="font-medium">No pending approvals.</p>
    </div>
  );
  return (
    <div className="space-y-3">
      {users.map(u => (
        <div key={u.id} className="bg-white rounded-xl border border-slate-200 p-4 flex items-center justify-between">
          <div>
            <p className="font-semibold text-slate-800">{u.username}</p>
            <p className="text-sm text-slate-400">{u.email}</p>
            <p className="text-xs text-slate-400 mt-0.5">Registered {formatDateTime(u.createdAt)}</p>
          </div>
          <button onClick={() => onApprove(u.id)}
            className="flex items-center gap-2 bg-emerald-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-emerald-700 transition-colors">
            <UserCheck className="w-4 h-4" /> Approve
          </button>
        </div>
      ))}
    </div>
  );
}

function UsersTab({ users, onDeactivate, onActivate, onSetRole }: {
  users: AdminUser[]; onDeactivate: (id: string) => void;
  onActivate: (id: string) => void; onSetRole: (id: string, role: string) => void;
}) {
  return (
    <div className="bg-white rounded-xl border border-slate-200 overflow-hidden">
      <div className="overflow-x-auto">
      <table className="w-full text-sm">
        <thead className="bg-slate-50 border-b border-slate-200">
          <tr>
            {['User', 'Role', 'Status', 'Last Login', 'Actions'].map(h => (
              <th key={h} className={cn('text-left px-5 py-3 font-medium text-slate-600', h === 'Actions' && 'text-right')}>{h}</th>
            ))}
          </tr>
        </thead>
        <tbody className="divide-y divide-slate-100">
          {users.map(u => (
            <tr key={u.id} className="hover:bg-slate-50/50">
              <td className="px-5 py-3">
                <p className="font-medium text-slate-800">{u.username}</p>
                <p className="text-xs text-slate-400">{u.email}</p>
              </td>
              <td className="px-5 py-3">
                <select value={u.role} onChange={e => onSetRole(u.id, e.target.value)}
                  className="text-xs border border-slate-200 rounded px-2 py-1 focus:outline-none focus:ring-1 focus:ring-indigo-500 bg-white">
                  <option value="User">User</option>
                  <option value="Admin">Admin</option>
                </select>
              </td>
              <td className="px-5 py-3">
                <span className={cn('text-xs font-medium px-2 py-1 rounded-full',
                  !u.isApproved ? 'bg-amber-100 text-amber-700' :
                  u.isActive ? 'bg-emerald-100 text-emerald-700' : 'bg-red-100 text-red-700')}>
                  {!u.isApproved ? 'Pending' : u.isActive ? 'Active' : 'Inactive'}
                </span>
              </td>
              <td className="px-5 py-2.5 text-xs text-slate-400">
                {u.lastLoginAt ? formatDateTime(u.lastLoginAt) : 'Never'}
              </td>
              <td className="px-5 py-2.5 text-right">
                {u.isActive ? (
                  <button onClick={() => onDeactivate(u.id)} className="text-xs text-red-600 hover:underline flex items-center gap-1 ml-auto">
                    <UserX className="w-3.5 h-3.5" /> Deactivate
                  </button>
                ) : (
                  <button onClick={() => onActivate(u.id)} className="text-xs text-emerald-600 hover:underline flex items-center gap-1 ml-auto">
                    <UserCheck className="w-3.5 h-3.5" /> Activate
                  </button>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      </div>
    </div>
  );
}

function AuditTab({ logs }: { logs: any[] }) {
  if (logs.length === 0) return <div className="text-center py-16 text-slate-400">No audit logs yet.</div>;
  return (
    <div className="bg-white rounded-xl border border-slate-200 overflow-hidden">
      <div className="overflow-x-auto">
      <table className="w-full text-sm">
        <thead className="bg-slate-50 border-b border-slate-200">
          <tr>
            {['Timestamp', 'User', 'Action', 'Resource', 'IP Address'].map(h => (
              <th key={h} className="text-left px-5 py-3 font-medium text-slate-600">{h}</th>
            ))}
          </tr>
        </thead>
        <tbody className="divide-y divide-slate-100">
          {logs.map(log => (
            <tr key={log.id} className="hover:bg-slate-50/50">
              <td className="px-5 py-2.5 text-xs text-slate-500 whitespace-nowrap">{formatDateTime(log.timestamp)}</td>
              <td className="px-5 py-2.5 font-medium text-slate-700">{log.username ?? '—'}</td>
              <td className="px-5 py-2.5 text-slate-600">{log.action}</td>
              <td className="px-5 py-2.5 text-xs text-slate-400">{log.resourceType ?? '—'}</td>
              <td className="px-5 py-2.5 text-xs text-slate-400 font-mono">{log.ipAddress ?? '—'}</td>
            </tr>
          ))}
        </tbody>
      </table>
      </div>
    </div>
  );
}

function OrgSettingsTab() {
  const [settings, setSettings] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [testingEmail, setTestingEmail] = useState(false);

  useEffect(() => {
    api.get('/admin/settings').then(res => { setSettings(res.data.data); setLoading(false); }).catch(() => setLoading(false));
  }, []);

  const update = (key: string, value: string) => setSettings(prev => ({ ...prev, [key]: value }));

  const save = async () => {
    setSaving(true);
    try {
      await api.put('/admin/settings', settings);
      toast.success('Settings saved.');
    } catch { toast.error('Failed to save settings.'); }
    finally { setSaving(false); }
  };

  const sendTestEmail = async () => {
    setTestingEmail(true);
    try {
      const res = await api.post('/admin/settings/test-email');
      toast.success(res.data.data);
    } catch (err: any) {
      toast.error(err.response?.data?.error?.message ?? 'Failed to send test email.');
    } finally { setTestingEmail(false); }
  };

  if (loading) return <div className="flex justify-center py-16"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600" /></div>;

  const sections = [
    {
      title: 'Security',
      fields: [
        { key: 'SessionTimeoutMinutes', label: 'Session Timeout (minutes)', type: 'number', hint: 'Auto-logout after inactivity. Default: 15' },
        { key: 'ClipboardClearSeconds', label: 'Clipboard Clear (seconds)', type: 'number', hint: 'Auto-clear clipboard after copying. Default: 30' },
        { key: 'MaxFailedLoginAttempts', label: 'Max Failed Login Attempts', type: 'number', hint: 'Lock account after N failed attempts. Default: 5' },
        { key: 'LockoutDurationMinutes', label: 'Lockout Duration (minutes)', type: 'number', hint: 'How long to lock account after too many failures. Default: 15' },
      ],
    },
    {
      title: 'Credentials',
      fields: [
        { key: 'ExpiryWarningDays', label: 'Expiry Warning Window (days)', type: 'number', hint: 'Show alerts N days before expiry. Default: 30' },
        { key: 'MaxAttachmentSizeMb', label: 'Max Attachment Size (MB)', type: 'number', hint: 'Maximum encrypted file upload size. Default: 10' },
      ],
    },
    {
      title: 'Email (SMTP)',
      fields: [
        { key: 'SmtpHost', label: 'SMTP Host', type: 'text', hint: 'e.g. smtp.office365.com' },
        { key: 'SmtpPort', label: 'SMTP Port', type: 'number', hint: 'e.g. 587' },
        { key: 'SmtpUsername', label: 'SMTP Username', type: 'text', hint: 'Authentication username' },
        { key: 'SmtpPassword', label: 'SMTP Password', type: 'password', hint: 'Leave blank to keep existing password' },
        { key: 'SmtpFromEmail', label: 'From Email', type: 'email', hint: 'e.g. noreply@yourcompany.com' },
        { key: 'SmtpFromName', label: 'From Name', type: 'text', hint: 'e.g. XCred Vault' },
        { key: 'SmtpUseSsl', label: 'Use SSL/TLS', type: 'select', hint: '' },
        { key: 'AppBaseUrl', label: 'Application Base URL', type: 'url', hint: 'Used in email links, e.g. https://xcred.yourcompany.com' },
      ],
    },
  ];

  return (
    <div className="space-y-6">
      {sections.map(section => (
        <div key={section.title} className="bg-white rounded-xl border border-slate-200 overflow-hidden">
          <div className="px-6 py-4 bg-slate-50 border-b border-slate-200">
            <h3 className="font-semibold text-slate-800">{section.title}</h3>
          </div>
          <div className="p-6 grid grid-cols-1 md:grid-cols-2 gap-5">
            {section.fields.map(f => (
              <div key={f.key}>
                <label className="block text-sm font-medium text-slate-700 mb-1">{f.label}</label>
                {f.type === 'select' ? (
                  <select value={settings[f.key] ?? 'true'} onChange={e => update(f.key, e.target.value)}
                    className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white">
                    <option value="true">Enabled</option>
                    <option value="false">Disabled</option>
                  </select>
                ) : (
                  <input
                    type={f.type}
                    value={f.type === 'password' ? '' : (settings[f.key] ?? '')}
                    placeholder={f.type === 'password' ? '(unchanged)' : ''}
                    onChange={e => update(f.key, e.target.value)}
                    className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
                  />
                )}
                {f.hint && <p className="text-xs text-slate-400 mt-1">{f.hint}</p>}
              </div>
            ))}
          </div>
          {section.title === 'Email (SMTP)' && (
            <div className="px-6 pb-5">
              <button onClick={sendTestEmail} disabled={testingEmail}
                className="flex items-center gap-2 border border-indigo-300 text-indigo-700 px-4 py-2 rounded-lg text-sm font-medium hover:bg-indigo-50 disabled:opacity-60 transition-colors">
                <Send className="w-4 h-4" />
                {testingEmail ? 'Sending…' : 'Send Test Email'}
              </button>
              <p className="text-xs text-slate-400 mt-1">Sends a test message to the admin account email using the settings above. Save first before testing.</p>
            </div>
          )}
        </div>
      ))}

      <div className="flex justify-end">
        <button onClick={save} disabled={saving}
          className="flex items-center gap-2 bg-indigo-600 text-white px-6 py-2.5 rounded-lg text-sm font-medium hover:bg-indigo-700 disabled:opacity-60 transition-colors">
          <Save className="w-4 h-4" />
          {saving ? 'Saving…' : 'Save All Settings'}
        </button>
      </div>
    </div>
  );
}

/* ─── System Backup (whole-instance, admin-only) ─────────────────────── */
interface SystemBackupSummary {
  users: number; groups: number; appSettings: number; groupMembers: number;
  folders: number; credentialGroups: number; tags: number; credentials: number;
  credentialTags: number; credentialAttachments: number; sharedCredentials: number; auditLogs: number;
}

function SystemBackupTab() {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [exporting, setExporting] = useState(false);
  const [restoring, setRestoring] = useState(false);
  const [result, setResult] = useState<{ summary: SystemBackupSummary; wiped: boolean } | null>(null);

  const handleExport = async () => {
    setExporting(true);
    try {
      const res = await api.get('/system-backup/export', { responseType: 'blob' });
      const url = URL.createObjectURL(res.data);
      const a = document.createElement('a');
      a.href = url;
      a.download = `xcred-system-backup-${new Date().toISOString().slice(0, 10)}.zip`;
      a.click();
      URL.revokeObjectURL(url);
      toast.success('System backup exported.');
    } catch {
      toast.error('Failed to export system backup.');
    } finally {
      setExporting(false);
    }
  };

  const doRestore = async (file: File, force: boolean) => {
    const formData = new FormData();
    formData.append('file', file);
    return api.post(`/system-backup/restore${force ? '?force=true' : ''}`, formData);
  };

  const handleFilePicked = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setResult(null);
    setRestoring(true);
    try {
      const res = await doRestore(file, false);
      setResult({ summary: res.data.data, wiped: false });
      toast.success('System backup restored.');
    } catch (err: any) {
      if (err.response?.data?.error?.code === 'TARGET_NOT_EMPTY') {
        const confirmed = confirm(
          'This instance already has data. Restoring will PERMANENTLY WIPE every ' +
          'existing user, credential, and setting and replace it all with the backup\'s ' +
          'data. This cannot be undone. Are you absolutely sure?'
        );
        if (confirmed) {
          try {
            const res2 = await doRestore(file, true);
            setResult({ summary: res2.data.data, wiped: true });
            toast.success('System backup restored — all previous data was replaced.');
          } catch (err2: any) {
            toast.error(err2.response?.data?.error?.message ?? 'Failed to restore system backup.');
          }
        }
      } else {
        toast.error(err.response?.data?.error?.message ?? 'Failed to restore system backup.');
      }
    } finally {
      setRestoring(false);
      if (fileInputRef.current) fileInputRef.current.value = '';
    }
  };

  return (
    <div className="space-y-4">
      <div className="bg-white rounded-xl border border-slate-200 p-6 space-y-4">
        <div>
          <h2 className="font-semibold text-slate-800">Export Full System Backup</h2>
          <p className="text-sm text-slate-500 mt-1">
            Downloads a zip containing every user, credential, folder, tag, team, share, and
            audit log on this instance — not just your own vault. Restoring it onto another
            XCred install (any database engine) recreates the whole instance there.
          </p>
        </div>
        <div className="bg-amber-50 border border-amber-200 rounded-lg p-3 flex gap-2">
          <AlertTriangle className="w-4 h-4 text-amber-600 shrink-0 mt-0.5" />
          <p className="text-xs text-amber-700">
            This file is more sensitive than your own per-account backup (Settings → Backup
            &amp; Restore): it includes every user's login password hash, their individually
            still-encrypted RSA private key, and the full audit trail. Handle it like the
            keys to the whole vault, because it is.
          </p>
        </div>
        <button onClick={handleExport} disabled={exporting}
          className="flex items-center gap-2 bg-indigo-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-indigo-700 disabled:opacity-60 transition-colors">
          <Download className="w-4 h-4" />
          {exporting ? 'Exporting…' : 'Export Full System Backup'}
        </button>
      </div>

      <div className="bg-white rounded-xl border border-red-200 p-6 space-y-4">
        <div>
          <h2 className="font-semibold text-slate-800">Restore Full System Backup</h2>
          <p className="text-sm text-slate-500 mt-1">
            Meant for a fresh, empty instance (e.g. a newly set-up portable install). If this
            instance already has data, restoring requires an extra confirmation and{' '}
            <b>permanently wipes and replaces everything</b> currently here.
          </p>
        </div>
        <div className="bg-red-50 border border-red-200 rounded-lg p-3 flex gap-2">
          <AlertTriangle className="w-4 h-4 text-red-600 shrink-0 mt-0.5" />
          <p className="text-xs text-red-700">
            High-risk operation. If it wipes this instance's data (including your own
            account), you may be signed out — log back in with an account from the restored
            backup afterward.
          </p>
        </div>
        <input ref={fileInputRef} type="file" accept=".zip" className="hidden" onChange={handleFilePicked} />
        <button onClick={() => fileInputRef.current?.click()} disabled={restoring}
          className="flex items-center gap-2 border border-red-300 text-red-700 px-4 py-2 rounded-lg text-sm font-medium hover:bg-red-50 disabled:opacity-60 transition-colors">
          <Upload className="w-4 h-4" />
          {restoring ? 'Restoring…' : 'Select System Backup File'}
        </button>

        {result && (
          <div className="bg-emerald-50 border border-emerald-200 rounded-lg p-4">
            <div className="flex items-center gap-2 mb-3">
              <CheckCircle2 className="w-5 h-5 text-emerald-600" />
              <p className="font-semibold text-emerald-800">
                Restore Complete{result.wiped ? ' — Previous Data Wiped' : ''}
              </p>
            </div>
            <div className="grid grid-cols-2 sm:grid-cols-3 gap-2 text-sm text-emerald-700">
              <span>Users: <b>{result.summary.users}</b></span>
              <span>Credentials: <b>{result.summary.credentials}</b></span>
              <span>Folders: <b>{result.summary.folders}</b></span>
              <span>Tags: <b>{result.summary.tags}</b></span>
              <span>Teams: <b>{result.summary.groups}</b></span>
              <span>Credential Groups: <b>{result.summary.credentialGroups}</b></span>
              <span>Attachments: <b>{result.summary.credentialAttachments}</b></span>
              <span>Shares: <b>{result.summary.sharedCredentials}</b></span>
              <span>Audit Log Entries: <b>{result.summary.auditLogs}</b></span>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
