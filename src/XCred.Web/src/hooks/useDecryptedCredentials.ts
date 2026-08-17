import { useCallback, useEffect, useState } from 'react';
import toast from 'react-hot-toast';
import api from '@/api/client';
import { useAuthStore } from '@/store/authStore';
import { decryptCredentialData } from '@/lib/vault';
import { credentialTypeLabel } from '@/lib/utils';

export interface CredentialListItem {
  id: string;
  type: string;
  encryptedData: string;
  dataIv: string;
  encryptedCredentialKey: string;
  folderId: string | null;
  credentialGroupId: string | null;
  expiryDate: string | null;
  updatedAt: string;
  tags: Array<{ id: string; name: string; color: string }>;
}

export interface DecryptedCredentialMeta {
  name: string;
  username?: string;
}

/** Shared by Credentials/Folders/Tags pages: fetches every credential the user can see and
 *  decrypts its display name/username once, so each page just needs to group/filter the result. */
export function useDecryptedCredentials() {
  const { privateKey } = useAuthStore();
  const [credentials, setCredentials] = useState<CredentialListItem[]>([]);
  const [decrypted, setDecrypted] = useState<Map<string, DecryptedCredentialMeta>>(new Map());
  const [loading, setLoading] = useState(true);

  const refetch = useCallback(async () => {
    setLoading(true);
    try {
      const res = await api.get('/credentials');
      const items: CredentialListItem[] = res.data.data;
      setCredentials(items);

      if (!privateKey) return;
      const map = new Map<string, DecryptedCredentialMeta>();
      await Promise.all(items.map(async item => {
        try {
          const fields = await decryptCredentialData(item.encryptedData, item.dataIv, item.encryptedCredentialKey, privateKey);
          map.set(item.id, {
            name: (fields.name as string) ?? credentialTypeLabel(item.type),
            username: (fields.username ?? fields.email ?? fields.cardholderName ?? fields.ssid) as string | undefined,
          });
        } catch {
          map.set(item.id, { name: credentialTypeLabel(item.type) });
        }
      }));
      setDecrypted(map);
    } catch {
      toast.error('Failed to load credentials.');
    } finally {
      setLoading(false);
    }
  }, [privateKey]);

  useEffect(() => { refetch(); }, [refetch]);

  const deleteCredential = async (id: string) => {
    await api.delete(`/credentials/${id}`);
    setCredentials(prev => prev.filter(c => c.id !== id));
  };

  /** Reassigns folder and/or credential group for one or many credentials in a single call —
   *  used by both drag-and-drop (one id) and the multi-select bulk-edit toolbar (many ids).
   *  Folder/group are independent: pass updateFolder/updateCredentialGroup to say which one(s)
   *  this call should touch, with folderId/credentialGroupId `null` meaning "unassign". */
  const bulkAssign = async (ids: string[], changes: {
    updateFolder?: boolean; folderId?: string | null;
    updateCredentialGroup?: boolean; credentialGroupId?: string | null;
  }) => {
    const res = await api.patch('/credentials/bulk-assign', { credentialIds: ids, ...changes });
    await refetch();
    return res.data.data as { updated: number; skipped: number };
  };

  /** Adds and/or removes tags across many credentials in one call. Tags are multi-valued per
   *  credential (unlike folder/group), so this is an add/remove delta, not a "set to" value. */
  const bulkTags = async (ids: string[], changes: { addTagIds?: string[]; removeTagIds?: string[] }) => {
    const res = await api.patch('/credentials/bulk-tags', {
      credentialIds: ids,
      addTagIds: changes.addTagIds ?? [],
      removeTagIds: changes.removeTagIds ?? [],
    });
    await refetch();
    return res.data.data as { updated: number; skipped: number };
  };

  return { credentials, decrypted, loading, refetch, deleteCredential, bulkAssign, bulkTags };
}
