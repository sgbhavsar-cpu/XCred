import { useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Save, Eye, EyeOff, AlertTriangle, Shield, Bell, User, Download, Upload, CheckCircle2 } from 'lucide-react';
import toast from 'react-hot-toast';
import api from '@/api/client';
import { useAuthStore } from '@/store/authStore';
import { deriveKey, generateSalt, generateKeyPair, encryptPrivateKey, decryptPrivateKey, decryptKeyWithPrivateKey, encryptKeyWithPublicKey } from '@/lib/crypto';
import { encryptCredentialData } from '@/lib/vault';
import { formatDateTime } from '@/lib/utils';

type Tab = 'profile' | 'security' | 'notifications' | 'backup' | 'master-key';

export default function SettingsPage() {
  const navigate = useNavigate();
  const { user, privateKey, setPublicKey, setCryptoKeys } = useAuthStore();
  const [tab, setTab] = useState<Tab>('profile');

  const tabs: Array<{ key: Tab; label: string; icon: React.ReactNode }> = [
    { key: 'profile', label: 'Profile', icon: <User className="w-4 h-4" /> },
    { key: 'security', label: 'Password', icon: <Shield className="w-4 h-4" /> },
    { key: 'notifications', label: 'Notifications', icon: <Bell className="w-4 h-4" /> },
    { key: 'backup', label: 'Backup & Restore', icon: <Download className="w-4 h-4" /> },
    { key: 'master-key', label: 'Master Password', icon: <AlertTriangle className="w-4 h-4" /> },
  ];

  return (
    <div className="p-6 max-w-2xl mx-auto">
      <h1 className="text-2xl font-bold text-slate-900 mb-6">Settings</h1>

      {/* Tab list */}
      <div className="flex flex-wrap gap-1 bg-slate-100 rounded-xl p-1 mb-6">
        {tabs.map(t => (
          <button key={t.key} onClick={() => setTab(t.key)}
            className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition-colors ${tab === t.key ? 'bg-white text-slate-900 shadow-sm' : 'text-slate-500 hover:text-slate-700'}`}>
            {t.icon} {t.label}
          </button>
        ))}
      </div>

      {tab === 'profile' && <ProfileTab user={user} />}
      {tab === 'security' && <ChangePasswordTab />}
      {tab === 'notifications' && <NotificationsTab />}
      {tab === 'backup' && <BackupTab privateKey={privateKey} />}
      {tab === 'master-key' && (
        <ChangeMasterKeyTab
          privateKey={privateKey}
          setPublicKey={setPublicKey}
          setCryptoKeys={setCryptoKeys}
          navigate={navigate}
        />
      )}
    </div>
  );
}

/* ─── Profile ─────────────────────────────────────────────────────────── */
function ProfileTab({ user }: { user: any }) {
  const [profile, setProfile] = useState<any>(null);

  useEffect(() => {
    api.get('/auth/profile').then(res => setProfile(res.data.data)).catch(() => {});
  }, []);

  return (
    <div className="bg-white rounded-xl border border-slate-200 p-6 space-y-5">
      <h2 className="font-semibold text-slate-800">Account Information</h2>
      <div className="grid grid-cols-2 gap-4">
        <Info label="Username" value={profile?.username ?? user?.username} />
        <Info label="Email" value={profile?.email ?? user?.email} />
        <Info label="Role" value={profile?.role ?? user?.role} />
        <Info label="Member Since" value={profile?.createdAt ? formatDateTime(profile.createdAt) : '—'} />
        <Info label="Last Login" value={profile?.lastLoginAt ? formatDateTime(profile.lastLoginAt) : 'N/A'} className="col-span-2" />
      </div>
      <div className="bg-amber-50 border border-amber-200 rounded-lg p-3 flex gap-2">
        <AlertTriangle className="w-4 h-4 text-amber-600 shrink-0 mt-0.5" />
        <p className="text-xs text-amber-700">To change your username or email, please contact an administrator.</p>
      </div>
    </div>
  );
}

function Info({ label, value, className = '' }: { label: string; value?: string; className?: string }) {
  return (
    <div className={className}>
      <p className="text-xs font-medium text-slate-400 uppercase tracking-wide mb-0.5">{label}</p>
      <p className="text-sm text-slate-800 font-medium">{value ?? '—'}</p>
    </div>
  );
}

/* ─── Change login password ───────────────────────────────────────────── */
function ChangePasswordTab() {
  const [current, setCurrent] = useState('');
  const [newPwd, setNewPwd] = useState('');
  const [confirm, setConfirm] = useState('');
  const [show, setShow] = useState(false);
  const [saving, setSaving] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (newPwd !== confirm) { toast.error("Passwords don't match."); return; }
    if (newPwd.length < 8) { toast.error('Password must be at least 8 characters.'); return; }
    setSaving(true);
    try {
      await api.post('/auth/change-password', { currentPassword: current, newPassword: newPwd });
      toast.success('Login password changed.');
      setCurrent(''); setNewPwd(''); setConfirm('');
    } catch (err: any) {
      toast.error(err.response?.data?.error?.message ?? 'Failed to change password.');
    } finally { setSaving(false); }
  };

  return (
    <form onSubmit={handleSubmit} className="bg-white rounded-xl border border-slate-200 p-6 space-y-4">
      <h2 className="font-semibold text-slate-800">Change Login Password</h2>
      <p className="text-sm text-slate-500">This is your login password — separate from your vault master password.</p>
      {[
        { label: 'Current Password', value: current, set: setCurrent },
        { label: 'New Password', value: newPwd, set: setNewPwd },
        { label: 'Confirm New Password', value: confirm, set: setConfirm },
      ].map(f => (
        <div key={f.label}>
          <label className="block text-sm font-medium text-slate-700 mb-1">{f.label}</label>
          <div className="relative">
            <input type={show ? 'text' : 'password'} value={f.value} onChange={e => f.set(e.target.value)}
              className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 pr-10" />
            <button type="button" onClick={() => setShow(s => !s)} className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400">
              {show ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
            </button>
          </div>
        </div>
      ))}
      <button type="submit" disabled={saving}
        className="flex items-center gap-2 bg-indigo-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-indigo-700 disabled:opacity-60 transition-colors">
        <Save className="w-4 h-4" /> {saving ? 'Saving…' : 'Change Password'}
      </button>
    </form>
  );
}

/* ─── Notifications ───────────────────────────────────────────────────── */
function NotificationsTab() {
  const [prefs, setPrefs] = useState({ expiryReminders: true, shareNotifications: true, securityAlerts: true });
  const [loaded, setLoaded] = useState(false);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    api.get('/auth/profile').then(res => {
      try {
        const p = JSON.parse(res.data.data.notificationPreferences ?? '{}');
        setPrefs(prev => ({ ...prev, ...p }));
      } catch {}
      setLoaded(true);
    }).catch(() => setLoaded(true));
  }, []);

  const save = async () => {
    setSaving(true);
    try {
      await api.put('/auth/notification-preferences', prefs);
      toast.success('Notification preferences saved.');
    } catch { toast.error('Failed to save preferences.'); }
    finally { setSaving(false); }
  };

  const toggle = (key: keyof typeof prefs) => setPrefs(prev => ({ ...prev, [key]: !prev[key] }));

  const items: Array<{ key: keyof typeof prefs; label: string; desc: string; mandatory?: boolean }> = [
    {
      key: 'securityAlerts',
      label: 'Security Alerts',
      desc: 'Failed login attempts, new device logins, account changes.',
      mandatory: true,
    },
    {
      key: 'expiryReminders',
      label: 'Expiry Reminders',
      desc: 'Email reminders 30, 14, 7, and 1 day before a credential expires.',
    },
    {
      key: 'shareNotifications',
      label: 'Share Notifications',
      desc: 'Emails when credentials are shared with you or a share is revoked.',
    },
  ];

  if (!loaded) return <div className="flex justify-center py-16"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600" /></div>;

  return (
    <div className="bg-white rounded-xl border border-slate-200 p-6 space-y-5">
      <h2 className="font-semibold text-slate-800">Email Notification Preferences</h2>
      <div className="space-y-4">
        {items.map(item => (
          <div key={item.key} className="flex items-start justify-between gap-4">
            <div>
              <p className="text-sm font-medium text-slate-800">
                {item.label}
                {item.mandatory && <span className="ml-2 text-xs text-slate-400">(cannot be disabled)</span>}
              </p>
              <p className="text-xs text-slate-500 mt-0.5">{item.desc}</p>
            </div>
            <button
              type="button"
              disabled={item.mandatory}
              onClick={() => !item.mandatory && toggle(item.key)}
              className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors focus:outline-none shrink-0 ${prefs[item.key] ? 'bg-indigo-600' : 'bg-slate-200'} ${item.mandatory ? 'opacity-60 cursor-not-allowed' : 'cursor-pointer'}`}
            >
              <span className={`inline-block h-4 w-4 transform rounded-full bg-white shadow transition-transform ${prefs[item.key] ? 'translate-x-6' : 'translate-x-1'}`} />
            </button>
          </div>
        ))}
      </div>
      <button onClick={save} disabled={saving}
        className="flex items-center gap-2 bg-indigo-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-indigo-700 disabled:opacity-60 transition-colors">
        <Save className="w-4 h-4" /> {saving ? 'Saving…' : 'Save Preferences'}
      </button>
    </div>
  );
}

