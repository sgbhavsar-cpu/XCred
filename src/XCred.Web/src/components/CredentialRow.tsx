import { Eye, Trash2, GripVertical } from 'lucide-react';
import { useDraggable } from '@dnd-kit/core';
import { credentialTypeLabel, credentialTypeIcon, formatDate, cn } from '@/lib/utils';
import type { CredentialListItem, DecryptedCredentialMeta } from '@/hooks/useDecryptedCredentials';

/** Shared row rendering used by the Credentials, Folders, and Tags pages so an expanded
 *  group/folder/tag looks identical to the flat credential list. `draggable` opts a row into
 *  dnd-kit dragging (id `cred:<id>`, see useCredentialDnd) and `selectable` adds a bulk-edit
 *  checkbox — both default off so pages that don't need them (e.g. Tags) are unaffected. */
export default function CredentialRow({
  cred, decrypted, onOpen, onDelete, onTagClick, indent, draggable, selectable, selected, onToggleSelect,
}: {
  cred: CredentialListItem;
  decrypted?: DecryptedCredentialMeta;
  onOpen: () => void;
  onDelete: (e: React.MouseEvent) => void;
  onTagClick: (tagId: string) => void;
  indent?: boolean;
  draggable?: boolean;
  selectable?: boolean;
  selected?: boolean;
  onToggleSelect?: () => void;
}) {
  const isExpired = cred.expiryDate && new Date(cred.expiryDate) < new Date();
  const { attributes, listeners, setNodeRef, transform, isDragging } = useDraggable({
    id: `cred:${cred.id}`,
    disabled: !draggable,
  });

  return (
    <div ref={setNodeRef} onClick={onOpen} data-testid="credential-row"
      style={transform ? { transform: `translate3d(${transform.x}px, ${transform.y}px, 0)`, zIndex: 20 } : undefined}
      className={cn('flex items-center gap-3 px-5 py-3.5 hover:bg-slate-50 cursor-pointer transition-colors relative',
        indent && 'pl-14 bg-slate-50/30', isDragging && 'opacity-40')}>
      {draggable && (
        <button type="button" {...attributes} {...listeners}
          onClick={e => e.stopPropagation()}
          className="shrink-0 text-slate-300 hover:text-slate-500 cursor-grab active:cursor-grabbing touch-none" title="Drag to move">
          <GripVertical className="w-4 h-4" />
        </button>
      )}
      {selectable && (
        <input type="checkbox" checked={!!selected}
          onClick={e => e.stopPropagation()}
          onChange={() => onToggleSelect?.()}
          className="shrink-0 w-4 h-4 rounded border-slate-300 text-indigo-600 focus:ring-indigo-500" />
      )}
      <span className="text-2xl shrink-0">{credentialTypeIcon(cred.type)}</span>
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2">
          <p className="text-sm font-semibold text-slate-800 truncate">{decrypted?.name ?? '…'}</p>
          {isExpired && <span className="text-xs bg-red-100 text-red-600 px-1.5 py-0.5 rounded-full font-medium shrink-0">Expired</span>}
        </div>
        <p className="text-xs text-slate-400 truncate">
          {credentialTypeLabel(cred.type)}{decrypted?.username ? ` · ${decrypted.username}` : ''}
        </p>
        {cred.tags.length > 0 && (
          <div className="flex gap-1 mt-1.5 flex-wrap">
            {cred.tags.slice(0, 5).map(tag => (
              <button key={tag.id}
                onClick={e => { e.stopPropagation(); onTagClick(tag.id); }}
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
        <button onClick={e => { e.stopPropagation(); onOpen(); }}
          className="p-1.5 rounded hover:bg-slate-100 text-slate-400 hover:text-indigo-600 transition-colors" title="View">
          <Eye className="w-3.5 h-3.5" />
        </button>
        <button onClick={onDelete}
          className="p-1.5 rounded hover:bg-red-50 text-slate-400 hover:text-red-500 transition-colors" title="Delete">
          <Trash2 className="w-3.5 h-3.5" />
        </button>
      </div>
    </div>
  );
}
