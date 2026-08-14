import { useState } from 'react';
import { X, Eye, EyeOff, AlertTriangle, KeyRound } from 'lucide-react';
import api from '@/api/client';
import { deriveKey, decryptPrivateKey, decryptKeyWithPrivateKey, encryptKeyWithPublicKey } from '@/lib/crypto';

// A restore whose backup file carries the exporting account's own crypto material (salt +
// RSA keypair) — present on every backup exported since VaultBackup v1.1. This is what makes
// a backup usable after a fresh re-registration on a different machine: without swapping this
// (new, unrelated) account's identity for the backup's, every restored credential's
// EncryptedCredentialKey stays wrapped under a public key this account has no matching private
// key for, regardless of whether the master password matches (see BackupController.Export's
// comment for the full mechanics).
interface BackupWithKeys {
  keyDerivationSalt: string;
  publicKey: string;
  encryptedPrivateKey: string;
  privateKeyIv: string;
  [key: string]: unknown;
}

interface Props {
  backup: BackupWithKeys;
  currentPrivateKey: CryptoKey | null;
  onClose: () => void;
  onVerified: (symmetricKey: CryptoKey, privateKey: CryptoKey, reWrappedCount: number) => void;
}

type Step = 'idle' | 'verifying' | 'rewrapping' | 'saving';

export default function RestoreAccountKeysModal({ backup, currentPrivateKey, onClose, onVerified }: Props) {
  const [password, setPassword] = useState('');
  const [show, setShow] = useState(false);
  const [step, setStep] = useState<Step>('idle');
  const [error, setError] = useState('');

  const busy = step !== 'idle';

  const handleConfirm = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setStep('verifying');

    // Verify entirely client-side BEFORE touching the server — if the password is wrong,
    // nothing should change about this account. A failed guess here must be a no-op, not a
    // half-applied identity swap.
    let symmetricKey: CryptoKey;
    let backupPrivateKey: CryptoKey;
    try {
      symmetricKey = await deriveKey(password, backup.keyDerivationSalt);
      backupPrivateKey = await decryptPrivateKey(symmetricKey, backup.encryptedPrivateKey, backup.privateKeyIv);
    } catch {
      setError("That master password doesn't match this backup's encryption keys.");
      setStep('idle');
      return;
    }

    try {
      // This (fresh) account may already have its own credentials — swapping the account's
      // keypair out from under them would silently orphan them, so re-wrap anything it
      // already owns under the backup's public key first, exactly like changing the master
      // password does.
      let reEncryptedCredentials: Array<{ credentialId: string; encryptedData: string; dataIv: string; encryptedCredentialKey: string }> = [];
      if (currentPrivateKey) {
        setStep('rewrapping');
        const existingRes = await api.get('/credentials');
        const existing: Array<{ id: string; encryptedData: string; dataIv: string; encryptedCredentialKey: string }> = existingRes.data.data;
        if (existing.length > 0) {
          reEncryptedCredentials = await Promise.all(existing.map(async (cred) => {
            try {
              const credKey = await decryptKeyWithPrivateKey(currentPrivateKey, cred.encryptedCredentialKey);
              const newEncKey = await encryptKeyWithPublicKey(backup.publicKey, credKey);
              return { credentialId: cred.id, encryptedData: cred.encryptedData, dataIv: cred.dataIv, encryptedCredentialKey: newEncKey };
            } catch {
              // Leave it wrapped as-is rather than fail the whole restore over one bad row —
              // matches ChangeMasterKeyTab's own fallback behavior.
              return { credentialId: cred.id, encryptedData: cred.encryptedData, dataIv: cred.dataIv, encryptedCredentialKey: cred.encryptedCredentialKey };
            }
          }));
        }
      }

      setStep('saving');
      await api.post('/auth/change-master-key', {
        newPublicKey: backup.publicKey,
        newEncryptedPrivateKey: backup.encryptedPrivateKey,
        newPrivateKeyIv: backup.privateKeyIv,
        newKeyDerivationSalt: backup.keyDerivationSalt,
        reEncryptedCredentials,
      });

      onVerified(symmetricKey, backupPrivateKey, reEncryptedCredentials.length);
    } catch (err: any) {
      setError(err.response?.data?.error?.message ?? 'Failed to apply the restored keys. Please try again.');
      setStep('idle');
    }
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md">
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-100">
          <h2 className="font-semibold text-slate-900 flex items-center gap-2">
            <KeyRound className="w-4 h-4 text-indigo-600" /> Restore Account Encryption Keys
          </h2>
          <button onClick={onClose} disabled={busy} className="text-slate-400 hover:text-slate-600 transition-colors disabled:opacity-40">
            <X className="w-5 h-5" />
          </button>
        </div>

        <form onSubmit={handleConfirm} className="p-6 space-y-4">
          <div className="bg-amber-50 border border-amber-200 rounded-lg p-3 flex gap-2">
            <AlertTriangle className="w-4 h-4 text-amber-600 shrink-0 mt-0.5" />
            <p className="text-xs text-amber-700">
              This backup includes the original account's encryption keys — this is what lets a
              backup from a different machine's registration actually decrypt here. Confirming
              will replace <b>this</b> account's encryption identity with the one from the
              backup. Enter the master password that was in use when this backup was created
              (usually the one you're already using).
            </p>
          </div>

          <div>
            <label className="block text-sm font-medium text-slate-700 mb-1">Master password</label>
            <div className="relative">
              <input
                type={show ? 'text' : 'password'}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                autoFocus
                autoComplete="off"
                disabled={busy}
                className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 text-sm pr-10 disabled:bg-slate-50"
                placeholder="••••••••"
              />
              <button type="button" onClick={() => setShow(!show)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600">
                {show ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
              </button>
            </div>
            {error && <p className="text-red-500 text-xs mt-1">{error}</p>}
          </div>

          <div className="flex gap-2 justify-end pt-2">
            <button type="button" onClick={onClose} disabled={busy}
              className="px-4 py-2 rounded-lg text-sm font-medium text-slate-600 hover:bg-slate-100 disabled:opacity-40 transition-colors">
              Cancel
            </button>
            <button type="submit" disabled={busy || !password}
              className="bg-indigo-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-indigo-700 disabled:opacity-60 transition-colors">
              {step === 'verifying' ? 'Verifying…' : step === 'rewrapping' ? 'Preparing…' : step === 'saving' ? 'Restoring…' : 'Verify & Restore'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
