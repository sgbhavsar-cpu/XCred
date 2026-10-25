import { useEffect, useState } from 'react';
import { Pencil, Share2, FileSpreadsheet, Trash2, X } from 'lucide-react';
import toast from 'react-hot-toast';
import api from '@/api/client';
import BulkEditModal from './BulkEditModal';
import BulkShareModal from './BulkShareModal';
import type { ShareRecipient } from './BulkShareModal';
import { buildCredentialsCsv, downloadCsv } from '@/lib/csv';
import type { BulkEditChanges } from '@/lib/bulk';
import type { CredentialListItem, DecryptedCredentialMeta, useDecryptedCredentials } from '@/hooks/useDecryptedCredentials';
import { apiErrorMessage } from '@/lib/apiError';

type Bulk = ReturnType<typeof useDecryptedCredentials>;

interface Option { id: string; name: string }
interface TagOption { id: string; name: string; color: string }

interface FolderNode { id: string; name: string; children?: FolderNode[] }

function flattenFolders(nodes: Array<{ id: string; name: string; children?: FolderNode[] }>, prefix = ''): Option[] {
  return nodes.flatMap(f => [{ id: f.id, name: prefix + f.name }, ...(f.children?.length ? flattenFolders(f.children, `${prefix}${f.name} / `) : [])]);
}

/** The sticky bar shown while 1+ credentials are ticked, plus the dialogs it opens. Shared by the
 *  Credentials, Folders and Tags pages so all three offer the same bulk actions: Edit (folder, group,
 *  tags, expiry, notes, custom fields), Share, Export CSV and Delete. Folder/group/tag option lists
 *  are fetched when the edit dialog opens, so pages don't each have to supply them. */
export default function BulkActionBar({ selectedIds, credentials, decrypted, bulk, onClear }: {
  selectedIds: Set<string>;
  credentials: CredentialListItem[];
  decrypted: Map<string, DecryptedCredentialMeta>;
  bulk: Pick<Bulk, 'bulkEdit' | 'bulkDelete' | 'bulkShare'>;
  onClear: () => void;
}) {
  const count = selectedIds.size;
  const [editing, setEditing] = useState(false);
  const [sharing, setSharing] = useState(false);
  const [options, setOptions] = useState<{ folders: Option[]; groups: Option[]; tags: TagOption[] } | null>(null);

  useEffect(() => {
    if (!editing || options) return;
    Promise.all([
      api.get('/folders').catch(() => ({ data: { data: [] } })),
      api.get('/credential-groups').catch(() => ({ data: { data: [] } })),
      api.get('/tags').catch(() => ({ data: { data: [] } })),
    ]).then(([f, g, t]) => setOptions({ folders: flattenFolders(f.data.data), groups: g.data.data, tags: t.data.data }));
  }, [editing, options]);

  if (count === 0) return null;
  const ids = Array.from(selectedIds);
  const plural = (n: number) => `${n} credential${n !== 1 ? 's' : ''}`;

  const applyEdit = async (changes: BulkEditChanges) => {
    try {
      const r = await bulk.bulkEdit(ids, changes);
      toast.success(`Updated ${plural(r.updated)}.`);
      onClear();
      setEditing(false);
    } catch (err) {
      toast.error(apiErrorMessage(err, 'Bulk edit failed.'));
    }
  };

  const exportCsv = () => {
    const picked = credentials.filter(c => selectedIds.has(c.id));
    downloadCsv(`xcred-selected-${new Date().toISOString().slice(0, 10)}.csv`, buildCredentialsCsv(picked, decrypted));
    toast.success(`Exported ${plural(picked.length)} to CSV.`);
  };

  const remove = async () => {
    if (!confirm(`Delete ${plural(count)}? This cannot be undone.`)) return;
    try {
      const r = await bulk.bulkDelete(ids);
      toast.success(`Deleted ${plural(r.updated)}.`);
      onClear();
    } catch (err) {
      toast.error(apiErrorMessage(err, 'Bulk delete failed.'));
    }
  };

  const share = async (recipient: ShareRecipient, opts: { expiresAt: string | null; untilChanged: boolean }) => {
    try {
      const r = await bulk.bulkShare(ids, recipient, opts);
      if (r.shared > 0) toast.success(`Shared ${plural(r.shared)} with ${recipient.username}.`);
      if (r.failed.length > 0) toast.error(`${plural(r.failed.length)} could not be shared.`);
      if (r.failed.length === 0) { onClear(); setSharing(false); }
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Bulk share failed.');
    }
  };

  const btn = 'flex items-center gap-1.5 bg-white/15 hover:bg-white/25 px-3 py-1 rounded-md text-sm font-medium transition-colors';

  return (
    <>
      <div className="sticky top-0 z-10 flex flex-wrap items-center gap-2 bg-indigo-600 text-white px-4 py-2.5 rounded-lg mb-3 shadow-sm">
        <span className="text-sm font-medium mr-1">{count} selected</span>
        <button onClick={() => setEditing(true)} className={btn}><Pencil className="w-3.5 h-3.5" /> Bulk Edit</button>
        <button onClick={() => setSharing(true)} className={btn}><Share2 className="w-3.5 h-3.5" /> Share</button>
        <button onClick={exportCsv} className={btn}><FileSpreadsheet className="w-3.5 h-3.5" /> Export CSV</button>
        <button onClick={remove} className={`${btn} hover:!bg-red-500/80`}><Trash2 className="w-3.5 h-3.5" /> Delete</button>
        <button onClick={onClear} className="ml-auto p-1 hover:bg-white/15 rounded transition-colors" title="Clear selection">
          <X className="w-4 h-4" />
        </button>
      </div>

      {editing && options && (
        <BulkEditModal count={count} folders={options.folders} groups={options.groups} tags={options.tags}
          onApply={applyEdit} onClose={() => setEditing(false)} />
      )}
      {sharing && <BulkShareModal count={count} onShare={share} onClose={() => setSharing(false)} />}
    </>
  );
}
