import { useEffect, useState, useCallback } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { Plus, Search, Filter, Eye, Trash2, RefreshCw, FolderOpen, Tag, ArrowLeft, X } from 'lucide-react';
import api from '@/api/client';
import { useAuthStore } from '@/store/authStore';
import { decryptCredentialData, CREDENTIAL_TYPES } from '@/lib/vault';
import { credentialTypeLabel, credentialTypeIcon, formatDate } from '@/lib/utils';
import { cn } from '@/lib/utils';
import toast from 'react-hot-toast';

interface CredentialItem {
  id: string;
  type: string;
  encryptedData: string;
  dataIv: string;
  encryptedCredentialKey: string;
  folderId: string | null;
  expiryDate: string | null;
  updatedAt: string;
  tags: Array<{ id: string; name: string; color: string }>;
}

interface FolderInfo { id: string; name: string }
interface TagInfo { id: string; name: string; color: string }

const ALL_TYPES = CREDENTIAL_TYPES;

export default function CredentialsPage() {
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const { privateKey } = useAuthStore();

  // URL-driven context filters
  const folderFilter = searchParams.get('folder');
  const tagFilter = searchParams.get('tag');

  const [credentials, setCredentials] = useState<CredentialItem[]>([]);
  const [decrypted, setDecrypted] = useState<Map<string, { name: string; username?: string }>>(new Map());
  const [search, setSearch] = useState('');
  const [filterType, setFilterType] = useState('');
  const [loading, setLoading] = useState(true);

  // Context info (folder name / tag name) loaded for the header
  const [contextLabel, setContextLabel] = useState<{ icon: React.ReactNode; name: string } | null>(null);

  // Resolve the human-readable name for the active folder/tag filter
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

  const fetchCredentials = useCallback(async () => {
    setLoading(true);
    try {
      const res = await api.get('/credentials');
      const items: CredentialItem[] = res.data.data;
      setCredentials(items);

      if (!privateKey) return;
      const map = new Map<string, { name: string; username?: string }>();
      await Promise.all(items.map(async item => {
        try {
          const fields = await decryptCredentialData(item.encryptedData, item.dataIv, item.encryptedCredentialKey, privateKey);
          map.set(item.id, {
            name: fields.name ?? credentialTypeLabel(item.type),
            username: fields.username ?? fields.email ?? fields.cardholderName ?? fields.ssid,
          });
        } catch {
          map.set(item.id, { name: credentialTypeLabel(item.type) });
        }
      }));
      setDecrypted(map);
    } catch {
      toast.error('Failed to load credentials.');
    } finally {
      setLoading(false);
    }
  }, [privateKey]);

  useEffect(() => { fetchCredentials(); }, [fetchCredentials]);

  const clearContextFilter = () => {
    setSearchParams({});
  };

  // Apply all active filters
  const filtered = credentials.filter(c => {
    // Folder filter from URL
    if (folderFilter && c.folderId !== folderFilter) return false;
    // Tag filter from URL
    if (tagFilter && !c.tags.some(t => t.id === tagFilter)) return false;
    // Type dropdown filter
    if (filterType && c.type !== filterType) return false;
    // Search box
    if (search) {
      const d = decrypted.get(c.id);
      const matchText = (d?.name ?? '').toLowerCase().includes(search.toLowerCase())
        || (d?.username ?? '').toLowerCase().includes(search.toLowerCase())
        || c.tags.some(t => t.name.toLowerCase().includes(search.toLowerCase()));
      if (!matchText) return false;
    }
    return true;
  });

  const handleDelete = async (id: string, e: React.MouseEvent) => {
    e.stopPropagation();
    if (!confirm('Delete this credential? This cannot be undone.')) return;
    try {
      await api.delete(`/credentials/${id}`);
      setCredentials(prev => prev.filter(c => c.id !== id));
      toast.success('Credential deleted.');
    } catch { toast.error('Failed to delete.'); }
  };

  const isFiltered = !!(folderFilter || tagFilter);

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
                  {filtered.length} credential{filtered.length !== 1 ? 's' : ''} ·{' '}
                  <button onClick={clearContextFilter} className="text-indigo-600 hover:underline">View all credentials</button>
                </p>
              </>
            ) : (
              <>
                <h1 className="text-2xl font-bold text-slate-900">Credentials</h1>
                <p className="text-slate-500 text-sm">{credentials.length} encrypted credential{credentials.length !== 1 ? 's' : ''}</p>
              </>
            )}
          </div>
        </div>
        <button onClick={() => navigate('/credentials/new')}
          className="flex items-center gap-2 bg-indigo-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-indigo-700 transition-colors">
          <Plus className="w-4 h-4" /> Add Credential
        </button>
      </div>

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
        <button onClick={fetchCredentials} title="Refresh" className="p-2 border border-slate-300 rounded-lg hover:bg-slate-50 transition-colors">
          <RefreshCw className="w-4 h-4 text-slate-500" />
        </button>
      </div>

      {/* Credential list */}
      {loading ? (
        <div className="flex justify-center py-16"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600" /></div>
      ) : filtered.length === 0 ? (
        <div className="text-center py-16 text-slate-400">
          <p className="text-4xl mb-3">🔐</p>
          <p className="font-medium">
            {isFiltered ? `No credentials in this ${folderFilter ? 'folder' : 'tag'}.` : search || filterType ? 'No credentials match your search.' : 'No credentials yet.'}
          </p>
          {isFiltered && (
            <button onClick={clearContextFilter} className="mt-3 text-indigo-600 text-sm hover:underline">← View all credentials</button>
          )}
          {!isFiltered && !search && !filterType && (
            <button onClick={() => navigate('/credentials/new')} className="mt-4 text-indigo-600 text-sm hover:underline">Add your first credential →</button>
          )}
        </div>
      ) : (
        <div className="bg-white rounded-xl border border-slate-200 divide-y divide-slate-100 overflow-hidden">
          {filtered.map(cred => {
            const d = decrypted.get(cred.id);
            const isExpired = cred.expiryDate && new Date(cred.expiryDate) < new Date();
            return (
              <div key={cred.id} onClick={() => navigate(`/credentials/${cred.id}`)}
                className="flex items-center gap-4 px-5 py-3.5 hover:bg-slate-50 cursor-pointer transition-colors">
                <span className="text-2xl shrink-0">{credentialTypeIcon(cred.type)}</span>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2">
                    <p className="text-sm font-semibold text-slate-800 truncate">{d?.name ?? '…'}</p>
                    {isExpired && <span className="text-xs bg-red-100 text-red-600 px-1.5 py-0.5 rounded-full font-medium shrink-0">Expired</span>}
                  </div>
                  <p className="text-xs text-slate-400 truncate">
                    {credentialTypeLabel(cred.type)}{d?.username ? ` · ${d.username}` : ''}
                  </p>
                  {cred.tags.length > 0 && (
                    <div className="flex gap-1 mt-1.5 flex-wrap">
                      {cred.tags.slice(0, 5).map(tag => (
                        <button key={tag.id}
                          onClick={e => { e.stopPropagation(); setSearchParams({ tag: tag.id }); }}
                          className="text-xs px-1.5 py-0.5 rounded-full font-medium text-white hover:opacity-80 transition-opacity"
                          style={{ backgroundColor: tag.color }}
                          title={`Filter by tag: ${tag.name}`}>
                          {tag.name}
                        </button>
                      ))}
                    </div>
                  )}
                </div>
                <div className="flex items-center gap-1 shrink-0">
                  <p className="text-xs text-slate-400 mr-2">{formatDate(cred.updatedAt)}</p>
                  <button onClick={e => { e.stopPropagation(); navigate(`/credentials/${cred.id}`); }}
                    className="p-1.5 rounded hover:bg-slate-100 text-slate-400 hover:text-indigo-600 transition-colors" title="View">
                    <Eye className="w-3.5 h-3.5" />
                  </button>
                  <button onClick={e => handleDelete(cred.id, e)}
                    className="p-1.5 rounded hover:bg-red-50 text-slate-400 hover:text-red-500 transition-colors" title="Delete">
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>
              </div>
            );
          })}
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
