import { useState } from 'react';
import { X, Plus, Minus, Trash2 } from 'lucide-react';
import { cn } from '@/lib/utils';
import { hasAnyChange } from '@/lib/bulk';
import type { BulkEditChanges, CustomFieldOp, CustomFieldType, ExpiryChange, NotesMode } from '@/lib/bulk';

const NO_CHANGE = '__no_change__';
const UNASSIGN = '__unassign__';

interface Option { id: string; name: string }
interface TagOption { id: string; name: string; color: string }
type TagState = 'none' | 'add' | 'remove';
type ExpiryMode = 'none' | 'set' | 'extend' | 'clear';
type NotesChoice = 'none' | NotesMode;
interface FieldRow { action: 'set' | 'remove'; label: string; value: string; fieldType: CustomFieldType }

const input = 'w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white';

/** One dialog for every bulk change, shared by the Credentials, Folders and Tags pages. Every section
 *  is "leave alone" by default, so only what the user explicitly touches is applied to the
 *  selection. Folder/group/expiry/tags are server-side metadata; notes and custom fields live in the
 *  encrypted blob and are edited in the browser (see useDecryptedCredentials.bulkEdit). */
export default function BulkEditModal({ count, folders, groups, tags, onApply, onClose }: {
  count: number;
  folders: Option[];
  groups: Option[];
  tags: TagOption[];
  onApply: (changes: BulkEditChanges) => Promise<void>;
  onClose: () => void;
}) {
  const [folderChoice, setFolderChoice] = useState(NO_CHANGE);
  const [groupChoice, setGroupChoice] = useState(NO_CHANGE);
  const [tagStates, setTagStates] = useState<Map<string, TagState>>(new Map());
  const [expiryMode, setExpiryMode] = useState<ExpiryMode>('none');
  const [expiryDate, setExpiryDate] = useState('');
  const [expiryDays, setExpiryDays] = useState('365');
  const [notesChoice, setNotesChoice] = useState<NotesChoice>('none');
  const [notesText, setNotesText] = useState('');
  const [rows, setRows] = useState<FieldRow[]>([]);
  const [applying, setApplying] = useState(false);

  const cycleTag = (id: string) => setTagStates(prev => {
    const next = new Map(prev);
    const cur = next.get(id) ?? 'none';
    next.set(id, cur === 'none' ? 'add' : cur === 'add' ? 'remove' : 'none');
    return next;
  });
  const patchRow = (i: number, p: Partial<FieldRow>) => setRows(prev => prev.map((r, j) => (j === i ? { ...r, ...p } : r)));

  const usableRows = rows.filter(r => r.label.trim());
  const days = Number(expiryDays);
  const expiryValid =
    expiryMode === 'none' || expiryMode === 'clear' ||
    (expiryMode === 'set' && !!expiryDate) ||
    (expiryMode === 'extend' && Number.isInteger(days) && days !== 0);

  const build = (): BulkEditChanges => {
    const c: BulkEditChanges = {};
    if (folderChoice !== NO_CHANGE) c.folder = { id: folderChoice === UNASSIGN ? null : folderChoice };
    if (groupChoice !== NO_CHANGE) c.group = { id: groupChoice === UNASSIGN ? null : groupChoice };
    const add = tags.filter(t => tagStates.get(t.id) === 'add').map(t => t.id);
    const remove = tags.filter(t => tagStates.get(t.id) === 'remove').map(t => t.id);
    if (add.length) c.addTagIds = add;
    if (remove.length) c.removeTagIds = remove;
    if (expiryMode !== 'none') {
      const e: ExpiryChange = expiryMode === 'set' ? { mode: 'set', date: expiryDate }
        : expiryMode === 'extend' ? { mode: 'extend', days } : { mode: 'clear' };
      c.expiry = e;
    }
    if (notesChoice !== 'none') c.notes = { mode: notesChoice, text: notesChoice === 'clear' ? '' : notesText };
    if (usableRows.length) {
      c.customFields = usableRows.map((r): CustomFieldOp =>
        r.action === 'remove'
          ? { action: 'remove', label: r.label }
          : { action: 'set', label: r.label, value: r.value, fieldType: r.fieldType });
    }
    return c;
  };

  const changes = build();
  const notesValid = notesChoice === 'none' || notesChoice === 'clear' || notesText.trim() !== '';
  const canApply = hasAnyChange(changes) && expiryValid && notesValid;

  const apply = async () => {
    setApplying(true);
    try {
      await onApply(changes);
    } finally {
      setApplying(false);
    }
  };

  const section = 'border-t border-slate-100 pt-3';
  const label = 'block text-xs font-medium text-slate-500 mb-1';

  return (
    <div className="fixed inset-0 bg-slate-900/40 flex items-center justify-center z-50 p-4" onClick={onClose}>
      <div data-testid="bulk-edit-modal"
        className="bg-white rounded-xl shadow-xl max-w-lg w-full p-5 space-y-4 max-h-[90vh] overflow-y-auto"
        onClick={e => e.stopPropagation()}>
        <div className="flex items-center justify-between">
          <h3 className="text-sm font-semibold text-slate-800">
            Bulk edit {count} credential{count !== 1 ? 's' : ''}
          </h3>
          <button onClick={onClose} className="p-1 text-slate-400 hover:text-slate-600 rounded"><X className="w-4 h-4" /></button>
        </div>
        <p className="text-xs text-slate-400 -mt-2">Anything left on "Don't change" is not touched.</p>

        <div>
          <label className={label}>Folder</label>
          <select value={folderChoice} onChange={e => setFolderChoice(e.target.value)} className={input}>
            <option value={NO_CHANGE}>Don't change</option>
            <option value={UNASSIGN}>No folder (remove)</option>
            {folders.map(f => <option key={f.id} value={f.id}>{f.name}</option>)}
          </select>
        </div>

        <div>
          <label className={label}>Credential Group</label>
          <select value={groupChoice} onChange={e => setGroupChoice(e.target.value)} className={input}>
            <option value={NO_CHANGE}>Don't change</option>
            <option value={UNASSIGN}>No group (remove)</option>
            {groups.map(g => <option key={g.id} value={g.id}>{g.name}</option>)}
          </select>
        </div>

        <div className={section} data-testid="bulk-tag-edit-modal">
          <label className={label}>Tags</label>
          <p className="text-xs text-slate-500 mb-2">
            Click a tag to add it to every selected credential; click again to remove it instead; a third click leaves it alone.
          </p>
          {tags.length === 0 ? (
            <p className="text-sm text-slate-400">No tags yet — create one from the Tags page first.</p>
          ) : (
            <div className="flex flex-wrap gap-2">
              {tags.map(tag => {
                const state = tagStates.get(tag.id) ?? 'none';
                return (
                  <button key={tag.id} type="button" onClick={() => cycleTag(tag.id)}
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
        </div>

        <div className={section}>
          <label className={label}>Expiry date</label>
          <div className="flex gap-2">
            <select value={expiryMode} onChange={e => setExpiryMode(e.target.value as ExpiryMode)} className={input} aria-label="Expiry change">
              <option value="none">Don't change</option>
              <option value="set">Set to a date</option>
              <option value="extend">Extend by N days</option>
              <option value="clear">Remove expiry</option>
            </select>
            {expiryMode === 'set' && (
              <input type="date" value={expiryDate} onChange={e => setExpiryDate(e.target.value)} className={input} aria-label="Expiry date" />
            )}
            {expiryMode === 'extend' && (
              <input type="number" value={expiryDays} onChange={e => setExpiryDays(e.target.value)} className={cn(input, 'w-28')} aria-label="Days to extend" />
            )}
          </div>
          {expiryMode === 'extend' && (
            <p className="text-xs text-slate-400 mt-1">
              Counted from each credential's own expiry (or from today when it has none). Use a negative number to shorten.
            </p>
          )}
        </div>

        <div className={section}>
          <label className={label}>Notes</label>
          <select value={notesChoice} onChange={e => setNotesChoice(e.target.value as NotesChoice)} className={input} aria-label="Notes change">
            <option value="none">Don't change</option>
            <option value="replace">Replace notes</option>
            <option value="append">Add to the end</option>
            <option value="prepend">Add to the start</option>
            <option value="clear">Clear notes</option>
          </select>
          {(notesChoice === 'replace' || notesChoice === 'append' || notesChoice === 'prepend') && (
            <textarea value={notesText} onChange={e => setNotesText(e.target.value)} rows={3} placeholder="Note text…"
              className={cn(input, 'mt-2 resize-none')} />
          )}
        </div>

        <div className={section}>
          <div className="flex items-center justify-between mb-1">
            <label className={cn(label, 'mb-0')}>Custom fields</label>
            <button type="button" onClick={() => setRows(prev => [...prev, { action: 'set', label: '', value: '', fieldType: 'text' }])}
              className="flex items-center gap-1 text-xs text-indigo-600 hover:text-indigo-700 font-medium">
              <Plus className="w-3.5 h-3.5" /> Add change
            </button>
          </div>
          {rows.length === 0 && <p className="text-xs text-slate-400">Add or update a field on every selected credential, or remove one by its label.</p>}
          <div className="space-y-2">
            {rows.map((r, i) => (
              <div key={i} className="flex gap-2 items-start" data-custom-field-row>
                <select value={r.action} onChange={e => patchRow(i, { action: e.target.value as 'set' | 'remove' })}
                  className={cn(input, 'w-32 shrink-0')} aria-label="Custom field action">
                  <option value="set">Add / update</option>
                  <option value="remove">Remove</option>
                </select>
                <input value={r.label} onChange={e => patchRow(i, { label: e.target.value })} placeholder="Label" className={input} aria-label="Custom field label" />
                {r.action === 'set' && (
                  <>
                    <input value={r.value} onChange={e => patchRow(i, { value: e.target.value })} placeholder="Value" className={input} aria-label="Custom field value"
                      type={r.fieldType === 'password' ? 'password' : 'text'} />
                    <select value={r.fieldType} onChange={e => patchRow(i, { fieldType: e.target.value as CustomFieldType })}
                      className={cn(input, 'w-24 shrink-0')} aria-label="Custom field type">
                      <option value="text">Text</option>
                      <option value="password">Hidden</option>
                      <option value="url">URL</option>
                    </select>
                  </>
                )}
                <button type="button" onClick={() => setRows(prev => prev.filter((_, j) => j !== i))}
                  className="p-2 text-slate-400 hover:text-red-500" title="Remove this change"><Trash2 className="w-4 h-4" /></button>
              </div>
            ))}
          </div>
        </div>

        <div className="flex gap-2 pt-1">
          <button onClick={onClose} disabled={applying}
            className="flex-1 py-2 border border-slate-200 rounded-lg text-sm text-slate-600 hover:bg-slate-50 disabled:opacity-50">
            Cancel
          </button>
          <button onClick={apply} disabled={!canApply || applying}
            className="flex-1 py-2 bg-indigo-600 text-white rounded-lg text-sm font-medium hover:bg-indigo-700 disabled:opacity-50">
            {applying ? 'Applying…' : 'Apply'}
          </button>
        </div>
      </div>
    </div>
  );
}
