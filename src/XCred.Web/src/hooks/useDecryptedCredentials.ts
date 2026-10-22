import { useCallback, useEffect, useState } from 'react';
import toast from 'react-hot-toast';
import api from '@/api/client';
import { useAuthStore } from '@/store/authStore';
import { decryptCredentialData, encryptCredentialData, CREDENTIAL_FIELDS } from '@/lib/vault';
import type { CredentialPayload } from '@/lib/vault';
import { credentialTypeLabel } from '@/lib/utils';
import { hasAccountsField, readAccounts } from '@/lib/accounts';
import { decrypt, encrypt, decryptKeyWithPrivateKey, encryptKeyWithPublicKey } from '@/lib/crypto';
import { applyDataChanges, hasDataChange, hasTagChange, nextExpiry } from '@/lib/bulk';
import type { BulkEditChanges } from '@/lib/bulk';

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
  // True when the type has no password-type field at all (not applicable) or a password-type
  // field is actually filled in; false only when the type has one and it's empty — that's the
  // "missing password" signal the Credentials/Folders/Tags toolbar filter looks for.
  hasPassword: boolean;
  /** Full decrypted field set (see CREDENTIAL_FIELDS in lib/vault.ts), used by CredentialGridView
   *  to render type-specific columns (address, password, transaction password/PIN, …). */
  fields?: Record<string, string>;
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
          const defs = CREDENTIAL_FIELDS[item.type] ?? [];
          if (hasAccountsField(defs)) {
            // Server types keep many user/password rows; expose the first row that has a password
            // (else the first row) as virtual username/password so the list, grid, CSV and
            // "missing password" filter keep working off the same keys as every other type.
            const rows = readAccounts(fields);
            const primary = rows.find(a => a.password) ?? rows[0];
            map.set(item.id, {
              name: (fields.name as string) ?? credentialTypeLabel(item.type),
              username: primary?.username || undefined,
              hasPassword: rows.some(a => a.password.trim()),
              fields: { ...(fields as Record<string, string>), username: primary?.username ?? '', password: primary?.password ?? '' },
            });
            return;
          }
          const passwordField = defs.find(f => f.type === 'password');
          map.set(item.id, {
            name: (fields.name as string) ?? credentialTypeLabel(item.type),
            username: (fields.username ?? fields.email ?? fields.cardholderName ?? fields.ssid) as string | undefined,
            hasPassword: !passwordField || !!(fields[passwordField.key] as string | undefined)?.trim(),
            fields: fields as Record<string, string>,
          });
        } catch {
          map.set(item.id, { name: credentialTypeLabel(item.type), hasPassword: true });
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
    const defs = CREDENTIAL_FIELDS[item.type] ?? [];
    const data = await decryptCredentialData(item.encryptedData, item.dataIv, item.encryptedCredentialKey, privateKey);
    const passwordField = defs.find(f => f.type === 'password');
    const accountsPassword = hasAccountsField(defs) ? readAccounts(data).find(a => a.password)?.password : undefined;
    if (!passwordField && !hasAccountsField(defs)) return false;
    const value = accountsPassword ?? (passwordField ? data[passwordField.key] : undefined);
    if (!value) return false;
    await navigator.clipboard.writeText(value);
    api.post(`/credentials/${id}/copy`, null, { params: { field: passwordField?.key ?? 'accounts' } }).catch(() => {});
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

  /** One bulk edit, any mix of: folder, credential group, expiry, tags, notes, custom fields.
   *  Notes/custom fields live inside the encrypted blob, so each selected credential is decrypted,
   *  edited and re-encrypted here in the browser (with its own existing key — sharing/wrapping is
   *  untouched) and then written back in one request. Metadata (folder/group/expiry/tags) goes
   *  through the cheap server-side bulk endpoints. Returns how many credentials were processed. */
  const bulkEdit = async (ids: string[], changes: BulkEditChanges) => {
    const selected = credentials.filter(c => ids.includes(c.id));
    let dataUpdated = 0;

    if (hasDataChange(changes)) {
      if (!privateKey) throw new Error('Vault is locked.');
      const items: Array<{ id: string; encryptedData: string; dataIv: string }> = [];
      for (const c of selected) {
        const credentialKey = await decryptKeyWithPrivateKey(privateKey, c.encryptedCredentialKey);
        const payload = JSON.parse(await decrypt(credentialKey, c.encryptedData, c.dataIv)) as Record<string, unknown>;
        const edited = applyDataChanges(payload, changes);
        const { ciphertext, iv } = await encrypt(credentialKey, JSON.stringify(edited));
        items.push({ id: c.id, encryptedData: ciphertext, dataIv: iv });
      }
      // Chunked so a large selection never exceeds the request-size limit.
      for (let i = 0; i < items.length; i += 50) {
        const res = await api.patch('/credentials/bulk-update-data', { items: items.slice(i, i + 50) });
        dataUpdated += (res.data.data as { updated: number }).updated;
      }
    }

    const folderOrGroup = changes.folder || changes.group;
    const expiry = changes.expiry;
    if (folderOrGroup || (expiry && expiry.mode !== 'extend')) {
      await api.patch('/credentials/bulk-assign', {
        credentialIds: ids,
        updateFolder: !!changes.folder, folderId: changes.folder?.id ?? null,
        updateCredentialGroup: !!changes.group, credentialGroupId: changes.group?.id ?? null,
        updateExpiry: !!expiry && expiry.mode !== 'extend',
        expiryDate: expiry && expiry.mode === 'set' ? expiry.date : null,
      });
    }
    if (expiry?.mode === 'extend') {
      // "Extend" is relative to each credential's own expiry, so group by the resulting date.
      const byDate = new Map<string, string[]>();
      for (const c of selected) {
        const d = nextExpiry(c.expiryDate, expiry)!;
        byDate.set(d, [...(byDate.get(d) ?? []), c.id]);
      }
      for (const [date, group] of byDate) {
        await api.patch('/credentials/bulk-assign', { credentialIds: group, updateExpiry: true, expiryDate: date });
      }
    }
    if (hasTagChange(changes)) {
      await api.patch('/credentials/bulk-tags', {
        credentialIds: ids, addTagIds: changes.addTagIds ?? [], removeTagIds: changes.removeTagIds ?? [],
      });
    }

    await refetch();
    return { updated: selected.length, dataUpdated };
  };

  /** Soft-deletes many credentials in one request. */
  const bulkDelete = async (ids: string[]) => {
    const res = await api.post('/credentials/bulk-delete', { credentialIds: ids });
    await refetch();
    return res.data.data as { updated: number; skipped: number };
  };

  /** Shares every selected credential with one user: for each, unwrap its key with our private key,
   *  re-wrap it with the recipient's public key (the server never sees a plaintext key), then call
   *  the same per-credential share endpoint the detail page uses. Failures are counted, not thrown,
   *  so one already-revoked/odd credential doesn't abort the rest. */
  const bulkShare = async (
    ids: string[],
    recipient: { id: string; publicKey: string },
    opts: { expiresAt: string | null; untilChanged: boolean },
  ) => {
    if (!privateKey) throw new Error('Vault is locked.');
    let shared = 0;
    const failed: string[] = [];
    for (const c of credentials.filter(x => ids.includes(x.id))) {
      try {
        const credentialKey = await decryptKeyWithPrivateKey(privateKey, c.encryptedCredentialKey);
        const encryptedCredentialKey = await encryptKeyWithPublicKey(recipient.publicKey, credentialKey);
        await api.post(`/shares/credential/${c.id}`, {
          sharedWithUserId: recipient.id,
          encryptedData: c.encryptedData, dataIv: c.dataIv, encryptedCredentialKey,
          expiresAt: opts.expiresAt, untilChanged: opts.untilChanged,
        });
        shared++;
      } catch {
        failed.push(c.id);
      }
    }
    return { shared, failed };
  };

  return { credentials, decrypted, loading, refetch, deleteCredential, bulkAssign, bulkTags, bulkEdit, bulkDelete, bulkShare, copyPassword, duplicateCredential };
}
