import { useEffect, useState } from 'react';
import { Plus, Edit2, Trash2, Check, X, Tag, ArrowRight } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import toast from 'react-hot-toast';
import api from '@/api/client';
import { cn } from '@/lib/utils';

interface TagItem { id: string; name: string; color: string; credentialCount: number }

const PRESET_COLORS = ['#6366f1','#3b82f6','#10b981','#f59e0b','#ef4444','#8b5cf6','#ec4899','#14b8a6','#f97316','#64748b'];

export default function TagsPage() {
  const navigate = useNavigate();
  const [tags, setTags] = useState<TagItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editName, setEditName] = useState('');
  const [editColor, setEditColor] = useState('');
  const [newName, setNewName] = useState('');
  const [newColor, setNewColor] = useState(PRESET_COLORS[0]);
  const [adding, setAdding] = useState(false);

  const load = async () => {
    try {
      const res = await api.get('/tags');
      setTags(res.data.data);
    } finally { setLoading(false); }
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

  return (
    <div className="p-6 max-w-3xl mx-auto">
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
            <button onClick={createTag} className="px-3 py-2 bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 transition-colors">
              <Check className="w-4 h-4" />
            </button>
            <button onClick={() => { setAdding(false); setNewName(''); }} className="px-3 py-2 border border-slate-200 text-slate-500 rounded-lg hover:bg-slate-50 transition-colors">
              <X className="w-4 h-4" />
            </button>
          </div>
        </div>
      )}

      {loading ? (
        <div className="flex justify-center py-16"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600" /></div>
      ) : tags.length === 0 ? (
        <div className="text-center py-16 text-slate-400">
          <Tag className="w-10 h-10 mx-auto mb-3 opacity-30" />
          <p className="font-medium">No tags yet.</p>
          <button onClick={() => setAdding(true)} className="mt-3 text-indigo-600 text-sm hover:underline">Create your first tag →</button>
        </div>
      ) : (
        <div className="bg-white rounded-xl border border-slate-200 divide-y divide-slate-100 overflow-hidden">
          {tags.map(tag => (
            <div key={tag.id} className="flex items-center gap-4 px-5 py-4">
              {editingId === tag.id ? (
                <>
                  {/* Color picker in edit mode */}
                  <div className="flex gap-1.5 flex-wrap">
                    {PRESET_COLORS.map(c => (
                      <button key={c} type="button" onClick={() => setEditColor(c)}
                        className={cn('w-5 h-5 rounded-full transition-all', editColor === c && 'ring-2 ring-offset-1 ring-slate-700 scale-110')}
                        style={{ backgroundColor: c }} />
                    ))}
                  </div>
                  <input value={editName} onChange={e => setEditName(e.target.value)} autoFocus
                    onKeyDown={e => { if (e.key === 'Enter') saveEdit(); if (e.key === 'Escape') setEditingId(null); }}
                    className="flex-1 px-3 py-1.5 border border-indigo-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
                  <button onClick={saveEdit} className="p-1.5 bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 transition-colors"><Check className="w-3.5 h-3.5" /></button>
                  <button onClick={() => setEditingId(null)} className="p-1.5 text-slate-400 hover:text-slate-600 transition-colors"><X className="w-3.5 h-3.5" /></button>
                </>
              ) : (
                <>
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
                        {tag.credentialCount === 0
                          ? 'No credentials'
                          : `${tag.credentialCount} credential${tag.credentialCount !== 1 ? 's' : ''}`}
                      </p>
                    </div>
                  </div>

                  <div className="flex items-center gap-2 shrink-0">
                    {/* View credentials — prominent button */}
                    <button
                      onClick={() => navigate(`/credentials?tag=${tag.id}`)}
                      className="flex items-center gap-1.5 px-3 py-1.5 bg-indigo-600 text-white rounded-lg text-sm font-medium hover:bg-indigo-700 transition-colors disabled:opacity-40"
                      disabled={tag.credentialCount === 0}
                    >
                      <ArrowRight className="w-3.5 h-3.5" />
                      View Credentials
                    </button>
                    <button onClick={() => startEdit(tag)}
                      className="p-2 text-slate-400 hover:text-indigo-600 hover:bg-indigo-50 rounded-lg transition-colors" title="Edit">
                      <Edit2 className="w-3.5 h-3.5" />
                    </button>
                    <button onClick={() => deleteTag(tag.id)}
                      className="p-2 text-slate-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors" title="Delete">
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
