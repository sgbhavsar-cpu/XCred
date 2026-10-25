import { useState } from 'react';
import { createPortal } from 'react-dom';
import { Clock, Save, ShieldOff, User, Users, X } from 'lucide-react';
import toast from 'react-hot-toast';
import api from '@/api/client';
import { apiErrorMessage } from '@/lib/apiError';
import { formatDate } from '@/lib/utils';
import type { ShareInfo } from '@/hooks/useCredentialShares';

const dateOnly = (iso?: string | null) => (iso ? iso.slice(0, 10) : '');
const isExpired = (s: ShareInfo) => !!s.expiresAt && new Date(s.expiresAt) <= new Date();

/** "Who can see this credential?" — one row per recipient with the access end date, the
 *  revoke-if-credential-changes flag (both editable and saved per row) and an immediate Stop button. */
export default function CredentialSharesDialog({ credentialName, shares, onChanged, onClose }: {
  credentialName: string;
  shares: ShareInfo[];
  onChanged: () => Promise<void> | void;
  onClose: () => void;
}) {
  // Per-row edits kept locally until Save; keyed by share id.
  const [edits, setEdits] = useState<Record<string, { date: string; untilChanged: boolean }>>({});
  const [busy, setBusy] = useState<string | null>(null);

  const view = (s: ShareInfo) => edits[s.id] ?? { date: dateOnly(s.expiresAt), untilChanged: s.untilChanged };
  const dirty = (s: ShareInfo) => { const v = view(s); return v.date !== dateOnly(s.expiresAt) || v.untilChanged !== s.untilChanged; };
  const patch = (s: ShareInfo, p: Partial<{ date: string; untilChanged: boolean }>) =>
    setEdits(prev => ({ ...prev, [s.id]: { ...view(s), ...p } }));

  const save = async (s: ShareInfo) => {
    const v = view(s);
    setBusy(s.id);
    try {
      await api.patch(`/shares/${s.id}`, { expiresAt: v.date || null, untilChanged: v.untilChanged });
      setEdits(prev => { const n = { ...prev }; delete n[s.id]; return n; });
      toast.success('Share updated.');
      await onChanged();
    } catch (err) {
      toast.error(apiErrorMessage(err, 'Failed to update share.'));
    } finally { setBusy(null); }
  };

  const stop = async (list: ShareInfo[], message: string) => {
    if (!confirm(message)) return;
    setBusy('stop');
    try {
      for (const s of list) await api.delete(`/shares/${s.id}`);
      toast.success(list.length === 1 ? 'Sharing stopped.' : 'Sharing stopped for everyone.');
      await onChanged();
      if (list.length === shares.length) onClose();
    } catch (err) {
      toast.error(apiErrorMessage(err, 'Failed to stop sharing.'));
      await onChanged();
    } finally { setBusy(null); }
  };

  const who = (s: ShareInfo) => s.sharedWithUsername ?? s.sharedWithGroupName ?? 'Unknown';

  return createPortal(
    <div className="fixed inset-0 bg-slate-900/40 flex items-center justify-center z-[60] p-4"
      onClick={e => { e.stopPropagation(); onClose(); }}>
      <div data-testid="credential-shares-dialog" className="bg-white rounded-xl shadow-xl max-w-xl w-full p-5 space-y-4 max-h-[85vh] overflow-y-auto"
        onClick={e => e.stopPropagation()}>
        <div className="flex items-center justify-between gap-3">
          <div className="min-w-0">
            <div className="flex items-center gap-2"><Users className="w-4 h-4 text-indigo-600 shrink-0" />
              <h3 className="text-sm font-semibold text-slate-800">Shared with</h3></div>
            <p className="text-xs text-slate-400 truncate mt-0.5">{credentialName}</p>
          </div>
          <button onClick={onClose} className="p-1 text-slate-400 hover:text-slate-600 rounded"><X className="w-4 h-4" /></button>
        </div>

        {shares.length === 0 && <p className="text-sm text-slate-400 py-4 text-center">This credential is not shared with anyone.</p>}

        <div className="space-y-3">
          {shares.map(s => {
            const v = view(s);
            return (
              <div key={s.id} data-testid="share-row" className="border border-slate-200 rounded-lg p-3 space-y-2.5">
                <div className="flex items-center justify-between gap-2">
                  <div className="flex items-center gap-2 min-w-0">
                    <User className="w-4 h-4 text-slate-400 shrink-0" />
                    <span className="text-sm font-medium text-slate-800 truncate">{who(s)}</span>
                    {isExpired(s) && <span className="text-[10px] bg-red-100 text-red-600 px-1.5 py-0.5 rounded-full font-medium">Expired</span>}
                  </div>
                  <span className="text-xs text-slate-400 shrink-0">since {formatDate(s.createdAt)}</span>
                </div>

                <div className="flex flex-wrap items-center gap-x-4 gap-y-2">
                  <label className="flex items-center gap-1.5 text-xs text-slate-500">
                    <Clock className="w-3.5 h-3.5" /> Access ends
                    <input type="date" value={v.date} onChange={e => patch(s, { date: e.target.value })} aria-label="Access end date"
                      className="px-2 py-1 border border-slate-300 rounded-lg text-xs focus:outline-none focus:ring-2 focus:ring-indigo-500" />
                    {v.date && (
                      <button type="button" onClick={() => patch(s, { date: '' })} className="text-slate-400 hover:text-slate-700" title="No end date" aria-label="Clear end date">
                        <X className="w-3 h-3" />
                      </button>
                    )}
                  </label>
                  <label className="flex items-center gap-1.5 text-xs text-slate-600 cursor-pointer">
                    <input type="checkbox" checked={v.untilChanged} onChange={e => patch(s, { untilChanged: e.target.checked })}
                      aria-label="Revoke on change" className="rounded border-slate-300 text-indigo-600 focus:ring-indigo-500" />
                    Revoke if the credential changes
                  </label>
                </div>
                {!v.date && <p className="text-[11px] text-slate-400 -mt-1">No end date — access continues until you stop it.</p>}

                <div className="flex justify-end gap-2">
                  <button onClick={() => save(s)} disabled={!dirty(s) || busy !== null}
                    className="flex items-center gap-1.5 px-3 py-1 rounded-md text-xs font-medium bg-indigo-600 text-white hover:bg-indigo-700 transition-colors disabled:opacity-40">
                    <Save className="w-3.5 h-3.5" /> Save
                  </button>
                  <button onClick={() => stop([s], `Stop sharing with ${who(s)}? They lose access immediately.`)}
                    disabled={busy !== null}
                    className="flex items-center gap-1.5 px-3 py-1 rounded-md text-xs font-medium border border-red-200 text-red-600 hover:bg-red-50 disabled:opacity-40">
                    <ShieldOff className="w-3.5 h-3.5" /> Stop sharing
                  </button>
                </div>
              </div>
            );
          })}
        </div>

        {shares.length > 1 && (
          <button onClick={() => stop(shares, `Stop sharing "${credentialName}" with all ${shares.length} people? They lose access immediately.`)}
            disabled={busy !== null}
            className="w-full py-2 border border-red-200 text-red-600 rounded-lg text-sm font-medium hover:bg-red-50 disabled:opacity-40">
            Stop sharing with everyone
          </button>
        )}
      </div>
    </div>,
    document.body,
  );
}
