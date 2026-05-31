import { useEffect, useState } from 'react';
import { Plus, ChevronRight, Edit2, Trash2, Check, X, Folder as FolderIcon, FolderOpen, ArrowRight } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import toast from 'react-hot-toast';
import api from '@/api/client';
import { cn } from '@/lib/utils';

interface FolderItem {
  id: string;
  name: string;
  parentFolderId: string | null;
  sortOrder: number;
  credentialCount: number;
  children: FolderItem[];
}

export default function FoldersPage() {
  const navigate = useNavigate();
  const [folders, setFolders] = useState<FolderItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [creating, setCreating] = useState(false);
  const [newName, setNewName] = useState('');
  const [newParentId, setNewParentId] = useState('');
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editName, setEditName] = useState('');

  const load = async () => {
    try {
      const res = await api.get('/folders');
      setFolders(res.data.data);
    } finally { setLoading(false); }
  };

  useEffect(() => { load(); }, []);

  const createFolder = async () => {
    if (!newName.trim()) return;
    try {
      await api.post('/folders', { name: newName.trim(), parentFolderId: newParentId || null });
      await load();
      setNewName(''); setNewParentId(''); setCreating(false);
      toast.success('Folder created.');
    } catch (err: any) { toast.error(err.response?.data?.error?.message ?? 'Failed to create.'); }
  };

  const updateFolder = async (id: string) => {
    if (!editName.trim()) return;
    try {
      await api.put(`/folders/${id}`, { name: editName.trim() });
      await load();
      setEditingId(null);
      toast.success('Folder renamed.');
    } catch { toast.error('Failed to rename.'); }
  };

  const deleteFolder = async (id: string) => {
    if (!confirm('Delete this folder? Credentials inside will be moved to "No Folder".')) return;
    try {
      await api.delete(`/folders/${id}`);
      await load();
      toast.success('Folder deleted.');
    } catch { toast.error('Failed to delete.'); }
  };

  const flatFolders = flattenFolderList(folders);

  return (
    <div className="p-6 max-w-3xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Folders</h1>
          <p className="text-slate-500 text-sm">Organise credentials into nested folders</p>
        </div>
        <button onClick={() => setCreating(true)}
          className="flex items-center gap-2 bg-indigo-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-indigo-700 transition-colors">
          <Plus className="w-4 h-4" /> New Folder
        </button>
      </div>

      {creating && (
        <div className="bg-white rounded-xl border border-indigo-200 p-4 mb-4 space-y-3">
          <h3 className="text-sm font-semibold text-slate-700">New Folder</h3>
          <input value={newName} onChange={e => setNewName(e.target.value)} placeholder="Folder name"
            autoFocus onKeyDown={e => e.key === 'Enter' && createFolder()}
            className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
          <div>
            <label className="block text-xs text-slate-500 mb-1">Parent Folder (optional)</label>
            <select value={newParentId} onChange={e => setNewParentId(e.target.value)}
              className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white">
              <option value="">None (top-level)</option>
              {flatFolders.map(f => <option key={f.id} value={f.id}>{f.name}</option>)}
            </select>
          </div>
          <div className="flex gap-2">
            <button onClick={() => { setCreating(false); setNewName(''); setNewParentId(''); }}
              className="flex-1 py-2 border border-slate-200 rounded-lg text-sm text-slate-600 hover:bg-slate-50">Cancel</button>
            <button onClick={createFolder}
              className="flex-1 py-2 bg-indigo-600 text-white rounded-lg text-sm font-medium hover:bg-indigo-700">Create</button>
          </div>
        </div>
      )}

      {loading ? (
        <div className="flex justify-center py-16"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600" /></div>
      ) : folders.length === 0 ? (
        <div className="text-center py-16 text-slate-400">
          <FolderOpen className="w-10 h-10 mx-auto mb-3 opacity-30" />
          <p className="font-medium">No folders yet.</p>
          <button onClick={() => setCreating(true)} className="mt-3 text-indigo-600 text-sm hover:underline">Create your first folder →</button>
        </div>
      ) : (
        <div className="bg-white rounded-xl border border-slate-200 divide-y divide-slate-100 overflow-hidden">
          <FolderTree
            folders={folders} depth={0}
            editingId={editingId} editName={editName}
            setEditingId={setEditingId} setEditName={setEditName}
            onUpdate={updateFolder} onDelete={deleteFolder}
            onViewCredentials={id => navigate(`/credentials?folder=${id}`)}
          />
        </div>
      )}
    </div>
  );
}

