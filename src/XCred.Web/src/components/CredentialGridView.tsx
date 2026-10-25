import { useState } from 'react';
import { Eye, EyeOff, Copy, Check, Trash2, Share2 } from 'lucide-react';
import api from '@/api/client';
import { credentialTypeLabel, credentialTypeIcon, formatDate, cn } from '@/lib/utils';
import { CREDENTIAL_GRID_COLUMNS, readGridField } from '@/lib/gridColumns';
import type { CredentialListItem, DecryptedCredentialMeta } from '@/hooks/useDecryptedCredentials';

const MASK = '••••••••';

/** Spreadsheet-style view of every credential at once — the Grid alternative to CredentialRow's
 *  list rendering, toggled via ViewModeToggle on the Credentials and Folders pages. Read-only:
 *  clicking a row opens the full detail/edit page, same as the list view. */
export default function CredentialGridView({ credentials, decrypted, onOpen, onDelete, onTagClick, selectedIds, onToggleSelect, onToggleSelectAll, sharedWith, onShowShares }: {
  credentials: CredentialListItem[];
  decrypted: Map<string, DecryptedCredentialMeta>;
  onOpen: (id: string) => void;
  onDelete: (id: string, e: React.MouseEvent) => void;
  onTagClick: (tagId: string) => void;
  /** Selection is optional; when supplied a checkbox column leads the grid. While anything is
   *  selected, clicking a row toggles it instead of opening it. */
  selectedIds?: Set<string>;
  onToggleSelect?: (id: string) => void;
  onToggleSelectAll?: () => void;
  /** Names of the people a credential is currently shared with (empty/undefined = not shared). */
  sharedWith?: (id: string) => string[];
  onShowShares?: (id: string) => void;
}) {
  const selectable = !!selectedIds && !!onToggleSelect;
  const selectionActive = selectable && selectedIds.size > 0;
  const allSelected = selectable && credentials.length > 0 && credentials.every(c => selectedIds.has(c.id));
  const someSelected = selectable && !allSelected && credentials.some(c => selectedIds.has(c.id));
  const [revealed, setRevealed] = useState<Set<string>>(new Set());
  const [copied, setCopied] = useState<Set<string>>(new Set());

  const cellKey = (id: string, field: string) => `${id}:${field}`;

  const toggleReveal = (e: React.MouseEvent, id: string, field: string) => {
    e.stopPropagation();
    setRevealed(prev => {
      const next = new Set(prev);
      const key = cellKey(id, field);
      if (next.has(key)) next.delete(key); else next.add(key);
      return next;
    });
  };

  const copyValue = async (e: React.MouseEvent, id: string, field: string, value: string) => {
    e.stopPropagation();
    if (!value) return;
    await navigator.clipboard.writeText(value);
    api.post(`/credentials/${id}/copy`, null, { params: { field } }).catch(() => {});
    const key = cellKey(id, field);
    setCopied(prev => new Set(prev).add(key));
    setTimeout(() => setCopied(prev => { const next = new Set(prev); next.delete(key); return next; }), 2000);
  };

  const SecretCell = ({ id, field, value }: { id: string; field: string; value: string }) => {
    if (!value) return <span className="text-slate-300">—</span>;
    const key = cellKey(id, field);
    const isRevealed = revealed.has(key);
    const isCopied = copied.has(key);
    return (
      <div className="flex items-center gap-1 group/cell">
        <span className={cn('font-mono text-xs truncate max-w-[10rem]', !isRevealed && 'tracking-widest text-slate-400')} title={isRevealed ? value : undefined}>
          {isRevealed ? value : MASK}
        </span>
        <button onClick={e => toggleReveal(e, id, field)} title={isRevealed ? 'Hide' : 'Reveal'}
          className="p-1 rounded hover:bg-slate-100 text-slate-400 hover:text-indigo-600 opacity-0 group-hover/cell:opacity-100 transition-opacity shrink-0">
          {isRevealed ? <EyeOff className="w-3 h-3" /> : <Eye className="w-3 h-3" />}
        </button>
        <button onClick={e => copyValue(e, id, field, value)} title="Copy"
          className="p-1 rounded hover:bg-slate-100 text-slate-400 hover:text-indigo-600 opacity-0 group-hover/cell:opacity-100 transition-opacity shrink-0">
          {isCopied ? <Check className="w-3 h-3 text-emerald-600" /> : <Copy className="w-3 h-3" />}
        </button>
      </div>
    );
  };

  return (
    <div className="bg-white rounded-xl border border-slate-200 overflow-x-auto">
      <table className="w-full text-sm border-collapse">
        <thead>
          <tr className="border-b border-slate-200 bg-slate-50 text-left text-xs font-semibold text-slate-500 uppercase tracking-wide">
            {selectable && (
              <th className="pl-4 pr-1 py-2.5 w-8">
                <input type="checkbox" checked={allSelected} aria-label="Select all rows"
                  ref={el => { if (el) el.indeterminate = someSelected; }}
                  onChange={() => onToggleSelectAll?.()}
                  className="w-4 h-4 rounded border-slate-300 text-indigo-600 focus:ring-indigo-500" />
              </th>
            )}
            <th className="px-4 py-2.5 whitespace-nowrap">Name</th>
            <th className="px-4 py-2.5 whitespace-nowrap">Type</th>
            <th className="px-4 py-2.5 whitespace-nowrap">Link / IP / Hostname</th>
            <th className="px-4 py-2.5 whitespace-nowrap">Username</th>
            <th className="px-4 py-2.5 whitespace-nowrap">Password</th>
            <th className="px-4 py-2.5 whitespace-nowrap">Transaction Password / PIN</th>
            <th className="px-4 py-2.5 whitespace-nowrap">Tags</th>
            <th className="px-4 py-2.5 whitespace-nowrap">Updated</th>
            <th className="px-4 py-2.5 whitespace-nowrap"></th>
          </tr>
        </thead>
        <tbody className="divide-y divide-slate-100">
          {credentials.map(cred => {
            const meta = decrypted.get(cred.id);
            const isSelected = !!selectedIds?.has(cred.id);
            const cols = CREDENTIAL_GRID_COLUMNS[cred.type] ?? {};
            const isExpired = cred.expiryDate && new Date(cred.expiryDate) < new Date();
            const address = readGridField(meta?.fields, cols.addressKey);
            const secondary = readGridField(meta?.fields, cols.secondaryKey);
            const primarySecret = readGridField(meta?.fields, cols.primarySecretKey);
            const secondarySecret = readGridField(meta?.fields, cols.secondarySecretKey);
            return (
              <tr key={cred.id} data-testid="credential-grid-row" data-selected={isSelected ? 'true' : undefined}
                onClick={() => (selectionActive ? onToggleSelect?.(cred.id) : onOpen(cred.id))}
                className={cn('cursor-pointer transition-colors', isSelected ? 'bg-indigo-100/70 hover:bg-indigo-100' : 'hover:bg-slate-50')}>
                {selectable && (
                  <td className={cn('pl-4 pr-1 py-2.5 w-8', isSelected && 'shadow-[inset_3px_0_0_0_var(--color-indigo-500)]')}>
                    <input type="checkbox" checked={isSelected} aria-label="Select row"
                      onClick={e => e.stopPropagation()} onChange={() => onToggleSelect?.(cred.id)}
                      className="w-4 h-4 rounded border-slate-300 text-indigo-600 focus:ring-indigo-500" />
                  </td>
                )}
                <td className="px-4 py-2.5 max-w-[16rem]">
                  <div className="flex items-center gap-1.5">
                    <span className="font-medium text-slate-800 truncate">{meta?.name ?? '…'}</span>
                    {isExpired && <span className="text-[10px] bg-red-100 text-red-600 px-1.5 py-0.5 rounded-full font-medium shrink-0">Expired</span>}
                    {(sharedWith?.(cred.id).length ?? 0) > 0 && (
                      <button type="button" data-testid="shared-icon" onClick={e => { e.stopPropagation(); onShowShares?.(cred.id); }}
                        title={`Shared with ${sharedWith!(cred.id).join(', ')} — click to manage`}
                        className="flex items-center gap-0.5 text-indigo-600 bg-indigo-50 hover:bg-indigo-100 rounded-full px-1.5 py-0.5 text-[10px] font-medium shrink-0">
                        <Share2 className="w-3 h-3" />{sharedWith!(cred.id).length}
                      </button>
                    )}
                  </div>
                </td>
                <td className="px-4 py-2.5 whitespace-nowrap text-slate-500">
                  <span className="mr-1">{credentialTypeIcon(cred.type)}</span>{credentialTypeLabel(cred.type)}
                </td>
                <td className="px-4 py-2.5 max-w-[14rem] truncate text-slate-600" title={address || undefined}>{address || <span className="text-slate-300">—</span>}</td>
                <td className="px-4 py-2.5 max-w-[10rem] truncate text-slate-600" title={secondary || undefined}>{secondary || <span className="text-slate-300">—</span>}</td>
                <td className="px-4 py-2.5"><SecretCell id={cred.id} field={cols.primarySecretKey ?? 'password'} value={primarySecret} /></td>
                <td className="px-4 py-2.5"><SecretCell id={cred.id} field={cols.secondarySecretKey ?? 'transactionSecret'} value={secondarySecret} /></td>
                <td className="px-4 py-2.5">
                  {cred.tags.length > 0 && (
                    <div className="flex gap-1 flex-wrap max-w-[10rem]">
                      {cred.tags.slice(0, 3).map(tag => (
                        <button key={tag.id} onClick={e => { e.stopPropagation(); onTagClick(tag.id); }}
                          className="text-[10px] px-1.5 py-0.5 rounded-full font-medium text-white hover:opacity-80 transition-opacity"
                          style={{ backgroundColor: tag.color }} title={`Filter by tag: ${tag.name}`}>
                          {tag.name}
                        </button>
                      ))}
                    </div>
                  )}
                </td>
                <td className="px-4 py-2.5 whitespace-nowrap text-slate-400 text-xs">{formatDate(cred.updatedAt)}</td>
                <td className="px-4 py-2.5 whitespace-nowrap">
                  <button onClick={e => onDelete(cred.id, e)} title="Delete"
                    className="p-1.5 rounded hover:bg-red-50 text-slate-400 hover:text-red-500 transition-colors">
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
