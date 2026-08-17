import { useState } from 'react';
import { X } from 'lucide-react';

const NO_CHANGE = '__no_change__';
const UNASSIGN = '__unassign__';

interface Option { id: string; name: string }

/** Shared by Credentials and Folders pages: lets the user assign a folder and/or credential
 *  group to every selected credential in one call. Each selector is 3-way (leave it alone /
 *  clear it / set it to a specific option) because a bulk edit shouldn't force every selected
 *  credential into the exact same folder AND group unless the user explicitly asked for that. */
export default function BulkEditModal({ count, folders, groups, onApply, onClose }: {
  count: number;
  folders: Option[];
  groups: Option[];
  onApply: (changes: {
    updateFolder?: boolean; folderId?: string | null;
    updateCredentialGroup?: boolean; credentialGroupId?: string | null;
  }) => Promise<void>;
  onClose: () => void;
}) {
  const [folderChoice, setFolderChoice] = useState(NO_CHANGE);
  const [groupChoice, setGroupChoice] = useState(NO_CHANGE);
  const [applying, setApplying] = useState(false);

  const hasChange = folderChoice !== NO_CHANGE || groupChoice !== NO_CHANGE;

  const apply = async () => {
    setApplying(true);
    try {
      await onApply({
        updateFolder: folderChoice !== NO_CHANGE,
        folderId: folderChoice === UNASSIGN ? null : folderChoice === NO_CHANGE ? undefined : folderChoice,
        updateCredentialGroup: groupChoice !== NO_CHANGE,
        credentialGroupId: groupChoice === UNASSIGN ? null : groupChoice === NO_CHANGE ? undefined : groupChoice,
      });
    } finally {
      setApplying(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-slate-900/40 flex items-center justify-center z-50 p-4" onClick={onClose}>
      <div data-testid="bulk-edit-modal" className="bg-white rounded-xl shadow-xl max-w-md w-full p-5 space-y-4" onClick={e => e.stopPropagation()}>
        <div className="flex items-center justify-between">
          <h3 className="text-sm font-semibold text-slate-800">
            Bulk edit {count} credential{count !== 1 ? 's' : ''}
          </h3>
          <button onClick={onClose} className="p-1 text-slate-400 hover:text-slate-600 rounded"><X className="w-4 h-4" /></button>
        </div>

        <div>
          <label className="block text-xs font-medium text-slate-500 mb-1">Folder</label>
          <select value={folderChoice} onChange={e => setFolderChoice(e.target.value)}
            className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white">
            <option value={NO_CHANGE}>Don't change</option>
            <option value={UNASSIGN}>No folder (remove)</option>
            {folders.map(f => <option key={f.id} value={f.id}>{f.name}</option>)}
          </select>
        </div>

        <div>
          <label className="block text-xs font-medium text-slate-500 mb-1">Credential Group</label>
          <select value={groupChoice} onChange={e => setGroupChoice(e.target.value)}
            className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white">
            <option value={NO_CHANGE}>Don't change</option>
            <option value={UNASSIGN}>No group (remove)</option>
            {groups.map(g => <option key={g.id} value={g.id}>{g.name}</option>)}
          </select>
        </div>

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