function FolderTree({ folders, depth, editingId, editName, setEditingId, setEditName, onUpdate, onDelete, onViewCredentials }: {
  folders: FolderItem[]; depth: number; editingId: string | null; editName: string;
  setEditingId: (id: string | null) => void; setEditName: (name: string) => void;
  onUpdate: (id: string) => void; onDelete: (id: string) => void; onViewCredentials: (id: string) => void;
}) {
  return (
    <>
      {folders.map(folder => (
        <div key={folder.id}>
          <div className={cn('flex items-center gap-3 px-4 py-4', depth > 0 && 'bg-slate-50/60')}>
            {/* Indent + connector */}
            {depth > 0 && <div style={{ width: depth * 20 }} className="shrink-0" />}
            {depth > 0 && <ChevronRight className="w-3.5 h-3.5 text-slate-300 shrink-0" />}

            <div className={cn('w-9 h-9 rounded-lg flex items-center justify-center shrink-0', depth === 0 ? 'bg-amber-100' : 'bg-amber-50')}>
              <FolderIcon className={cn('w-4.5 h-4.5', depth === 0 ? 'text-amber-600' : 'text-amber-400')} />
            </div>

            {editingId === folder.id ? (
              <>
                <input value={editName} onChange={e => setEditName(e.target.value)} autoFocus
                  onKeyDown={e => { if (e.key === 'Enter') onUpdate(folder.id); if (e.key === 'Escape') setEditingId(null); }}
                  className="flex-1 px-3 py-1.5 border border-indigo-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
                <button onClick={() => onUpdate(folder.id)} className="p-1.5 bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 transition-colors"><Check className="w-3.5 h-3.5" /></button>
                <button onClick={() => setEditingId(null)} className="p-1.5 text-slate-400 hover:text-slate-600 transition-colors"><X className="w-3.5 h-3.5" /></button>
              </>
            ) : (
              <>
                {/* Folder name + count */}
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-semibold text-slate-800 truncate">{folder.name}</p>
                  <p className="text-xs text-slate-400 mt-0.5">
                    {folder.credentialCount === 0
                      ? 'Empty'
                      : `${folder.credentialCount} credential${folder.credentialCount !== 1 ? 's' : ''}`}
                  </p>
                </div>

                {/* Actions */}
                <div className="flex items-center gap-2 shrink-0">
                  {/* View credentials — prominent button */}
                  <button
                    onClick={() => onViewCredentials(folder.id)}
                    className="flex items-center gap-1.5 px-3 py-1.5 bg-indigo-600 text-white rounded-lg text-sm font-medium hover:bg-indigo-700 transition-colors"
                  >
                    <ArrowRight className="w-3.5 h-3.5" />
                    View Credentials
                  </button>
                  <button onClick={() => { setEditingId(folder.id); setEditName(folder.name); }}
                    className="p-2 text-slate-400 hover:text-indigo-600 hover:bg-indigo-50 rounded-lg transition-colors" title="Rename">
                    <Edit2 className="w-3.5 h-3.5" />
                  </button>
                  <button onClick={() => onDelete(folder.id)}
                    className="p-2 text-slate-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors" title="Delete">
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>
              </>
            )}
          </div>

          {folder.children.length > 0 && (
            <div className="border-t border-slate-100">
              <FolderTree
                folders={folder.children} depth={depth + 1}
                editingId={editingId} editName={editName}
                setEditingId={setEditingId} setEditName={setEditName}
                onUpdate={onUpdate} onDelete={onDelete} onViewCredentials={onViewCredentials}
              />
            </div>
          )}
        </div>
      ))}
    </>
  );
}

function flattenFolderList(folders: FolderItem[], prefix = ''): Array<{ id: string; name: string }> {
  const result: Array<{ id: string; name: string }> = [];
  for (const f of folders) {
    result.push({ id: f.id, name: prefix + f.name });
    if (f.children.length) result.push(...flattenFolderList(f.children, prefix + f.name + ' / '));
  }
  return result;
}
