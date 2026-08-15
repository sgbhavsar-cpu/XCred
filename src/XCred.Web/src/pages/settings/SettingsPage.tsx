import { useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Save, Eye, EyeOff, AlertTriangle, Shield, Bell, User, Download, Upload, CheckCircle2, FileSpreadsheet, FileJson } from 'lucide-react';
import toast from 'react-hot-toast';
import api from '@/api/client';
import { useAuthStore } from '@/store/authStore';
import { deriveKey, generateSalt, generateKeyPair, encryptPrivateKey, decryptPrivateKey, decryptKeyWithPrivateKey, encryptKeyWithPublicKey, decrypt } from '@/lib/crypto';
import { encryptCredentialData } from '@/lib/vault';
import { formatDateTime } from '@/lib/utils';
import { parseCsv } from '@/lib/csv';
import RestoreAccountKeysModal from './components/RestoreAccountKeysModal';
import ImportCsvModal from './components/ImportCsvModal';

type Tab = 'profile' | 'security' | 'notifications' | 'backup' | 'import' | 'master-key';

export default function SettingsPage() {
  const navigate = useNavigate();
  const { user, privateKey, setPublicKey, setCryptoKeys } = useAuthStore();
  const [tab, setTab] = useState<Tab>('profile');

  const tabs: Array<{ key: Tab; label: string; icon: React.ReactNode }> = [
    { key: 'profile', label: 'Profile', icon: <User className="w-4 h-4" /> },
    { key: 'security', label: 'Password', icon: <Shield className="w-4 h-4" /> },
    { key: 'notifications', label: 'Notifications', icon: <Bell className="w-4 h-4" /> },
    { key: 'backup', label: 'Backup & Restore', icon: <Download className="w-4 h-4" /> },
    { key: 'import', label: 'Import', icon: <Upload className="w-4 h-4" /> },
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
      {tab === 'backup' && (
        <BackupTab privateKey={privateKey} setPublicKey={setPublicKey} setCryptoKeys={setCryptoKeys} />
      )}
      {tab === 'import' && <ImportTab />}
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
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
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
interface RestoreResult {
  credentialsRestored: number;
  credentialsSkipped: number;
  tagsRestored: number;
  foldersRestored: number;
  accountKeysRestored?: boolean;
  credentialsReWrapped?: number;
}

function BackupTab({ privateKey, setPublicKey, setCryptoKeys }: {
  privateKey: CryptoKey | null;
  setPublicKey: (k: string) => void;
  setCryptoKeys: (sym: CryptoKey, priv: CryptoKey) => void;
}) {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [exporting, setExporting] = useState(false);
  const [restoring, setRestoring] = useState(false);
  const [restoreResult, setRestoreResult] = useState<RestoreResult | null>(null);
  const [pendingBackup, setPendingBackup] = useState<any | null>(null);
  const [plainExporting, setPlainExporting] = useState(false);

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

  // Shared by both restore paths: a plain restore (this backup's own account keys either
  // absent, or already matching this account) just replays credentials/folders/tags as before.
  const restoreCredentials = async (backup: any, extra: Partial<RestoreResult> = {}) => {
    const res = await api.post('/backup/restore', backup);
    setRestoreResult({ ...res.data.data, ...extra });
    toast.success('Backup restored successfully.');
  };

  const handleRestore = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setRestoreResult(null);
    try {
      const text = await file.text();
      const backup = JSON.parse(text);

      // Backups exported since VaultBackup v1.1 carry the exporting account's own crypto
      // material — needed to make a backup from a different machine's fresh registration
      // actually decrypt here. Route through the confirmation modal instead of restoring
      // immediately whenever it's present, since applying it replaces this account's
      // encryption identity.
      if (backup.keyDerivationSalt && backup.encryptedPrivateKey && backup.privateKeyIv && backup.publicKey) {
        setPendingBackup(backup);
        return;
      }

      setRestoring(true);
      await restoreCredentials(backup);
    } catch (err: any) {
      toast.error(err.response?.data?.error?.message ?? 'Failed to restore backup. File may be invalid.');
    } finally {
      setRestoring(false);
      if (fileInputRef.current) fileInputRef.current.value = '';
    }
  };

  const handleAccountKeysVerified = async (symmetricKey: CryptoKey, backupPrivateKey: CryptoKey, reWrappedCount: number) => {
    const backup = pendingBackup;
    setPendingBackup(null);
    setRestoring(true);
    try {
      await restoreCredentials(backup, { accountKeysRestored: true, credentialsReWrapped: reWrappedCount });
      setPublicKey(backup.publicKey);
      setCryptoKeys(symmetricKey, backupPrivateKey);
    } catch (err: any) {
      toast.error(err.response?.data?.error?.message ?? 'Account keys were restored, but importing the backup\'s credentials failed. Try restoring the same file again.');
    } finally {
      setRestoring(false);
      if (fileInputRef.current) fileInputRef.current.value = '';
    }
  };

  const handlePlainExport = async () => {
    if (!privateKey) { toast.error('Vault is not unlocked.'); return; }
    if (!confirm(
      'This will download ALL your credentials as PLAIN, UNENCRYPTED text — anyone who ' +
      'gets this file can read everything in it. Store it somewhere very safe (e.g. an ' +
      'offline encrypted drive) and delete it when you no longer need it. Continue?'
    )) return;

    setPlainExporting(true);
    try {
      const res = await api.get('/credentials');
      const items: any[] = res.data.data;

      let failed = 0;
      const decrypted = await Promise.all(items.map(async (item) => {
        try {
          const credentialKey = await decryptKeyWithPrivateKey(privateKey, item.encryptedCredentialKey);
          const plaintext = await decrypt(credentialKey, item.encryptedData, item.dataIv);
          const fields = JSON.parse(plaintext);
          if (typeof fields.customFields === 'string') {
            try { fields.customFields = JSON.parse(fields.customFields); } catch { /* leave as-is */ }
          }

          const attachments = await Promise.all((item.attachments ?? []).map(async (att: any) => {
            const name = await decrypt(credentialKey, att.encryptedFileName, att.fileNameIv).catch(() => 'Encrypted file');
            return { fileName: name, fileSizeBytes: att.fileSizeBytes, uploadedAt: att.uploadedAt };
          }));

          return {
            id: item.id,
            type: item.type,
            folder: item.folderName ?? null,
            credentialGroup: item.credentialGroupName ?? null,
            tags: (item.tags ?? []).map((t: any) => t.name),
            expiryDate: item.expiryDate,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt,
            attachments,
            ...fields,
          };
        } catch {
          failed++;
          return { id: item.id, type: item.type, error: 'Failed to decrypt this credential.' };
        }
      }));

      const bundle = {
        warning: 'UNENCRYPTED EXPORT — every field below is plain text. Treat this file like the passwords it contains.',
        exportedAt: new Date().toISOString(),
        credentialCount: decrypted.length,
        credentials: decrypted,
      };

      const blob = new Blob([JSON.stringify(bundle, null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `xcred-plaintext-export-${new Date().toISOString().slice(0, 10)}.json`;
      a.click();
      URL.revokeObjectURL(url);

      toast.success(failed > 0
        ? `Exported ${decrypted.length} credentials (${failed} failed to decrypt).`
        : `Exported ${decrypted.length} credentials.`);
    } catch {
      toast.error('Failed to export credentials.');
    } finally {
      setPlainExporting(false);
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
            The backup file contains your credentials in their encrypted form, plus your
            account's own encryption keys (also RSA-wrapped) — this is what lets a restore work
            even after a fresh registration on a different machine. Without your master
            password, none of it can be decrypted by anyone.
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
            If this backup includes the original account's encryption keys (every backup
            exported since this feature shipped does), restoring it can also repair a fresh
            registration on a new device — you'll be asked to confirm the master password used
            when the backup was created before anything changes.
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
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-sm text-emerald-700">
              <span>Credentials restored: <b>{restoreResult.credentialsRestored}</b></span>
              <span>Skipped (duplicates): <b>{restoreResult.credentialsSkipped}</b></span>
              <span>Folders restored: <b>{restoreResult.foldersRestored}</b></span>
              <span>Tags restored: <b>{restoreResult.tagsRestored}</b></span>
            </div>
            {restoreResult.accountKeysRestored && (
              <p className="text-xs text-emerald-700 mt-3 pt-3 border-t border-emerald-200">
                This account's encryption identity was replaced with the backup's
                {restoreResult.credentialsReWrapped ? ` (${restoreResult.credentialsReWrapped} pre-existing credential${restoreResult.credentialsReWrapped === 1 ? '' : 's'} on this account re-wrapped to match)` : ''} —
                you're already unlocked with it, nothing else to do.
              </p>
            )}
          </div>
        )}
      </div>

      {/* Plain JSON export */}
      <div className="bg-white rounded-xl border border-red-200 p-6 space-y-4">
        <div>
          <h2 className="font-semibold text-slate-800">Export as Plain JSON</h2>
          <p className="text-sm text-slate-500 mt-1">
            Decrypts every credential and downloads them as a single, human-readable JSON file — a
            last-resort failsafe for when you can't rely on this app or your master password to
            get your data back.
          </p>
        </div>
        <div className="bg-red-50 border border-red-200 rounded-lg p-3 flex gap-2">
          <AlertTriangle className="w-4 h-4 text-red-600 shrink-0 mt-0.5" />
          <p className="text-xs text-red-700">
            This file is <b>not encrypted</b>. Everything XCred normally protects — passwords,
            notes, custom fields — will be sitting in plain text. Only export this if you have a
            genuinely secure place to put it (e.g. an offline drive, a safe), and delete it once
            you no longer need it.
          </p>
        </div>
        <button onClick={handlePlainExport} disabled={plainExporting || !privateKey}
          className="flex items-center gap-2 border border-red-300 text-red-700 px-4 py-2 rounded-lg text-sm font-medium hover:bg-red-50 disabled:opacity-60 transition-colors">
          <Download className="w-4 h-4" />
          {plainExporting ? 'Exporting…' : 'Export All as Plain JSON'}
        </button>
      </div>

      {pendingBackup && (
        <RestoreAccountKeysModal
          backup={pendingBackup}
          currentPrivateKey={privateKey}
          onClose={() => { setPendingBackup(null); if (fileInputRef.current) fileInputRef.current.value = ''; }}
          onVerified={handleAccountKeysVerified}
        />
      )}
    </div>
  );
}

/* ─── Import (CSV, and this app's own plain-JSON export) ────────────────── */
function ImportTab() {
  const { publicKey } = useAuthStore();
  const csvInputRef = useRef<HTMLInputElement>(null);
  const jsonInputRef = useRef<HTMLInputElement>(null);
  const [csvData, setCsvData] = useState<{ headers: string[]; rows: string[][] } | null>(null);
  const [jsonImporting, setJsonImporting] = useState(false);
  const [jsonResult, setJsonResult] = useState<{ created: number; skipped: number; failed: number } | null>(null);

  const handleCsvPicked = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    try {
      const text = await file.text();
      const parsed = parseCsv(text);
      if (parsed.length === 0) { toast.error('That CSV file is empty.'); return; }
      setCsvData({ headers: parsed[0], rows: parsed.slice(1) });
    } catch {
      toast.error('Failed to read that CSV file.');
    } finally {
      if (csvInputRef.current) csvInputRef.current.value = '';
    }
  };

  // Reconstructs a payload encryptCredentialData can wrap for each entry produced by this
  // app's own "Export as Plain JSON" (SettingsPage's BackupTab) — everything BEFORE it hits
  // the wire again is re-encrypted client-side, exactly like a normal credential save.
  // Folders/tags/credential groups aren't recreated (only the credential data itself is) —
  // the export doesn't carry enough to safely reconstruct them (e.g. a folder path could
  // collide with something already renamed), and getting the actual secrets back is the
  // point of a failsafe, not perfect organizational fidelity.
  const handleJsonPicked = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    if (jsonInputRef.current) jsonInputRef.current.value = '';
    if (!publicKey) { toast.error('Public key not found. Please log out and log back in.'); return; }

    let entries: any[];
    try {
      const parsed = JSON.parse(await file.text());
      if (!Array.isArray(parsed.credentials)) throw new Error('not our format');
      entries = parsed.credentials;
    } catch {
      toast.error('That file doesn\'t look like an XCred plain JSON export.');
      return;
    }

    const importable = entries.filter(en => !en.error);
    if (importable.length === 0) { toast.error('No importable credentials found in that file.'); return; }
    if (!confirm(
      `Import ${importable.length} credential${importable.length === 1 ? '' : 's'} from this file? ` +
      'Each one is re-encrypted with your current keys. Folders, tags, and credential ' +
      'groups are not recreated — just the credential data itself.'
    )) return;

    setJsonImporting(true);
    setJsonResult(null);
    let created = 0, failed = 0;
    const META_KEYS = new Set(['id', 'type', 'folder', 'credentialGroup', 'tags', 'expiryDate', 'createdAt', 'updatedAt', 'attachments', 'error']);

    for (const entry of importable) {
      try {
        const { customFields, ...rest } = entry;
        const fields: Record<string, unknown> = {};
        for (const [k, v] of Object.entries(rest)) {
          if (!META_KEYS.has(k)) fields[k] = v;
        }
        const payload = { ...fields, name: (fields.name as string) ?? '', customFields: JSON.stringify(customFields ?? []) };
        const { encryptedData, dataIv, encryptedCredentialKey } = await encryptCredentialData(payload, publicKey);
        await api.post('/credentials', {
          type: entry.type,
          encryptedData, dataIv, encryptedCredentialKey,
          expiryDate: entry.expiryDate ?? null,
          folderId: null, credentialGroupId: null, tagIds: [],
        });
        created++;
      } catch {
        failed++;
      }
    }

    setJsonResult({ created, skipped: entries.length - importable.length, failed });
    setJsonImporting(false);
  };

  return (
    <div className="space-y-4">
      <div className="bg-white rounded-xl border border-slate-200 p-6 space-y-4">
        <div className="flex items-center gap-2">
          <FileSpreadsheet className="w-5 h-5 text-indigo-600" />
          <h2 className="font-semibold text-slate-800">Import from CSV</h2>
        </div>
        <p className="text-sm text-slate-500">
          Bring in credentials exported from a browser (Chrome/Firefox), another password
          manager, or your own spreadsheet. You'll map columns and preview before anything is
          created — each row becomes a Website Login credential.
        </p>
        <input ref={csvInputRef} type="file" accept=".csv,text/csv" className="hidden" onChange={handleCsvPicked} />
        <button onClick={() => csvInputRef.current?.click()}
          className="flex items-center gap-2 border border-slate-300 text-slate-700 px-4 py-2 rounded-lg text-sm font-medium hover:bg-slate-50 transition-colors">
          <Upload className="w-4 h-4" /> Select CSV File
        </button>
      </div>

      <div className="bg-white rounded-xl border border-slate-200 p-6 space-y-4">
        <div className="flex items-center gap-2">
          <FileJson className="w-5 h-5 text-indigo-600" />
          <h2 className="font-semibold text-slate-800">Import Plain JSON Export</h2>
        </div>
        <p className="text-sm text-slate-500">
          Re-import a file produced by this app's own "Export as Plain JSON" (Backup &amp;
          Restore tab) — useful if you moved that data elsewhere and need it back in the vault.
          Every credential is re-encrypted with your current keys as it's imported.
        </p>
        <input ref={jsonInputRef} type="file" accept=".json" className="hidden" onChange={handleJsonPicked} />
        <button onClick={() => jsonInputRef.current?.click()} disabled={jsonImporting}
          className="flex items-center gap-2 border border-slate-300 text-slate-700 px-4 py-2 rounded-lg text-sm font-medium hover:bg-slate-50 disabled:opacity-60 transition-colors">
          <Upload className="w-4 h-4" /> {jsonImporting ? 'Importing…' : 'Select JSON File'}
        </button>

        {jsonResult && (
          <div className="bg-emerald-50 border border-emerald-200 rounded-lg p-4">
            <div className="flex items-center gap-2 mb-3">
              <CheckCircle2 className="w-5 h-5 text-emerald-600" />
              <p className="font-semibold text-emerald-800">Import Complete</p>
            </div>
            <div className="grid grid-cols-3 gap-2 text-sm text-emerald-700">
              <span>Created: <b>{jsonResult.created}</b></span>
              <span>Skipped: <b>{jsonResult.skipped}</b></span>
              <span>Failed: <b>{jsonResult.failed}</b></span>
            </div>
          </div>
        )}
      </div>

      {csvData && publicKey && (
        <ImportCsvModal
          headers={csvData.headers}
          rows={csvData.rows}
          publicKey={publicKey}
          onClose={() => setCsvData(null)}
          onImported={() => toast.success('CSV import complete — check Credentials for the new entries.')}
        />
      )}
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
