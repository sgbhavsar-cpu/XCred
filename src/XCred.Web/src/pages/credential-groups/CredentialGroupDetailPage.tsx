import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { ArrowLeft, Plus, X, Trash2, Eye } from 'lucide-react';
import toast from 'react-hot-toast';
import api from '@/api/client';
import { useAuthStore } from '@/store/authStore';
import { decryptCredentialData } from '@/lib/vault';
import { credentialTypeLabel, credentialTypeIcon } from '@/lib/utils';

interface MemberCredential {
  id: string; type: string; encryptedData: string; dataIv: string; encryptedCredentialKey: string;
  expiryDate: string | null; folderId: string | null;
  tags: Array<{ id: string; name: string; color: string }>;
}

interface GroupDetail {
  id: string; name: string; icon: string; credentialCount: number;
  credentials: MemberCredential[];
}

interface CredentialListItem { id: string; type: string; credentialGroupId: string | null }

export default function CredentialGroupDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { privateKey } = useAuthStore();

  const [group, setGroup] = useState<GroupDetail | null>(null);
  const [names, setNames] = useState<Map<string, string>>(new Map());
  const [loading, setLoading] = useState(true);
  const [showAdd, setShowAdd] = useState(false);
  const [candidates, setCandidates] = useState<CredentialListItem[]>([]);
  const [candidateNames, setCandidateNames] = useState<Map<string, string>>(new Map());
  const [selectedCandidate, setSelectedCandidate] = useState('');
  const [busy, setBusy] = useState(false);

  const load = async () => {
    try {
      const res = await api.get(`/credential-groups/${id}`);
      const g: GroupDetail = res.data.data;
      setGroup(g);

      if (privateKey) {
        const map = new Map<string, string>();
        await Promise.all(g.credentials.map(async c => {
          try {
            const fields = await decryptCredentialData(c.encryptedData, c.dataIv, c.encryptedCredentialKey, privateKey);
            map.set(c.id, (fields.name as string) ?? credentialTypeLabel(c.type));
          } catch {
            map.set(c.id, credentialTypeLabel(c.type));
          }
        }));
        setNames(map);
      }
    } catch {
      toast.error('Failed to load credential group.');
      navigate('/credential-groups');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, [id, privateKey]);

  const openAddModal = async () => {
    try {
      const res = await api.get('/credentials');
      const all: CredentialListItem[] = res.data.data;
      const available = all.filter(c => c.credentialGroupId !== id);
      setCandidates(available);

      if (privateKey) {
        const map = new Map<string, string>();
        await Promise.all(res.data.data.map(async (c: any) => {
          if (c.credentialGroupId === id) return;
          try {
            const fields = await decryptCredentialData(c.encryptedData, c.dataIv, c.encryptedCredentialKey, privateKey);
            map.set(c.id, (fields.name as string) ?? credentialTypeLabel(c.type));
          } catch {
            map.set(c.id, credentialTypeLabel(c.type));
          }
        }));
        setCandidateNames(map);
      }
      setShowAdd(true);
    } catch {
      toast.error('Failed to load credentials.');
    }
  };

  const assignToGroup = async (credentialId: string, targetGroupId: string | null) => {
    setBusy(true);
    try {
      const res = await api.get(`/credentials/${credentialId}`);
      const c = res.data.data;
      await api.put(`/credentials/${credentialId}`, {
        encryptedData: c.encryptedData,
        dataIv: c.dataIv,
        encryptedCredentialKey: c.encryptedCredentialKey,
        expiryDate: c.expiryDate,
        folderId: c.folderId,
        credentialGroupId: targetGroupId,
        tagIds: c.tags.map((t: { id: string }) => t.id),
      });
      await load();
      setShowAdd(false);
      setSelectedCandidate('');
      toast.success(targetGroupId ? 'Credential added to group.' : 'Credential removed from group.');
    } catch {
      toast.error('Failed to update credential.');
    } finally {
      setBusy(false);
    }
  };

  const deleteGroup = async () => {
    if (!group || !confirm(`Delete "${group.name}"? Its credentials will not be deleted, just unlinked.`)) return;
    try {
      await api.delete(`/credential-groups/${group.id}`);
      toast.success('Credential group deleted.');
      navigate('/credential-groups');
    } catch {
      toast.error('Failed to delete credential group.');
    }
  };

  if (loading) {
    return <div className="flex justify-center items-center h-full"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600" /></div>;
  }
  if (!group) return null;

  return (
    <div className="p-6 max-w-2xl mx-auto">
      <div className="flex items-start justify-between mb-6">
        <div className="flex items-start gap-3">
          <button onClick={() => navigate('/credential-groups')} className="mt-1 text-slate-400 hover:text-slate-600 transition-colors">
            <ArrowLeft className="w-5 h-5" />
          </button>
          <div>
            <div className="flex items-center gap-2">
              <span className="text-2xl">{group.icon}</span>
              <h1 className="text-2xl font-bold text-slate-900">{group.name}</h1>
            </div>
            <p className="text-slate-500 text-sm mt-0.5">{group.credentialCount} credential{group.credentialCount !== 1 ? 's' : ''}</p>
          </div>
        </div>
        <button onClick={deleteGroup} className="p-2 text-slate-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors">
          <Trash2 className="w-4 h-4" />
        </button>
      </div>

      <div className="bg-white rounded-xl border border-slate-200 overflow-hidden mb-4">
        <div className="px-5 py-3.5 flex items-center justify-between border-b border-slate-100">
          <span className="font-medium text-slate-800 text-sm">Credentials in this group</span>
          <button onClick={openAddModal}
            className="flex items-center gap-1.5 px-3 py-1.5 border border-slate-200 rounded-lg text-sm text-slate-600 hover:bg-slate-50 transition-colors">
            <Plus className="w-3.5 h-3.5" /> Add Existing Credential
          </button>
        </div>

        {group.credentials.length === 0 ? (
          <div className="px-5 py-8 text-center text-slate-400">
            <p className="text-sm">No credentials in this group yet.</p>
          </div>
        ) : (
          <div className="divide-y divide-slate-100">
            {group.credentials.map(c => (
              <div key={c.id} className="px-5 py-3 flex items-center justify-between gap-3">
                <div className="flex items-center gap-3 min-w-0 cursor-pointer" onClick={() => navigate(`/credentials/${c.id}`)}>
                  <span className="text-xl shrink-0">{credentialTypeIcon(c.type)}</span>
                  <div className="min-w-0">
                    <p className="text-sm font-medium text-slate-800 truncate">{names.get(c.id) ?? '…'}</p>
                    <p className="text-xs text-slate-400">{credentialTypeLabel(c.type)}</p>
                  </div>
                </div>
                <div className="flex items-center gap-1 shrink-0">
                  <button onClick={() => navigate(`/credentials/${c.id}`)}
                    className="p-1.5 text-slate-400 hover:text-indigo-600 hover:bg-indigo-50 rounded-lg transition-colors" title="View">
                    <Eye className="w-4 h-4" />
                  </button>
                  <button onClick={() => assignToGroup(c.id, null)} disabled={busy}
                    className="p-1.5 text-slate-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors disabled:opacity-50" title="Remove from group">
                    <X className="w-4 h-4" />
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {showAdd && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md p-6">
            <div className="flex items-center justify-between mb-5">
              <h2 className="font-semibold text-slate-900">Add Existing Credential</h2>
              <button onClick={() => setShowAdd(false)} className="text-slate-400 hover:text-slate-600 transition-colors">
                <X className="w-5 h-5" />
              </button>
            </div>

            <select value={selectedCandidate} onChange={e => setSelectedCandidate(e.target.value)}
              className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white mb-4">
              <option value="">Select a credential…</option>
              {candidates.map(c => (
                <option key={c.id} value={c.id}>
                  {credentialTypeIcon(c.type)} {candidateNames.get(c.id) ?? credentialTypeLabel(c.type)} ({credentialTypeLabel(c.type)})
                </option>
              ))}
            </select>
            {candidates.length === 0 && <p className="text-xs text-slate-400 mb-4">All your credentials are already in this group, or you don't have any yet.</p>}

            <div className="flex gap-2">
              <button onClick={() => setShowAdd(false)} className="flex-1 py-2.5 border border-slate-200 rounded-lg text-sm text-slate-600 hover:bg-slate-50 transition-colors">Cancel</button>
              <button onClick={() => selectedCandidate && assignToGroup(selectedCandidate, group.id)} disabled={!selectedCandidate || busy}
                className="flex-1 py-2.5 bg-indigo-600 text-white rounded-lg text-sm font-medium hover:bg-indigo-700 disabled:opacity-60 transition-colors">
                {busy ? 'Adding…' : 'Add to Group'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
