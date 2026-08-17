import { useState } from 'react';
import { X, Plus, Minus } from 'lucide-react';
import { cn } from '@/lib/utils';

interface TagOption { id: string; name: string; color: string }
type TagState = 'none' | 'add' | 'remove';

/** Unlike BulkEditModal (folder/group — single "set to" value), a credential can carry many
 *  tags at once, so this is an add/remove delta: click a tag once to add it to every selected
 *  credential, again to remove it from every selected credential, again to leave it alone. */
export default function BulkTagEditModal({ count, tags, onApply, onClose }: {
  count: number;
  tags: TagOption[];
  onApply: (changes: { addTagIds: string[]; removeTagIds: string[] }) => Promise<void>;
  onClose: () => void;
}) {
  const [states, setStates] = useState<Map<string, TagState>>(new Map());
  const [applying, setApplying] = useState(false);

  const cycle = (id: string) => setStates(prev => {
    const next = new Map(prev);
    const cur = next.get(id) ?? 'none';
    next.set(id, cur === 'none' ? 'add' : cur === 'add' ? 'remove' : 'none');
    return next;
  });

  const addTagIds = tags.filter(t => states.get(t.id) === 'add').map(t => t.id);
  const removeTagIds = tags.filter(t => states.get(t.id) === 'remove').map(t => t.id);
  const hasChange = addTagIds.length > 0 || removeTagIds.length > 0;

  const apply = async () => {
    setApplying(true);
    try {
      await onApply({ addTagIds, removeTagIds });
    } finally {
      setApplying(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-slate-900/40 flex items-center justify-center z-50 p-4" onClick={onClose}>
      <div data-testid="bulk-tag-edit-modal" className="bg-white rounded-xl shadow-xl max-w-md w-full p-5 space-y-4" onClick={e => e.stopPropagation()}>
        <div className="flex items-center justify-between">
          <h3 className="text-sm font-semibold text-slate-800">
            Bulk edit tags on {count} credential{count !== 1 ? 's' : ''}
          </h3>
          <button onClick={onClose} className="p-1 text-slate-400 hover:text-slate-600 rounded"><X className="w-4 h-4" /></button>
        </div>

        <p className="text-xs text-slate-500">
          Click a tag to add it to every selected credential; click again to remove it instead; a third click leaves it alone.
        </p>

        {tags.length === 0 ? (
          <p className="text-sm text-slate-400">No tags yet — create one from the Tags page first.</p>
        ) : (
          <div className="flex flex-wrap gap-2">
            {tags.map(tag => {
              const state = states.get(tag.id) ?? 'none';
              return (
                <button key={tag.id} type="button" onClick={() => cycle(tag.id)}
                  className={cn(
                    'flex items-center gap-1 text-xs px-2.5 py-1 rounded-full font-medium border-2 transition-all',
                    state === 'none' && 'border-transparent text-white opacity-60 hover:opacity-90',
                    state === 'add' && 'border-emerald-500 text-white ring-2 ring-emerald-200',
                    state === 'remove' && 'border-red-500 text-white ring-2 ring-red-200 line-through',
                  )}
                  style={{ backgroundColor: tag.color }}>
                  {state === 'add' && <Plus className="w-3 h-3" />}
                  {state === 'remove' && <Minus className="w-3 h-3" />}
                  {tag.name}
                </button>
              );
            })}
          </div>
        )}

        <div className="flex gap-2 pt-1">
          <button onClick={onClose} disabled={applying}
            className="flex-1 py-2 border border-slate-200 rounded-lg text-sm text-slate-600 hover:bg-slate-50 disabled:opacity-50">
            Cancel
          </button>
          <button onClick={apply} disabled={!hasChange || applying}
            className="flex-1 py-2 bg-indigo-600 text-white rounded-lg text-sm font-medium hover:bg-indigo-700 disabled:opacity-50">
            {applying ? 'Applying…' : 'Apply'}
          </button>
        </div>
      </div>
    </div>
  );
}