/* ─── Backup & Restore ────────────────────────────────────────────────── */
function BackupTab({ privateKey }: { privateKey: CryptoKey | null }) {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [exporting, setExporting] = useState(false);
  const [restoring, setRestoring] = useState(false);
  const [restoreResult, setRestoreResult] = useState<{ credentialsRestored: number; credentialsSkipped: number; tagsRestored: number; foldersRestored: number } | null>(null);

  const handleExport = async () => {
    setExporting(true);
    try {
      const res = await api.get('/backup', { responseType: 'blob' });
      const url = URL.createObjectURL(res.data);
      const a = document.createElement('a');
      a.href = url;
      a.download = `xcred-backup-${new Date().toISOString().slice(0, 10)}.xcredbak`;
      a.click();
      URL.revokeObjectURL(url);
      toast.success('Backup exported successfully.');
    } catch { toast.error('Failed to export backup.'); }
    finally { setExporting(false); }
  };

  const handleRestore = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setRestoring(true);
    setRestoreResult(null);
    try {
      const text = await file.text();
      const backup = JSON.parse(text);
      const res = await api.post('/backup/restore', backup);
      setRestoreResult(res.data.data);
      toast.success('Backup restored successfully.');
    } catch (err: any) {
      toast.error(err.response?.data?.error?.message ?? 'Failed to restore backup. File may be invalid.');
    } finally {
      setRestoring(false);
      if (fileInputRef.current) fileInputRef.current.value = '';
    }
  };

  return (
    <div className="space-y-4">
      {/* Export */}
      <div className="bg-white rounded-xl border border-slate-200 p-6 space-y-4">
        <div>
          <h2 className="font-semibold text-slate-800">Export Backup</h2>
          <p className="text-sm text-slate-500 mt-1">
            Download all your encrypted credentials, folders, and tags as a <code className="text-xs bg-slate-100 px-1 py-0.5 rounded">.xcredbak</code> file.
            Your data remains encrypted — only you can decrypt it with your master password.
          </p>
        </div>
        <div className="bg-indigo-50 border border-indigo-100 rounded-lg p-3 flex gap-2">
          <Shield className="w-4 h-4 text-indigo-600 shrink-0 mt-0.5" />
          <p className="text-xs text-indigo-700">
            The backup file contains your credentials in their encrypted form. Without your master password, the backup cannot be decrypted by anyone.
          </p>
        </div>
        <button onClick={handleExport} disabled={exporting}
          className="flex items-center gap-2 bg-indigo-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-indigo-700 disabled:opacity-60 transition-colors">
          <Download className="w-4 h-4" />
          {exporting ? 'Exporting…' : 'Download Backup'}
        </button>
      </div>

      {/* Import */}
      <div className="bg-white rounded-xl border border-slate-200 p-6 space-y-4">
        <div>
          <h2 className="font-semibold text-slate-800">Restore from Backup</h2>
          <p className="text-sm text-slate-500 mt-1">
            Import a <code className="text-xs bg-slate-100 px-1 py-0.5 rounded">.xcredbak</code> file to restore credentials, folders, and tags.
            Duplicate credentials (same encrypted content) will be skipped.
          </p>
        </div>
        <div className="bg-amber-50 border border-amber-200 rounded-lg p-3 flex gap-2">
          <AlertTriangle className="w-4 h-4 text-amber-600 shrink-0 mt-0.5" />
          <p className="text-xs text-amber-700">
            Only restore backups created from your own account. Credentials are encrypted with your personal key — backups from other accounts cannot be decrypted.
          </p>
        </div>
        <input ref={fileInputRef} type="file" accept=".xcredbak,.json" className="hidden" onChange={handleRestore} />
        <button onClick={() => fileInputRef.current?.click()} disabled={restoring}
          className="flex items-center gap-2 border border-slate-300 text-slate-700 px-4 py-2 rounded-lg text-sm font-medium hover:bg-slate-50 disabled:opacity-60 transition-colors">
          <Upload className="w-4 h-4" />
          {restoring ? 'Restoring…' : 'Select Backup File'}
        </button>

        {restoreResult && (
          <div className="bg-emerald-50 border border-emerald-200 rounded-lg p-4">
            <div className="flex items-center gap-2 mb-3">
              <CheckCircle2 className="w-5 h-5 text-emerald-600" />
              <p className="font-semibold text-emerald-800">Restore Complete</p>
            </div>
            <div className="grid grid-cols-2 gap-2 text-sm text-emerald-700">
              <span>Credentials restored: <b>{restoreResult.credentialsRestored}</b></span>
              <span>Skipped (duplicates): <b>{restoreResult.credentialsSkipped}</b></span>
              <span>Folders restored: <b>{restoreResult.foldersRestored}</b></span>
              <span>Tags restored: <b>{restoreResult.tagsRestored}</b></span>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

/* ─── Change Master Password ──────────────────────────────────────────── */
function ChangeMasterKeyTab({ privateKey, setPublicKey, setCryptoKeys, navigate }: {
  privateKey: CryptoKey | null;
  setPublicKey: (k: string) => void;
  setCryptoKeys: (sym: CryptoKey, priv: CryptoKey) => void;
  navigate: ReturnType<typeof useNavigate>;
}) {
  const [newMaster, setNewMaster] = useState('');
  const [confirmMaster, setConfirmMaster] = useState('');
  const [show, setShow] = useState(false);
  const [saving, setSaving] = useState(false);
  const [step, setStep] = useState('');

  const handleChange = async (e: React.FormEvent) => {
    e.preventDefault();
    if (newMaster.length < 12) { toast.error('Master password must be at least 12 characters.'); return; }
    if (newMaster !== confirmMaster) { toast.error("Master passwords don't match."); return; }
    if (!privateKey) { toast.error('Vault is not unlocked. Please log out and back in.'); return; }

    setSaving(true);
    try {
      setStep('Fetching credentials…');
      const res = await api.get('/credentials');
      const credentials = res.data.data;

      setStep('Generating new key material…');
      const newSalt = generateSalt();
      const newSymmetricKey = await deriveKey(newMaster, newSalt);
      const { publicKey: newPubKey, privateKey: newPrivKeyB64 } = await generateKeyPair();
      const { encryptedPrivateKey: newEncPrivKey, iv: newPrivKeyIv } = await encryptPrivateKey(newSymmetricKey, newPrivKeyB64);

      setStep(`Re-encrypting ${credentials.length} credential${credentials.length !== 1 ? 's' : ''}…`);
      const reEncrypted = await Promise.all(
        credentials.map(async (cred: any) => {
          try {
            const credKey = await decryptKeyWithPrivateKey(privateKey, cred.encryptedCredentialKey);
            const newEncKey = await encryptKeyWithPublicKey(newPubKey, credKey);
            return { credentialId: cred.id, encryptedData: cred.encryptedData, dataIv: cred.dataIv, encryptedCredentialKey: newEncKey };
          } catch {
            return { credentialId: cred.id, encryptedData: cred.encryptedData, dataIv: cred.dataIv, encryptedCredentialKey: cred.encryptedCredentialKey };
          }
        })
      );

      setStep('Saving new key material to server…');
      await api.post('/auth/change-master-key', {
        newPublicKey: newPubKey,
        newEncryptedPrivateKey: newEncPrivKey,
        newPrivateKeyIv: newPrivKeyIv,
        newKeyDerivationSalt: newSalt,
        reEncryptedCredentials: reEncrypted,
      });

      const newPrivKey = await decryptPrivateKey(newSymmetricKey, newEncPrivKey, newPrivKeyIv);
      setPublicKey(newPubKey);
      setCryptoKeys(newSymmetricKey, newPrivKey);

      toast.success('Master password changed. All credentials re-encrypted.');
      setNewMaster(''); setConfirmMaster('');
    } catch (err: any) {
      toast.error(err.response?.data?.error?.message ?? 'Failed to change master password.');
    } finally { setSaving(false); setStep(''); }
  };

  return (
    <form onSubmit={handleChange} className="space-y-4">
      <div className="bg-red-50 border border-red-200 rounded-xl p-4 flex gap-3">
        <AlertTriangle className="w-5 h-5 text-red-500 shrink-0 mt-0.5" />
        <div>
          <p className="text-sm font-semibold text-red-800 mb-1">High-Risk Operation</p>
          <p className="text-xs text-red-700">
            Changing the master password re-encrypts all your credentials with a new key. Export a backup first as a precaution.
            If this fails partway through, some credentials may become inaccessible until you restore from backup.
          </p>
        </div>
      </div>

      <div className="bg-white rounded-xl border border-slate-200 p-6 space-y-4">
        <h2 className="font-semibold text-slate-800">Change Master Password</h2>
        {[
          { label: 'New Master Password', value: newMaster, set: setNewMaster, hint: 'Minimum 12 characters' },
          { label: 'Confirm New Master Password', value: confirmMaster, set: setConfirmMaster, hint: '' },
        ].map(f => (
          <div key={f.label}>
            <label className="block text-sm font-medium text-slate-700 mb-1">{f.label}</label>
            <div className="relative">
              <input type={show ? 'text' : 'password'} value={f.value} onChange={e => f.set(e.target.value)}
                className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 pr-10" />
              <button type="button" onClick={() => setShow(s => !s)} className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400">
                {show ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
              </button>
            </div>
            {f.hint && <p className="text-xs text-slate-400 mt-1">{f.hint}</p>}
          </div>
        ))}
        <button type="submit" disabled={saving}
          className="flex items-center gap-2 bg-red-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-red-700 disabled:opacity-60 transition-colors">
          <Shield className="w-4 h-4" />
          {saving ? (step || 'Processing…') : 'Change Master Password'}
        </button>
      </div>
    </form>
  );
}
