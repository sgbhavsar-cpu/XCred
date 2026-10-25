import { useCallback, useEffect, useState } from 'react';
import api from '@/api/client';
import CredentialSharesDialog from '@/components/CredentialSharesDialog';
import { credentialTypeLabel } from '@/lib/utils';
import type { DecryptedCredentialMeta } from '@/hooks/useDecryptedCredentials';

export interface ShareInfo {
  id: string;
  credentialId: string;
  credentialType: string;
  sharedWithUserId?: string;
  sharedWithUsername?: string;
  sharedWithGroupName?: string;
  expiresAt?: string | null;
  untilChanged: boolean;
  createdAt: string;
}

/** The credentials *I* have shared out (GET /shares/shared-by-me), indexed per credential so list
 *  rows can show a "shared" icon, plus the manage-shares dialog that icon opens. Render `dialog`
 *  once in the host page. Shares whose end date has passed no longer count as "shared". */
export function useCredentialShares(decrypted: Map<string, DecryptedCredentialMeta>) {
  const [shares, setShares] = useState<ShareInfo[]>([]);
  const [openId, setOpenId] = useState<string | null>(null);

  const reload = useCallback(async () => {
    try {
      const res = await api.get('/shares/shared-by-me');
      setShares(res.data.data);
    } catch { /* the icon just doesn't show; the Shared page reports load failures */ }
  }, []);

  useEffect(() => { reload(); }, [reload]);

  const live = (s: ShareInfo) => !s.expiresAt || new Date(s.expiresAt) > new Date();
  const forCredential = (id: string) => shares.filter(s => s.credentialId === id);
  /** Currently-effective shares of one credential (what the row icon reflects). */
  const activeFor = (id: string) => forCredential(id).filter(live);

  const openShares = openId ? forCredential(openId) : [];
  const dialog = openId && (
    <CredentialSharesDialog
      credentialName={decrypted.get(openId)?.name ?? credentialTypeLabel(openShares[0]?.credentialType ?? '')}
      shares={openShares}
      onChanged={reload}
      onClose={() => setOpenId(null)} />
  );

  return { activeFor, open: setOpenId, reload, dialog };
}
