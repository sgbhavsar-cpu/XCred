import { useEffect, useState } from 'react';
import { Share2, ShieldOff, Clock, User, Users, CheckCircle2, XCircle } from 'lucide-react';
import toast from 'react-hot-toast';
import api from '@/api/client';
import { useAuthStore } from '@/store/authStore';
import { decryptCredentialData } from '@/lib/vault';
import { credentialTypeLabel, credentialTypeIcon, formatDate, formatDateTime } from '@/lib/utils';
import { cn } from '@/lib/utils';

interface SharedCredential {
  id: string;
  credentialId: string;
  encryptedData: string;
  dataIv: string;
  encryptedCredentialKey: string;
  credentialType: string;
  sharedByUsername: string;
  sharedWithUserId?: string;
  sharedWithUsername?: string;
  sharedWithGroupId?: string;
  sharedWithGroupName?: string;
  expiresAt?: string;
  untilChanged: boolean;
  createdAt: string;
  isRevoked: boolean;
}

interface DecryptedShare extends SharedCredential { name: string }

type Tab = 'with-me' | 'by-me';

export default function SharesPage() {
  const { privateKey } = useAuthStore();
  const [tab, setTab] = useState<Tab>('with-me');
  const [withMe, setWithMe] = useState<DecryptedShare[]>([]);
  const [byMe, setByMe] = useState<DecryptedShare[]>([]);
  const [loading, setLoading] = useState(true);

  const decrypt = async (shares: SharedCredential[]): Promise<DecryptedShare[]> => {
    if (!privateKey) return shares.map(s => ({ ...s, name: credentialTypeLabel(s.credentialType) }));
    return Promise.all(shares.map(async s => {
      try {
        const fields = await decryptCredentialData(s.encryptedData, s.dataIv, s.encryptedCredentialKey, privateKey);
        return { ...s, name: fields.name ?? credentialTypeLabel(s.credentialType) };
      } catch {
        return { ...s, name: credentialTypeLabel(s.credentialType) };
      }
    }));
  };

  const load = async () => {
    setLoading(true);
    try {
      const [withMeRes, byMeRes] = await Promise.all([
        api.get('/shares/shared-with-me'),
        api.get('/shares/shared-by-me'),
      ]);
      setWithMe(await decrypt(withMeRes.data.data));
      setByMe(await decrypt(byMeRes.data.data));
    } catch {
      toast.error('Failed to load shares.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, [privateKey]);

  const revoke = async (shareId: string) => {
    if (!confirm('Revoke this share? The recipient will lose access immediately.')) return;
    try {
      await api.delete(`/shares/${shareId}`);
      setByMe(prev => prev.filter(s => s.id !== shareId));
      toast.success('Share revoked.');
    } catch (err: any) {
      toast.error(err.response?.data?.error?.message ?? 'Failed to revoke.');
    }
  };

  const withMeActive = withMe.filter(s => !s.isRevoked);
  const byMeActive = byMe.filter(s => !s.isRevoked);
  const byMeRevoked = byMe.filter(s => s.isRevoked);

  return (
    <div className="p-6 max-w-4xl mx-auto">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">Shared Credentials</h1>
        <p className="text-slate-500 text-sm">Credentials shared with you and credentials you've shared with others.</p>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 bg-slate-100 rounded-xl p-1 mb-6 w-fit">
        {([
          { key: 'with-me' as Tab, label: 'Shared With Me', count: withMeActive.length },
          { key: 'by-me' as Tab, label: 'Shared By Me', count: byMeActive.length },
        ]).map(t => (
          <button key={t.key} onClick={() => setTab(t.key)}
            className={cn(
              'flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition-colors',
              tab === t.key ? 'bg-white text-slate-900 shadow-sm' : 'text-slate-500 hover:text-slate-700'
            )}>
            {t.label}
            {t.count > 0 && (
              <span className="bg-indigo-600 text-white text-xs rounded-full px-1.5 py-0.5 min-w-[18px] text-center">
                {t.count}
              </span>
            )}
          </button>
        ))}
      </div>

      {loading ? (
        <div className="flex justify-center py-16">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600" />
        </div>
      ) : tab === 'with-me' ? (
        <SharedWithMe shares={withMeActive} />
      ) : (
        <SharedByMe active={byMeActive} revoked={byMeRevoked} onRevoke={revoke} />
      )}
    </div>
  );
}

function SharedWithMe({ shares }: { shares: DecryptedShare[] }) {
  if (shares.length === 0) {
    return (
      <EmptyState icon={<Share2 className="w-10 h-10 opacity-30" />} message="No credentials shared with you yet." />
    );
  }

  return (
    <div className="space-y-3">
      {shares.map(s => (
        <div key={s.id} className="bg-white rounded-xl border border-slate-200 p-5">
          <div className="flex items-start justify-between gap-4">
            <div className="flex items-center gap-3">
              <span className="text-2xl">{credentialTypeIcon(s.credentialType)}</span>
              <div>
                <p className="font-semibold text-slate-900">{s.name}</p>
                <p className="text-sm text-slate-500">{credentialTypeLabel(s.credentialType)}</p>
              </div>
            </div>
            <StatusBadge expiresAt={s.expiresAt} untilChanged={s.untilChanged} />
          </div>

          <div className="mt-4 grid grid-cols-2 gap-3 text-sm">
            <MetaItem icon={<User className="w-3.5 h-3.5" />} label="Shared by" value={s.sharedByUsername} />
            <MetaItem icon={<Clock className="w-3.5 h-3.5" />} label="Shared on" value={formatDate(s.createdAt)} />
            {s.expiresAt && (
              <MetaItem icon={<Clock className="w-3.5 h-3.5" />} label="Expires" value={formatDateTime(s.expiresAt)} />
            )}
            {s.untilChanged && (
              <MetaItem icon={<ShieldOff className="w-3.5 h-3.5" />} label="Access" value="Revokes if credential changes" />
            )}
          </div>
        </div>
      ))}
    </div>
  );
}

function SharedByMe({ active, revoked, onRevoke }: {
  active: DecryptedShare[];
  revoked: DecryptedShare[];
  onRevoke: (id: string) => void;
}) {
  if (active.length === 0 && revoked.length === 0) {
    return <EmptyState icon={<Share2 className="w-10 h-10 opacity-30" />} message="You haven't shared any credentials yet." />;
  }

  return (
    <div className="space-y-6">
      {active.length > 0 && (
        <div>
          <h2 className="text-sm font-semibold text-slate-500 uppercase tracking-wide mb-3">
            Active ({active.length})
          </h2>
          <div className="space-y-3">
            {active.map(s => (
              <div key={s.id} className="bg-white rounded-xl border border-slate-200 p-5">
                <div className="flex items-start justify-between gap-4">
                  <div className="flex items-center gap-3">
                    <span className="text-2xl">{credentialTypeIcon(s.credentialType)}</span>
                    <div>
                      <p className="font-semibold text-slate-900">{s.name}</p>
                      <p className="text-sm text-slate-500">{credentialTypeLabel(s.credentialType)}</p>
                    </div>
                  </div>
                  <div className="flex items-center gap-2 shrink-0">
                    <StatusBadge expiresAt={s.expiresAt} untilChanged={s.untilChanged} />
                    <button
                      onClick={() => onRevoke(s.id)}
                      className="flex items-center gap-1.5 px-3 py-1.5 border border-red-200 text-red-600 rounded-lg text-sm hover:bg-red-50 transition-colors"
                    >
                      <ShieldOff className="w-3.5 h-3.5" />
                      Revoke
                    </button>
                  </div>
                </div>

                <div className="mt-4 grid grid-cols-2 gap-3 text-sm">
                  {s.sharedWithUsername && (
                    <MetaItem icon={<User className="w-3.5 h-3.5" />} label="Shared with" value={s.sharedWithUsername} />
                  )}
                  {s.sharedWithGroupName && (
                    <MetaItem icon={<Users className="w-3.5 h-3.5" />} label="Shared with group" value={s.sharedWithGroupName} />
                  )}
                  <MetaItem icon={<Clock className="w-3.5 h-3.5" />} label="Shared on" value={formatDate(s.createdAt)} />
                  {s.expiresAt && (
                    <MetaItem icon={<Clock className="w-3.5 h-3.5" />} label="Expires" value={formatDateTime(s.expiresAt)} />
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {revoked.length > 0 && (
        <div>
          <h2 className="text-sm font-semibold text-slate-400 uppercase tracking-wide mb-3">
            Revoked / Expired ({revoked.length})
          </h2>
          <div className="space-y-2">
            {revoked.map(s => (
              <div key={s.id} className="bg-slate-50 rounded-xl border border-slate-200 px-5 py-3 opacity-60">
                <div className="flex items-center gap-3">
                  <span className="text-xl">{credentialTypeIcon(s.credentialType)}</span>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold text-slate-700 truncate">{s.name}</p>
                    <p className="text-xs text-slate-400">
                      {s.sharedWithUsername ?? s.sharedWithGroupName} · {formatDate(s.createdAt)}
                    </p>
                  </div>
                  <span className="text-xs text-slate-400 font-medium">Revoked</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

function StatusBadge({ expiresAt, untilChanged }: { expiresAt?: string; untilChanged: boolean }) {
  if (expiresAt) {
    const expired = new Date(expiresAt) < new Date();
    return (
      <span className={cn('text-xs font-medium px-2 py-1 rounded-full flex items-center gap-1',
        expired ? 'bg-red-100 text-red-700' : 'bg-amber-100 text-amber-700')}>
        <Clock className="w-3 h-3" />
        {expired ? 'Expired' : `Until ${formatDate(expiresAt)}`}
      </span>
    );
  }
  if (untilChanged) {
    return (
      <span className="text-xs font-medium px-2 py-1 rounded-full bg-blue-100 text-blue-700 flex items-center gap-1">
        <ShieldOff className="w-3 h-3" />
        Until changed
      </span>
    );
  }
  return (
    <span className="text-xs font-medium px-2 py-1 rounded-full bg-emerald-100 text-emerald-700 flex items-center gap-1">
      <CheckCircle2 className="w-3 h-3" />
      No expiry
    </span>
  );
}

function MetaItem({ icon, label, value }: { icon: React.ReactNode; label: string; value: string }) {
  return (
    <div className="flex items-center gap-2 text-slate-500">
      <span className="shrink-0 text-slate-400">{icon}</span>
      <span className="text-xs text-slate-400">{label}:</span>
      <span className="text-sm text-slate-700 font-medium truncate">{value}</span>
    </div>
  );
}

function EmptyState({ icon, message }: { icon: React.ReactNode; message: string }) {
  return (
    <div className="text-center py-16 text-slate-400">
      <div className="flex justify-center mb-3">{icon}</div>
      <p className="font-medium">{message}</p>
    </div>
  );
}
