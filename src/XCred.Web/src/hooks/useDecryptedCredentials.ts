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

  return { credentials, decrypted, loading, refetch, deleteCredential };
}
