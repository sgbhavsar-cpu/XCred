import { useEffect, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import {
  Plus, Search, Filter, RefreshCw, FolderOpen, ArrowLeft, X,
  ChevronDown, ChevronRight, Boxes, Settings, Trash2,
} from 'lucide-react';
import api from '@/api/client';
import { useDecryptedCredentials } from '@/hooks/useDecryptedCredentials';
import CredentialRow from '@/components/CredentialRow';
import { CREDENTIAL_TYPES } from '@/lib/vault';
import { credentialTypeLabel } from '@/lib/utils';
import { cn } from '@/lib/utils';
import toast from 'react-hot-toast';

interface CredGroup { id: string; name: string; icon: string; credentialCount: number }
interface FolderInfo { id: string; name: string }
interface TagInfo { id: string; name: string; color: string }

const ALL_TYPES = CREDENTIAL_TYPES;
const ICON_OPTIONS = ['🏦', '📧', '🌐', '📱', '🏢', '🚗', '🏥', '📦'];

export default function CredentialsPage() {
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const { credentials, decrypted, loading, refetch, deleteCredential } = useDecryptedCredentials();

  // URL-driven context filters (linked from Folders/Tags pages)
  const folderFilter = searchParams.get('folder');
  const tagFilter = searchParams.get('tag');

  const [groups, setGroups] = useState<CredGroup[]>([]);
  const [groupsLoading, setGroupsLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [filterType, setFilterType] = useState('');
  const [expanded, setExpanded] = useState<Set<string>>(new Set());

  const [showCreateGroup, setShowCreateGroup] = useState(false);
  const [newGroupName, setNewGroupName] = useState('');
  const [newGroupIcon, setNewGroupIcon] = useState('🏦');

  // Context info (folder name / tag name) loaded for the header
  const [contextLabel, setContextLabel] = useState<{ icon: React.ReactNode; name: string } | null>(null);

  const fetchGroups = async () => {
    setGroupsLoading(true);
    try {
      const res = await api.get('/credential-groups');
      setGroups(res.data.data);
    } catch {
      toast.error('Failed to load credential groups.');
    } finally {
      setGroupsLoading(false);
    }
  };

  useEffect(() => { fetchGroups(); }, []);

  useEffect(() => {
    if (!folderFilter && !tagFilter) { setContextLabel(null); return; }

    if (folderFilter) {
      api.get('/folders').then(res => {
        const flat = flattenFolders(res.data.data);
        const found = flat.find((f: FolderInfo) => f.id === folderFilter);
        if (found) setContextLabel({ icon: <FolderOpen className="w-4 h-4" />, name: found.name });
      }).catch(() => {});
    }

    if (tagFilter) {
      api.get('/tags').then(res => {
        const found = (res.data.data as TagInfo[]).find(t => t.id === tagFilter);
        if (found) setContextLabel({
          icon: <span className="w-3 h-3 rounded-full" style={{ backgroundColor: found.color }} />,
          name: found.name,
        });
      }).catch(() => {});
    }
  }, [folderFilter, tagFilter]);

  const clearContextFilter = () => setSearchParams({});
  const isFiltered = !!(folderFilter || tagFilter);
  const activeFilter = !!(search || filterType || isFiltered);

  const matchesFilters = (c: (typeof credentials)[number]) => {
    if (folderFilter && c.folderId !== folderFilter) return false;
    if (tagFilter && !c.tags.some(t => t.id === tagFilter)) return false;
    if (filterType && c.type !== filterType) return false;
    if (search) {
      const d = decrypted.get(c.id);
      const matchText = (d?.name ?? '').toLowerCase().includes(search.toLowerCase())
        || (d?.username ?? '').toLowerCase().includes(search.toLowerCase())
        || c.tags.some(t => t.name.toLowerCase().includes(search.toLowerCase()));
      if (!matchText) return false;
    }
    return true;
  };

  const filtered = credentials.filter(matchesFilters);

  const byGroup = new Map<string, typeof credentials>();
  const ungrouped: typeof credentials = [];
  for (const c of filtered) {
    if (c.credentialGroupId) {
      if (!byGroup.has(c.credentialGroupId)) byGroup.set(c.credentialGroupId, []);
      byGroup.get(c.credentialGroupId)!.push(c);
    } else {
      ungrouped.push(c);
    }
  }

  const visibleGroups = groups
    .filter(g => !activeFilter || (byGroup.get(g.id)?.length ?? 0) > 0)
    .sort((a, b) => a.name.localeCompare(b.name));

  const toggleExpand = (id: string) => setExpanded(prev => {
    const next = new Set(prev);
    next.has(id) ? next.delete(id) : next.add(id);
    return next;
  });

  const handleDelete = async (id: string, e: React.MouseEvent) => {
    e.stopPropagation();
    if (!confirm('Delete this credential? This cannot be undone.')) return;
    try {
      await deleteCredential(id);
      toast.success('Credential deleted.');
    } catch { toast.error('Failed to delete.'); }
  };

  const createGroup = async () => {
    if (!newGroupName.trim()) return;
    try {
      await api.post('/credential-groups', { name: newGroupName.trim(), icon: newGroupIcon });
      await fetchGroups();
      setNewGroupName(''); setNewGroupIcon('🏦'); setShowCreateGroup(false);
      toast.success('Credential group created.');
    } catch (err: any) {
      toast.error(err.response?.data?.error?.message ?? 'Failed to create credential group.');
    }
  };

  const deleteGroup = async (id: string, e: React.MouseEvent) => {
    e.stopPropagation();
    if (!confirm('Delete this credential group? Its credentials will not be deleted, just unlinked.')) return;
    try {
      await api.delete(`/credential-groups/${id}`);
      await fetchGroups();
      toast.success('Credential group deleted.');
    } catch { toast.error('Failed to delete credential group.'); }
  };

  const totalVisible = filtered.length;
  const nothingAtAll = credentials.length === 0 && groups.length === 0;
  const anyLoading = loading || groupsLoading;

  const refreshAll = () => { refetch(); fetchGroups(); };

  return (
    <div className="p-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-5">
        <div className="flex items-center gap-3">
          {isFiltered && (
            <button onClick={clearContextFilter}
              className="p-1.5 text-slate-400 hover:text-slate-700 hover:bg-slate-100 rounded-lg transition-colors" title="Back to all credentials">
              <ArrowLeft className="w-5 h-5" />
            </button>
          )}
          <div>
            {isFiltered && contextLabel ? (
              <>
                <div className="flex items-center gap-2 mb-0.5">
                  {contextLabel.icon}
                  <h1 className="text-2xl font-bold text-slate-900">{contextLabel.name}</h1>
                  <button onClick={clearContextFilter}
                    className="ml-1 p-0.5 text-slate-400 hover:text-slate-600 rounded" title="Clear filter">
                    <X className="w-3.5 h-3.5" />
                  </button>
                </div>
                <p className="text-slate-500 text-sm">
                  {totalVisible} credential{totalVisible !== 1 ? 's' : ''} ·{' '}
                  <button onClick={clearContextFilter} className="text-indigo-600 hover:underline">View all credentials</button>
                </p>
              </>
            ) : (
              <>
                <h1 className="text-2xl font-bold text-slate-900">Credentials</h1>
                <p className="text-slate-500 text-sm">{credentials.length} encrypted credential{credentials.length !== 1 ? 's' : ''} in {groups.length} group{groups.length !== 1 ? 's' : ''}</p>
              </>
            )}
          </div>
        </div>
        <div className="flex items-center gap-2 shrink-0">
          <button onClick={() => setShowCreateGroup(true)}
            className="flex items-center gap-2 border border-slate-300 text-slate-700 px-4 py-2 rounded-lg text-sm font-medium hover:bg-slate-50 transition-colors">
            <Boxes className="w-4 h-4" /> New Credential Group
          </button>
          <button onClick={() => navigate('/credentials/new')}
            className="flex items-center gap-2 bg-indigo-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-indigo-700 transition-colors">
            <Plus className="w-4 h-4" /> Add Credential
          </button>
        </div>
      </div>

      {/* New credential group inline form */}
      {showCreateGroup && (
        <div className="bg-white rounded-xl border border-indigo-200 p-4 mb-4 space-y-3">
          <h3 className="text-sm font-semibold text-slate-700">Create Credential Group</h3>
          <div className="flex gap-2 flex-wrap">
            {ICON_OPTIONS.map(icon => (
              <button key={icon} type="button" onClick={() => setNewGroupIcon(icon)}
                className={cn('text-xl w-10 h-10 rounded-lg border-2 flex items-center justify-center transition-all',
                  newGroupIcon === icon ? 'border-indigo-500 bg-indigo-50' : 'border-slate-200 hover:border-slate-300')}>
                {icon}
              </button>
            ))}
          </div>
          <input value={newGroupName} onChange={e => setNewGroupName(e.target.value)} placeholder='e.g. "HDFC Bank"' autoFocus
            className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
          <div className="flex gap-2">
            <button onClick={() => { setShowCreateGroup(false); setNewGroupName(''); }}
              className="flex-1 py-2 border border-slate-200 rounded-lg text-sm text-slate-600 hover:bg-slate-50">Cancel</button>
            <button onClick={createGroup} className="flex-1 py-2 bg-indigo-600 text-white rounded-lg text-sm font-medium hover:bg-indigo-700">Create</button>
          </div>
        </div>
      )}

      {/* Active filter badge */}
      {isFiltered && contextLabel && (
        <div className="flex items-center gap-2 mb-4">
          <span className="text-xs font-medium text-slate-500">Filtered by:</span>
          <span className="flex items-center gap-1.5 px-2.5 py-1 bg-indigo-50 border border-indigo-200 text-indigo-700 rounded-full text-xs font-medium">
            {contextLabel.icon}
            {folderFilter ? 'Folder:' : 'Tag:'} {contextLabel.name}
            <button onClick={clearContextFilter} className="ml-0.5 hover:text-indigo-900">
              <X className="w-3 h-3" />
            </button>
          </span>
        </div>
      )}

      {/* Search + type filter */}
      <div className="flex gap-3 mb-5">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
          <input value={search} onChange={e => setSearch(e.target.value)}
            placeholder="Search by name, username, or tag…"
            className="w-full pl-9 pr-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
        </div>
        <div className="relative">
          <Filter className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
          <select value={filterType} onChange={e => setFilterType(e.target.value)}
            className="pl-9 pr-8 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white">
            <option value="">All Types</option>
            {ALL_TYPES.map(t => <option key={t} value={t}>{credentialTypeLabel(t)}</option>)}
          </select>
        </div>
        <button onClick={refreshAll} title="Refresh" className="p-2 border border-slate-300 rounded-lg hover:bg-slate-50 transition-colors">
          <RefreshCw className="w-4 h-4 text-slate-500" />
        </button>
      </div>

      {/* Tree: credential groups (expandable) + ungrouped credentials */}
      {anyLoading ? (
        <div className="flex justify-center py-16"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600" /></div>
      ) : nothingAtAll ? (
        <div className="text-center py-16 text-slate-400">
          <p className="text-4xl mb-3">🔐</p>
          <p className="font-medium">No credentials yet.</p>
          <button onClick={() => navigate('/credentials/new')} className="mt-4 text-indigo-600 text-sm hover:underline">Add your first credential →</button>
        </div>
      ) : visibleGroups.length === 0 && ungrouped.length === 0 ? (
        <div className="text-center py-16 text-slate-400">
          <p className="text-4xl mb-3">🔐</p>
          <p className="font-medium">
            {isFiltered ? `No credentials in this ${folderFilter ? 'folder' : 'tag'}.` : 'No credentials match your search.'}
          </p>
          {isFiltered && (
            <button onClick={clearContextFilter} className="mt-3 text-indigo-600 text-sm hover:underline">← View all credentials</button>
          )}
        </div>
      ) : (
        <div className="bg-white rounded-xl border border-slate-200 divide-y divide-slate-100 overflow-hidden">
          {visibleGroups.map(group => {
            const members = byGroup.get(group.id) ?? [];
            const isOpen = expanded.has(group.id) || activeFilter;
            return (
              <div key={group.id}>
                <div onClick={() => toggleExpand(group.id)}
                  className="flex items-center gap-3 px-5 py-3.5 hover:bg-slate-50 cursor-pointer transition-colors">
                  {isOpen ? <ChevronDown className="w-4 h-4 text-slate-400 shrink-0" /> : <ChevronRight className="w-4 h-4 text-slate-400 shrink-0" />}
                  <span className="text-2xl shrink-0">{group.icon}</span>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold text-slate-800 truncate">{group.name}</p>
                    <p className="text-xs text-slate-400">{members.length} credential{members.length !== 1 ? 's' : ''}</p>
                  </div>
                  <div className="flex items-center gap-1 shrink-0">
                    <button onClick={e => { e.stopPropagation(); navigate(`/credentials/new?groupId=${group.id}&returnTo=${encodeURIComponent('/credentials')}`); }}
                      className="p-1.5 rounded hover:bg-indigo-50 text-slate-400 hover:text-indigo-600 transition-colors" title="Add credential to this group">
                      <Plus className="w-3.5 h-3.5" />
                    </button>
                    <button onClick={e => { e.stopPropagation(); navigate(`/credential-groups/${group.id}`); }}
                      className="p-1.5 rounded hover:bg-slate-100 text-slate-400 hover:text-indigo-600 transition-colors" title="Manage group (rename, add existing credential)">
                      <Settings className="w-3.5 h-3.5" />
                    </button>
                    <button onClick={e => deleteGroup(group.id, e)}
                      className="p-1.5 rounded hover:bg-red-50 text-slate-400 hover:text-red-500 transition-colors" title="Delete group">
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </div>

                {isOpen && (
                  members.length === 0 ? (
                    <div className="px-5 py-4 pl-14 text-xs text-slate-400 bg-slate-50/50">
                      No credentials in this group yet. <button onClick={() => navigate(`/credential-groups/${group.id}`)} className="text-indigo-600 hover:underline">Add one</button>.
                    </div>
                  ) : (
                    <div className="divide-y divide-slate-100">
                      {members.map(cred => (
                        <CredentialRow key={cred.id} cred={cred} decrypted={decrypted.get(cred.id)}
                          onOpen={() => navigate(`/credentials/${cred.id}`)}
                          onDelete={e => handleDelete(cred.id, e)}
                          onTagClick={tagId => setSearchParams({ tag: tagId })}
                          indent
                        />
                      ))}
                    </div>
                  )
                )}
              </div>
            );
          })}

          {ungrouped.length > 0 && (
            <div>
              {visibleGroups.length > 0 && (
                <div className="px-5 py-2 bg-slate-50">
                  <p className="text-xs font-semibold text-slate-500 uppercase tracking-wide">Ungrouped</p>
                </div>
              )}
              <div className="divide-y divide-slate-100">
                {ungrouped.map(cred => (
                  <CredentialRow key={cred.id} cred={cred} decrypted={decrypted.get(cred.id)}
                    onOpen={() => navigate(`/credentials/${cred.id}`)}
                    onDelete={e => handleDelete(cred.id, e)}
                    onTagClick={tagId => setSearchParams({ tag: tagId })}
                  />
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function flattenFolders(folders: Array<{ id: string; name: string; children?: any[] }>, prefix = ''): FolderInfo[] {
  const result: FolderInfo[] = [];
  for (const f of folders) {
    result.push({ id: f.id, name: prefix + f.name });
    if (f.children?.length) result.push(...flattenFolders(f.children, prefix + f.name + ' / '));
  }
  return result;
}
