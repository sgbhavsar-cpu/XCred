// Pure helpers behind the Bulk Edit dialog. They work on the decrypted payload of ONE credential
// (notes is a plain string, customFields is a JSON string), so the hook can apply the same
// change to every selected credential and so they can be unit-checked without a browser.

export type NotesMode = 'replace' | 'append' | 'prepend' | 'clear';
export interface NotesChange { mode: NotesMode; text: string }

export type CustomFieldType = 'text' | 'password' | 'url';
export interface CustomField { label: string; value: string; fieldType: CustomFieldType }

/** `set` updates the field with that label (case-insensitive) or adds it when missing;
 *  `remove` deletes any field with that label. */
export type CustomFieldOp =
  | { action: 'set'; label: string; value: string; fieldType: CustomFieldType }
  | { action: 'remove'; label: string };

export type ExpiryChange =
  | { mode: 'set'; date: string }       // YYYY-MM-DD
  | { mode: 'clear' }
  | { mode: 'extend'; days: number };   // from the current expiry, or from today when there is none

export interface BulkEditChanges {
  folder?: { id: string | null };
  group?: { id: string | null };
  expiry?: ExpiryChange;
  addTagIds?: string[];
  removeTagIds?: string[];
  notes?: NotesChange;
  customFields?: CustomFieldOp[];
}

export const hasDataChange = (c: BulkEditChanges) => !!c.notes || (c.customFields?.length ?? 0) > 0;
export const hasTagChange = (c: BulkEditChanges) => (c.addTagIds?.length ?? 0) > 0 || (c.removeTagIds?.length ?? 0) > 0;
export const hasAnyChange = (c: BulkEditChanges) =>
  !!c.folder || !!c.group || !!c.expiry || hasTagChange(c) || hasDataChange(c);

export function applyNotes(existing: string | undefined, change: NotesChange): string {
  const cur = existing ?? '';
  switch (change.mode) {
    case 'clear': return '';
    case 'replace': return change.text;
    case 'append': return cur ? `${cur}\n${change.text}` : change.text;
    case 'prepend': return cur ? `${change.text}\n${cur}` : change.text;
  }
}

export function parseCustomFields(raw: string | undefined): CustomField[] {
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

/** Returns the new customFields JSON string. */
export function applyCustomFieldOps(raw: string | undefined, ops: CustomFieldOp[]): string {
  let fields = parseCustomFields(raw);
  for (const op of ops) {
    const key = op.label.trim().toLowerCase();
    if (!key) continue;
    if (op.action === 'remove') {
      fields = fields.filter(f => (f.label ?? '').trim().toLowerCase() !== key);
    } else {
      const idx = fields.findIndex(f => (f.label ?? '').trim().toLowerCase() === key);
      const next: CustomField = { label: op.label.trim(), value: op.value, fieldType: op.fieldType };
      if (idx >= 0) fields = fields.map((f, i) => (i === idx ? { ...f, ...next, label: f.label } : f));
      else fields = [...fields, next];
    }
  }
  return JSON.stringify(fields);
}

/** Applies the notes / custom-field part of a bulk edit to one decrypted payload. */
export function applyDataChanges<T extends Record<string, unknown>>(payload: T, changes: BulkEditChanges): T {
  const out: Record<string, unknown> = { ...payload };
  if (changes.notes) out.notes = applyNotes(out.notes as string | undefined, changes.notes);
  if (changes.customFields?.length) {
    out.customFields = applyCustomFieldOps(out.customFields as string | undefined, changes.customFields);
  }
  return out as T;
}

const ymd = (d: Date) => d.toISOString().slice(0, 10);

/** New expiry (YYYY-MM-DD) for one credential, or null to clear it. */
export function nextExpiry(current: string | null | undefined, change: ExpiryChange, today = new Date()): string | null {
  if (change.mode === 'clear') return null;
  if (change.mode === 'set') return change.date;
  const base = current ? new Date(current) : today;
  const next = new Date(Date.UTC(base.getUTCFullYear(), base.getUTCMonth(), base.getUTCDate() + change.days));
  return ymd(next);
}
