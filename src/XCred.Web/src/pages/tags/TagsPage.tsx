import { useEffect, useState } from 'react';
import { Plus, Search, Edit2, Trash2, Check, X, Tag, ChevronDown, ChevronRight } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import toast from 'react-hot-toast';
import api from '@/api/client';
import { cn } from '@/lib/utils';
import { useDecryptedCredentials } from '@/hooks/useDecryptedCredentials';
import CredentialRow from '@/components/CredentialRow';
import SelectionToolbar from '@/components/SelectionToolbar';
import SelectAllButton from '@/components/SelectAllButton';
import BulkTagEditModal from '@/components/BulkTagEditModal';

interface TagItem { id: string; name: string; color: string; credentialCount: number }

const PRESET_COLORS = ['#6366f1','#3b82f6','#10b981','#f59e0b','#ef4444','#8b5cf6','#ec4899','#14b8a6','#f97316','#64748b'];

export default function TagsPage() {
  const navigate = useNavigate();
  const { credentials, decrypted, loading: credsLoading, deleteCredential, bulkTags } = useDecryptedCredentials();

  const [tags, setTags] = useState<TagItem[]>([]);
  const [tagsLoading, setTagsLoading] = useState(true);
  const [expanded, setExpanded] = useState<Set<string>>(new Set());
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editName, setEditName] = useState('');
  const [editColor, setEditColor] = useState('');
  const [newName, setNewName] = useState('');
  const [newColor, setNewColor] = useState(PRESET_COLORS[0]);
  const [adding, setAdding] = useState(false);
  const [search, setSearch] = useState('');
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [showBulkEdit, setShowBulkEdit] = useState(false);

  const load = async () => {
    setTagsLoading(true);
    try {
      const res = await api.get('/tags');
      setTags(res.data.data);
    } finally { setTagsLoading(false); }
  };

  useEffect(() => { load(); }, []);

  const startEdit = (tag: TagItem) => { setEditingId(tag.id); setEditName(tag.name); setEditColor(tag.color); };

  const saveEdit = async () => {
    if (!editName.trim()) return;
    try {
      await api.put(`/tags/${editingId}`, { name: editName.trim(), color: editColor });
      setTags(prev => prev.map(t => t.id === editingId ? { ...t, name: editName.trim(), color: editColor } : t));
      setEditingId(null);
      toast.success('Tag updated.');
    } catch (err: any) { toast.error(err.response?.data?.error?.message ?? 'Failed to update.'); }
  };

  const deleteTag = async (id: string) => {
    if (!confirm('Delete this tag? It will be removed from all credentials.')) return;
    try {
      await api.delete(`/tags/${id}`);
      setTags(prev => prev.filter(t => t.id !== id));
      toast.success('Tag deleted.');
    } catch { toast.error('Failed to delete.'); }
  };

  const createTag = async () => {
    if (!newName.trim()) return;
    try {
      const res = await api.post('/tags', { name: newName.trim(), color: newColor });
      setTags(prev => [...prev, res.data.data]);
      setNewName(''); setNewColor(PRESET_COLORS[0]); setAdding(false);
      toast.success('Tag created.');
    } catch (err: any) { toast.error(err.response?.data?.error?.message ?? 'Failed to create.'); }
  };

  const toggleExpand = (id: string) => setExpanded(prev => {
    const next = new Set(prev);
    next.has(id) ? next.delete(id) : next.add(id);
    return next;
  });

  const toggleSelect = (id: string) => setSelectedIds(prev => {
    const next = new Set(prev);
    next.has(id) ? next.delete(id) : next.add(id);
    return next;
  });
  const clearSelection = () => setSelectedIds(new Set());

  const handleDeleteCredential = async (id: string, e: React.MouseEvent) => {
    e.stopPropagation();
    if (!confirm('Delete this credential? This cannot be undone.')) return;
    try {
      await deleteCredential(id);
      toast.success('Credential deleted.');
    } catch { toast.error('Failed to delete.'); }
  };

  const applyBulkTagEdit = async (changes: { addTagIds: string[]; removeTagIds: string[] }) => {
    try {
      const result = await bulkTags(Array.from(selectedIds), changes);
      toast.success(`Updated ${result.updated} credential${result.updated !== 1 ? 's' : ''}.`);
      clearSelection();
      setShowBulkEdit(false);
    } catch (err: any) {
      toast.error(err.response?.data?.error?.message ?? 'Bulk edit failed.');
    }
  };

  const matchesSearch = (c: (typeof credentials)[number]) => {
    if (!search) return true;
    const d = decrypted.get(c.id);
    const q = search.toLowerCase();
    return (d?.name ?? '').toLowerCase().includes(q) || (d?.username ?? '').toLowerCase().includes(q);
  };
  const activeFilter = !!search;
  const visibleCredentials = credentials.filter(matchesSearch);

  const byTag = new Map<string, typeof credentials>();
  const untagged: typeof credentials = [];
  for (const c of visibleCredentials) {
    if (c.tags.length === 0) { untagged.push(c); continue; }
    for (const t of c.tags) {
      if (!byTag.has(t.id)) byTag.set(t.id, []);
      byTag.get(t.id)!.push(c);
    }
  }

  const loading = tagsLoading || credsLoading;
  const visibleTags = tags.filter(t => !activeFilter || (byTag.get(t.id)?.length ?? 0) > 0);
  const nothingVisible = activeFilter && visibleTags.length === 0 && untagged.length === 0;

  const allVisibleSelected = visibleCredentials.length > 0 && visibleCredentials.every(c => selectedIds.has(c.id));
  const toggleSelectAll = () => setSelectedIds(allVisibleSelected ? new Set() : new Set(visibleCredentials.map(c => c.id)));

  return (
    <div className="p-6">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Tags</h1>
          <p className="text-slate-500 text-sm">Organise credentials with color-coded labels</p>
        </div>
        <button onClick={() => setAdding(true)}
          className="flex items-center gap-2 bg-indigo-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-indigo-700 transition-colors">
          <Plus className="w-4 h-4" /> New Tag
        </button>
      </div>

      {/* Create form */}
      {adding && (
        <div className="bg-white rounded-xl border border-indigo-200 p-4 mb-4">
          <p className="text-sm font-medium text-slate-700 mb-3">New Tag</p>
          <div className="flex items-center gap-3 mb-3">
            <div className="flex gap-1.5 flex-wrap">
              {PRESET_COLORS.map(c => (
                <button key={c} type="button" onClick={() => setNewColor(c)}
                  className={cn('w-6 h-6 rounded-full transition-all', newColor === c && 'ring-2 ring-offset-2 ring-slate-600 scale-110')}
                  style={{ backgroundColor: c }} />
              ))}
            </div>
          </div>
          <div className="flex gap-2">
            <input value={newName} onChange={e => setNewName(e.target.value)} placeholder="Tag name…"
              onKeyDown={e => e.key === 'Enter' && createTag()}
              autoFocus
              className="flex-1 px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
            <button onClick={createTag} title="Create tag" className="px-3 py-2 bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 transition-colors">
              <Check className="w-4 h-4" />
            </button>
            <button onClick={() => { setAdding(false); setNewName(''); }} title="Cancel" className="px-3 py-2 border border-slate-200 text-slate-500 rounded-lg hover:bg-slate-50 transition-colors">
              <X className="w-4 h-4" />
            </button>
          </div>
        </div>
      )}

      <div className="flex flex-wrap gap-3 mb-4">
        <div className="relative flex-1 min-w-[200px]">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
          <input value={search} onChange={e => setSearch(e.target.value)}
            placeholder="Search by name or username…"
            className="w-full pl-9 pr-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
        </div>
        <SelectAllButton allSelected={allVisibleSelected} onToggle={toggleSelectAll} disabled={visibleCredentials.length === 0} />
      </div>

      <SelectionToolbar count={selectedIds.size} onBulkEdit={() => setShowBulkEdit(true)} onClear={clearSelection} />

      {loading ? (
        <div className="flex justify-center py-16"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600" /></div>
      ) : tags.length === 0 ? (
        <div className="text-center py-16 text-slate-400">
          <Tag className="w-10 h-10 mx-auto mb-3 opacity-30" />
          <p className="font-medium">No tags yet.</p>
          <button onClick={() => setAdding(true)} className="mt-3 text-indigo-600 text-sm hover:underline">Create your first tag →</button>
        </div>
      ) : nothingVisible ? (
        <div className="text-center py-16 text-slate-400">
          <p className="text-4xl mb-3">🔍</p>
          <p className="font-medium">No credentials match your search.</p>
        </div>
      ) : (
        <div className="bg-white rounded-xl border border-slate-200 divide-y divide-slate-100 overflow-hidden">
          {visibleTags.map(tag => {
            const members = byTag.get(tag.id) ?? [];
            const isOpen = expanded.has(tag.id) || activeFilter;
            const isEditing = editingId === tag.id;
            return (
              <div key={tag.id}>
                <div onClick={() => !isEditing && toggleExpand(tag.id)}
                  className={cn('flex items-center gap-4 px-5 py-4', !isEditing && 'cursor-pointer hover:bg-slate-50 transition-colors')}>
                  {isEditing ? (
                    <>
                      {/* Color picker in edit mode */}
                      <div className="flex gap-1.5 flex-wrap">
                        {PRESET_COLORS.map(c => (
                          <button key={c} type="button" onClick={e => { e.stopPropagation(); setEditColor(c); }}
                            className={cn('w-5 h-5 rounded-full transition-all', editColor === c && 'ring-2 ring-offset-1 ring-slate-700 scale-110')}
                            style={{ backgroundColor: c }} />
                        ))}
                      </div>
                      <input value={editName} onChange={e => setEditName(e.target.value)} autoFocus
                        onClick={e => e.stopPropagation()}
                        onKeyDown={e => { if (e.key === 'Enter') saveEdit(); if (e.key === 'Escape') setEditingId(null); }}
                        className="flex-1 px-3 py-1.5 border border-indigo-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
                      <button onClick={e => { e.stopPropagation(); saveEdit(); }} className="p-1.5 bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 transition-colors"><Check className="w-3.5 h-3.5" /></button>
                      <button onClick={e => { e.stopPropagation(); setEditingId(null); }} className="p-1.5 text-slate-400 hover:text-slate-600 transition-colors"><X className="w-3.5 h-3.5" /></button>
                    </>
                  ) : (
                    <>
                      {isOpen ? <ChevronDown className="w-4 h-4 text-slate-400 shrink-0" /> : <ChevronRight className="w-4 h-4 text-slate-400 shrink-0" />}
                      {/* Color dot + pill preview */}
                      <div className="flex items-center gap-3 flex-1 min-w-0">
                        <span className="w-4 h-4 rounded-full shrink-0" style={{ backgroundColor: tag.color }} />
                        <div>
                          <div className="flex items-center gap-2">
                            <span className="text-sm font-semibold text-slate-800">{tag.name}</span>
                            <span
                              className="text-xs px-2 py-0.5 rounded-full font-medium text-white"
                              style={{ backgroundColor: tag.color }}
                            >
                              {tag.name}
                            </span>
                          </div>
                          <p className="text-xs text-slate-400 mt-0.5">
                            {members.length === 0
                              ? 'No credentials'
                              : `${members.length} credential${members.length !== 1 ? 's' : ''}`}
                          </p>
                        </div>
                      </div>

                      <div className="flex items-center gap-1 shrink-0">
                        <button onClick={e => { e.stopPropagation(); navigate(`/credentials/new?tagId=${tag.id}&returnTo=${encodeURIComponent('/tags')}`); }}
                          className="p-2 text-slate-400 hover:text-indigo-600 hover:bg-indigo-50 rounded-lg transition-colors" title="Add credential with this tag">
                          <Plus className="w-3.5 h-3.5" />
                        </button>
                        <button onClick={e => { e.stopPropagation(); startEdit(tag); }}
                          className="p-2 text-slate-400 hover:text-indigo-600 hover:bg-indigo-50 rounded-lg transition-colors" title="Edit">
                          <Edit2 className="w-3.5 h-3.5" />
                        </button>
                        <button onClick={e => { e.stopPropagation(); deleteTag(tag.id); }}
                          className="p-2 text-slate-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors" title="Delete">
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    </>
                  )}
                </div>

                {isOpen && !isEditing && (
                  members.length === 0 ? (
                    <div className="px-5 py-4 pl-14 text-xs text-slate-400 bg-slate-50/50">
                      No credentials with this tag yet. <button onClick={() => navigate(`/credentials/new?tagId=${tag.id}&returnTo=${encodeURIComponent('/tags')}`)} className="text-indigo-600 hover:underline">Add one</button>.
                    </div>
                  ) : (
                    <div className="divide-y divide-slate-100">
                      {members.map(cred => (
                        <CredentialRow key={cred.id} cred={cred} decrypted={decrypted.get(cred.id)}
                          onOpen={() => navigate(`/credentials/${cred.id}`)}
                          onDelete={e => handleDeleteCredential(cred.id, e)}
                          onTagClick={tagId => navigate(`/credentials?tag=${tagId}`)}
                          indent selectable
                          selected={selectedIds.has(cred.id)}
                          onToggleSelect={() => toggleSelect(cred.id)}
                        />
                      ))}
                    </div>
                  )
                )}
              </div>
            );
          })}

          {untagged.length > 0 && (
            <div>
              {visibleTags.length > 0 && (
                <div className="px-5 py-2 bg-slate-50">
                  <p className="text-xs font-semibold text-slate-500 uppercase tracking-wide">Untagged</p>
                </div>
              )}
              <div className="divide-y divide-slate-100">
                {untagged.map(cred => (
                  <CredentialRow key={cred.id} cred={cred} decrypted={decrypted.get(cred.id)}
                    onOpen={() => navigate(`/credentials/${cred.id}`)}
                    onDelete={e => handleDeleteCredential(cred.id, e)}
                    onTagClick={tagId => navigate(`/credentials?tag=${tagId}`)}
                    selectable
                    selected={selectedIds.has(cred.id)}
                    onToggleSelect={() => toggleSelect(cred.id)}
                  />
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      {showBulkEdit && (
        <BulkTagEditModal count={selectedIds.size} tags={tags}
          onApply={applyBulkTagEdit} onClose={() => setShowBulkEdit(false)} />
      )}
    </div>
  );
}
