import toast from 'react-hot-toast';
import BulkShareModal from '@/components/BulkShareModal';
import type { ShareRecipient } from '@/components/BulkShareModal';
import type { useDecryptedCredentials } from '@/hooks/useDecryptedCredentials';

/** "Share this whole folder / credential group": a title plus the ids of every credential under it
 *  (folder = its whole subtree) go through the same per-credential re-encryption as bulk Share. */
export default function ScopeShareModal({ title, ids, bulkShare, onDone, onClose }: {
  title: string;
  ids: string[];
  bulkShare: ReturnType<typeof useDecryptedCredentials>['bulkShare'];
  onDone: () => void;
  onClose: () => void;
}) {
  const share = async (recipient: ShareRecipient, opts: { expiresAt: string | null; untilChanged: boolean }) => {
    try {
      const r = await bulkShare(ids, recipient, opts);
      const plural = (n: number) => `${n} credential${n !== 1 ? 's' : ''}`;
      if (r.shared > 0) toast.success(`Shared ${plural(r.shared)} from ${title} with ${recipient.username}.`);
      if (r.failed.length > 0) toast.error(`${plural(r.failed.length)} could not be shared.`);
      onDone();
      if (r.failed.length === 0) onClose();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Share failed.');
    }
  };
  return <BulkShareModal count={ids.length} title={title} onShare={share} onClose={onClose} />;
}
