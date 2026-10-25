import { useEffect, useState } from 'react';
import { X, Users } from 'lucide-react';
import toast from 'react-hot-toast';
import api from '@/api/client';
import Select from '@/components/Select';

export interface ShareRecipient { id: string; username: string; email: string; publicKey: string }

/** Share every selected credential with one user. The per-credential key re-wrapping happens in the
 *  browser (useDecryptedCredentials.bulkShare); this is just the recipient/expiry picker. */
export default function BulkShareModal({ count, onShare, onClose }: {
  count: number;
  onShare: (recipient: ShareRecipient, opts: { expiresAt: string | null; untilChanged: boolean }) => Promise<void>;
  onClose: () => void;
}) {
  const [peers, setPeers] = useState<ShareRecipient[] | null>(null);
  const [shareWithId, setShareWithId] = useState('');
  const [expiry, setExpiry] = useState('');
  const [untilChanged, setUntilChanged] = useState(false);
  const [sharing, setSharing] = useState(false);

  useEffect(() => {
    api.get('/users').then(r => setPeers(r.data.data)).catch(() => { toast.error('Failed to load users.'); setPeers([]); });
  }, []);

  const submit = async () => {
    const recipient = peers?.find(p => p.id === shareWithId);
    if (!recipient) return;
    setSharing(true);
    try {
      await onShare(recipient, { expiresAt: expiry || null, untilChanged });
    } finally {
      setSharing(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-slate-900/40 flex items-center justify-center z-50 p-4" onClick={onClose}>
      <div data-testid="bulk-share-modal" className="bg-white rounded-xl shadow-xl max-w-md w-full p-5 space-y-4" onClick={e => e.stopPropagation()}>
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Users className="w-4 h-4 text-indigo-600" />
            <h3 className="text-sm font-semibold text-slate-800">Share {count} credential{count !== 1 ? 's' : ''}</h3>
          </div>
          <button onClick={onClose} className="p-1 text-slate-400 hover:text-slate-600 rounded"><X className="w-4 h-4" /></button>
        </div>

        <div>
          <label className="block text-xs font-medium text-slate-500 mb-1">Share with</label>
          <Select value={shareWithId} onChange={setShareWithId} ariaLabel="Share with"
            placeholder={peers === null ? 'Loading…' : 'Select a user…'}
            options={(peers ?? []).map(p => ({ value: p.id, label: p.username, hint: `(${p.email})` }))} />
          {peers?.length === 0 && <p className="text-xs text-slate-400 mt-1">No other users in the organisation.</p>}
        </div>

        <div>
          <label className="block text-xs font-medium text-slate-500 mb-1">Access expires <span className="text-slate-400 font-normal">(optional)</span></label>
          <input type="date" value={expiry} onChange={e => setExpiry(e.target.value)} min={new Date().toISOString().split('T')[0]}
            className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
        </div>

        <label className="flex items-start gap-2.5 cursor-pointer">
          <input type="checkbox" checked={untilChanged} onChange={e => setUntilChanged(e.target.checked)}
            className="mt-0.5 rounded border-slate-300 text-indigo-600 focus:ring-indigo-500" />
          <span className="text-sm text-slate-600">Revoke access automatically if a credential is updated</span>
        </label>

        <div className="bg-indigo-50 border border-indigo-100 rounded-lg p-3 text-xs text-indigo-700">
          Each credential's key is re-encrypted with the recipient's public key in your browser — the server never sees the plaintext.
        </div>

        <div className="flex gap-2 pt-1">
          <button onClick={onClose} disabled={sharing}
            className="flex-1 py-2 border border-slate-200 rounded-lg text-sm text-slate-600 hover:bg-slate-50 disabled:opacity-50">Cancel</button>
          <button onClick={submit} disabled={!shareWithId || sharing}
            className="flex-1 py-2 bg-indigo-600 text-white rounded-lg text-sm font-medium hover:bg-indigo-700 disabled:opacity-50">
            {sharing ? 'Sharing…' : 'Share'}
          </button>
        </div>
      </div>
    </div>
  );
}
