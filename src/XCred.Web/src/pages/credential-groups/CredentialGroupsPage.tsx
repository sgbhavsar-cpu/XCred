import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Plus, Boxes, Trash2, ChevronRight } from 'lucide-react';
import toast from 'react-hot-toast';
import api from '@/api/client';
import { formatDate } from '@/lib/utils';

interface CredentialGroup { id: string; name: string; icon: string; credentialCount: number; createdAt: string }

const ICON_OPTIONS = ['🏦', '📧', '🌐', '📱', '🏢', '🚗', '🏥', '📦'];

export default function CredentialGroupsPage() {
  const navigate = useNavigate();
  const [groups, setGroups] = useState<CredentialGroup[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreate, setShowCreate] = useState(false);
  const [newName, setNewName] = useState('');
  const [newIcon, setNewIcon] = useState('🏦');

  const load = async () => {
    try {
      const res = await api.get('/credential-groups');
      setGroups(res.data.data);
    } catch {
      toast.error('Failed to load credential groups.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, []);

  const createGroup = async () => {
    if (!newName.trim()) return;
    try {
      await api.post('/credential-groups', { name: newName.trim(), icon: newIcon });
      await load();
      setNewName(''); setNewIcon('🏦'); setShowCreate(false);
      toast.success('Credential group created.');
    } catch (err: any) {
      toast.error(err.response?.data?.error?.message ?? 'Failed to create credential group.');
    }
  };

  const deleteGroup = async (id: string, e: React.MouseEvent) => {
    e.stopPropagation();
    if (!confirm('Delete this credential group? Its credentials will not be deleted, just unlinked from the group.')) return;
    try {
      await api.delete(`/credential-groups/${id}`);
      await load();
      toast.success('Credential group deleted.');
    } catch {
      toast.error('Failed to delete credential group.');
    }
  };

  return (
    <div className="p-6 max-w-2xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Credential Groups</h1>
          <p className="text-slate-500 text-sm">Bundle related credentials under one real-world entity — e.g. a bank's cards and logins</p>
        </div>
        <button onClick={() => setShowCreate(true)} className="flex items-center gap-2 bg-indigo-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-indigo-700 transition-colors shrink-0">
          <Plus className="w-4 h-4" /> New Group
        </button>
      </div>

      {showCreate && (
        <div className="bg-white rounded-xl border border-indigo-200 p-4 mb-4 space-y-3">
          <h3 className="text-sm font-semibold text-slate-700">Create Credential Group</h3>
          <div className="flex gap-2 flex-wrap">
            {ICON_OPTIONS.map(icon => (
              <button key={icon} type="button" onClick={() => setNewIcon(icon)}
                className={`text-xl w-10 h-10 rounded-lg border-2 flex items-center justify-center transition-all ${newIcon === icon ? 'border-indigo-500 bg-indigo-50' : 'border-slate-200 hover:border-slate-300'}`}>
                {icon}
              </button>
            ))}
          </div>
          <input value={newName} onChange={e => setNewName(e.target.value)} placeholder='e.g. "HDFC Bank"' autoFocus
            className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
          <div className="flex gap-2">
            <button onClick={() => { setShowCreate(false); setNewName(''); }}
              className="flex-1 py-2 border border-slate-200 rounded-lg text-sm text-slate-600 hover:bg-slate-50">Cancel</button>
            <button onClick={createGroup} className="flex-1 py-2 bg-indigo-600 text-white rounded-lg text-sm font-medium hover:bg-indigo-700">Create</button>
          </div>
        </div>
      )}

      {loading ? (
        <div className="flex justify-center py-16"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600" /></div>
      ) : groups.length === 0 ? (
        <div className="text-center py-16 text-slate-400">
          <Boxes className="w-10 h-10 mx-auto mb-3 opacity-30" />
          <p className="font-medium">No credential groups yet.</p>
          <p className="text-xs mt-1">Example: a "Bank" group holding your debit cards, netbanking login, and mobile PIN.</p>
          <button onClick={() => setShowCreate(true)} className="mt-3 text-indigo-600 text-sm hover:underline">Create your first credential group →</button>
        </div>
      ) : (
        <div className="bg-white rounded-xl border border-slate-200 divide-y divide-slate-100 overflow-hidden">
          {groups.map(group => (
            <div key={group.id} onClick={() => navigate(`/credential-groups/${group.id}`)}
              className="flex items-center gap-3 px-5 py-3.5 hover:bg-slate-50 cursor-pointer transition-colors">
              <span className="text-2xl shrink-0">{group.icon}</span>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-semibold text-slate-800 truncate">{group.name}</p>
                <p className="text-xs text-slate-400">
                  {group.credentialCount} credential{group.credentialCount !== 1 ? 's' : ''} · Created {formatDate(group.createdAt)}
                </p>
              </div>
              <button onClick={e => deleteGroup(group.id, e)}
                className="p-1.5 text-slate-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors">
                <Trash2 className="w-3.5 h-3.5" />
              </button>
              <ChevronRight className="w-4 h-4 text-slate-300" />
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
