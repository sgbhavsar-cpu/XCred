import { useState } from 'react';
import { createPortal } from 'react-dom';
import { X } from 'lucide-react';
import toast from 'react-hot-toast';
import api from '@/api/client';
import Select from '@/components/Select';
import { cn } from '@/lib/utils';
import type { SelectOption } from '@/components/Select';
import { apiErrorMessage } from '@/lib/apiError';

/** Small "create it right here" dialogs behind the "+" button next to the Folder / Credential Group
 *  dropdowns, so a record can be made without leaving (and losing) the editor that needs it.
 *  Rendered through a portal so they also work inside <form>s and other modals, and they stop
 *  click/keyboard events from reaching the host editor. */
function Shell({ title, onClose, busy, onSubmit, submitLabel, canSubmit, children }: {
  title: string; onClose: () => void; busy: boolean; onSubmit: () => void; submitLabel: string; canSubmit: boolean;
  children: React.ReactNode;
}) {
  return createPortal(
    <div className="fixed inset-0 bg-slate-900/40 flex items-center justify-center z-[60] p-4"
      onClick={e => { e.stopPropagation(); onClose(); }} onKeyDown={e => e.stopPropagation()}>
      <div data-testid="quick-create-modal" className="bg-white rounded-xl shadow-xl max-w-sm w-full p-5 space-y-4"
        onClick={e => e.stopPropagation()}>
        <div className="flex items-center justify-between">
          <h3 className="text-sm font-semibold text-slate-800">{title}</h3>
          <button type="button" onClick={onClose} className="p-1 text-slate-400 hover:text-slate-600 rounded"><X className="w-4 h-4" /></button>
        </div>
        {children}
        <div className="flex gap-2">
          <button type="button" onClick={onClose} disabled={busy}
            className="flex-1 py-2 border border-slate-200 rounded-lg text-sm text-slate-600 hover:bg-slate-50 disabled:opacity-50">Cancel</button>
          <button type="button" onClick={onSubmit} disabled={!canSubmit || busy}
            className="flex-1 py-2 bg-indigo-600 text-white rounded-lg text-sm font-medium hover:bg-indigo-700 disabled:opacity-50">
            {busy ? 'Creating…' : submitLabel}
          </button>
        </div>
      </div>
    </div>,
    document.body,
  );
}

const textInput = 'w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500';

export function QuickCreateFolderModal({ parentOptions, defaultParentId = '', onCreated, onClose }: {
  /** Existing folders (flattened "A / B" names) offered as the parent. */
  parentOptions: SelectOption[];
  defaultParentId?: string;
  onCreated: (folder: { id: string; name: string; parentFolderId: string | null }) => void;
  onClose: () => void;
}) {
  const [name, setName] = useState('');
  const [parentId, setParentId] = useState(defaultParentId);
  const [busy, setBusy] = useState(false);

  const submit = async () => {
    if (!name.trim() || busy) return;
    setBusy(true);
    try {
      const res = await api.post('/folders', { name: name.trim(), parentFolderId: parentId || null });
      toast.success('Folder created.');
      onCreated(res.data.data);
    } catch (err) {
      toast.error(apiErrorMessage(err, 'Failed to create folder.'));
      setBusy(false);
    }
  };

  return (
    <Shell title="New Folder" onClose={onClose} busy={busy} onSubmit={submit} submitLabel="Create" canSubmit={!!name.trim()}>
      <input value={name} onChange={e => setName(e.target.value)} placeholder="Folder name" autoFocus aria-label="Folder name"
        onKeyDown={e => { if (e.key === 'Enter') { e.preventDefault(); submit(); } if (e.key === 'Escape') onClose(); }}
        className={textInput} />
      <div>
        <label className="block text-xs text-slate-500 mb-1">Parent Folder (optional)</label>
        <Select value={parentId} onChange={setParentId} ariaLabel="Parent folder"
          options={[{ value: '', label: 'None (top-level)' }, ...parentOptions]} />
      </div>
    </Shell>
  );
}

const GROUP_ICONS = ['🏦', '📧', '🌐', '📱', '🏢', '🚗', '🏥', '📦'];

export function QuickCreateGroupModal({ onCreated, onClose }: {
  onCreated: (group: { id: string; name: string; icon: string }) => void;
  onClose: () => void;
}) {
  const [name, setName] = useState('');
  const [icon, setIcon] = useState(GROUP_ICONS[0]);
  const [busy, setBusy] = useState(false);

  const submit = async () => {
    if (!name.trim() || busy) return;
    setBusy(true);
    try {
      const res = await api.post('/credential-groups', { name: name.trim(), icon });
      toast.success('Credential group created.');
      onCreated(res.data.data);
    } catch (err) {
      toast.error(apiErrorMessage(err, 'Failed to create credential group.'));
      setBusy(false);
    }
  };

  return (
    <Shell title="New Credential Group" onClose={onClose} busy={busy} onSubmit={submit} submitLabel="Create" canSubmit={!!name.trim()}>
      <div className="flex gap-2 flex-wrap">
        {GROUP_ICONS.map(i => (
          <button key={i} type="button" onClick={() => setIcon(i)}
            className={cn('text-xl w-10 h-10 rounded-lg border-2 flex items-center justify-center transition-all',
              icon === i ? 'border-indigo-500 bg-indigo-50' : 'border-slate-200 hover:border-slate-300')}>
            {i}
          </button>
        ))}
      </div>
      <input value={name} onChange={e => setName(e.target.value)} placeholder='e.g. "HDFC Bank"' autoFocus aria-label="Credential group name"
        onKeyDown={e => { if (e.key === 'Enter') { e.preventDefault(); submit(); } if (e.key === 'Escape') onClose(); }}
        className={textInput} />
    </Shell>
  );
}
