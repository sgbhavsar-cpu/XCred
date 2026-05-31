import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { Save, X, Plus, Trash2, Eye, EyeOff, Wand2, ChevronDown } from 'lucide-react';
import toast from 'react-hot-toast';
import api from '@/api/client';
import { useAuthStore } from '@/store/authStore';
import { encryptCredentialData, decryptCredentialData, CREDENTIAL_FIELDS, CREDENTIAL_TYPES } from '@/lib/vault';
import type { FieldDef } from '@/lib/vault';
import { credentialTypeLabel, credentialTypeIcon } from '@/lib/utils';
import { passwordStrength } from '@/lib/crypto';
import PasswordGeneratorModal from './components/PasswordGeneratorModal';
import { cn } from '@/lib/utils';

interface Tag { id: string; name: string; color: string }
interface Folder { id: string; name: string; parentFolderId: string | null }
interface CustomField { label: string; value: string; fieldType: 'text' | 'password' | 'url' }

export default function CredentialFormPage() {
  const navigate = useNavigate();
  const { id } = useParams<{ id: string }>();
  const isEdit = Boolean(id);

  const { publicKey, privateKey } = useAuthStore();

  const [type, setType] = useState('WebsiteLogin');
  const [name, setName] = useState('');
  const [fields, setFields] = useState<Record<string, string>>({});
  const [notes, setNotes] = useState('');
  const [expiryDate, setExpiryDate] = useState('');
  const [folderId, setFolderId] = useState('');
  const [selectedTagIds, setSelectedTagIds] = useState<string[]>([]);
  const [customFields, setCustomFields] = useState<CustomField[]>([]);
  const [showGenerator, setShowGenerator] = useState(false);
  const [generatorTarget, setGeneratorTarget] = useState<string | null>(null);
  const [hidden, setHidden] = useState<Record<string, boolean>>({});
  const [allTags, setAllTags] = useState<Tag[]>([]);
  const [allFolders, setAllFolders] = useState<Folder[]>([]);
  const [saving, setSaving] = useState(false);
  const [loading, setLoading] = useState(isEdit);

  useEffect(() => {
    const loadMeta = async () => {
      const [tagsRes, foldersRes] = await Promise.all([
        api.get('/tags').catch(() => ({ data: { data: [] } })),
        api.get('/folders').catch(() => ({ data: { data: [] } })),
      ]);
      setAllTags(tagsRes.data.data);
      setAllFolders(flattenFolders(foldersRes.data.data));
    };
    loadMeta();
  }, []);

  useEffect(() => {
    if (!isEdit || !privateKey) return;
    const load = async () => {
      try {
        const res = await api.get(`/credentials/${id}`);
        const cred = res.data.data;
        setType(cred.type);
        setExpiryDate(cred.expiryDate ? cred.expiryDate.split('T')[0] : '');
        setFolderId(cred.folderId ?? '');
        setSelectedTagIds(cred.tags.map((t: Tag) => t.id));

        const decrypted = await decryptCredentialData(cred.encryptedData, cred.dataIv, cred.encryptedCredentialKey, privateKey);
        setName(decrypted.name ?? '');
        setNotes(decrypted.notes ?? '');
        setCustomFields(decrypted.customFields ? JSON.parse(decrypted.customFields as string) : []);
        const typeFields = CREDENTIAL_FIELDS[cred.type] ?? [];
        const fieldData: Record<string, string> = {};
        typeFields.forEach(f => { fieldData[f.key] = (decrypted[f.key] as string) ?? ''; });
        setFields(fieldData);
      } catch {
        toast.error('Failed to load credential for editing.');
        navigate('/credentials');
      } finally {
        setLoading(false);
      }
    };
    load();
  }, [id, isEdit, privateKey]);

  // Reset fields when type changes (only on create)
  useEffect(() => {
    if (!isEdit) setFields({});
  }, [type, isEdit]);

  const setField = (key: string, value: string) => setFields(prev => ({ ...prev, [key]: value }));

  const toggleHidden = (key: string) => setHidden(prev => ({ ...prev, [key]: !prev[key] }));

  const openGenerator = (key: string) => { setGeneratorTarget(key); setShowGenerator(true); };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) { toast.error('Name is required.'); return; }
    if (!publicKey) { toast.error('Public key not found. Please log out and log back in.'); return; }

    setSaving(true);
    try {
      const payload = {
        name: name.trim(),
        notes,
        customFields: JSON.stringify(customFields),
        ...fields,
      };

      const { encryptedData, dataIv, encryptedCredentialKey } = await encryptCredentialData(payload, publicKey);

      const body = {
        type,
        encryptedData,
        dataIv,
        encryptedCredentialKey,
        expiryDate: expiryDate || null,
        folderId: folderId || null,
        tagIds: selectedTagIds,
      };

      if (isEdit) {
        await api.put(`/credentials/${id}`, body);
        toast.success('Credential updated.');
      } else {
        await api.post('/credentials', body);
        toast.success('Credential saved securely.');
      }
      navigate('/credentials');
    } catch (err: any) {
      toast.error(err.response?.data?.error?.message ?? 'Failed to save credential.');
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return <div className="flex justify-center items-center h-full"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600" /></div>;
  }

  const typeFields = CREDENTIAL_FIELDS[type] ?? [];

  return (
    <div className="p-6 max-w-2xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-slate-900">{isEdit ? 'Edit Credential' : 'Add Credential'}</h1>
        <button onClick={() => navigate(-1)} className="text-slate-400 hover:text-slate-600">
          <X className="w-5 h-5" />
        </button>
      </div>

      <form onSubmit={handleSubmit} className="space-y-6">
        {/* Type selector */}
        {!isEdit && (
          <div>
            <label className="block text-sm font-medium text-slate-700 mb-2">Credential Type</label>
            <div className="grid grid-cols-3 sm:grid-cols-4 gap-2">
              {CREDENTIAL_TYPES.map(t => (
                <button key={t} type="button" onClick={() => setType(t)}
                  className={cn(
                    'flex flex-col items-center gap-1 p-2.5 rounded-xl border text-xs font-medium transition-all',
                    type === t
                      ? 'border-indigo-500 bg-indigo-50 text-indigo-700 ring-2 ring-indigo-200'
                      : 'border-slate-200 text-slate-600 hover:border-slate-300 hover:bg-slate-50'
                  )}>
                  <span className="text-xl">{credentialTypeIcon(t)}</span>
                  <span className="text-center leading-tight">{credentialTypeLabel(t)}</span>
                </button>
              ))}
            </div>
          </div>
        )}

        <div className="bg-white rounded-xl border border-slate-200 p-5 space-y-4">
          {/* Name */}
          <div>
            <label className="block text-sm font-medium text-slate-700 mb-1">Name <span className="text-red-500">*</span></label>
            <input value={name} onChange={e => setName(e.target.value)} placeholder={`e.g. Company ${credentialTypeLabel(type)}`}
              className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
          </div>

          {/* Type-specific fields */}
          {typeFields.map(field => (
            <FormField key={field.key} field={field} value={fields[field.key] ?? ''}
              onChange={v => setField(field.key, v)}
              hidden={field.type === 'password' ? (hidden[field.key] ?? true) : false}
              onToggleHidden={() => toggleHidden(field.key)}
              onGeneratePassword={() => openGenerator(field.key)}
            />
          ))}

          {/* Notes */}
          <div>
            <label className="block text-sm font-medium text-slate-700 mb-1">Notes <span className="text-slate-400 font-normal text-xs">(optional)</span></label>
            <textarea value={notes} onChange={e => setNotes(e.target.value)} rows={3} placeholder="Additional notes…"
              className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 resize-none" />
          </div>
        </div>

        {/* Custom fields */}
        <div className="bg-white rounded-xl border border-slate-200 p-5">
          <div className="flex items-center justify-between mb-3">
            <h3 className="font-medium text-slate-800 text-sm">Custom Fields</h3>
            <button type="button" onClick={() => setCustomFields(prev => [...prev, { label: '', value: '', fieldType: 'text' }])}
              className="flex items-center gap-1 text-xs text-indigo-600 hover:text-indigo-700 font-medium">
              <Plus className="w-3.5 h-3.5" /> Add Field
            </button>
          </div>
          {customFields.length === 0 && <p className="text-xs text-slate-400">No custom fields. Click "Add Field" to add one.</p>}
          <div className="space-y-2">
            {customFields.map((cf, i) => (
              <div key={i} className="flex gap-2 items-start">
                <input value={cf.label} onChange={e => setCustomFields(prev => prev.map((f, j) => j === i ? { ...f, label: e.target.value } : f))}
                  placeholder="Label" className="w-1/3 px-2.5 py-1.5 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
                <div className="flex-1 relative">
                  <input value={cf.value} type={cf.fieldType === 'password' && hidden[`custom_${i}`] !== false ? 'password' : 'text'}
                    onChange={e => setCustomFields(prev => prev.map((f, j) => j === i ? { ...f, value: e.target.value } : f))}
                    placeholder="Value"
                    className="w-full px-2.5 py-1.5 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 pr-8" />
                  {cf.fieldType === 'password' && (
                    <button type="button" onClick={() => toggleHidden(`custom_${i}`)}
                      className="absolute right-2 top-1/2 -translate-y-1/2 text-slate-400">
                      {hidden[`custom_${i}`] !== false ? <Eye className="w-3.5 h-3.5" /> : <EyeOff className="w-3.5 h-3.5" />}
                    </button>
                  )}
                </div>
                <select value={cf.fieldType} onChange={e => setCustomFields(prev => prev.map((f, j) => j === i ? { ...f, fieldType: e.target.value as 'text' | 'password' | 'url' } : f))}
                  className="px-2 py-1.5 border border-slate-300 rounded-lg text-xs focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white">
                  <option value="text">Text</option>
                  <option value="password">Hidden</option>
                  <option value="url">URL</option>
                </select>
                <button type="button" onClick={() => setCustomFields(prev => prev.filter((_, j) => j !== i))}
                  className="p-1.5 text-slate-400 hover:text-red-500 transition-colors">
                  <Trash2 className="w-3.5 h-3.5" />
                </button>
              </div>
            ))}
          </div>
        </div>

        {/* Metadata */}
        <div className="bg-white rounded-xl border border-slate-200 p-5 space-y-4">
          <h3 className="font-medium text-slate-800 text-sm">Organisation</h3>

          {/* Tags */}
          <div>
            <label className="block text-sm font-medium text-slate-700 mb-2">Tags</label>
            {allTags.length === 0
              ? <p className="text-xs text-slate-400">No tags yet. <a href="/tags" className="text-indigo-600 hover:underline">Create tags</a> first.</p>
              : (
                <div className="flex flex-wrap gap-2">
                  {allTags.map(tag => (
                    <button key={tag.id} type="button"
                      onClick={() => setSelectedTagIds(prev => prev.includes(tag.id) ? prev.filter(id => id !== tag.id) : [...prev, tag.id])}
                      className={cn('px-3 py-1 rounded-full text-xs font-medium border-2 transition-all',
                        selectedTagIds.includes(tag.id) ? 'border-transparent text-white' : 'bg-transparent border-slate-200 text-slate-600')}
                      style={selectedTagIds.includes(tag.id) ? { backgroundColor: tag.color, borderColor: tag.color } : {}}>
                      {tag.name}
                    </button>
                  ))}
                </div>
              )}
          </div>

          {/* Folder */}
          <div>
            <label className="block text-sm font-medium text-slate-700 mb-1">Folder</label>
            <div className="relative">
              <ChevronDown className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400 pointer-events-none" />
              <select value={folderId} onChange={e => setFolderId(e.target.value)}
                className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white appearance-none">
                <option value="">No Folder</option>
                {allFolders.map(f => <option key={f.id} value={f.id}>{f.name}</option>)}
              </select>
            </div>
          </div>

          {/* Expiry */}
          <div>
            <label className="block text-sm font-medium text-slate-700 mb-1">Expiry Date <span className="text-slate-400 font-normal text-xs">(optional)</span></label>
            <input type="date" value={expiryDate} onChange={e => setExpiryDate(e.target.value)}
              className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
          </div>
        </div>

        {/* Actions */}
        <div className="flex gap-3">
          <button type="button" onClick={() => navigate(-1)}
            className="flex-1 py-2.5 border border-slate-300 rounded-lg text-sm font-medium text-slate-600 hover:bg-slate-50 transition-colors">
            Cancel
          </button>
          <button type="submit" disabled={saving}
            className="flex-1 flex items-center justify-center gap-2 bg-indigo-600 text-white py-2.5 rounded-lg text-sm font-medium hover:bg-indigo-700 disabled:opacity-60 transition-colors">
            <Save className="w-4 h-4" />
            {saving ? 'Encrypting & Saving…' : isEdit ? 'Update Credential' : 'Save Credential'}
          </button>
        </div>
      </form>

      {showGenerator && (
        <PasswordGeneratorModal
          onSelect={pw => { if (generatorTarget) setField(generatorTarget, pw); }}
          onClose={() => { setShowGenerator(false); setGeneratorTarget(null); }}
        />
      )}
    </div>
  );
}

