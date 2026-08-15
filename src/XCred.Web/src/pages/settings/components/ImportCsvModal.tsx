import { useMemo, useState } from 'react';
import { X, AlertTriangle, CheckCircle2 } from 'lucide-react';
import api from '@/api/client';
import { encryptCredentialData } from '@/lib/vault';
import { type CsvColumnMapping, guessColumnMapping } from '@/lib/csv';

// CSV exports from Chrome/Firefox/Bitwarden/LastPass/1Password — or someone's own
// spreadsheet — don't share one fixed column layout, so this asks the user to confirm
// the mapping rather than guessing silently. Every imported row becomes a WebsiteLogin
// credential (the one type every such export maps onto cleanly); anything beyond
// name/url/username/password/notes in the source file is simply not brought in.
interface Props {
  headers: string[];
  rows: string[][];
  publicKey: string;
  onClose: () => void;
  onImported: () => void;
}

type Step = 'mapping' | 'importing' | 'done';

const FIELD_LABELS: Record<keyof CsvColumnMapping, string> = {
  name: 'Name',
  url: 'URL',
  username: 'Username',
  password: 'Password',
  notes: 'Notes',
};

export default function ImportCsvModal({ headers, rows, publicKey, onClose, onImported }: Props) {
  const [mapping, setMapping] = useState<CsvColumnMapping>(() => guessColumnMapping(headers));
  const [step, setStep] = useState<Step>('mapping');
  const [progress, setProgress] = useState(0);
  const [result, setResult] = useState({ created: 0, skipped: 0, failed: 0 });

  const nonEmptyRows = useMemo(() => rows.filter(r => r.some(c => c.trim() !== '')), [rows]);
  const cell = (row: string[], colIndex: number | null) =>
    colIndex === null ? '' : (row[colIndex] ?? '').trim();

  const handleImport = async () => {
    setStep('importing');
    let created = 0, skipped = 0, failed = 0;

    // Sequential, not Promise.all — a CSV can be hundreds of rows, and this is already
    // fast enough per-row (one AES-GCM + one RSA-OAEP encrypt) that parallelizing just
    // risks hammering the API; sequential also makes the progress counter meaningful.
    for (let i = 0; i < nonEmptyRows.length; i++) {
      const row = nonEmptyRows[i];
      setProgress(i + 1);
      const name = cell(row, mapping.name);
      const url = cell(row, mapping.url);
      const username = cell(row, mapping.username);
      const password = cell(row, mapping.password);
      const notes = cell(row, mapping.notes);

      if (!name && !url && !username && !password) { skipped++; continue; }

      try {
        const payload = {
          name: name || url || username || 'Imported credential',
          notes,
          customFields: '[]',
          url,
          username,
          password,
        };
        const { encryptedData, dataIv, encryptedCredentialKey } = await encryptCredentialData(payload, publicKey);
        await api.post('/credentials', {
          type: 'WebsiteLogin',
          encryptedData, dataIv, encryptedCredentialKey,
          expiryDate: null, folderId: null, credentialGroupId: null, tagIds: [],
        });
        created++;
      } catch {
        failed++;
      }
    }

    setResult({ created, skipped, failed });
    setStep('done');
    if (created > 0) onImported();
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-2xl max-h-[90vh] flex flex-col">
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-100">
          <h2 className="font-semibold text-slate-900">Import from CSV</h2>
          <button onClick={onClose} disabled={step === 'importing'}
            className="text-slate-400 hover:text-slate-600 transition-colors disabled:opacity-40">
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="p-6 overflow-y-auto space-y-4">
          {step === 'mapping' && (
            <>
              <p className="text-sm text-slate-500">
                Match each CSV column to a field. Every row becomes a Website Login
                credential — {nonEmptyRows.length} row{nonEmptyRows.length === 1 ? '' : 's'} found.
              </p>
              <div className="grid grid-cols-2 gap-3">
                {(Object.keys(FIELD_LABELS) as Array<keyof CsvColumnMapping>).map(field => (
                  <div key={field}>
                    <label className="block text-xs font-medium text-slate-600 mb-1">{FIELD_LABELS[field]}</label>
                    <select
                      value={mapping[field] ?? ''}
                      onChange={e => setMapping(m => ({ ...m, [field]: e.target.value === '' ? null : Number(e.target.value) }))}
                      className="w-full px-2 py-1.5 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500">
                      <option value="">— Not in this file —</option>
                      {headers.map((h, i) => <option key={i} value={i}>{h || `Column ${i + 1}`}</option>)}
                    </select>
                  </div>
                ))}
              </div>

              {mapping.name === null && mapping.url === null && mapping.username === null && (
                <div className="bg-amber-50 border border-amber-200 rounded-lg p-3 flex gap-2">
                  <AlertTriangle className="w-4 h-4 text-amber-600 shrink-0 mt-0.5" />
                  <p className="text-xs text-amber-700">
                    Map at least Name, URL, or Username so imported credentials are identifiable.
                  </p>
                </div>
              )}

              {nonEmptyRows.length > 0 && (
                <div>
                  <p className="text-xs font-medium text-slate-600 mb-1">Preview (first 3 rows)</p>
                  <div className="border border-slate-200 rounded-lg overflow-x-auto">
                    <table className="w-full text-xs">
                      <thead className="bg-slate-50">
                        <tr>
                          {(Object.keys(FIELD_LABELS) as Array<keyof CsvColumnMapping>).map(f => (
                            <th key={f} className="text-left px-2 py-1.5 font-medium text-slate-500">{FIELD_LABELS[f]}</th>
                          ))}
                        </tr>
                      </thead>
                      <tbody>
                        {nonEmptyRows.slice(0, 3).map((row, ri) => (
                          <tr key={ri} className="border-t border-slate-100">
                            {(Object.keys(FIELD_LABELS) as Array<keyof CsvColumnMapping>).map(f => (
                              <td key={f} className="px-2 py-1.5 text-slate-700 max-w-[140px] truncate">
                                {f === 'password' ? (cell(row, mapping[f]) ? '••••••••' : '') : cell(row, mapping[f])}
                              </td>
                            ))}
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              )}
            </>
          )}

          {step === 'importing' && (
            <div className="py-8 text-center">
              <p className="text-sm text-slate-600 mb-3">Importing {progress} of {nonEmptyRows.length}…</p>
              <div className="w-full bg-slate-100 rounded-full h-2">
                <div className="bg-indigo-600 h-2 rounded-full transition-all"
                  style={{ width: `${(progress / Math.max(nonEmptyRows.length, 1)) * 100}%` }} />
              </div>
            </div>
          )}

          {step === 'done' && (
            <div className="bg-emerald-50 border border-emerald-200 rounded-lg p-4">
              <div className="flex items-center gap-2 mb-3">
                <CheckCircle2 className="w-5 h-5 text-emerald-600" />
                <p className="font-semibold text-emerald-800">Import Complete</p>
              </div>
              <div className="grid grid-cols-3 gap-2 text-sm text-emerald-700">
                <span>Created: <b>{result.created}</b></span>
                <span>Empty rows skipped: <b>{result.skipped}</b></span>
                <span>Failed: <b>{result.failed}</b></span>
              </div>
            </div>
          )}
        </div>

        <div className="flex gap-2 justify-end px-6 py-4 border-t border-slate-100">
          {step === 'mapping' && (
            <>
              <button onClick={onClose} className="px-4 py-2 rounded-lg text-sm font-medium text-slate-600 hover:bg-slate-100 transition-colors">
                Cancel
              </button>
              <button onClick={handleImport} disabled={nonEmptyRows.length === 0}
                className="bg-indigo-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-indigo-700 disabled:opacity-60 transition-colors">
                Import {nonEmptyRows.length} row{nonEmptyRows.length === 1 ? '' : 's'}
              </button>
            </>
          )}
          {step === 'done' && (
            <button onClick={onClose} className="bg-indigo-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-indigo-700 transition-colors">
              Done
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
