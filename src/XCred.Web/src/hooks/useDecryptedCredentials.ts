import { useCallback, useEffect, useState } from 'react';
import toast from 'react-hot-toast';
import api from '@/api/client';
import { useAuthStore } from '@/store/authStore';
import { decryptCredentialData, encryptCredentialData, CREDENTIAL_FIELDS } from '@/lib/vault';
import type { CredentialPayload } from '@/lib/vault';
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
  const { privateKey, publicKey } = useAuthStore();
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

  /** Copies this credential's primary sensitive field (the first `password`-type field for its
   *  type — e.g. "password" for a login, "passphrase" for an SSH key, "keyValue" for an API
   *  key) to the clipboard, logging it the same way CredentialDetailPage's own copy buttons do.
   *  Returns false if the type has no password-type field at all, or the credential can't be
   *  decrypted — callers use this to show a clear error rather than a silent no-op. */
  const copyPassword = async (id: string): Promise<boolean> => {
    const item = credentials.find(c => c.id === id);
    if (!item || !privateKey) return false;
    const passwordField = (CREDENTIAL_FIELDS[item.type] ?? []).find(f => f.type === 'password');
    if (!passwordField) return false;
    const data = await decryptCredentialData(item.encryptedData, item.dataIv, item.encryptedCredentialKey, privateKey);
    const value = data[passwordField.key];
    if (!value) return false;
    await navigator.clipboard.writeText(value);
    api.post(`/credentials/${id}/copy`, null, { params: { field: passwordField.key } }).catch(() => {});
    return true;
  };

  /** Decrypts a credential and re-encrypts the same data (with " (Copy)" appended to the name)
   *  as a brand-new credential carrying the same type/folder/group/tags — for "duplicate, then
   *  tweak something" rather than starting a new one from scratch. Returns the new id, or null
   *  if it couldn't be duplicated (caller navigates to /credentials/<id>/edit with it). */
  const duplicateCredential = async (id: string): Promise<string | null> => {
    const item = credentials.find(c => c.id === id);
    if (!item || !privateKey || !publicKey) return null;
    const data = await decryptCredentialData(item.encryptedData, item.dataIv, item.encryptedCredentialKey, privateKey);
    const payload: CredentialPayload = { ...data, name: `${data.name ?? credentialTypeLabel(item.type)} (Copy)` };
    const { encryptedData, dataIv, encryptedCredentialKey } = await encryptCredentialData(payload, publicKey);
    const res = await api.post('/credentials', {
      type: item.type,
      encryptedData, dataIv, encryptedCredentialKey,
      expiryDate: item.expiryDate,
      folderId: item.folderId,
      credentialGroupId: item.credentialGroupId,
      tagIds: item.tags.map(t => t.id),
    });
    await refetch();
    return res.data.data.id as string;
  };

  return { credentials, decrypted, loading, refetch, deleteCredential, bulkAssign, bulkTags, copyPassword, duplicateCredential };
}