function FormField({ field, value, onChange, hidden, onToggleHidden, onGeneratePassword }: {
  field: FieldDef; value: string; onChange: (v: string) => void;
  hidden: boolean; onToggleHidden: () => void; onGeneratePassword: () => void;
}) {
  const strength = field.type === 'password' && value ? passwordStrength(value) : null;

  return (
    <div>
      <label className="block text-sm font-medium text-slate-700 mb-1">
        {field.label}
        {field.optional && <span className="text-slate-400 font-normal text-xs ml-1">(optional)</span>}
      </label>

      {field.type === 'select' ? (
        <div className="relative">
          <ChevronDown className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400 pointer-events-none" />
          <select value={value} onChange={e => onChange(e.target.value)}
            className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white appearance-none">
            <option value="">Select…</option>
            {field.options?.map(o => <option key={o} value={o}>{o}</option>)}
          </select>
        </div>
      ) : field.type === 'textarea' ? (
        <textarea value={value} onChange={e => onChange(e.target.value)} rows={field.rows ?? 4}
          placeholder={field.placeholder}
          className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 resize-none font-mono" />
      ) : (
        <div className="relative">
          <input value={value} onChange={e => onChange(e.target.value)}
            type={field.type === 'password' ? (hidden ? 'password' : 'text') : field.type}
            placeholder={field.placeholder}
            className={cn('w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500',
              field.type === 'password' ? 'pr-20 font-mono' : '')} />
          {field.type === 'password' && (
            <div className="absolute right-2 top-1/2 -translate-y-1/2 flex items-center gap-1">
              <button type="button" onClick={onToggleHidden} className="p-1 text-slate-400 hover:text-slate-600">
                {hidden ? <Eye className="w-4 h-4" /> : <EyeOff className="w-4 h-4" />}
              </button>
              <button type="button" onClick={onGeneratePassword} className="p-1 text-slate-400 hover:text-indigo-600" title="Generate password">
                <Wand2 className="w-4 h-4" />
              </button>
            </div>
          )}
        </div>
      )}

      {strength && (
        <div className="mt-1.5 flex items-center gap-2">
          <div className="flex-1 h-1 bg-slate-200 rounded-full overflow-hidden">
            <div className={cn('h-full rounded-full transition-all', strength.color)} style={{ width: `${(strength.score + 1) * 20}%` }} />
          </div>
          <span className="text-xs text-slate-500">{strength.label}</span>
        </div>
      )}
    </div>
  );
}

function flattenFolders(folders: Array<Folder & { children?: Folder[] }>, prefix = ''): Folder[] {
  const result: Folder[] = [];
  for (const f of folders) {
    result.push({ ...f, name: prefix + f.name });
    if (f.children?.length) result.push(...flattenFolders(f.children, prefix + f.name + ' / '));
  }
  return result;
}
