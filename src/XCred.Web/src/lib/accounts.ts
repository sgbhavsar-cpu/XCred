import type { FieldDef } from './vault';

/** One login on a server credential (Windows Server / Linux Server). Stored as a JSON array in the
 *  `accounts` field of the encrypted payload, the same way list-type fields are. */
export interface Account { label: string; username: string; password: string }

export const ACCOUNTS_KEY = 'accounts';

/** Rows a brand-new credential of this type starts with; the user can edit, delete or add to them. */
export function defaultAccounts(type: string): Account[] {
  switch (type) {
    case 'LinuxServer':
      return ['RDP', 'Root', 'SSH'].map(label => ({ label, username: '', password: '' }));
    case 'WindowsServer':
      return [{ label: 'Administrator', username: '', password: '' }];
    default:
      return [];
  }
}

export function parseAccounts(raw: string | undefined): Account[] {
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return parsed.map(a => ({
      label: String(a?.label ?? ''),
      username: String(a?.username ?? ''),
      password: String(a?.password ?? ''),
    }));
  } catch {
    return [];
  }
}

/** Reads the account rows from a decrypted payload. Windows Server entries saved before accounts
 *  existed carry single `username`/`password` fields; those surface as a first "Default" row and are
 *  written back in the new shape the next time the credential is saved (no bulk migration). */
export function readAccounts(fields: Record<string, unknown> | undefined): Account[] {
  if (!fields) return [];
  const rows = parseAccounts(fields[ACCOUNTS_KEY] as string | undefined);
  if (rows.length > 0 || fields[ACCOUNTS_KEY] !== undefined) return rows;
  const username = String(fields.username ?? '');
  const password = String(fields.password ?? '');
  return username || password ? [{ label: 'Default', username, password }] : [];
}

export const hasAccountsField = (defs: FieldDef[]) => defs.some(f => f.type === 'accounts');

/** Strict dotted-quad check (four 0–255 parts). Used only for a non-blocking warning. */
export function isValidIPv4(value: string): boolean {
  const m = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/.exec(value.trim());
  return !!m && m.slice(1).every(p => Number(p) <= 255);
}
