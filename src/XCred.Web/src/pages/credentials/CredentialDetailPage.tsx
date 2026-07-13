import { useEffect, useRef, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import {
  Edit2, Trash2, Copy, Eye, EyeOff, Share2, ArrowLeft,
  Check, Clock, Tag, Paperclip, Users, Upload, X, Download, Folder, Boxes, ExternalLink,
} from 'lucide-react';
import toast from 'react-hot-toast';
import api from '@/api/client';
import { useAuthStore } from '@/store/authStore';
import { decryptCredentialData, CREDENTIAL_FIELDS } from '@/lib/vault';
import { decrypt, decryptKeyWithPrivateKey, encrypt, encryptKeyWithPublicKey } from '@/lib/crypto';
import { credentialTypeLabel, credentialTypeIcon, formatDate, formatDateTime, isValidUrl } from '@/lib/utils';
import { cn } from '@/lib/utils';

interface CredentialDetail {
  id: string; type: string; encryptedData: string; dataIv: string; encryptedCredentialKey: string;
  expiryDate: string | null; folderId: string | null; folderName: string | null;
  credentialGroupId: string | null; credentialGroupName: string | null;
  ownerId: string; ownerUsername: string;
  createdAt: string; updatedAt: string;
  tags: Array<{ id: string; name: string; color: string }>;
  attachments: Array<{ id: string; encryptedFileName: string; fileNameIv: string; encryptedMimeType: string; mimeTypeIv: string; fileSizeBytes: number; uploadedAt: string }>;
}

interface AttachmentMeta { name: string; mime: string }

interface PeerUser { id: string; username: string; email: string; publicKey: string }

export default function CredentialDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { privateKey } = useAuthStore();
  const fileInputRef = useRef<HTMLInputElement>(null);

  const [cred, setCred] = useState<CredentialDetail | null>(null);
  const [fields, setFields] = useState<Record<string, string>>({});
  const [name, setName] = useState('');
  const [notes, setNotes] = useState('');
  const [customFields, setCustomFields] = useState<Array<{ label: string; value: string; fieldType: string }>>([]);
  const [hidden, setHidden] = useState<Record<string, boolean>>({});
  const [copied, setCopied] = useState<Record<string, boolean>>({});
  const [loading, setLoading] = useState(true);
  const [uploading, setUploading] = useState(false);
  const [attachmentMeta, setAttachmentMeta] = useState<Record<string, AttachmentMeta>>({});

  // Share modal state
  const [showShare, setShowShare] = useState(false);
  const [peers, setPeers] = useState<PeerUser[]>([]);
  const [shareWithId, setShareWithId] = useState('');
  const [shareExpiry, setShareExpiry] = useState('');
  const [untilChanged, setUntilChanged] = useState(false);
  const [sharing, setSharing] = useState(false);

  const loadCred = async () => {
    if (!privateKey) return;
    try {
      const res = await api.get(`/credentials/${id}`);
      const c: CredentialDetail = res.data.data;
      setCred(c);

      const decrypted = await decryptCredentialData(c.encryptedData, c.dataIv, c.encryptedCredentialKey, privateKey);
      setName(decrypted.name ?? '');
      setNotes(decrypted.notes ?? '');
      try { setCustomFields(JSON.parse((decrypted.customFields as string) ?? '[]')); } catch { setCustomFields([]); }

      const fd: Record<string, string> = {};
      const defHidden: Record<string, boolean> = {};
      (CREDENTIAL_FIELDS[c.type] ?? []).forEach(f => {
        fd[f.key] = (decrypted[f.key] as string) ?? '';
        if (f.type === 'password') defHidden[f.key] = true;
      });
      setFields(fd);
      setHidden(defHidden);

      if (c.attachments.length > 0) {
        const credentialKey = await decryptKeyWithPrivateKey(privateKey, c.encryptedCredentialKey);
        const metaEntries = await Promise.all(c.attachments.map(async att => {
          const name = att.fileNameIv
            ? await decrypt(credentialKey, att.encryptedFileName, att.fileNameIv).catch(() => 'Encrypted file')
            : 'Encrypted file';
          const mime = att.mimeTypeIv
            ? await decrypt(credentialKey, att.encryptedMimeType, att.mimeTypeIv).catch(() => 'application/octet-stream')
            : 'application/octet-stream';
          return [att.id, { name, mime }] as const;
        }));
        setAttachmentMeta(Object.fromEntries(metaEntries));
      } else {
        setAttachmentMeta({});
      }
    } catch {
      toast.error('Failed to decrypt credential.');
      navigate('/credentials');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { loadCred(); }, [id, privateKey]);

  const copy = async (value: string, key: string) => {
    await navigator.clipboard.writeText(value);
    setCopied(prev => ({ ...prev, [key]: true }));
    api.post(`/credentials/${id}/copy`, null, { params: { field: key } }).catch(() => {});
    setTimeout(() => setCopied(prev => ({ ...prev, [key]: false })), 2000);
  };

  const handleDelete = async () => {
    if (!confirm('Delete this credential? This cannot be undone.')) return;
    await api.delete(`/credentials/${id}`);
    toast.success('Credential deleted.');
    navigate('/credentials');
  };

  // --- SHARING ---
  const openShareModal = async () => {
    try {
      const res = await api.get('/users');
      setPeers(res.data.data);
    } catch {
      toast.error('Failed to load users.');
      return;
    }
    setShowShare(true);
  };

  const handleShare = async () => {
    if (!shareWithId || !cred || !privateKey) return;
    const recipient = peers.find(p => p.id === shareWithId);
    if (!recipient) return;

    setSharing(true);
    try {
      // 1. Decrypt the per-credential AES key using owner's RSA private key
      const credentialKey = await decryptKeyWithPrivateKey(privateKey, cred.encryptedCredentialKey);

      // 2. Re-encrypt that key with the recipient's RSA public key
      const encryptedKeyForRecipient = await encryptKeyWithPublicKey(recipient.publicKey, credentialKey);

      await api.post(`/shares/credential/${id}`, {
        sharedWithUserId: shareWithId,
        encryptedData: cred.encryptedData,
        dataIv: cred.dataIv,
        encryptedCredentialKey: encryptedKeyForRecipient,
        expiresAt: shareExpiry || null,
        untilChanged,
      });

      toast.success(`Shared with ${recipient.username}.`);
      setShowShare(false);
      setShareWithId(''); setShareExpiry(''); setUntilChanged(false);
    } catch (err: any) {
      toast.error(err.response?.data?.error?.message ?? 'Failed to share.');
    } finally {
      setSharing(false);
    }
  };

  // --- ATTACHMENT UPLOAD ---
  const handleFileSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files;
    if (!files || files.length === 0 || !cred || !privateKey) return;

    const maxMb = 10;
    for (const file of Array.from(files)) {
      if (file.size > maxMb * 1024 * 1024) {
        toast.error(`"${file.name}" is too large. Maximum size is ${maxMb} MB.`);
        if (fileInputRef.current) fileInputRef.current.value = '';
        return;
      }
    }

    setUploading(true);
    try {
      const credentialKey = await decryptKeyWithPrivateKey(privateKey, cred.encryptedCredentialKey);

      for (const file of Array.from(files)) {
        const arrayBuffer = await file.arrayBuffer();
        const fileBase64 = btoa(String.fromCharCode(...new Uint8Array(arrayBuffer)));

        const { ciphertext: encryptedData, iv: dataIv } = await encrypt(credentialKey, fileBase64);
        const { ciphertext: encryptedFileName, iv: fileNameIv } = await encrypt(credentialKey, file.name);
        const { ciphertext: encryptedMimeType, iv: mimeTypeIv } = await encrypt(credentialKey, file.type || 'application/octet-stream');

        await api.post(`/credentials/${id}/attachments`, {
          encryptedFileName,
          fileNameIv,
          encryptedMimeType,
          mimeTypeIv,
          encryptedData,
          dataIv,
          fileSizeBytes: file.size,
        });

        toast.success(`"${file.name}" uploaded and encrypted.`);
      }

      await loadCred();
    } catch {
      toast.error('Failed to upload attachment.');
    } finally {
      setUploading(false);
      if (fileInputRef.current) fileInputRef.current.value = '';
    }
  };

  const handleDownload = async (attId: string) => {
    if (!privateKey || !cred) return;
    try {
      const res = await api.get(`/credentials/${id}/attachments/${attId}`);
      const { encryptedData, dataIv, encryptedFileName, fileNameIv, encryptedMimeType, mimeTypeIv } = res.data.data;

      const credentialKey = await decryptKeyWithPrivateKey(privateKey, cred.encryptedCredentialKey);
      const fileBase64 = await decrypt(credentialKey, encryptedData, dataIv);
      const fileName = fileNameIv
        ? await decrypt(credentialKey, encryptedFileName, fileNameIv).catch(() => 'attachment')
        : 'attachment';
      const mimeType = mimeTypeIv
        ? await decrypt(credentialKey, encryptedMimeType, mimeTypeIv).catch(() => 'application/octet-stream')
        : 'application/octet-stream';

      const binary = atob(fileBase64);
      const bytes = new Uint8Array(binary.length);
      for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);

      // Preserving the original MIME type keeps the browser from guessing an unrelated
      // extension (e.g. defaulting to .txt) for the downloaded file.
      const blob = new Blob([bytes], { type: mimeType });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url; a.download = fileName; a.click();
      URL.revokeObjectURL(url);
    } catch {
      toast.error('Failed to download attachment.');
    }
  };

  const handleDeleteAttachment = async (attId: string) => {
    if (!confirm('Delete this attachment?')) return;
    await api.delete(`/credentials/${id}/attachments/${attId}`);
    toast.success('Attachment deleted.');
    await loadCred();
  };

  if (loading) {
    return <div className="flex justify-center items-center h-full"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600" /></div>;
  }
  if (!cred) return null;

  const typeFields = CREDENTIAL_FIELDS[cred.type] ?? [];
  const isExpired = cred.expiryDate && new Date(cred.expiryDate) < new Date();

  return (
    <div className="p-6 max-w-2xl mx-auto">
      {/* Header */}
      <div className="flex items-start justify-between mb-6">
        <div className="flex items-start gap-3">
          <button onClick={() => navigate(-1)} className="mt-1 text-slate-400 hover:text-slate-600 transition-colors">
            <ArrowLeft className="w-5 h-5" />
          </button>
          <div>
            <div className="flex items-center gap-2 flex-wrap">
              <span className="text-2xl">{credentialTypeIcon(cred.type)}</span>
              <h1 data-field="name" className="text-2xl font-bold text-slate-900">{name}</h1>
              {isExpired && <span className="text-xs bg-red-100 text-red-600 px-2 py-0.5 rounded-full font-medium">Expired</span>}
            </div>
            <p className="text-slate-500 text-sm mt-0.5">{credentialTypeLabel(cred.type)}</p>
          </div>
        </div>
        <div className="flex items-center gap-2 shrink-0">
          <button onClick={openShareModal}
            className="flex items-center gap-1.5 px-3 py-2 border border-slate-200 rounded-lg text-sm text-slate-600 hover:bg-slate-50 transition-colors">
            <Share2 className="w-4 h-4" /> Share
          </button>
          <button onClick={() => navigate(`/credentials/${id}/edit`)}
            className="flex items-center gap-1.5 px-3 py-2 bg-indigo-600 text-white rounded-lg text-sm hover:bg-indigo-700 transition-colors">
            <Edit2 className="w-4 h-4" /> Edit
          </button>
          <button onClick={handleDelete}
            className="p-2 text-slate-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors">
            <Trash2 className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* Credential fields */}
      <div className="bg-white rounded-xl border border-slate-200 divide-y divide-slate-100 overflow-hidden mb-4">
        {typeFields.map(field => {
          const value = fields[field.key] ?? '';
          if (!value || (field.type === 'list' && value === '[]')) return null;
          const isHidden = hidden[field.key] ?? false;
          const listItems = field.type === 'list' ? safeParseList(value) : null;
          const displayValue = listItems ? listItems.join(', ') : value;
          return (
            <div key={field.key} data-field={field.key} className="px-5 py-3.5 flex items-center justify-between gap-4">
              <div className="flex-1 min-w-0">
                <p className="text-xs text-slate-400 font-medium uppercase tracking-wide">{field.label}</p>
                {listItems ? (
                  <ul className="text-sm text-slate-800 mt-0.5 space-y-0.5">
                    {listItems.map((item, i) => <li key={i} className="break-all">{item}</li>)}
                  </ul>
                ) : (
                  <p className={cn(
                    'text-sm text-slate-800 mt-0.5 break-all',
                    field.type === 'textarea' && 'whitespace-pre-wrap font-mono text-xs',
                    isHidden && 'font-mono tracking-widest text-slate-400'
                  )}>
                    {isHidden ? '•'.repeat(12) : value}
                  </p>
                )}
              </div>
              <div className="flex items-center gap-1 shrink-0">
                {field.type === 'password' && (
                  <button onClick={() => setHidden(prev => ({ ...prev, [field.key]: !prev[field.key] }))}
                    className="p-1.5 rounded-lg text-slate-400 hover:text-slate-600 hover:bg-slate-50 transition-colors">
                    {isHidden ? <Eye className="w-4 h-4" /> : <EyeOff className="w-4 h-4" />}
                  </button>
                )}
                {field.type === 'url' && isValidUrl(value) && (
                  <button onClick={() => window.open(value, '_blank', 'noopener,noreferrer')}
                    className="p-1.5 rounded-lg text-slate-400 hover:text-indigo-600 hover:bg-indigo-50 transition-colors" title="Open in new tab">
                    <ExternalLink className="w-4 h-4" />
                  </button>
                )}
                <button onClick={() => copy(displayValue, field.key)}
                  className="p-1.5 rounded-lg text-slate-400 hover:text-indigo-600 hover:bg-indigo-50 transition-colors">
                  {copied[field.key] ? <Check className="w-4 h-4 text-emerald-500" /> : <Copy className="w-4 h-4" />}
                </button>
              </div>
            </div>
          );
        })}

        {notes && (
          <div className="px-5 py-3.5">
            <p className="text-xs text-slate-400 font-medium uppercase tracking-wide mb-1">Notes</p>
            <p className="text-sm text-slate-700 whitespace-pre-wrap">{notes}</p>
          </div>
        )}
      </div>

      {/* Custom fields */}
      {customFields.length > 0 && (
        <div className="bg-white rounded-xl border border-slate-200 divide-y divide-slate-100 overflow-hidden mb-4">
          <div className="px-5 py-3 bg-slate-50">
            <p className="text-xs font-semibold text-slate-500 uppercase tracking-wide">Custom Fields</p>
          </div>
          {customFields.map((cf, i) => {
            const cfKey = `cf_${i}`;
            const isHidden = cf.fieldType === 'password' ? (hidden[cfKey] ?? true) : false;
            return (
              <div key={i} className="px-5 py-3.5 flex items-center justify-between gap-4">
                <div className="flex-1 min-w-0">
                  <p className="text-xs text-slate-400 font-medium uppercase tracking-wide">{cf.label}</p>
                  <p className="text-sm text-slate-800 mt-0.5 break-all">
                    {isHidden ? '•'.repeat(12) : cf.value}
                  </p>
                </div>
                <div className="flex items-center gap-1 shrink-0">
                  {cf.fieldType === 'password' && (
                    <button onClick={() => setHidden(prev => ({ ...prev, [cfKey]: !prev[cfKey] }))}
                      className="p-1.5 rounded-lg text-slate-400 hover:text-slate-600 hover:bg-slate-50">
                      {isHidden ? <Eye className="w-4 h-4" /> : <EyeOff className="w-4 h-4" />}
                    </button>
                  )}
                  <button onClick={() => copy(cf.value, cfKey)}
                    className="p-1.5 rounded-lg text-slate-400 hover:text-indigo-600 hover:bg-indigo-50">
                    {copied[cfKey] ? <Check className="w-4 h-4 text-emerald-500" /> : <Copy className="w-4 h-4" />}
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Metadata (tags, expiry, timestamps) */}
      <div className="bg-white rounded-xl border border-slate-200 p-5 space-y-3 mb-4">
        {cred.folderName && (
          <div className="flex items-center gap-2 text-sm">
            <Folder className="w-3.5 h-3.5 text-slate-400" />
            <span className="text-slate-500">Folder:</span>
            <span className="font-medium text-slate-700">{cred.folderName}</span>
          </div>
        )}
        {cred.credentialGroupName && (
          <div className="flex items-center gap-2 text-sm">
            <Boxes className="w-3.5 h-3.5 text-slate-400" />
            <span className="text-slate-500">Credential Group:</span>
            <button onClick={() => navigate(`/credential-groups/${cred.credentialGroupId}`)}
              className="font-medium text-indigo-600 hover:underline">
              {cred.credentialGroupName}
            </button>
          </div>
        )}
        {cred.tags.length > 0 && (
          <div className="flex items-center gap-2 flex-wrap">
            <Tag className="w-3.5 h-3.5 text-slate-400" />
            {cred.tags.map(tag => (
              <span key={tag.id} className="text-xs px-2.5 py-1 rounded-full font-medium text-white"
                style={{ backgroundColor: tag.color }}>{tag.name}</span>
            ))}
          </div>
        )}
        {cred.expiryDate && (
          <div className="flex items-center gap-2 text-sm">
            <Clock className="w-3.5 h-3.5 text-slate-400" />
            <span className="text-slate-500">Expires:</span>
            <span className={cn('font-medium', isExpired ? 'text-red-600' : 'text-slate-700')}>
              {formatDate(cred.expiryDate)}
            </span>
          </div>
        )}
        <div className="grid grid-cols-2 gap-2 text-xs text-slate-400 pt-1 border-t border-slate-100">
          <span>Created {formatDateTime(cred.createdAt)}</span>
          <span>Updated {formatDateTime(cred.updatedAt)}</span>
        </div>
      </div>

      {/* Attachments */}
      <div className="bg-white rounded-xl border border-slate-200 overflow-hidden mb-4">
        <div className="px-5 py-3.5 flex items-center justify-between border-b border-slate-100">
          <div className="flex items-center gap-2">
            <Paperclip className="w-4 h-4 text-slate-400" />
            <span className="font-medium text-slate-800 text-sm">
              Attachments {cred.attachments.length > 0 && `(${cred.attachments.length})`}
            </span>
          </div>
          <>
            <input ref={fileInputRef} type="file" multiple className="hidden" onChange={handleFileSelect} />
            <button
              onClick={() => fileInputRef.current?.click()}
              disabled={uploading}
              className="flex items-center gap-1.5 px-3 py-1.5 border border-slate-200 rounded-lg text-sm text-slate-600 hover:bg-slate-50 disabled:opacity-50 transition-colors"
            >
              <Upload className="w-3.5 h-3.5" />
              {uploading ? 'Encrypting…' : 'Add File'}
            </button>
          </>
        </div>

        {cred.attachments.length === 0 ? (
          <div className="px-5 py-8 text-center text-slate-400">
            <Paperclip className="w-8 h-8 mx-auto mb-2 opacity-30" />
            <p className="text-sm">No attachments yet. Files are encrypted before upload.</p>
          </div>
        ) : (
          <div className="divide-y divide-slate-100">
            {cred.attachments.map(att => (
              <div key={att.id} data-testid="attachment-row" className="px-5 py-3 flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 bg-slate-100 rounded-lg flex items-center justify-center">
                    <Paperclip className="w-4 h-4 text-slate-500" />
                  </div>
                  <div className="min-w-0">
                    <p data-testid="attachment-name" className="text-sm text-slate-700 font-medium truncate" title={attachmentMeta[att.id]?.name}>
                      {attachmentMeta[att.id]?.name ?? 'Decrypting…'}
                    </p>
                    <p className="text-xs text-slate-400">
                      {(att.fileSizeBytes / 1024).toFixed(1)} KB · {formatDate(att.uploadedAt)}
                    </p>
                  </div>
                </div>
                <div className="flex items-center gap-1">
                  <button onClick={() => handleDownload(att.id)}
                    className="p-1.5 text-slate-400 hover:text-indigo-600 hover:bg-indigo-50 rounded-lg transition-colors" title="Download">
                    <Download className="w-4 h-4" />
                  </button>
                  <button onClick={() => handleDeleteAttachment(att.id)}
                    className="p-1.5 text-slate-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors" title="Delete">
                    <X className="w-4 h-4" />
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Share modal */}
      {showShare && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md p-6">
            <div className="flex items-center justify-between mb-5">
              <div className="flex items-center gap-2">
                <Users className="w-5 h-5 text-indigo-600" />
                <h2 className="font-semibold text-slate-900">Share Credential</h2>
              </div>
              <button onClick={() => setShowShare(false)} className="text-slate-400 hover:text-slate-600 transition-colors">
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1">Share With</label>
                <select value={shareWithId} onChange={e => setShareWithId(e.target.value)}
                  className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white">
                  <option value="">Select a user…</option>
                  {peers.map(p => <option key={p.id} value={p.id}>{p.username} ({p.email})</option>)}
                </select>
                {peers.length === 0 && (
                  <p className="text-xs text-slate-400 mt-1">No other users in the organisation.</p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1">
                  Access Expires <span className="text-slate-400 font-normal text-xs">(optional)</span>
                </label>
                <input type="date" value={shareExpiry} onChange={e => setShareExpiry(e.target.value)}
                  min={new Date().toISOString().split('T')[0]}
                  className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>

              <label className="flex items-start gap-2.5 cursor-pointer">
                <input type="checkbox" checked={untilChanged} onChange={e => setUntilChanged(e.target.checked)}
                  className="mt-0.5 rounded border-slate-300 text-indigo-600 focus:ring-indigo-500" />
                <span className="text-sm text-slate-600">
                  Revoke access automatically if this credential is updated
                </span>
              </label>

              <div className="bg-indigo-50 border border-indigo-100 rounded-lg p-3 text-xs text-indigo-700">
                The credential key will be re-encrypted with the recipient's public key — they can decrypt it without the server ever seeing the plaintext.
              </div>

              <div className="flex gap-2 pt-1">
                <button onClick={() => setShowShare(false)}
                  className="flex-1 py-2.5 border border-slate-200 rounded-lg text-sm text-slate-600 hover:bg-slate-50 transition-colors">
                  Cancel
                </button>
                <button onClick={handleShare} disabled={!shareWithId || sharing}
                  className="flex-1 py-2.5 bg-indigo-600 text-white rounded-lg text-sm font-medium hover:bg-indigo-700 disabled:opacity-60 transition-colors">
                  {sharing ? 'Sharing…' : 'Share'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function safeParseList(value: string): string[] | null {
  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed) ? parsed.filter(Boolean) : null;
  } catch {
    return null;
  }
}
